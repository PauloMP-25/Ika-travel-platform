"""Esquemas Pydantic para el módulo `reviews`."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ReviewImageResponse(BaseModel):
    """Información de una imagen subida en una reseña."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    image_url: str
    created_at: datetime


class ReviewCreate(BaseModel):
    """Payload para crear una nueva reseña (1 a 5 estrellas)."""

    rating: int = Field(..., ge=1, le=5, description="Calificación de 1 a 5 estrellas")
    comment: str | None = Field(default=None, max_length=2000, description="Comentario o feedback")


class ReviewUpdate(BaseModel):
    """Payload para actualizar una reseña existente."""

    rating: int | None = Field(default=None, ge=1, le=5)
    comment: str | None = Field(default=None, max_length=2000)


class ReviewAuthor(BaseModel):
    """Datos básicos del autor de la reseña."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    full_name: str


class ReviewResponse(BaseModel):
    """Detalle completo de una reseña."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    attraction_id: UUID
    user_id: UUID
    rating: int
    comment: str | None = None
    created_at: datetime
    updated_at: datetime | None = None
    user: ReviewAuthor | None = None
    images: list[ReviewImageResponse] = []


class ReviewSummary(BaseModel):
    """Resumen estadístico de reseñas de un atractivo turístico."""

    attraction_id: UUID
    total_reviews: int
    average_rating: float
    rating_distribution: dict[int, int]  # e.g., {5: 10, 4: 2, 3: 0, 2: 1, 1: 0}


class FavoriteToggleResponse(BaseModel):
    """Resultado de alternar (toggle) un atractivo en favoritos."""

    attraction_id: UUID
    is_favorite: bool
    message: str


class FavoriteItemResponse(BaseModel):
    """Elemento del listado de favoritos del usuario."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    attraction_id: UUID
    created_at: datetime
