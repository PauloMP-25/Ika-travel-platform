"""Cliente Redis asíncrono con degradación elegante.

Redis se usa solo como caché. Si no está disponible, la API sigue funcionando
(consultando la fuente original) y se registra una advertencia en el log.
"""
import json
import logging
from typing import Any

import redis.asyncio as redis
from redis.exceptions import RedisError

from src.core.config import configuracion

logger = logging.getLogger(__name__)

_cliente: redis.Redis | None = None


def obtener_cliente_redis() -> redis.Redis:
    global _cliente
    if _cliente is None:
        _cliente = redis.from_url(
            configuracion.URL_REDIS,
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
    return _cliente


async def cache_obtener_json(clave: str) -> Any | None:
    try:
        crudo = await obtener_cliente_redis().get(clave)
    except (RedisError, OSError) as exc:
        logger.warning("Redis no disponible al leer '%s': %s", clave, exc)
        return None
    if crudo is None:
        return None
    try:
        return json.loads(crudo)
    except json.JSONDecodeError:
        logger.warning("Valor corrupto en caché para '%s'; se ignora.", clave)
        return None


async def cache_guardar_json(clave: str, valor: Any, ttl_segundos: int) -> bool:
    try:
        await obtener_cliente_redis().set(clave, json.dumps(valor, default=str), ex=ttl_segundos)
    except (RedisError, OSError) as exc:
        logger.warning("Redis no disponible al escribir '%s': %s", clave, exc)
        return False
    return True


async def cerrar_redis() -> None:
    """Cierra la conexión (apagado de la app o fin de una tarea Celery)."""
    global _cliente
    if _cliente is not None:
        try:
            await _cliente.aclose()
        except (RedisError, OSError, RuntimeError) as exc:
            logger.debug("Error al cerrar Redis (ignorable): %s", exc)
        _cliente = None
