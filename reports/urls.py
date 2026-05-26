from django.urls import path
from .views import health, compare_consumption, integrity_check, simulate_tamper

urlpatterns = [
    path('health/', health, name='health'),
    path('reports/compare-consumption/', compare_consumption, name='compare_consumption'),
    path('reports/integrity/check/', integrity_check, name='integrity_check'),
    path('reports/tamper/', simulate_tamper, name='simulate_tamper'),
]
