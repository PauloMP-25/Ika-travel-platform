"""Dependencias de FastAPI del módulo translation (Sprint 3, F-4)."""

from __future__ import annotations

from functools import lru_cache

from fastapi import Depends
from redis.asyncio import Redis

from src.core.config import configuracion
from src.modules.translation.cache import TranslationCache
from src.modules.translation.phrasebook import PHRASEBOOK, Phrasebook
from src.modules.translation.providers import GeminiTranslationProvider, TranslationProvider
from src.modules.translation.service import TranslationService
from src.redis_client import obtener_cliente_redis


@lru_cache
def _gemini_provider() -> GeminiTranslationProvider:
    """Instancia única del proveedor Gemini (el cliente se construye de forma perezosa)."""
    return GeminiTranslationProvider(
        api_key=configuracion.GEMINI_API_KEY,
        model=configuracion.TRANSLATION_MODEL or configuracion.GEMINI_MODELO,
        timeout_seconds=configuracion.TRANSLATION_TIMEOUT_SECONDS,
    )


def get_translation_provider() -> TranslationProvider:
    return _gemini_provider()


def get_phrasebook() -> Phrasebook:
    return PHRASEBOOK


def get_translation_cache(redis: Redis = Depends(obtener_cliente_redis)) -> TranslationCache:
    return TranslationCache(
        redis=redis,
        ttl_seconds=configuracion.TRANSLATION_CACHE_TTL_SECONDS,
        fallback_ttl_seconds=configuracion.TRANSLATION_FALLBACK_TTL_SECONDS,
    )


def get_translation_service(
    provider: TranslationProvider = Depends(get_translation_provider),
    cache: TranslationCache = Depends(get_translation_cache),
    phrasebook: Phrasebook = Depends(get_phrasebook),
) -> TranslationService:
    return TranslationService(provider, cache, phrasebook)
