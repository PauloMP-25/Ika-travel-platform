"""Esquemas Pydantic del módulo `reviews`.

Ningún DTO de respuesta expone datos sensibles del usuario (email, hash de
contraseña o teléfono): solo el nombre público.
"""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ReviewCreate(BaseModel):
    """Payload de creación de una reseña (multipart o JSON)."""

    attraction_id: UUID
    rating: int = Field(ge=1, le=5)
    comment: str | None = Field(default=None, max_length=2000)
    image_urls: list[str] = Field(default_factory=list, max_length=10)


class ReviewImageResponse(BaseModel):
    """Foto de una reseña."""

    id: UUID
    url: str


class ReviewResponse(BaseModel):
    """Reseña pública. Incluye solo el nombre del autor, jamás su email."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    attraction_id: UUID
    user_name: str
    rating: int
    comment: str | None
    images: list[str] = Field(default_factory=list)
    created_at: datetime


class FavoriteResponse(BaseModel):
    """Atractivo guardado en favoritos por el usuario."""

    attraction_id: UUID
    attraction_name: str
    cover_image_url: str | None
    created_at: datetime


class FavoriteToggleResponse(BaseModel):
    """Resultado de alternar un favorito: True = añadido, False = eliminado."""

    attraction_id: UUID
    is_favorite: bool
