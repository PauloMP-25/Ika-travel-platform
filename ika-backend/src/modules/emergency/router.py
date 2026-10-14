"""Endpoints del módulo `emergency` (botón SOS, llamadas rápidas y reportes DIRCETUR).

Solo recibe la petición, delega en `service` y devuelve la respuesta.
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status

from src.modules.emergency import service
from src.modules.emergency.models import IncidentStatus
from src.modules.emergency.schemas import (
    IncidentHistoryItem,
    SOSCreate,
    SOSResponse,
    SOSStatusResponse,
    TouristIncidentCreate,
    TouristIncidentResponse,
    TouristIncidentUpdateAdmin,
)
from src.modules.users.dependencies import (
    CurrentUser,
    DbSession,
    require_dircetur_admin,
)
from src.modules.users.models import User

emergency_router = APIRouter()


# ============================================================================
# Números de Emergencia y Asistencia Rápida (RF-05 / CUN06)
# ============================================================================

EMERGENCY_CONTACTS = [
    {
        "name": "Policía de Turismo (POLTUR Ica)",
        "phone": "056-224553",
        "category": "poltur",
        "description": "Atención especializada, protección al turista y patrullaje en zonas turísticas de Ica y Huacachina.",
    },
    {
        "name": "Central de Emergencias PNP",
        "phone": "105",
        "category": "police",
        "description": "Policía Nacional del Perú - Emergencias generales 24 horas.",
    },
    {
        "name": "SAMU (Ambulancia)",
        "phone": "106",
        "category": "ambulance",
        "description": "Sistema de Atención Móvil de Urgencia médica.",
    },
    {
        "name": "Compañía General de Bomberos Ica",
        "phone": "116",
        "category": "firefighters",
        "description": "Rescate, incendios y atención de emergencias.",
    },
    {
        "name": "DIRCETUR Ica (Fiscalización Turística)",
        "phone": "056-238710",
        "category": "dircetur",
        "description": "Dirección Regional de Comercio Exterior y Turismo de Ica - Oficina de fiscalización y denuncias.",
    },
]


@emergency_router.get(
    "/emergency/contacts",
    tags=["emergency"],
    summary="Directorio oficial de números de emergencia y asistencia turística",
)
async def get_emergency_contacts() -> list[dict]:
    """Retorna los números telefónicos oficiales de emergencia en la Región Ica."""
    return EMERGENCY_CONTACTS


# ============================================================================
# Botón SOS e Historial
# ============================================================================

@emergency_router.post(
    "/emergency/sos",
    response_model=SOSResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["emergency"],
)
async def create_sos_report(
    data: SOSCreate,
    current_user: CurrentUser,
    db: DbSession,
) -> SOSResponse:
    """Registra una emergencia con la ubicación GPS del usuario (RN-04)."""
    report = await service.create_sos_report(db, current_user.id, data)
    return SOSResponse.model_validate(report)


@emergency_router.get(
    "/emergency/incidents",
    response_model=list[IncidentHistoryItem],
    tags=["emergency"],
)
async def list_my_incidents(
    current_user: CurrentUser,
    db: DbSession,
) -> list[IncidentHistoryItem]:
    """Historial de incidentes SOS propios del usuario autenticado."""
    incidents = await service.get_user_incidents(db, current_user.id)
    return [IncidentHistoryItem.model_validate(item) for item in incidents]


@emergency_router.get(
    "/emergency/sos/{report_id}/status",
    response_model=SOSStatusResponse,
    tags=["emergency"],
)
async def get_report_status(
    report_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> SOSStatusResponse:
    """Estado de un reporte; 403 si intentas consultar el de otro usuario."""
    report = await service.get_report_for_user(db, report_id, current_user)
    return SOSStatusResponse.model_validate(report)


# ============================================================================
# Reporte de Informalidad / Incidencias DIRCETUR (RF-05 / CUN06)
# ============================================================================

@emergency_router.post(
    "/emergency/reports",
    response_model=TouristIncidentResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["emergency", "dircetur"],
    summary="Enviar reporte de informalidad o incidencia turística a DIRCETUR Ica",
)
async def report_tourist_incident(
    data: TouristIncidentCreate,
    current_user: CurrentUser,
    db: DbSession,
) -> TouristIncidentResponse:
    """Permite al turista autenticado emitir un reporte formal a DIRCETUR."""
    incident = await service.create_tourist_incident_report(
        db, current_user.id, data
    )
    return TouristIncidentResponse.model_validate(incident)


@emergency_router.get(
    "/emergency/my-reports",
    response_model=list[TouristIncidentResponse],
    tags=["emergency", "dircetur"],
    summary="Listar reportes de incidencia emitidos por el usuario",
)
async def list_my_tourist_reports(
    current_user: CurrentUser,
    db: DbSession,
) -> list[TouristIncidentResponse]:
    """Retorna los reportes emitidos por el turista logueado."""
    incidents = await service.get_user_tourist_incidents(db, current_user.id)
    return [TouristIncidentResponse.model_validate(item) for item in incidents]


@emergency_router.get(
    "/emergency/admin/reports",
    response_model=list[TouristIncidentResponse],
    tags=["emergency", "dircetur"],
    summary="Panel DIRCETUR: Listado de reportes de fiscalización e informalidad",
)
async def list_reports_for_admin(
    _admin: Annotated[User, Depends(require_dircetur_admin)],
    db: DbSession,
    status_filter: IncidentStatus | None = Query(default=None, alias="status"),
) -> list[TouristIncidentResponse]:
    """Exclusivo administradores DIRCETUR para fiscalización y control."""
    incidents = await service.list_all_tourist_incidents(
        db, status_filter=status_filter
    )
    return [TouristIncidentResponse.model_validate(item) for item in incidents]


@emergency_router.patch(
    "/emergency/admin/reports/{incident_id}",
    response_model=TouristIncidentResponse,
    tags=["emergency", "dircetur"],
    summary="Panel DIRCETUR: Actualizar estado y observaciones de un reporte",
)
async def update_report_status_for_admin(
    incident_id: UUID,
    data: TouristIncidentUpdateAdmin,
    _admin: Annotated[User, Depends(require_dircetur_admin)],
    db: DbSession,
) -> TouristIncidentResponse:
    """Actualiza el estado de la incidencia (e.g., in_review, resolved) y notas."""
    updated = await service.update_tourist_incident_status(
        db, incident_id, data
    )
    return TouristIncidentResponse.model_validate(updated)
