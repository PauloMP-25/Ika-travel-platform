"""Rutas y controladores del módulo `reviews` (Reseñas, Fotos y Favoritos)."""

from typing import Annotated
from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    File,
    Query,
    UploadFile,
    status,
)

from src.modules.reviews import service
from src.modules.reviews.models import ReviewImage
from src.modules.reviews.schemas import (
    FavoriteItemResponse,
    FavoriteToggleResponse,
    ReviewCreate,
    ReviewImageResponse,
    ReviewResponse,
    ReviewSummary,
    ReviewUpdate,
)
from src.modules.users.dependencies import (
    CurrentUser,
    DbSession,
)
from src.modules.users.models import UserRole

reviews_router = APIRouter()


# ============================================================================
# Endpoints Públicos de Consulta (Reseñas y Estadísticas)
# ============================================================================

@reviews_router.get(
    "/catalog/attractions/{attraction_id}/reviews",
    response_model=list[ReviewResponse],
    tags=["reviews"],
    summary="Listar reseñas paginadas de un atractivo turístico",
)
async def list_reviews(
    attraction_id: UUID,
    db: DbSession,
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=10, ge=1, le=50),
) -> list[ReviewResponse]:
    """Consulta pública de opiniones y fotos de otros turistas."""
    reviews = await service.list_attraction_reviews(
        db, attraction_id, page=page, limit=limit
    )
    return [ReviewResponse.model_validate(r) for r in reviews]


@reviews_router.get(
    "/catalog/attractions/{attraction_id}/reviews/summary",
    response_model=ReviewSummary,
    tags=["reviews"],
    summary="Obtener promedio y distribución de calificaciones de un atractivo",
)
async def get_review_summary(
    attraction_id: UUID,
    db: DbSession,
) -> ReviewSummary:
    """Calcula el promedio de estrellas (1.0 - 5.0) y desglose por puntaje."""
    return await service.get_attraction_review_summary(db, attraction_id)


# ============================================================================
# Endpoints de Gestión de Reseñas (Turista Autenticado)
# ============================================================================

@reviews_router.post(
    "/catalog/attractions/{attraction_id}/reviews",
    response_model=ReviewResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["reviews"],
    summary="Publicar una reseña (1 a 5 estrellas)",
)
async def create_review(
    attraction_id: UUID,
    data: ReviewCreate,
    current_user: CurrentUser,
    db: DbSession,
) -> ReviewResponse:
    """Publica una nueva reseña (máximo 1 reseña por usuario por atractivo)."""
    review = await service.create_review(
        db, current_user.id, attraction_id, data
    )
    return ReviewResponse.model_validate(review)


@reviews_router.put(
    "/reviews/{review_id}",
    response_model=ReviewResponse,
    tags=["reviews"],
    summary="Editar una reseña propia",
)
async def update_review(
    review_id: UUID,
    data: ReviewUpdate,
    current_user: CurrentUser,
    db: DbSession,
) -> ReviewResponse:
    """Actualiza la calificación o texto de la reseña."""
    updated = await service.update_review(
        db, review_id, current_user.id, data
    )
    return ReviewResponse.model_validate(updated)


@reviews_router.delete(
    "/reviews/{review_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    tags=["reviews"],
    summary="Eliminar una reseña propia (o por DIRCETUR)",
)
async def delete_review(
    review_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> None:
    """Elimina la reseña y las imágenes asociadas."""
    is_admin = current_user.role == UserRole.DIRCETUR_ADMIN
    await service.delete_review(
        db, review_id, current_user.id, is_admin=is_admin
    )


@reviews_router.post(
    "/reviews/{review_id}/images",
    response_model=ReviewImageResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["reviews"],
    summary="Subir una fotografía para la reseña",
)
async def upload_review_image(
    review_id: UUID,
    file: UploadFile = File(...),
    current_user: CurrentUser = None,
    db: DbSession = None,
) -> ReviewImageResponse:
    """Sube una foto (JPG, PNG o WEBP <= 5MB) usando el Patrón Strategy."""
    content = await file.read()
    image = await service.add_review_image(
        db=db,
        review_id=review_id,
        user_id=current_user.id,
        file_bytes=content,
        filename=file.filename or "review.jpg",
        content_type=file.content_type or "image/jpeg",
    )
    return ReviewImageResponse.model_validate(image)


# ============================================================================
# Endpoints de Favoritos (RN-02: Requiere Autenticación)
# ============================================================================

@reviews_router.post(
    "/catalog/attractions/{attraction_id}/favorite",
    response_model=FavoriteToggleResponse,
    tags=["favorites"],
    summary="Guardar o retirar un atractivo de favoritos (Toggle)",
)
async def toggle_favorite(
    attraction_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> FavoriteToggleResponse:
    """Alterna el estado favorito del atractivo para el usuario actual."""
    return await service.toggle_favorite(db, current_user.id, attraction_id)


@reviews_router.get(
    "/users/me/favorites",
    response_model=list[FavoriteItemResponse],
    tags=["favorites"],
    summary="Listar atractivos favoritos del usuario",
)
async def list_favorites(
    current_user: CurrentUser,
    db: DbSession,
) -> list[FavoriteItemResponse]:
    """Retorna la lista de favoritos guardados por el turista."""
    favs = await service.list_user_favorites(db, current_user.id)
    return [FavoriteItemResponse.model_validate(f) for f in favs]


@reviews_router.get(
    "/catalog/attractions/{attraction_id}/is-favorite",
    response_model=bool,
    tags=["favorites"],
    summary="Verificar si el atractivo está en favoritos",
)
async def check_favorite(
    attraction_id: UUID,
    current_user: CurrentUser,
    db: DbSession,
) -> bool:
    """Devuelve true si el atractivo está marcado como favorito por el usuario."""
    return await service.check_is_favorite(db, current_user.id, attraction_id)
