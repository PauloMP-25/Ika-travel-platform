"""Enums y DTOs del módulo de traducción (Sprint 3, RNF-04)."""

from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, model_validator
from typing_extensions import Self

from src.core.config import configuracion


class Language(str, Enum):
    ES = "es"
    EN = "en"


class PhraseCategory(str, Enum):
    GREETINGS = "saludos"
    EMERGENCY = "emergencia"
    TRANSPORT = "transporte"
    FOOD = "alimentacion"
    ACTIVITIES = "actividades"
    ORIENTATION = "orientacion"
    HEALTH = "salud"
    FORMAL_SERVICES = "servicios_formales"


class TranslationOrigin(str, Enum):
    OFFICIAL_PHRASE = "official_phrase"
    CACHE = "cache"
    CACHE_FALLBACK = "cache_fallback"
    PROVIDER = "provider"


class TranslationRequest(BaseModel):
    """Solicitud de traducción de texto libre (es↔en, idiomas distintos)."""

    model_config = ConfigDict(str_strip_whitespace=True)

    text: str = Field(min_length=1, max_length=configuracion.TRANSLATION_MAX_CHARS)
    source_lang: Language
    target_lang: Language

    @model_validator(mode="after")
    def validate_distinct_languages(self) -> Self:
        if self.source_lang == self.target_lang:
            raise ValueError("El idioma de origen y el de destino deben ser distintos")
        return self


class TranslationResponse(BaseModel):
    translated_text: str
    source_lang: Language
    target_lang: Language
    origin: TranslationOrigin
    phrase_id: str | None = None


class PhraseItem(BaseModel):
    id: str
    category: PhraseCategory
    es: str
    en: str


class PhrasebookResponse(BaseModel):
    version: str
    total: int
    categories: list[PhraseCategory]
    phrases: list[PhraseItem]
