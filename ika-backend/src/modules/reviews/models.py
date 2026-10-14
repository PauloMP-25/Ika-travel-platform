"""Modelos SQLAlchemy para Reseñas, Fotos y Favoritos (`reviews`).

Cumple con:
- Calificación entera de 1 a 5 con CheckConstraint (ck_review_rating_range).
- 1 reseña por usuario por atractivo (UniqueConstraint uq_user_attraction_review).
- Relación 1:N con ReviewImage (fotos subidas).
- Favoritos con UniqueConstraint (uq_user_attraction_favorite).
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
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
    """Reseña de un atractivo turístico por parte de un usuario autenticado."""

    __tablename__ = "reviews"
    __table_args__ = (
        CheckConstraint("rating >= 1 AND rating <= 5", name="ck_review_rating_range"),
        UniqueConstraint("user_id", "attraction_id", name="uq_user_attraction_review"),
        Index("ix_reviews_attraction_id", "attraction_id"),
        Index("ix_reviews_user_id", "user_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    attraction_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("attraction.id", ondelete="CASCADE"),
        nullable=False,
    )
    rating: Mapped[int] = mapped_column(Integer, nullable=False)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now(), nullable=True
    )

    user = relationship("User")
    attraction = relationship("Attraction")
    images: Mapped[list["ReviewImage"]] = relationship(
        "ReviewImage",
        back_populates="review",
        cascade="all, delete-orphan",
        order_by="ReviewImage.created_at",
    )


class ReviewImage(Base):
    """Imagen asociada a una reseña turística."""

    __tablename__ = "review_images"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    review_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("reviews.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    image_url: Mapped[str] = mapped_column(String(500), nullable=False)
    storage_provider: Mapped[str] = mapped_column(String(50), nullable=False, default="local")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    review: Mapped["Review"] = relationship("Review", back_populates="images")


class Favorite(Base):
    """Marcador de atractivo favorito guardado por un turista."""

    __tablename__ = "favorites"
    __table_args__ = (
        UniqueConstraint("user_id", "attraction_id", name="uq_user_attraction_favorite"),
        Index("ix_favorites_user_id", "user_id"),
        Index("ix_favorites_attraction_id", "attraction_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    attraction_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("attraction.id", ondelete="CASCADE"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user = relationship("User")
    attraction = relationship("Attraction")
