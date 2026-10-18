"""Lógica de negocio del módulo `emergency` (reportes SOS, informalidad y notificaciones)."""

import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.emergency import tasks
from src.modules.emergency.exceptions import (
    MissingLocationPermissionException,
    SOSReportNotFoundException,
    UnauthorizedIncidentAccessException,
)
from src.modules.emergency.models import (
    EmergencyNotification,
    IncidentStatus,
    NotificationChannel,
    NotificationStatus,
    SOSReport,
    SOSStatus,
    TouristIncidentReport,
)
from src.modules.emergency.schemas import (
    SOSCreate,
    TouristIncidentCreate,
    TouristIncidentUpdateAdmin,
)
from src.modules.users.models import User
from src.shared.exceptions import IdempotencyKeyReutilizadaError
from src.shared.idempotency import calcular_hash_solicitud

logger = logging.getLogger(__name__)

# Límites geográficos válidos (WGS84)
LATITUDE_RANGE = (-90.0, 90.0)
LONGITUDE_RANGE = (-180.0, 180.0)


def _validate_location(data: SOSCreate) -> tuple[float, float]:
    """Aplica RN-04: sin coordenadas GPS válidas no se abre el incidente SOS."""
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
    """Encola la tarea Celery que despacha las notificaciones del reporte."""
    try:
        tasks.dispatch_sos_notifications.delay(str(report_id))
    except Exception:
        logger.exception(
            "No se pudo encolar el despacho de notificaciones para el SOS %s",
            report_id,
        )


async def _buscar_sos_por_clave(
    db: AsyncSession, user_id: UUID, clave: str
) -> SOSReport | None:
    """Consulta por la clave de idempotencia **dentro del ámbito del usuario**."""
    resultado = await db.execute(
        select(SOSReport).where(
            SOSReport.user_id == user_id,
            SOSReport.idempotency_key == clave,
        )
    )
    return resultado.scalars().first()


def _validar_repeticion_sos(previo: SOSReport, huella: str) -> SOSReport:
    """Misma clave: si el payload coincide se reenvía el recurso original; si no, 422."""
    if previo.request_hash != huella:
        raise IdempotencyKeyReutilizadaError()
    return previo


async def crear_reporte_sos(
    db: AsyncSession,
    user_id: UUID,
    data: SOSCreate,
    clave: str | None = None,
) -> tuple[SOSReport, bool]:
    """Crea un reporte SOS respetando la `Idempotency-Key` opcional (Sprint 4, F4).

    Devuelve `(reporte, repetido)`. La validación RN-04 (coordenadas) ocurre
    **antes** de consultar la clave: una petición malformada nunca consume la
    clave ni se considera un replay.
    """
    lat, lon = _validate_location(data)

    user = await db.get(User, user_id)
    if user is None:
        raise UnauthorizedIncidentAccessException()

    huella = calcular_hash_solicitud(data)
    if clave is not None:
        previo = await _buscar_sos_por_clave(db, user_id, clave)
        if previo is not None:
            return _validar_repeticion_sos(previo, huella), True

    report = SOSReport(
        user_id=user.id,
        latitude=lat,
        longitude=lon,
        description=data.description,
        status=SOSStatus.PENDING,
        idempotency_key=clave,
        request_hash=huella,
    )
    db.add(report)
    try:
        # El `flush` ya puede fallar con IntegrityError (PostgreSQL valida la
        # restricción única al INSERTar), por eso va dentro del `try`: es el
        # caso típico de dos peticiones simultáneas con la misma clave.
        await db.flush()  # obtiene el id antes de crear las notificaciones

        for notification in _build_notifications(user, report):
            db.add(notification)

        await db.commit()
    except IntegrityError:
        # Carrera entre dos peticiones simultáneas con la misma clave: la
        # restricción única (user_id, idempotency_key) decide la ganadora.
        await db.rollback()
        if clave is not None:
            previo = await _buscar_sos_por_clave(db, user_id, clave)
            if previo is not None:
                return _validar_repeticion_sos(previo, huella), True
        raise

    await db.refresh(report)

    # El despacho se encola solo en la creación real, nunca en un replay.
    _dispatch_notifications(report.id)
    return report, False


async def create_sos_report(
    db: AsyncSession, user_id: UUID, data: SOSCreate
) -> SOSReport:
    """Registra un reporte SOS y crea sus notificaciones pendientes (RN-04).

    Equivalente a `crear_reporte_sos` sin cabecera de idempotencia: se mantiene
    como fachada para los clientes y tests existentes.
    """
    report, _ = await crear_reporte_sos(db, user_id, data, clave=None)
    return report


async def get_user_incidents(
    db: AsyncSession, user_id: UUID
) -> list[SOSReport]:
    """Historial de incidentes SOS del usuario, del más reciente al más antiguo."""
    resultado = await db.execute(
        select(SOSReport)
        .where(SOSReport.user_id == user_id)
        .order_by(SOSReport.created_at.desc())
    )
    return list(resultado.scalars().all())


