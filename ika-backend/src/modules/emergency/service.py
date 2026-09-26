"""Lógica de negocio del módulo `emergency` (reportes SOS y notificaciones)."""

import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from src.modules.emergency import tasks
from src.modules.emergency.exceptions import (
    MissingLocationPermissionException,
    SOSReportNotFoundException,
    UnauthorizedIncidentAccessException,
)
from src.modules.emergency.models import (
    EmergencyNotification,
    NotificationChannel,
    NotificationStatus,
    SOSReport,
    SOSStatus,
)
from src.modules.emergency.schemas import SOSCreate
from src.modules.users.models import User

logger = logging.getLogger(__name__)

# Límites geográficos válidos (WGS84)
LATITUDE_RANGE = (-90.0, 90.0)
LONGITUDE_RANGE = (-180.0, 180.0)


def _validate_location(data: SOSCreate) -> tuple[float, float]:
    """Aplica RN-04: sin coordenadas GPS válidas no se abre el incidente."""
    if data.latitude is None or data.longitude is None:
        raise MissingLocationPermissionException(
            "No se detectaron coordenadas GPS: revisa los permisos de ubicación"
        )

    lat, lon = float(data.latitude), float(data.longitude)
    if not (LATITUDE_RANGE[0] <= lat <= LATITUDE_RANGE[1]):
        raise MissingLocationPermissionException(
            f"Latitud fuera de rango: {lat}"
        )
    if not (LONGITUDE_RANGE[0] <= lon <= LONGITUDE_RANGE[1]):
        raise MissingLocationPermissionException(
            f"Longitud fuera de rango: {lon}"
        )
    return lat, lon


def _build_notifications(
    user: User, report: SOSReport
) -> list[EmergencyNotification]:
    """Crea las notificaciones `queued` para los canales disponibles del usuario."""
    notifications = [
        EmergencyNotification(
            sos_report_id=report.id,
            channel=NotificationChannel.PUSH,
            recipient=str(user.id),
            status=NotificationStatus.QUEUED,
        ),
        EmergencyNotification(
            sos_report_id=report.id,
            channel=NotificationChannel.EMAIL,
            recipient=user.email,
            status=NotificationStatus.QUEUED,
        ),
    ]
    if user.phone:
        notifications.append(
            EmergencyNotification(
                sos_report_id=report.id,
                channel=NotificationChannel.SMS,
                recipient=user.phone,
                status=NotificationStatus.QUEUED,
            )
        )
    return notifications


def _dispatch_notifications(report_id: UUID) -> None:
    """Encola la tarea Celery que despacha las notificaciones del reporte.

    Un incidente SOS nunca debe fallar porque el broker esté caído: el
    reporte ya está persistido con sus notificaciones en `queued`, así que
    el error queda registrado en el log y la tarea podrá retomarlo.
    """
    try:
        tasks.dispatch_sos_notifications.delay(str(report_id))
    except Exception:
        logger.exception(
            "No se pudo encolar el despacho de notificaciones para el SOS %s",
            report_id,
        )


def create_sos_report(
    db: Session, user_id: UUID, data: SOSCreate
) -> SOSReport:
    """Registra un reporte SOS y crea sus notificaciones pendientes (RN-04)."""
    lat, lon = _validate_location(data)

    user = db.get(User, user_id)
    if user is None:
        raise UnauthorizedIncidentAccessException()

    report = SOSReport(
        user_id=user.id,
        latitude=lat,
        longitude=lon,
        description=data.description,
        status=SOSStatus.PENDING,
    )
    db.add(report)
    db.flush()  # obtiene el id antes de crear las notificaciones

    for notification in _build_notifications(user, report):
        db.add(notification)

    db.commit()
    db.refresh(report)

    _dispatch_notifications(report.id)
    return report


def get_user_incidents(db: Session, user_id: UUID) -> list[SOSReport]:
    """Historial de incidentes del usuario, del más reciente al más antiguo."""
    return (
        db.query(SOSReport)
        .filter(SOSReport.user_id == user_id)
        .order_by(SOSReport.created_at.desc())
        .all()
    )


def get_report_for_user(
    db: Session, report_id: UUID, user: User
) -> SOSReport:
    """Devuelve un reporte solo si pertenece al usuario autenticado."""
    report = db.get(SOSReport, report_id)
    if report is None:
        raise SOSReportNotFoundException()
    if report.user_id != user.id:
        raise UnauthorizedIncidentAccessException()
    return report


def resolve_sos_report(db: Session, report_id: UUID) -> SOSReport:
    """Marca un incidente como resuelto (uso interno/administrativo)."""
    report = db.get(SOSReport, report_id)
    if report is None:
        raise SOSReportNotFoundException()

    report.status = SOSStatus.RESOLVED
    report.resolved_at = report.resolved_at or datetime.now(timezone.utc)
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


# Nota: `resolve_sos_report` no expone endpoint público todavía porque el
# modelo de usuarios no tiene roles de administrador.
