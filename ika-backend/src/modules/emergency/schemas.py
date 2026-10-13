"""Esquemas Pydantic del módulo `emergency`."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


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
