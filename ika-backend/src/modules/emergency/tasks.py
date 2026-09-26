"""Tareas en segundo plano del módulo `emergency` (Celery)."""

import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from src.celery_app import celery_app
from src.database import SessionLocal
from src.modules.emergency.models import (
    EmergencyNotification,
    NotificationChannel,
    NotificationStatus,
    SOSReport,
)

logger = logging.getLogger(__name__)


def send_notification(
    channel: NotificationChannel, recipient: str, message: str
) -> bool:
    """Entrega una notificación por su canal y devuelve si tuvo éxito.

    TODO(Dev 1): integrar los proveedores reales — Twilio (SMS), SMTP
    (email) y FCM (push). Hasta entonces el envío queda documentado como
    fallido en la tabla de notificaciones, nunca silenciosamente.
    """
    logger.warning(
        "Proveedor de notificaciones no configurado: canal=%s destinatario=%s",
        channel.value,
        recipient,
    )
    return False


@celery_app.task(name="emergency.dispatch_sos_notifications")
def dispatch_sos_notifications(report_id: str) -> int:
    """Entrypoint de la tarea: abre su propia sesión de BD."""
    db = SessionLocal()
    try:
        return process_sos_notifications(UUID(report_id), db)
    finally:
        db.close()


def process_sos_notifications(report_id: UUID, db: Session) -> int:
    """Despacha las notificaciones `queued` de un reporte SOS.

    Devuelve la cantidad de notificaciones enviadas. Las fallas se marcan
    como `failed` en la BD y quedan registradas en el log.
    """
    report = db.get(SOSReport, report_id)
    if report is None:
        logger.warning("SOS %s no encontrado; se omiten notificaciones", report_id)
        return 0

    message = (
        f"SOS activado en {report.latitude}, {report.longitude}."
        + (f" Descripción: {report.description}" if report.description else "")
    )

    sent_count = 0
    for notification in report.notifications:
        if notification.status != NotificationStatus.QUEUED:
            continue

        delivered = send_notification(
            notification.channel, notification.recipient, message
        )
        if delivered:
            notification.status = NotificationStatus.SENT
            notification.sent_at = datetime.now(timezone.utc)
            sent_count += 1
        else:
            notification.status = NotificationStatus.FAILED
            logger.error(
                "Notificación %s (%s a %s) del SOS %s marcada como fallida",
                notification.id,
                notification.channel.value,
                notification.recipient,
                report.id,
            )

    db.commit()
    return sent_count
