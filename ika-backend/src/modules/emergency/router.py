"""Endpoints del módulo `emergency` (botón SOS e historial de incidentes).

Solo recibe la petición, delega en `service` y devuelve la respuesta.
"""

from uuid import UUID

from fastapi import APIRouter, status

from src.modules.emergency import service
from src.modules.emergency.schemas import (
    IncidentHistoryItem,
    SOSCreate,
    SOSResponse,
    SOSStatusResponse,
)
from src.modules.users.dependencies import CurrentUser, DbSession

emergency_router = APIRouter()


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
    """Historial de incidentes propios del usuario autenticado."""
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
