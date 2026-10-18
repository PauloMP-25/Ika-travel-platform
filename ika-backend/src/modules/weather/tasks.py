"""Tareas programadas (Celery Beat) del módulo weather. Ver `celery_worker.py`."""

import asyncio
import logging

from celery import shared_task

from src.core.database import SesionAsincronaLocal, motor
from src.modules.weather import service
from src.redis_client import cerrar_redis

logger = logging.getLogger(__name__)


async def _ejecutar(operacion):
    """Corre `operacion(db)` en una sesión propia y libera conexiones del loop.

    `asyncio.run` crea un event loop nuevo por tarea: el cliente Redis global y
    el pool de BD quedarían atados a un loop cerrado, así que se cierran al final.
    """
    try:
        async with SesionAsincronaLocal() as db:
            return await operacion(db)
    finally:
        await cerrar_redis()
        await motor.dispose()


@shared_task(name="weather.refrescar_cache_clima")
def refrescar_cache_clima() -> dict[str, int]:
    """RN-03: refresca clima, alertas y recomendaciones (cada 5 h < 6 h de vigencia)."""
    resultado = asyncio.run(_ejecutar(service.refrescar_todo))
    logger.info("Clima refrescado: %s", resultado)
    return resultado


@shared_task(name="weather.purgar_datos_antiguos")
def purgar_datos_antiguos() -> int:
    """Limpia snapshots de más de 7 días y alertas vencidas."""
    eliminados = asyncio.run(_ejecutar(service.purgar_antiguos))
    logger.info("Snapshots de clima purgados: %s", eliminados)
    return eliminados
