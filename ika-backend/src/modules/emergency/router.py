"""Endpoints del módulo `emergency` (botón SOS e historial de incidentes).

Solo recibe la petición, delega en `service` y devuelve la respuesta.
"""

from uuid import UUID

from fastapi import APIRouter, status

from src.core.dependencies import CurrentUser, DbSession
from src.modules.emergency import service
from src.modules.emergency.schemas import (
    IncidentHistoryItem,
    SOSCreate,
    SOSResponse,
    SOSStatusResponse,
)

emergency_router = APIRouter()


@emergency_router.post(
    "/emergency/sos",
    response_model=SOSResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["emergency"],
)
def create_sos_report(
    data: SOSCreate,
    current_user: CurrentUser,
    db: DbSession,
) -> SOSResponse:
    """Registra una emergencia con la ubicación GPS del usuario (RN-04)."""
    report = service.create_sos_report(db, current_user.id, data)
    return SOSResponse.model_validate(report)


@emergency_router.get(
    "/emergency/incidents",
    response_model=list[IncidentHistoryItem],
    tags=["emergency"],
)
def list_my_incidents(
    current_user: CurrentUser,
    db: DbSession,
) -> list[IncidentHistoryItem]:
    """Historial de incidentes propios del usuario autenticado."""
    incidents = service.get_user_incidents(db, current_user.id)
    return [IncidentHistoryItem.model_validate(item) for item in incidents]


@emergency_router.get(
    "/emergency/sos/{report_id}/status",
    response_model=SOSStatusResponse,
    tags=["emergency"],
)
def get_report_status(
    report_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> SOSStatusResponse:
    """Estado de un reporte; 403 si intentas consultar el de otro usuario."""
    report = service.get_report_for_user(db, report_id, current_user)
    return SOSStatusResponse.model_validate(report)
