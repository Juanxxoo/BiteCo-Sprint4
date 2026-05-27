import time
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from alerts.logic.alert_logic import (
    save_security_alert,
    get_security_alerts,
    save_audit_log,
    get_audit_logs,
)


# ── Health check ──────────────────────────────────────────────────────────────

def health(request):
    return JsonResponse({"status": "ok", "service": "ms-alertas"})


# ── Alertas de seguridad ──────────────────────────────────────────────────────

@csrf_exempt
def security_alerts(request):
    if request.method == "POST":
        start = time.perf_counter()

        try:
            body = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({"error": "body JSON inválido"}, status=400)

        report_id = body.get("report_id")
        project_id = body.get("project_id")
        client_id = body.get("client_id", "unknown")
        detail = body.get("detail", "Tampering detectado")

        if not report_id or not project_id:
            return JsonResponse({"error": "report_id y project_id requeridos"}, status=400)

        alert = save_security_alert(report_id, project_id, client_id, detail)

        elapsed_ms = round((time.perf_counter() - start) * 1000, 3)
        asr_threshold = 400

        return JsonResponse({
            "message": "Alerta de seguridad registrada",
            "report_id": report_id,
            "project_id": project_id,
            "alert_type": "tampering",
            "security_alert_generated": True,
            "registration_time_ms": elapsed_ms,
            "asr_threshold_ms": asr_threshold,
            "asr_met": elapsed_ms < asr_threshold,
        })

    elif request.method == "GET":
        project_id = request.GET.get("project_id")
        alerts = get_security_alerts(project_id)
        return JsonResponse({
            "count": len(alerts),
            "alerts": alerts,
        })

    return JsonResponse({"error": "Método no permitido"}, status=405)


# ── Logs de auditoría ─────────────────────────────────────────────────────────

@csrf_exempt
def audit_logs(request):
    if request.method == "POST":
        start = time.perf_counter()

        try:
            body = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({"error": "body JSON inválido"}, status=400)

        report_id = body.get("report_id")
        project_id = body.get("project_id")
        client_id = body.get("client_id", "unknown")
        action = body.get("action", "tampering_detected")
        detail = body.get("detail", "Modificación no autorizada detectada")

        if not report_id or not project_id:
            return JsonResponse({"error": "report_id y project_id requeridos"}, status=400)

        log = save_audit_log(report_id, project_id, client_id, action, detail)

        elapsed_ms = round((time.perf_counter() - start) * 1000, 3)
        asr_threshold = 400

        return JsonResponse({
            "message": "Log de auditoría registrado",
            "report_id": report_id,
            "project_id": project_id,
            "action": action,
            "audit_log_created": True,
            "registration_time_ms": elapsed_ms,
            "asr_threshold_ms": asr_threshold,
            "asr_met": elapsed_ms < asr_threshold,
        })

    elif request.method == "GET":
        project_id = request.GET.get("project_id")
        logs = get_audit_logs(project_id)
        return JsonResponse({
            "count": len(logs),
            "logs": logs,
        })

    return JsonResponse({"error": "Método no permitido"}, status=405)
