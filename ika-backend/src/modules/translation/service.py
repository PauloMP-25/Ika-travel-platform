"""Servicio de traducción: frasebook → caché → proveedor → respaldo → 503."""

from __future__ import annotations

from src.modules.translation.cache import TranslationCache, build_cache_keys
from src.modules.translation.exceptions import TranslationProviderUnavailableException
from src.modules.translation.normalization import normalize_for_lookup
from src.modules.translation.phrasebook import Phrasebook
from src.modules.translation.providers import TranslationProvider
from src.modules.translation.schemas import (
    PhraseCategory,
    PhraseItem,
    PhrasebookResponse,
    TranslationOrigin,
    TranslationRequest,
    TranslationResponse,
)
from src.shared.usage_events import UsageEventData, UsageRecorder


class TranslationService:
    """Orquesta: frasebook → caché → proveedor → caché de respaldo → error."""

    def __init__(
        self,
        provider: TranslationProvider,
        cache: TranslationCache,
        phrasebook: Phrasebook,
        recorder: UsageRecorder | None = None,
    ) -> None:
        self._provider = provider
        self._cache = cache
        self._phrasebook = phrasebook
        self._recorder = recorder

    async def translate(self, request: TranslationRequest) -> TranslationResponse:
        """Resuelve la traducción sin fuzzy matching: una frase mal resuelta en un
        contexto SOS o de salud es inaceptable."""
        phrase = self._phrasebook.find(request.source_lang, normalize_for_lookup(request.text))
        if phrase is not None:
            resp = TranslationResponse(
                translated_text=phrase.text_in(request.target_lang),
                source_lang=request.source_lang,
                target_lang=request.target_lang,
                origin=TranslationOrigin.OFFICIAL_PHRASE,
                phrase_id=phrase.id,
            )
            await self._record_event(resp)
            return resp

        resp = await self._translate_free_text(request)
        await self._record_event(resp)
        return resp

    async def _translate_free_text(self, request: TranslationRequest) -> TranslationResponse:
        keys = build_cache_keys(request.source_lang, request.target_lang, request.text)

        cached = await self._cache.get(keys.primary)
        if cached is not None:
            return self._build(request, cached, TranslationOrigin.CACHE)

        try:
            translated = await self._provider.translate(
                request.text, request.source_lang, request.target_lang
            )
        except TranslationProviderUnavailableException:
            # Degradación controlada: si hay copia de respaldo, se sirve; si no, se relanza.
            backup = await self._cache.get(keys.fallback)
            if backup is None:
                raise
            return self._build(request, backup, TranslationOrigin.CACHE_FALLBACK)

        await self._cache.set(keys, translated)
        return self._build(request, translated, TranslationOrigin.PROVIDER)

    async def _record_event(self, response: TranslationResponse) -> None:
        """Registra el evento de uso anónimo (Ley N° 29733: nunca el texto)."""
        if self._recorder is None:
            return
        try:
            event = UsageEventData(
                event_type="translation",
                source_language=response.source_lang.value,
                target_language=response.target_lang.value,
                translation_origin=response.origin.value,
            )
            await self._recorder.record(event)
        except Exception:
            # Analítica nunca interrumpe la respuesta
            pass

    @staticmethod
    def _build(
        request: TranslationRequest, translated: str, origin: TranslationOrigin
    ) -> TranslationResponse:
        return TranslationResponse(
            translated_text=translated,
            source_lang=request.source_lang,
            target_lang=request.target_lang,
            origin=origin,
        )


def build_phrasebook_response(
    phrasebook: Phrasebook, category: PhraseCategory | None
) -> PhrasebookResponse:
    """Construye el DTO del frasebook (con o sin filtro de categoría)."""
    phrases = phrasebook.list(category)
    return PhrasebookResponse(
        version=phrasebook.version,
        total=len(phrases),
        categories=sorted({p.category for p in phrases}, key=lambda c: c.value),
        phrases=[PhraseItem(id=p.id, category=p.category, es=p.es, en=p.en) for p in phrases],
    )
