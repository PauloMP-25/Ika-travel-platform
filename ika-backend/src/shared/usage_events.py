from __future__ import annotations

from dataclasses import dataclass
from typing import Literal, Protocol
from uuid import UUID

EventType = Literal["translation", "attraction_search", "attraction_view"]


@dataclass(frozen=True, slots=True)
class UsageEventData:
    """Evento anónimo: solo dimensiones agregables, sin datos personales (Ley N° 29733)."""

    event_type: EventType
    ui_language: str | None = None
    source_lang: str | None = None
    target_lang: str | None = None
    translation_origin: str | None = None
    category_slug: str | None = None
    district: str | None = None
    attraction_id: UUID | None = None


class UsageRecorder(Protocol):
    """Protocolo desacoplado para registrar eventos de uso."""

    async def record(self, event: UsageEventData) -> None:
        """Registra un evento de forma asíncrona."""
        ...
