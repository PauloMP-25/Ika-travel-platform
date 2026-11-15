"""Esquemas Pydantic para Favoritos."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class FavoriteToggleResponse(BaseModel):
    """Resultado de alternar (toggle) un atractivo en favoritos."""

    attraction_id: UUID
    is_favorite: bool
    message: str


class FavoriteItemResponse(BaseModel):
    """Elemento del listado de favoritos del usuario enriquecido con datos del atractivo."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    attraction_id: UUID
    created_at: datetime
    name: str | None = None
    district: str | None = None
    cover_image_url: str | None = None
