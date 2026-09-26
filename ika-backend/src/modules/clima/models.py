"""Modelo de persistencia de snapshots de clima.

No se usa todavía en el flujo del PoC (`service.obtener_clima_destino`
consulta siempre en vivo). Queda listo para la iteración 2, cuando se
implemente el caché de RN-03 (frescura de datos ≤6h) vía Celery Beat —
equivale a `WeatherSnapshot` en `docs/modelo_datos.md`.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from src.core.database import Base


class RegistroClima(Base):
    __tablename__ = "registro_clima"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    atractivo_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("attraction.id", ondelete="SET NULL"), nullable=True
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

    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
