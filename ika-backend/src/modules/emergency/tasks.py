from celery import shared_task

@shared_task(name="emergency.enviar_notificaciones_sos")
def enviar_notificaciones_sos(report_id: str):
    """Tarea asíncrona: enviar notificaciones de emergencia (email/log)."""
    pass
