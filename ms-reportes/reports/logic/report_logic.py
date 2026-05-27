from config.mongo import get_db
import hashlib
import json


# --- Mock de proyectos (reemplazar por llamada HTTP a ms-proyectos cuando exista) ---

PROJECTS_MOCK = {
    "project-001": {"project_id": "project-001", "name": "Proyecto Alpha", "client_id": "client-001"},
    "project-002": {"project_id": "project-002", "name": "Proyecto Beta",  "client_id": "client-002"},
    "project-003": {"project_id": "project-003", "name": "Proyecto Gamma", "client_id": "client-001"},
}


def get_project(project_id):
    return PROJECTS_MOCK.get(project_id)


# --- Seed data: inserta reportes de prueba si la colección está vacía ---

SEED_REPORTS = [
    {
        "report_id": "report-2026-05",
        "project_id": "project-001",
        "month": "2026-05",
        "currency": "USD",
        "total_cost": 1450,
        "services": [
            {"name": "EC2", "cost": 600, "usage": 140},
            {"name": "S3",  "cost": 350, "usage": 220},
            {"name": "RDS", "cost": 500, "usage": 90},
        ]
    },
    {
        "report_id": "report-2026-04",
        "project_id": "project-001",
        "month": "2026-04",
        "currency": "USD",
        "total_cost": 1200,
        "services": [
            {"name": "EC2", "cost": 500, "usage": 120},
            {"name": "S3",  "cost": 300, "usage": 200},
            {"name": "RDS", "cost": 400, "usage": 80},
        ]
    },
    {
        "report_id": "report-2026-05-p002",
        "project_id": "project-002",
        "month": "2026-05",
        "currency": "USD",
        "total_cost": 980,
        "services": [
            {"name": "EC2", "cost": 400, "usage": 100},
            {"name": "S3",  "cost": 280, "usage": 180},
            {"name": "RDS", "cost": 300, "usage": 60},
        ]
    },
    {
        "report_id": "report-2026-04-p002",
        "project_id": "project-002",
        "month": "2026-04",
        "currency": "USD",
        "total_cost": 870,
        "services": [
            {"name": "EC2", "cost": 350, "usage": 90},
            {"name": "S3",  "cost": 250, "usage": 160},
            {"name": "RDS", "cost": 270, "usage": 55},
        ]
    },
]


def seed_reports_if_empty():
    db = get_db()
    collection = db["reports"]
    if collection.count_documents({}) == 0:
        # Agregar hash de integridad a cada reporte antes de insertar
        for report in SEED_REPORTS:
            report["integrity_hash"] = _compute_hash(report)
        collection.insert_many(SEED_REPORTS)


def _compute_hash(report):
    """Calcula hash SHA256 del contenido del reporte para detectar tampering."""
    data = {k: v for k, v in report.items() if k not in ("integrity_hash", "_id")}
    serialized = json.dumps(data, sort_keys=True)
    return hashlib.sha256(serialized.encode()).hexdigest()


# --- Consultas CQRS: READ MODEL ---

def get_current_consumption(project_id):
    """Lee el reporte del mes actual para un proyecto."""
    db = get_db()
    # Trae el reporte más reciente del proyecto
    report = db["reports"].find_one(
        {"project_id": project_id},
        sort=[("month", -1)]
    )
    return report


def get_last_month_report(project_id, current_month):
    """Lee el reporte del mes anterior al actual."""
    db = get_db()
    report = db["reports"].find_one(
        {"project_id": project_id, "month": {"$lt": current_month}},
        sort=[("month", -1)]
    )
    return report


# --- Consultas CQRS: WRITE MODEL (detección de tampering) ---

def get_report_by_id(report_id):
    db = get_db()
    return db["reports"].find_one({"report_id": report_id})


def verify_integrity(report_id):
    """Verifica si el reporte fue modificado comparando el hash almacenado."""
    report = get_report_by_id(report_id)
    if not report:
        return None, "report_not_found"

    stored_hash = report.get("integrity_hash")
    if not stored_hash:
        return None, "no_hash"

    current_hash = _compute_hash(report)
    tampered = stored_hash != current_hash
    return tampered, report


def save_audit_log(report_id, project_id, detail):
    db = get_db()
    db["audit_logs"].insert_one({
        "report_id": report_id,
        "project_id": project_id,
        "event": "tampering_detected",
        "detail": detail,
        "timestamp": __import__("datetime").datetime.utcnow().isoformat()
    })


def save_security_alert(report_id, project_id):
    db = get_db()
    db["security_alerts"].insert_one({
        "report_id": report_id,
        "project_id": project_id,
        "alert_type": "tampering",
        "timestamp": __import__("datetime").datetime.utcnow().isoformat()
    })
