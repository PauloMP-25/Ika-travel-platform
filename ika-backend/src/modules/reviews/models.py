"""Modelos SQLAlchemy del módulo `reviews` (reseñas, fotos y favoritos)."""

import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base


class Review(Base):
    """Calificación (1 a 5) que un usuario deja sobre un atractivo."""

    __tablename__ = "reviews"
    __table_args__ = (
        # Regla de negocio: la calificación solo admite enteros de 1 a 5.
        CheckConstraint("rating BETWEEN 1 AND 5", name="ck_reviews_rating_range"),
        # Un usuario solo puede reseñar una vez cada atractivo.
        UniqueConstraint(
            "user_id", "attraction_id", name="uq_reviews_user_attraction"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    attraction_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("attraction.id", ondelete="CASCADE"), index=True, nullable=False
    )
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # `back_populates` enlaza con `User.reviews` (módulo users).
    user = relationship("User", back_populates="reviews")
    images: Mapped[list["ReviewImage"]] = relationship(
        "ReviewImage",
        back_populates="review",
        cascade="all, delete-orphan",
        order_by="ReviewImage.id",
    )
    # Relación unidireccional: el catálogo no expone reseñas desde su modelo.
    attraction = relationship("Attraction")


class ReviewImage(Base):
    """Foto adjuntada por el turista a su reseña."""

    __tablename__ = "review_images"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    review_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("reviews.id", ondelete="CASCADE"), index=True, nullable=False
    )
    url: Mapped[str] = mapped_column(String(500), nullable=False)

    review = relationship("Review", back_populates="images")


class Favorite(Base):
    """Atractivo guardado por un usuario (entidad asociativa N:M)."""

    __tablename__ = "favorites"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "attraction_id", name="uq_favorites_user_attraction"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    attraction_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("attraction.id", ondelete="CASCADE"), index=True, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user = relationship("User", back_populates="favorites")
    attraction = relationship("Attraction")
