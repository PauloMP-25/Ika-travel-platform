"""Tareas en segundo plano del módulo `emergency` (Celery)."""

import asyncio
import logging
from datetime import datetime, timezone
from uuid import UUID

from celery import shared_task
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.core.database import SesionAsincronaLocal
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


async def process_sos_notifications(
    report_id: UUID, db: AsyncSession
) -> int:
    """Despacha las notificaciones `queued` de un reporte SOS.

    Devuelve la cantidad de notificaciones enviadas. Las fallas se marcan
    como `failed` en la BD y quedan registradas en el log.
    """
    resultado = await db.execute(
        select(SOSReport)
        .where(SOSReport.id == report_id)
        .options(selectinload(SOSReport.notifications))
    )
    report = resultado.scalar_one_or_none()
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

    await db.commit()
    return sent_count


async def _despachar(report_id: UUID) -> int:
    """Abre su propia sesión de BD (el worker no comparte la de la petición)."""
    async with SesionAsincronaLocal() as db:
        return await process_sos_notifications(report_id, db)


@shared_task(name="emergency.dispatch_sos_notifications")
def dispatch_sos_notifications(report_id: str) -> int:
    """Entrypoint de la tarea Celery.

    En modo *eager* (tests) no hay worker: ejecutarla en línea rompería el
    ciclo de vida del event loop de la petición, así que se omite y los
    tests invocan `process_sos_notifications` directamente.
    """
    if dispatch_sos_notifications.app.conf.task_always_eager:
        logger.info(
            "Modo eager: despacho del SOS %s difiero a los tests", report_id
        )
        return 0
    return asyncio.run(_despachar(UUID(report_id)))
