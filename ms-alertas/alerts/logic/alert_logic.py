from config.mongo import get_db
import datetime


def save_security_alert(report_id, project_id, client_id, detail):
    db = get_db()
    alert = {
        "report_id": report_id,
        "project_id": project_id,
        "client_id": client_id,
        "alert_type": "tampering",
        "detail": detail,
        "timestamp": datetime.datetime.utcnow().isoformat(),
    }
    db["security_alerts"].insert_one(alert)
    return alert


def get_security_alerts(project_id=None):
    db = get_db()
    query = {}
    if project_id:
        query["project_id"] = project_id
    alerts = list(db["security_alerts"].find(query, {"_id": 0}))
    return alerts


def save_audit_log(report_id, project_id, client_id, action, detail):
    db = get_db()
    log = {
        "report_id": report_id,
        "project_id": project_id,
        "client_id": client_id,
        "action": action,
        "detail": detail,
        "timestamp": datetime.datetime.utcnow().isoformat(),
    }
    db["audit_logs"].insert_one(log)
    return log


def get_audit_logs(project_id=None):
    db = get_db()
    query = {}
    if project_id:
        query["project_id"] = project_id
    logs = list(db["audit_logs"].find(query, {"_id": 0}))
    return logs
