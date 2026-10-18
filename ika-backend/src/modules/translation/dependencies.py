"""Dependencias de FastAPI del módulo translation (Sprint 3, F-4 / F-5)."""

from __future__ import annotations

from functools import lru_cache

from fastapi import Depends
from redis.asyncio import Redis

from src.core.config import configuracion
from src.core.rate_limit import limit_requests
from src.modules.analytics.dependencies import get_usage_recorder
from src.modules.translation.cache import TranslationCache
from src.modules.translation.phrasebook import PHRASEBOOK, Phrasebook
from src.modules.translation.providers import GeminiTranslationProvider, TranslationProvider
from src.modules.translation.service import TranslationService
from src.redis_client import obtener_cliente_redis
from src.shared.usage_events import UsageRecorder


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
    recorder: UsageRecorder = Depends(get_usage_recorder),
) -> TranslationService:
    return TranslationService(
        provider=provider,
        cache=cache,
        phrasebook=phrasebook,
        recorder=recorder,
    )


# Rate limit F-5: 30 traducciones por minuto por IP (RN-02 / RNF-01)
limit_translations = limit_requests(
    scope="translate",
    maximum=configuracion.TRANSLATION_RATE_LIMIT_PER_MINUTE,
    window_seconds=60,
)
