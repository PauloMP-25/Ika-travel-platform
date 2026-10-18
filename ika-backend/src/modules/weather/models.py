"""Modelos de persistencia del módulo weather.

`WeatherSnapshot` guarda cada lectura de clima consensuada. Es la base del
caché de RN-03 (frescura de datos ≤ 6 h): el servicio consulta primero Redis,
luego el último snapshot de BD con `fecha_hora_pronostico` reciente y solo
si ambos fallan refresca contra los proveedores.

Los nombres de columna siguen el esquema `ClimaActual` para poder construir
un snapshot con `WeatherSnapshot(**clima.model_dump())`.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, Float, ForeignKey, Index, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from src.core.database import Base


class WeatherSnapshot(Base):
    __tablename__ = "weather_snapshot"
    __table_args__ = (
        # Consulta típica: último snapshot de un atractivo/destino.
        Index("ix_weather_snapshot_atractivo_creado", "atractivo_id", "creado_en"),
        Index("ix_weather_snapshot_destino_creado", "destino", "creado_en"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    atractivo_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("attraction.id", ondelete="CASCADE"), nullable=True
    )
    destino: Mapped[str] = mapped_column(String, nullable=False)

    temperatura_actual: Mapped[float] = mapped_column(Float, nullable=False)
    sensacion_termica: Mapped[float] = mapped_column(Float, nullable=False)
    probabilidad_precipitacion: Mapped[float] = mapped_column(Float, nullable=False)
    humedad: Mapped[float] = mapped_column(Float, nullable=False)
    velocidad_viento: Mapped[float] = mapped_column(Float, nullable=False)
    rafagas_viento: Mapped[float | None] = mapped_column(Float, nullable=True)
    indice_uv: Mapped[float] = mapped_column(Float, nullable=False)
    descripcion_clima: Mapped[str] = mapped_column(String, nullable=False)
    visibilidad: Mapped[float] = mapped_column(Float, nullable=False)
    hora_amanecer: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    hora_atardecer: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    fecha_hora_pronostico: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    origen_api: Mapped[str] = mapped_column(String, nullable=False)
    # --- Variables ampliadas para Ica (Sprint 4) ---
    presion_atmosferica: Mapped[float | None] = mapped_column(Float, nullable=True)  # hPa (predictor de tormentas de arena)
    precipitacion_mm: Mapped[float | None] = mapped_column(Float, nullable=True)  # mm acumulados
    temperatura_suelo_arena: Mapped[float | None] = mapped_column(Float, nullable=True)  # °C arena dunas
    calidad_aire_pm10: Mapped[float | None] = mapped_column(Float, nullable=True)  # ug/m3 particulas
    ventana_pico_uv: Mapped[str | None] = mapped_column(String(50), nullable=True)  # ej. '11:00 - 14:30'
    horas_sol_directo: Mapped[float | None] = mapped_column(Float, nullable=True)  # horas de sol
    altura_ola_metros: Mapped[float | None] = mapped_column(Float, nullable=True)  # m en Paracas / costa

    # Momento en que se guardó la lectura; RN-03 se evalúa contra este campo.
    creado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )


class SeveridadAlerta(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"


class WeatherAlert(Base):
    """Alerta meteorológica activa mientras `ends_at > now()`."""

    __tablename__ = "weather_alert"
    __table_args__ = (Index("ix_weather_alert_ends_at", "ends_at"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    zone: Mapped[str] = mapped_column(String(120), nullable=False)
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    severity: Mapped[SeveridadAlerta] = mapped_column(
        Enum(SeveridadAlerta, name="severidad_alerta"), nullable=False
    )
    message: Mapped[str] = mapped_column(Text, nullable=False)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class AIRecommendation(Base):
    """Recomendación por atractivo: score por reglas y texto (opcionalmente de Gemini)."""

    __tablename__ = "ai_recommendation"
    __table_args__ = (
        Index("ix_ai_recommendation_atractivo_generado", "atractivo_id", "generated_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    atractivo_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("attraction.id", ondelete="CASCADE"), nullable=False
    )
    weather_snapshot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("weather_snapshot.id", ondelete="CASCADE"), nullable=False
    )
    recommendation_text: Mapped[str] = mapped_column(Text, nullable=False)
    score: Mapped[float] = mapped_column(Float, nullable=False)  # 0–1
    nivel: Mapped[str] = mapped_column(String(20), nullable=False)
    generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