async def get_report_for_user(
    db: AsyncSession, report_id: UUID, user: User
) -> SOSReport:
    """Devuelve un reporte SOS solo si pertenece al usuario autenticado."""
    report = await db.get(SOSReport, report_id)
    if report is None:
        raise SOSReportNotFoundException()
    if report.user_id != user.id:
        raise UnauthorizedIncidentAccessException()
    return report


async def resolve_sos_report(
    db: AsyncSession, report_id: UUID
) -> SOSReport:
    """Marca un incidente SOS como resuelto."""
    report = await db.get(SOSReport, report_id)
    if report is None:
        raise SOSReportNotFoundException()

    report.status = SOSStatus.RESOLVED
    report.resolved_at = report.resolved_at or datetime.now(timezone.utc)
    db.add(report)
    await db.commit()
    await db.refresh(report)
    return report


# ============================================================================
# Lógica de Reportes de Informalidad e Incidencias (RF-05 / CUN06)
# ============================================================================

async def _buscar_incidencia_por_clave(
    db: AsyncSession, user_id: UUID, clave: str
) -> TouristIncidentReport | None:
    resultado = await db.execute(
        select(TouristIncidentReport).where(
            TouristIncidentReport.user_id == user_id,
            TouristIncidentReport.idempotency_key == clave,
        )
    )
    return resultado.scalars().first()


def _validar_repeticion_incidencia(
    previo: TouristIncidentReport, huella: str
) -> TouristIncidentReport:
    if previo.request_hash != huella:
        raise IdempotencyKeyReutilizadaError()
    return previo


async def crear_reporte_incidencia(
    db: AsyncSession,
    user_id: UUID,
    data: TouristIncidentCreate,
    clave: str | None = None,
) -> tuple[TouristIncidentReport, bool]:
    """Crea un reporte de informalidad con `Idempotency-Key` opcional (F4).

    Devuelve `(reporte, repetido)`.
    """
    user = await db.get(User, user_id)
    if user is None:
        raise UnauthorizedIncidentAccessException()

    huella = calcular_hash_solicitud(data)
    if clave is not None:
        previo = await _buscar_incidencia_por_clave(db, user_id, clave)
        if previo is not None:
            return _validar_repeticion_incidencia(previo, huella), True

    incident = TouristIncidentReport(
        user_id=user.id,
        incident_type=data.incident_type,
        title=data.title,
        description=data.description,
        latitude=data.latitude,
        longitude=data.longitude,
        agency_name=data.agency_name,
        status=IncidentStatus.RECEIVED,
        idempotency_key=clave,
        request_hash=huella,
    )
    db.add(incident)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        if clave is not None:
            previo = await _buscar_incidencia_por_clave(db, user_id, clave)
            if previo is not None:
                return _validar_repeticion_incidencia(previo, huella), True
        raise
    await db.refresh(incident)
    return incident, False


async def create_tourist_incident_report(
    db: AsyncSession,
    user_id: UUID,
    data: TouristIncidentCreate,
) -> TouristIncidentReport:
    """Registra un reporte de informalidad (fachada sin idempotencia)."""
    incident, _ = await crear_reporte_incidencia(db, user_id, data, clave=None)
    return incident


async def get_user_tourist_incidents(
    db: AsyncSession,
    user_id: UUID,
) -> list[TouristIncidentReport]:
    """Historial de incidencias reportadas por el usuario."""
    resultado = await db.execute(
        select(TouristIncidentReport)
        .where(TouristIncidentReport.user_id == user_id)
        .order_by(TouristIncidentReport.created_at.desc())
    )
    return list(resultado.scalars().all())


async def list_all_tourist_incidents(
    db: AsyncSession,
    status_filter: IncidentStatus | None = None,
) -> list[TouristIncidentReport]:
    """Listado completo de incidencias para fiscalización de DIRCETUR Ica."""
    query = select(TouristIncidentReport).order_by(TouristIncidentReport.created_at.desc())
    if status_filter is not None:
        query = query.where(TouristIncidentReport.status == status_filter)
    resultado = await db.execute(query)
    return list(resultado.scalars().all())


async def update_tourist_incident_status(
    db: AsyncSession,
    incident_id: UUID,
    data: TouristIncidentUpdateAdmin,
) -> TouristIncidentReport:
    """Actualiza el estado y notas administrativas de una incidencia (personal DIRCETUR)."""
    incident = await db.get(TouristIncidentReport, incident_id)
    if incident is None:
        raise SOSReportNotFoundException("Incidencia turística no encontrada")

    incident.status = data.status
    if data.admin_notes is not None:
        incident.admin_notes = data.admin_notes
    incident.updated_at = datetime.now(timezone.utc)

    db.add(incident)
    await db.commit()
    await db.refresh(incident)
    return incident
