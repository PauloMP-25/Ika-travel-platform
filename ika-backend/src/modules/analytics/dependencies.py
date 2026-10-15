from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from uuid import UUID

from fastapi import BackgroundTasks, Depends, Query, Request
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from src.core.config import configuracion
from src.core.database import SesionAsincronaLocal, obtener_bd
from src.modules.analytics.date_range import DateRange, get_date_range
from src.modules.analytics.exceptions import (
    DateRangeTooLargeException,
    InvalidDateRangeException,
)
from src.modules.analytics.recorder import PostgresUsageRecorder
from src.modules.analytics.repository import AnalyticsRepository
from src.modules.analytics.service import AnalyticsCache, AnalyticsService
from src.redis_client import obtener_cliente_redis
from src.shared.usage_events import UsageEventData, UsageRecorder

DEFAULT_ANALYTICS_CACHE_TTL_SECONDS = getattr(configuracion, "ANALYTICS_CACHE_TTL_SECONDS", 900)


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    return SesionAsincronaLocal


def get_usage_recorder(
    factory: async_sessionmaker[AsyncSession] = Depends(get_session_factory),
) -> UsageRecorder:
    return PostgresUsageRecorder(factory)


def get_analytics_service(
    session: AsyncSession = Depends(obtener_bd),
    redis_client: Redis = Depends(obtener_cliente_redis),
) -> AnalyticsService:
    cache = AnalyticsCache(redis_client, DEFAULT_ANALYTICS_CACHE_TTL_SECONDS)
    return AnalyticsService(AnalyticsRepository(session), cache)


def _ui_language(request: Request) -> str | None:
    header = request.headers.get("accept-language", "")
    primary = header.split(",")[0].strip().lower()[:2]
    return primary if primary in {"es", "en"} else None


async def track_attraction_search(
    request: Request,
    tasks: BackgroundTasks,
    recorder: UsageRecorder = Depends(get_usage_recorder),
) -> None:
    tasks.add_task(
        recorder.record,
        UsageEventData(
            event_type="attraction_search",
            ui_language=_ui_language(request),
            category_slug=(request.query_params.get("category") or None) and request.query_params["category"][:80],
            district=(request.query_params.get("district") or None) and request.query_params["district"][:80],
        ),
    )


async def track_attraction_view(
    attraction_id: UUID,
    request: Request,
    tasks: BackgroundTasks,
    recorder: UsageRecorder = Depends(get_usage_recorder),
) -> None:
    tasks.add_task(
        recorder.record,
        UsageEventData(
            event_type="attraction_view",
            ui_language=_ui_language(request),
            attraction_id=attraction_id,
        ),
    )
