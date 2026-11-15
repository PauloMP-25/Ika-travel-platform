"""Modelos SQLAlchemy para Favoritos (`reviews`).

Cumple con:
- Favoritos con UniqueConstraint (uq_user_attraction_favorite).
"""

import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base


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
