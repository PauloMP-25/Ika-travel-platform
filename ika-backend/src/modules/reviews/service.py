"""Servicio y lógica de negocio para Reseñas y Favoritos (`reviews`)."""

from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.modules.catalog.models import Attraction
from src.modules.reviews.exceptions import (
    InvalidImageUploadException,
    ReviewAlreadyExistsException,
    ReviewNotFoundException,
    UnauthorizedReviewActionException,
)
from src.modules.reviews.models import Favorite, Review, ReviewImage
from src.modules.reviews.schemas import (
    FavoriteToggleResponse,
    ReviewCreate,
    ReviewSummary,
    ReviewUpdate,
)
from src.modules.reviews.storage import get_storage_strategy

ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024  # 5MB


async def create_review(
    db: AsyncSession,
    user_id: UUID,
    attraction_id: UUID,
    data: ReviewCreate,
) -> Review:
    """Crea una nueva reseña garantizando unicidad usuario-atractivo."""
    # Verificar existencia del atractivo
    attraction = await db.get(Attraction, attraction_id)
    if attraction is None:
        raise ReviewNotFoundException("El atractivo turístico indicado no existe.")

    # Verificar si ya existe reseña
    existing = await db.execute(
        select(Review).where(
            Review.user_id == user_id,
            Review.attraction_id == attraction_id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise ReviewAlreadyExistsException()

    review = Review(
        user_id=user_id,
        attraction_id=attraction_id,
        rating=data.rating,
        comment=data.comment.strip() if data.comment else None,
    )
    db.add(review)
    await db.commit()
    await db.refresh(review)
    return await get_review_by_id(db, review.id)


async def get_review_by_id(db: AsyncSession, review_id: UUID) -> Review:
    """Obtiene una reseña cargando usuario e imágenes."""
    result = await db.execute(
        select(Review)
        .where(Review.id == review_id)
        .options(selectinload(Review.user), selectinload(Review.images))
    )
    review = result.scalar_one_or_none()
    if review is None:
        raise ReviewNotFoundException()
    return review


async def list_attraction_reviews(
    db: AsyncSession,
    attraction_id: UUID,
    page: int = 1,
    limit: int = 10,
) -> list[Review]:
    """Lista las reseñas paginadas de un atractivo."""
    offset = (max(page, 1) - 1) * limit
    result = await db.execute(
        select(Review)
        .where(Review.attraction_id == attraction_id)
        .options(selectinload(Review.user), selectinload(Review.images))
        .order_by(Review.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    return list(result.scalars().all())


async def get_attraction_review_summary(
    db: AsyncSession,
    attraction_id: UUID,
) -> ReviewSummary:
    """Calcula el promedio de calificación y distribución de estrellas."""
    # Total y promedio
    agg_result = await db.execute(
        select(
            func.count(Review.id).label("total"),
            func.coalesce(func.avg(Review.rating), 0.0).label("avg_rating"),
        ).where(Review.attraction_id == attraction_id)
    )
    total, avg = agg_result.one()

    # Distribución
    dist_result = await db.execute(
        select(Review.rating, func.count(Review.id))
        .where(Review.attraction_id == attraction_id)
        .group_by(Review.rating)
    )
    distribution = {star: 0 for star in range(1, 6)}
    for star, count in dist_result.all():
        distribution[star] = count

    return ReviewSummary(
        attraction_id=attraction_id,
        total_reviews=total,
        average_rating=round(float(avg), 2),
        rating_distribution=distribution,
    )


async def update_review(
    db: AsyncSession,
    review_id: UUID,
    user_id: UUID,
    data: ReviewUpdate,
) -> Review:
    """Actualiza una reseña verificando que pertenezca al usuario."""
    review = await get_review_by_id(db, review_id)
    if review.user_id != user_id:
        raise UnauthorizedReviewActionException()

    if data.rating is not None:
        review.rating = data.rating
    if data.comment is not None:
        review.comment = data.comment.strip()

    db.add(review)
    await db.commit()
    await db.refresh(review)
    return await get_review_by_id(db, review.id)


async def delete_review(
    db: AsyncSession,
    review_id: UUID,
    user_id: UUID,
    is_admin: bool = False,
) -> None:
    """Elimina una reseña (por su autor o por un administrador DIRCETUR)."""
    review = await get_review_by_id(db, review_id)
    if not is_admin and review.user_id != user_id:
        raise UnauthorizedReviewActionException()

    storage = get_storage_strategy()
    for image in review.images:
        await storage.delete(image.image_url)

    await db.delete(review)
    await db.commit()


async def add_review_image(
    db: AsyncSession,
    review_id: UUID,
    user_id: UUID,
    file_bytes: bytes,
    filename: str,
    content_type: str,
) -> ReviewImage:
    """Sube una imagen para la reseña usando el StorageStrategy configurado."""
    review = await get_review_by_id(db, review_id)
    if review.user_id != user_id:
        raise UnauthorizedReviewActionException()

    if content_type.lower() not in ALLOWED_MIME_TYPES or len(file_bytes) > MAX_FILE_SIZE_BYTES:
        raise InvalidImageUploadException()

    storage = get_storage_strategy()
    saved_url = await storage.upload(file_bytes, filename, content_type)

    image = ReviewImage(
        review_id=review_id,
        image_url=saved_url,
        storage_provider="local" if "mock" not in saved_url else "mock",
    )
    db.add(image)
    await db.commit()
    await db.refresh(image)
    return image


# ============================================================================
# Lógica de Favoritos (Toggle y Listado)
# ============================================================================

async def toggle_favorite(
    db: AsyncSession,
    user_id: UUID,
    attraction_id: UUID,
) -> FavoriteToggleResponse:
    """Alterna el estado de favorito de un atractivo para el usuario."""
    # Verificar si el atractivo existe
    attraction = await db.get(Attraction, attraction_id)
    if attraction is None:
        raise ReviewNotFoundException("El atractivo turístico indicado no existe.")

    existing = await db.execute(
        select(Favorite).where(
            Favorite.user_id == user_id,
            Favorite.attraction_id == attraction_id,
        )
    )
    fav = existing.scalar_one_or_none()

    if fav is not None:
        await db.delete(fav)
        await db.commit()
        return FavoriteToggleResponse(
            attraction_id=attraction_id,
            is_favorite=False,
            message="Atractivo retirado de tus favoritos.",
        )
    else:
        new_fav = Favorite(user_id=user_id, attraction_id=attraction_id)
        db.add(new_fav)
        await db.commit()
        return FavoriteToggleResponse(
            attraction_id=attraction_id,
            is_favorite=True,
            message="Atractivo guardado en tus favoritos con éxito.",
        )


async def list_user_favorites(
    db: AsyncSession,
    user_id: UUID,
) -> list[Favorite]:
    """Retorna los atractivos favoritos del usuario logueado."""
    result = await db.execute(
        select(Favorite)
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
