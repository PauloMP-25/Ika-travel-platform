"""Servicio y lógica de negocio para Favoritos."""

from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from src.modules.catalog.models import Attraction
from src.modules.reviews.models import Favorite
from src.modules.reviews.schemas import FavoriteToggleResponse


async def toggle_favorite(
    db: AsyncSession,
    user_id: UUID,
    attraction_id: UUID,
) -> FavoriteToggleResponse:
    """Alterna el estado favorito de un atractivo para el usuario actual."""
    result = await db.execute(
        select(Favorite).where(
            Favorite.user_id == user_id,
            Favorite.attraction_id == attraction_id,
        )
    )
    fav = result.scalar_one_or_none()

    if fav:
        await db.delete(fav)
        await db.commit()
        return FavoriteToggleResponse(
            attraction_id=attraction_id,
            is_favorite=False,
            message="Atractivo retirado de favoritos.",
        )
    else:
        new_fav = Favorite(user_id=user_id, attraction_id=attraction_id)
        db.add(new_fav)
        await db.commit()
        return FavoriteToggleResponse(
            attraction_id=attraction_id,
            is_favorite=True,
            message="Atractivo guardado en favoritos.",
        )


async def list_user_favorites(
    db: AsyncSession,
    user_id: UUID,
) -> list[Favorite]:
    """Retorna los atractivos favoritos del usuario logueado enriquecidos con datos del atractivo."""
    result = await db.execute(
        select(Favorite)
        .options(
            joinedload(Favorite.attraction).selectinload(Attraction.images)
        )
        .where(Favorite.user_id == user_id)
        .order_by(Favorite.created_at.desc())
    )
    return list(result.scalars().all())


async def check_is_favorite(
    db: AsyncSession,
    user_id: UUID,
    attraction_id: UUID,
) -> bool:
    """Verifica si un atractivo es favorito para el usuario."""
    result = await db.execute(
        select(Favorite.id).where(
            Favorite.user_id == user_id,
            Favorite.attraction_id == attraction_id,
        )
    )
    return result.scalar_one_or_none() is not None
