"""Endpoints del módulo `reviews` (reseñas, fotos y favoritos).

Todos protegidos con JWT (`Depends(get_current_user)`); el router solo
recibe la petición y delega en `service`.
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, File, Form, UploadFile, status

from src.modules.reviews import service
from src.modules.reviews.schemas import (
    FavoriteResponse,
    FavoriteToggleResponse,
    ReviewCreate,
    ReviewResponse,
)
from src.modules.users.dependencies import CurrentUser, DbSession

reviews_router = APIRouter(prefix="/reviews", tags=["reviews"])


@reviews_router.post(
    "",
    response_model=ReviewResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_review(
    current_user: CurrentUser,
    db: DbSession,
    attraction_id: Annotated[UUID, Form()],
    rating: Annotated[int, Form(ge=1, le=5)],
    comment: Annotated[str | None, Form(max_length=2000)] = None,
    images: Annotated[list[UploadFile] | None, File()] = None,
) -> ReviewResponse:
    """Publica una reseña con fotos (multipart: attraction_id, rating, comment, images).

    `rating` fuera de 1–5 o imágenes inválidas devuelven 422 (validación).
    """
    data = ReviewCreate(
        attraction_id=attraction_id,
        rating=rating,
        comment=comment,
    )
    return await service.create_review(db, current_user, data, archivos=images)


@reviews_router.get(
    "/attractions/{attraction_id}",
    response_model=list[ReviewResponse],
)
async def list_attraction_reviews(
    attraction_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> list[ReviewResponse]:
    """Reseñas publicadas para un atractivo (la más reciente primero)."""
    return await service.list_attraction_reviews(db, attraction_id)


@reviews_router.delete(
    "/{review_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_review(
    review_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> None:
    """Borra una reseña propia; 403 si intentas borrar la de otro usuario."""
    await service.delete_review(db, current_user, review_id)


@reviews_router.get("/favorites", response_model=list[FavoriteResponse])
async def list_my_favorites(
    current_user: CurrentUser,
    db: DbSession,
) -> list[FavoriteResponse]:
    """Favoritos del usuario autenticado."""
    return await service.list_user_favorites(db, current_user.id)


@reviews_router.post(
    "/favorites/{attraction_id}",
    response_model=FavoriteToggleResponse,
)
async def toggle_favorite(
    attraction_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> FavoriteToggleResponse:
    """Añade o quita un atractivo de favoritos (idempotente en el cliente)."""
    return await service.toggle_favorite(db, current_user, attraction_id)
