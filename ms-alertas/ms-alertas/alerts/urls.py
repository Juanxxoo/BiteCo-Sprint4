from django.urls import path
from .views import health, security_alerts, audit_logs

urlpatterns = [
    path('health/', health, name='health'),
    path('alerts/security/', security_alerts, name='security_alerts'),
    path('alerts/audit-log/', audit_logs, name='audit_logs'),
]
