"""Consultas SQLAlchemy del módulo `reviews` (sin reglas de negocio)."""

from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.modules.catalog.models import Attraction, AttractionImage
from src.modules.reviews.models import Favorite, Review


async def get_review_by_id(db: AsyncSession, review_id: UUID) -> Review | None:
    resultado = await db.execute(
        select(Review)
        .where(Review.id == review_id)
        .options(selectinload(Review.images), selectinload(Review.user))
    )
    return resultado.scalar_one_or_none()


async def get_review_by_user_and_attraction(
    db: AsyncSession, user_id: UUID, attraction_id: UUID
) -> Review | None:
    resultado = await db.execute(
        select(Review).where(
            Review.user_id == user_id, Review.attraction_id == attraction_id
        )
    )
    return resultado.scalar_one_or_none()


async def list_reviews_by_attraction(db: AsyncSession, attraction_id: UUID) -> list[Review]:
    resultado = await db.execute(
        select(Review)
        .where(Review.attraction_id == attraction_id)
        .options(selectinload(Review.images), selectinload(Review.user))
        .order_by(Review.created_at.desc())
    )
    return list(resultado.scalars().all())


async def get_favorite(
    db: AsyncSession, user_id: UUID, attraction_id: UUID
) -> Favorite | None:
    resultado = await db.execute(
        select(Favorite).where(
            Favorite.user_id == user_id, Favorite.attraction_id == attraction_id
        )
    )
    return resultado.scalar_one_or_none()


async def list_favorites_by_user(db: AsyncSession, user_id: UUID) -> list[Favorite]:
    """Favoritos del usuario con su atractivo y portada ya cargados (sin lazy-load)."""
    resultado = await db.execute(
        select(Favorite)
        .where(Favorite.user_id == user_id)
        .options(
            selectinload(Favorite.attraction).selectinload(Attraction.images)
        )
        .order_by(Favorite.created_at.desc())
    )
    return list(resultado.scalars().all())


async def average_rating(db: AsyncSession, attraction_id: UUID) -> float | None:
    """Promedio de ratings; ``None`` si el atractivo no tiene reseñas."""
    promedio = await db.scalar(
        select(func.avg(Review.rating)).where(Review.attraction_id == attraction_id)
    )
    return float(promedio) if promedio is not None else None
