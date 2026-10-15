from __future__ import annotations

import logging
from collections.abc import Awaitable, Callable

from fastapi import Depends, Request
from redis.asyncio import Redis
from redis.exceptions import RedisError

from src.core.exceptions import RateLimitExceededException
from src.redis_client import obtener_cliente_redis

logger = logging.getLogger(__name__)


def limit_requests(
    scope: str, maximum: int, window_seconds: int
) -> Callable[..., Awaitable[None]]:
    """Fábrica de dependencias de rate limiting por IP (ventana fija, falla abierto).

    Detrás de un proxy, ejecutar uvicorn con --proxy-headers para que request.client.host
    sea la IP real del cliente.
    """

    async def dependency(request: Request, redis_client: Redis = Depends(obtener_cliente_redis)) -> None:
        client_ip = request.client.host if request.client else "desconocida"
        key = f"limite:{scope}:{client_ip}"
        try:
            async with redis_client.pipeline(transaction=True) as pipe:
                pipe.set(key, 0, ex=window_seconds, nx=True)
                pipe.incr(key)
                _, count = await pipe.execute()
        except (RedisError, OSError):
            logger.warning("Redis no disponible: rate limit omitido para %s", scope, exc_info=True)
            return
        if int(count) > maximum:
            raise RateLimitExceededException(window_seconds)

    return dependency
