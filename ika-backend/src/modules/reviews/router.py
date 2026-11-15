"""Rutas y controladores del módulo `reviews` (Favoritos)."""

from uuid import UUID

from fastapi import APIRouter

from src.modules.reviews import service
from src.modules.reviews.schemas import (
    FavoriteItemResponse,
    FavoriteToggleResponse,
)
from src.modules.users.dependencies import (
    CurrentUser,
    DbSession,
)

reviews_router = APIRouter()


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
    """Retorna la lista de favoritos guardados por el turista enriquecida con datos del atractivo."""
    favs = await service.list_user_favorites(db, current_user.id)
    items = []
    for f in favs:
        cover = None
        if f.attraction and f.attraction.images:
            sorted_imgs = sorted(f.attraction.images, key=lambda img: img.display_order)
            if sorted_imgs:
                cover = sorted_imgs[0].url
        items.append(
            FavoriteItemResponse(
                id=f.id,
                attraction_id=f.attraction_id,
                created_at=f.created_at,
                name=f.attraction.name if f.attraction else None,
                district=f.attraction.district if f.attraction else None,
                cover_image_url=cover,
            )
        )
    return items


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
