from __future__ import annotations

import logging

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from src.modules.analytics.models import UsageEvent, UsageEventType
from src.shared.usage_events import UsageEventData

logger = logging.getLogger(__name__)


class PostgresUsageRecorder:
    """Persiste eventos con su propia sesión. Un fallo de analítica jamás afecta al turista."""

    def __init__(self, session_factory: async_sessionmaker[AsyncSession]) -> None:
        self._session_factory = session_factory

    async def record(self, event: UsageEventData) -> None:
        try:
            async with self._session_factory() as session:
                session.add(
                    UsageEvent(
                        event_type=UsageEventType(event.event_type),
                        ui_language=event.ui_language,
                        source_lang=event.source_lang,
                        target_lang=event.target_lang,
                        translation_origin=event.translation_origin,
                        category_slug=event.category_slug,
                        district=event.district,
                        attraction_id=event.attraction_id,
                    )
                )
                await session.commit()
        except SQLAlchemyError:
            logger.warning(
                "No se pudo registrar el evento de uso %s", event.event_type, exc_info=True
            )
