import time
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
import os
import requests

from reports.logic.report_logic import (
    get_current_consumption,
    get_last_month_report,
    get_project,
    verify_integrity,
    save_audit_log,
    save_security_alert,
    seed_reports_if_empty,
)


# ── Health check ──────────────────────────────────────────────────────────────

def health(request):
    return JsonResponse({"status": "ok", "service": "ms-reportes"})


# ── ASR Latencia ──────────────────────────────────────────────────────────────
# GET /reports/compare-consumption/?project_id=<id>

def compare_consumption(request):
    start = time.perf_counter()

    # Asegurar que haya datos de prueba
    seed_reports_if_empty()

    project_id = request.GET.get("project_id")
    if not project_id:
        return JsonResponse({"error": "project_id requerido"}, status=400)

    # Verificar que el proyecto existe (mock o ms-proyectos)
    project = get_project(project_id)
    if not project:
        return JsonResponse({"error": f"proyecto {project_id} no encontrado"}, status=404)

    # CQRS Read: consumo actual (mes más reciente)
    current = get_current_consumption(project_id)
    if not current:
        return JsonResponse({"error": "no hay reporte actual para este proyecto"}, status=404)

    # CQRS Read: reporte del mes anterior
    last_month = get_last_month_report(project_id, current["month"])
    if not last_month:
        return JsonResponse({"error": "no hay reporte del mes anterior"}, status=404)

    # Calcular variación
    current_cost = current["total_cost"]
    last_cost = last_month["total_cost"]
    difference = current_cost - last_cost
    variation_pct = round((difference / last_cost) * 100, 2) if last_cost else 0

    elapsed_ms = round((time.perf_counter() - start) * 1000, 3)
    asr_threshold = 500

    return JsonResponse({
        "project_id": project_id,
        "project_name": project["name"],
        "project_source": project.get("source", "unknown"),
        "current_month": current["month"],
        "current_consumption": current_cost,
        "last_month": last_month["month"],
        "last_month_consumption": last_cost,
        "difference": difference,
        "variation_percentage": variation_pct,
        "latency_ms": elapsed_ms,
        "asr_threshold_ms": asr_threshold,
        "asr_met": elapsed_ms < asr_threshold,
    })


# ── ASR Seguridad ─────────────────────────────────────────────────────────────
# POST /reports/integrity/check/

@csrf_exempt
@require_http_methods(["POST"])
def integrity_check(request):
    start = time.perf_counter()

    try:
        body = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "body JSON inválido"}, status=400)

    report_id = body.get("report_id")
    project_id = body.get("project_id")

    if not report_id or not project_id:
        return JsonResponse({"error": "report_id y project_id requeridos"}, status=400)

    tampered, report = verify_integrity(report_id)

    if report is None:
        return JsonResponse({"error": report}, status=404)

    audit_created = False
    alert_generated = False

    if tampered:
        alerts_service_url = os.getenv("ALERTS_SERVICE_URL", "")

        if alerts_service_url:
            payload_alert = {
                "report_id": report_id,
                "project_id": project_id,
                "client_id": body.get("client_id", "client-001"),
                "detail": "Hash mismatch detectado"
            }

            payload_audit = {
                "report_id": report_id,
                "project_id": project_id,
                "client_id": body.get("client_id", "client-001"),
                "action": "tampering_detected",
                "detail": "Modificación no autorizada detectada"
            }

            alert_response = requests.post(
                f"{alerts_service_url}/alerts/security/",
                json=payload_alert,
                timeout=0.3
            )

            audit_response = requests.post(
                f"{alerts_service_url}/alerts/audit-log/",
                json=payload_audit,
                timeout=0.3
            )

            alert_generated = alert_response.status_code == 200
            audit_created = audit_response.status_code == 200

    else:
        save_audit_log(report_id, project_id, "Hash mismatch detectado")
        save_security_alert(report_id, project_id)
        audit_created = True
        alert_generated = True

    elapsed_ms = round((time.perf_counter() - start) * 1000, 3)
    asr_threshold = 400

    return JsonResponse({
        "event": "tampering_detected" if tampered else "integrity_ok",
        "report_id": report_id,
        "project_id": project_id,
        "tampering_detected": tampered,
        "audit_log_created": audit_created,
        "security_alert_generated": alert_generated,
        "tampering_detection_time_ms": elapsed_ms,
        "asr_threshold_ms": asr_threshold,
        "asr_met": elapsed_ms < asr_threshold,
    })


# ── Endpoint para simular tampering (usado por ms-clientes o JMeter) ──────────
# POST /reports/tamper/  — solo para experimentos

@csrf_exempt
@require_http_methods(["POST"])
def simulate_tamper(request):
    """Modifica directamente un campo del reporte en MongoDB para simular tampering.
    El integrity_hash queda desactualizado, lo que permite que /integrity/check/ lo detecte."""
    try:
        body = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "body JSON inválido"}, status=400)

    report_id = body.get("report_id")
    field = body.get("field", "total_cost")
    new_value = body.get("new_value", 999999)

    if not report_id:
        return JsonResponse({"error": "report_id requerido"}, status=400)

    from config.mongo import get_db
    db = get_db()
    result = db["reports"].update_one(
        {"report_id": report_id},
        {"$set": {field: new_value}}
        # Nótese: NO actualizamos integrity_hash — eso es lo que simula el tampering
    )

    if result.matched_count == 0:
        return JsonResponse({"error": "reporte no encontrado"}, status=404)

    return JsonResponse({
        "message": f"Campo '{field}' modificado a {new_value} en reporte {report_id}",
        "tampering_simulated": True,
    })
