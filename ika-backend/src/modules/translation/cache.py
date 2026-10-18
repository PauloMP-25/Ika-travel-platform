"""Caché Redis de traducciones con doble TTL y degradación controlada."""

from __future__ import annotations

import hashlib
import logging
from dataclasses import dataclass

from redis.asyncio import Redis
from redis.exceptions import RedisError

from src.modules.translation.normalization import normalize_for_cache
from src.modules.translation.schemas import Language

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class CacheKeys:
    primary: str
    fallback: str


def build_cache_keys(source: Language, target: Language, text: str) -> CacheKeys:
    """Construye claves estables y sin texto en claro: traduccion:v1:{src}:{dst}:{sha256}."""
    digest = hashlib.sha256(normalize_for_cache(text).encode("utf-8")).hexdigest()
    suffix = f"v1:{source.value}:{target.value}:{digest}"
    return CacheKeys(primary=f"traduccion:{suffix}", fallback=f"traduccion:respaldo:{suffix}")


class TranslationCache:
    """Caché de traducciones con degradación controlada si Redis no responde."""

    def __init__(self, redis: Redis, ttl_seconds: int, fallback_ttl_seconds: int) -> None:
        self._redis = redis
        self._ttl = ttl_seconds
        self._fallback_ttl = fallback_ttl_seconds

    async def get(self, key: str) -> str | None:
        try:
            value = await self._redis.get(key)
        except RedisError:
            logger.warning("Redis no disponible al leer la caché de traducciones", exc_info=True)
            return None
        if value is None:
            return None
        return value.decode("utf-8") if isinstance(value, bytes) else str(value)

    async def set(self, keys: CacheKeys, translated_text: str) -> None:
        try:
            async with self._redis.pipeline(transaction=True) as pipe:
                pipe.set(keys.primary, translated_text, ex=self._ttl)
                pipe.set(keys.fallback, translated_text, ex=self._fallback_ttl)
                await pipe.execute()
        except RedisError:
            logger.warning("Redis no disponible al guardar la caché de traducciones", exc_info=True)
