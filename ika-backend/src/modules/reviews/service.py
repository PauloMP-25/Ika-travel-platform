"""Lógica de negocio del módulo `reviews` (reseñas, fotos y favoritos)."""

from uuid import UUID

from fastapi import UploadFile
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.catalog.models import Attraction
from src.modules.reviews import repository
from src.modules.reviews.exceptions import (
    AttractionNotFoundException,
    DuplicateReviewException,
    InvalidRatingException,
    ReviewForbiddenException,
    ReviewNotFoundException,
)
from src.modules.reviews.models import Favorite, Review, ReviewImage
from src.modules.reviews.schemas import (
    FavoriteResponse,
    FavoriteToggleResponse,
    ReviewCreate,
    ReviewResponse,
)
from src.modules.users.models import User
from src.shared.storage import StorageStrategy, get_storage


async def _get_attraction(db: AsyncSession, attraction_id: UUID) -> Attraction:
    attraction = await db.get(Attraction, attraction_id)
    if attraction is None:
        raise AttractionNotFoundException(
            f"El atractivo {attraction_id} no existe"
        )
    return attraction


def _to_review_response(review: Review) -> ReviewResponse:
    """Data Mapper: ORM → DTO. No expone email ni hash del autor."""
    return ReviewResponse(
        id=review.id,
        attraction_id=review.attraction_id,
        user_name=review.user.full_name,
        rating=review.rating,
        comment=review.comment,
        images=[image.url for image in review.images],
        created_at=review.created_at,
    )


def _to_favorite_response(favorite: Favorite) -> FavoriteResponse:
    """Data Mapper: ORM → DTO con la portada del atractivo (si tiene)."""
    cover = favorite.attraction.images[0].url if favorite.attraction.images else None
    return FavoriteResponse(
        attraction_id=favorite.attraction_id,
        attraction_name=favorite.attraction.name,
        cover_image_url=cover,
        created_at=favorite.created_at,
    )


async def create_review(
    db: AsyncSession,
    user: User,
    data: ReviewCreate,
    archivos: list[UploadFile] | None = None,
    storage: StorageStrategy | None = None,
) -> ReviewResponse:
    """Publica una reseña (una por usuario y atractivo) con sus fotos.

    Las fotos se guardan a través de la estrategia de almacenamiento activa
    (`STORAGE_BACKEND`); la subida se valida antes de tocar la BD.
    """
    if not 1 <= data.rating <= 5:
        raise InvalidRatingException(f"Calificación inválida: {data.rating}")

    await _get_attraction(db, data.attraction_id)

    if await repository.get_review_by_user_and_attraction(
        db, user.id, data.attraction_id
    ):
        raise DuplicateReviewException()

    estrategia = storage or get_storage()
    urls_subidas = [
        # `prefix` agrupa los archivos por atractivo en el disco/nube.
        estrategia.save(archivo, prefix=f"reviews/{data.attraction_id}")
        for archivo in (archivos or [])
    ]

    review = Review(
        user_id=user.id,
        attraction_id=data.attraction_id,
        rating=data.rating,
        comment=data.comment,
    )
    review.images = [ReviewImage(url=url) for url in urls_subidas + data.image_urls]

    db.add(review)
    try:
        await db.commit()
    except IntegrityError:
        # Carrera entre dos envíos simultáneos: el UniqueConstraint es la
        # última línea de defensa contra la reseña duplicada.
        await db.rollback()
        raise DuplicateReviewException()
    await db.refresh(review, attribute_names=["images", "user"])

    return _to_review_response(review)


async def delete_review(db: AsyncSession, user: User, review_id: UUID) -> None:
    """Borra una reseña solo si el usuario autenticado es su autor (403)."""
    review = await repository.get_review_by_id(db, review_id)
    if review is None:
        raise ReviewNotFoundException(f"La reseña {review_id} no existe")
    if review.user_id != user.id:
        raise ReviewForbiddenException()

    await db.delete(review)
    await db.commit()


async def toggle_favorite(
    db: AsyncSession, user: User, attraction_id: UUID
) -> FavoriteToggleResponse:
    """Añade el favorito si no existe y lo elimina si ya existía."""
    await _get_attraction(db, attraction_id)

    favorito = await repository.get_favorite(db, user.id, attraction_id)
    if favorito is not None:
        await db.delete(favorito)
        await db.commit()
        return FavoriteToggleResponse(attraction_id=attraction_id, is_favorite=False)

    db.add(Favorite(user_id=user.id, attraction_id=attraction_id))
    try:
        await db.commit()
    except IntegrityError:
        # Otro request añadió el favorito a la vez: se asume ya existente.
        await db.rollback()
        return FavoriteToggleResponse(attraction_id=attraction_id, is_favorite=True)
    return FavoriteToggleResponse(attraction_id=attraction_id, is_favorite=True)


async def list_user_favorites(
    db: AsyncSession, user_id: UUID
) -> list[FavoriteResponse]:
    """Favoritos del usuario con nombre y portada del atractivo."""
    favoritos = await repository.list_favorites_by_user(db, user_id)
    return [_to_favorite_response(f) for f in favoritos]


async def list_attraction_reviews(
    db: AsyncSession, attraction_id: UUID
) -> list[ReviewResponse]:
    """Reseñas de un atractivo, de la más reciente a la más antigua."""
    reviews = await repository.list_reviews_by_attraction(db, attraction_id)
    return [_to_review_response(r) for r in reviews]


async def calculate_average_rating(
    db: AsyncSession, attraction_id: UUID
) -> float | None:
    """Promedio de calificaciones (lo consume `catalog.get_attraction_detail`)."""
    return await repository.average_rating(db, attraction_id)
