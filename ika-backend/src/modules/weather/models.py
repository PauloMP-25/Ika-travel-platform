import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    String,
    Text,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base


class AlertSeverity(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"


class WeatherSnapshot(Base):
    """Foto del clima en un momento dado. ``attraction_id`` NULL = región (Ica)."""

    __tablename__ = "weather_snapshot"
    __table_args__ = (Index("ix_weather_snapshot_attr_fetched", "attraction_id", "fetched_at"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    attraction_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("attraction.id", ondelete="CASCADE"), nullable=True
    )
    temperature: Mapped[float] = mapped_column(Float, nullable=False)  # °C
    uv_index: Mapped[float] = mapped_column(Float, nullable=False)
    wind_speed: Mapped[float] = mapped_column(Float, nullable=False)  # km/h
    humidity: Mapped[float] = mapped_column(Float, nullable=False)  # %
    precipitation: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)  # mm
    condition: Mapped[str] = mapped_column(String(60), nullable=False)
    # Clave para cumplir RN-03 (máx. 6 h de antigüedad)
    fetched_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), index=True, nullable=False, server_default=func.now()
    )
    source: Mapped[str] = mapped_column(String(50), nullable=False)

    recommendations: Mapped[list["AIRecommendation"]] = relationship(
        back_populates="weather_snapshot", cascade="all, delete-orphan", passive_deletes=True
    )


class WeatherAlert(Base):
    __tablename__ = "weather_alert"
    __table_args__ = (Index("ix_weather_alert_zone_code", "zone", "code"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    zone: Mapped[str] = mapped_column(String(100), nullable=False)
    # Extensión: identifica el tipo de alerta para no duplicarla en cada refresco.
    code: Mapped[str] = mapped_column(String(40), nullable=False, default="manual")
    severity: Mapped[AlertSeverity] = mapped_column(
        Enum(AlertSeverity, name="alert_severity"), nullable=False
    )
    message: Mapped[str] = mapped_column(Text, nullable=False)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class AIRecommendation(Base):
    __tablename__ = "ai_recommendation"
    __table_args__ = (
        Index("ix_ai_recommendation_attr_snapshot", "attraction_id", "weather_snapshot_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    attraction_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("attraction.id", ondelete="CASCADE"), nullable=False
    )
    weather_snapshot_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("weather_snapshot.id", ondelete="CASCADE"), nullable=False
    )
    recommendation_text: Mapped[str] = mapped_column(Text, nullable=False)
    score: Mapped[float] = mapped_column(Float, nullable=False)  # 0–1
    # Extensión: "reglas" (texto por plantilla) o "gemini" (redactado por IA generativa).
    text_source: Mapped[str] = mapped_column(String(20), nullable=False, default="reglas")
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    weather_snapshot: Mapped["WeatherSnapshot"] = relationship(back_populates="recommendations")
