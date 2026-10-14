"""Esquemas Pydantic del módulo `emergency`."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from src.modules.emergency.models import IncidentStatus, IncidentType


class SOSCreate(BaseModel):
    """Payload del botón SOS (`POST /emergency/sos`).

    Las coordenadas se validan en `service` (RN-04) para poder devolver la
    excepción de dominio `MissingLocationPermissionException` cuando el GPS
    está apagado o sin permisos.
    """

    latitude: float | None = None
    longitude: float | None = None
    description: str | None = Field(default=None, max_length=2000)


class SOSResponse(BaseModel):
    """Confirmación de que el reporte quedó registrado."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    status: str
    created_at: datetime


class SOSStatusResponse(BaseModel):
    """Estado actual de un reporte SOS."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    status: str
    resolved_at: datetime | None = None


class IncidentHistoryItem(BaseModel):
    """Entrada del historial de incidentes del usuario."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    status: str
    created_at: datetime
    latitude: float
    longitude: float


# ============================================================================
# Esquemas para Reportes de Informalidad e Incidencias (RF-05 / CUN06)
# ============================================================================

class TouristIncidentCreate(BaseModel):
    """Payload para reportar informalidad o incidente a DIRCETUR Ica."""

    incident_type: IncidentType = Field(
        default=IncidentType.INFORMAL_SERVICE,
        description="Categoría de la incidencia (informal_service, information_error, route_obstruction, safety_hazard, other)",
    )
    title: str = Field(..., min_length=3, max_length=200, description="Título o resumen breve")
    description: str = Field(..., min_length=10, max_length=3000, description="Detalle de lo ocurrido")
    latitude: float | None = Field(default=None, description="Latitud GPS opcional")
    longitude: float | None = Field(default=None, description="Longitud GPS opcional")
    agency_name: str | None = Field(default=None, max_length=200, description="Nombre de la empresa o informal involucrado")


class TouristIncidentUpdateAdmin(BaseModel):
    """Payload para que el administrador DIRCETUR actualice el estado y notas."""

    status: IncidentStatus
    admin_notes: str | None = Field(default=None, max_length=2000)


class TouristIncidentResponse(BaseModel):
    """Respuesta con los datos de una incidencia reportada."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    incident_type: IncidentType
    title: str
    description: str
    latitude: float | None = None
    longitude: float | None = None
    agency_name: str | None = None
    status: IncidentStatus
    admin_notes: str | None = None
    created_at: datetime
    updated_at: datetime | None = None
