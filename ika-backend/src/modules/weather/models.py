"""Modelos de persistencia del módulo weather.

`WeatherSnapshot` guarda cada lectura de clima consensuada. Es la base del
caché de RN-03 (frescura de datos ≤ 6 h): el servicio consulta primero Redis,
luego el último snapshot de BD con `fecha_hora_pronostico` reciente y solo
si ambos fallan refresca contra los proveedores.

Los nombres de columna siguen el esquema `ClimaActual` para poder construir
un snapshot con `WeatherSnapshot(**clima.model_dump())`.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Index, String, func
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

    # Momento en que se guardó la lectura; RN-03 se evalúa contra este campo.
    creado_en: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
