from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Index, String, func
from sqlalchemy.orm import Mapped, mapped_column

from src.core.database import Base


class UsageEventType(str, enum.Enum):
    TRANSLATION = "translation"
    ATTRACTION_SEARCH = "attraction_search"
    ATTRACTION_VIEW = "attraction_view"


def _enum_values(enum_cls: enum.EnumMeta) -> list[str]:
    return [member.value for member in enum_cls]


class UsageEvent(Base):
    """Evento de uso anonimizado. No almacena IP, user_id ni texto libre (Ley N° 29733)."""

    __tablename__ = "usage_events"
    __table_args__ = (
        Index("ix_usage_events_type_created_at", "event_type", "created_at"),
        Index("ix_usage_events_attraction_id", "attraction_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    event_type: Mapped[UsageEventType] = mapped_column(
        Enum(
            UsageEventType,
            name="usage_event_type",
            values_callable=_enum_values,
        ),
        nullable=False,
    )
    ui_language: Mapped[str | None] = mapped_column(String(5), nullable=True)
    source_lang: Mapped[str | None] = mapped_column(String(5), nullable=True)
    target_lang: Mapped[str | None] = mapped_column(String(5), nullable=True)
    translation_origin: Mapped[str | None] = mapped_column(String(20), nullable=True)
    category_slug: Mapped[str | None] = mapped_column(String(80), nullable=True)
    district: Mapped[str | None] = mapped_column(String(80), nullable=True)
    attraction_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("attraction.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
