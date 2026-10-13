import math
from collections.abc import Awaitable, Callable
from datetime import datetime, timezone
from typing import TypeVar

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from src.core.config import configuracion
from src.redis_client import cerrar_redis

T = TypeVar("T")


def utc_ahora() -> datetime:
    return datetime.now(timezone.utc)


def escapar_like(termino: str) -> str:
    """Escapa %, _ y \\ para usar el texto del usuario dentro de un ILIKE (escape='\\\\')."""
    return termino.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def distancia_haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distancia en metros entre dos coordenadas (fórmula de Haversine)."""
    radio_tierra_m = 6_371_000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * radio_tierra_m * math.asin(math.sqrt(a))


async def ejecutar_con_sesion_aislada(funcion: Callable[[AsyncSession], Awaitable[T]]) -> T:
    """Ejecuta ``funcion(sesion)`` con un motor propio (sin pool).

    Pensado para tareas Celery: cada ``asyncio.run`` crea un event loop nuevo y
    las conexiones del motor global de FastAPI no son reutilizables entre loops.
    """
    motor_local = create_async_engine(configuracion.URL_BASE_DATOS, poolclass=NullPool)
    fabrica = async_sessionmaker(motor_local, expire_on_commit=False)
    try:
        async with fabrica() as sesion:
            return await funcion(sesion)
    finally:
        await motor_local.dispose()
        await cerrar_redis()
