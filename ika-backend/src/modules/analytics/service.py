from __future__ import annotations

import logging
from datetime import timedelta
from typing import Sequence

from redis.asyncio import Redis
from redis.exceptions import RedisError

from src.modules.analytics.date_range import DateRange
from src.modules.analytics.repository import AnalyticsRepository, SortBy
from src.modules.analytics.schemas import (
    DailyPoint,
    DashboardSummaryResponse,
    IncidentStatsResponse,
    LabelCount,
    LanguageStatsResponse,
    PeriodResponse,
    PreferenceStatsResponse,
    SummaryKpis,
    TopAttraction,
    TopAttractionsResponse,
)

logger = logging.getLogger(__name__)


def _percentage(part: int, total: int) -> float:
    return round(part * 100 / total, 2) if total else 0.0


def to_label_counts(rows: Sequence[tuple[str, int]]) -> list[LabelCount]:
    total = sum(count for _, count in rows)
    return [LabelCount(label=label, count=count, percentage=_percentage(count, total)) for label, count in rows]


class AnalyticsCache:
    def __init__(self, redis: Redis, ttl_seconds: int) -> None:
        self._redis = redis
        self._ttl = ttl_seconds

    async def get_summary(self, key: str) -> DashboardSummaryResponse | None:
        try:
            raw = await self._redis.get(key)
        except (RedisError, OSError):
            logger.warning("Redis no disponible al leer la caché analítica", exc_info=True)
            return None
        if raw is None:
            return None
        return DashboardSummaryResponse.model_validate_json(raw)

    async def set_summary(self, key: str, value: DashboardSummaryResponse) -> None:
        try:
            await self._redis.set(key, value.model_dump_json(), ex=self._ttl)
        except (RedisError, OSError):
            logger.warning("Redis no disponible al guardar la caché analítica", exc_info=True)


class AnalyticsService:
    def __init__(self, repository: AnalyticsRepository, cache: AnalyticsCache) -> None:
        self._repo = repository
        self._cache = cache

    @staticmethod
    def _period(rng: DateRange) -> PeriodResponse:
        return PeriodResponse(date_from=rng.start, date_to=rng.end)

    async def get_languages(self, rng: DateRange) -> LanguageStatsResponse:
        return LanguageStatsResponse(
            period=self._period(rng),
            preferred_language_users=to_label_counts(await self._repo.preferred_languages()),
            translation_target_languages=to_label_counts(await self._repo.translation_target_languages(rng)),
            interface_languages=to_label_counts(await self._repo.interface_languages(rng)),
            translation_origins=to_label_counts(await self._repo.translation_origins(rng)),
        )

    async def get_preferences(self, rng: DateRange) -> PreferenceStatsResponse:
        return PreferenceStatsResponse(
            period=self._period(rng),
            registered_preferences=to_label_counts(await self._repo.registered_preferences()),
            searched_categories=to_label_counts(await self._repo.searched_categories(rng)),
        )

    async def get_top_attractions(self, rng: DateRange, limit: int, sort_by: SortBy) -> TopAttractionsResponse:
        rows = await self._repo.top_attractions(rng, limit, sort_by)
        return TopAttractionsResponse(
            period=self._period(rng),
            sort_by=sort_by,
            items=[TopAttraction(**row) for row in rows],
        )

    # --- Incidentes ---

    async def get_incident_stats(self, rng: DateRange) -> IncidentStatsResponse:
        by_type = await self._repo.incidents_by_type(rng)
        by_status = await self._repo.incidents_by_status(rng)
        daily = await self._repo.incidents_daily(rng)
        resolved, avg_hours = await self._repo.incidents_resolution(rng)
        agencies = await self._repo.top_informal_agencies(rng)

        total = sum(count for _, count in by_status)
        days = (rng.end - rng.start).days + 1
        series = [
            DailyPoint(day=rng.start + timedelta(days=offset), count=daily.get(rng.start + timedelta(days=offset), 0))
            for offset in range(days)
        ]
        return IncidentStatsResponse(
            period=self._period(rng),
            total=total,
            by_type=to_label_counts(by_type),
            by_status=to_label_counts(by_status),
            resolution_rate=_percentage(resolved, total),
            avg_resolution_hours=avg_hours,
            daily_series=series,
            top_informal_agencies=to_label_counts(agencies),
        )

    # --- Resumen (secuencial: una AsyncSession no admite consultas concurrentes) ---

    async def get_summary(self, rng: DateRange) -> DashboardSummaryResponse:
        key = f"analytics:summary:v1:{rng.start.isoformat()}:{rng.end.isoformat()}"
        cached = await self._cache.get_summary(key)
        if cached is not None:
            return cached

        languages = await self.get_languages(rng)
        preferences = await self.get_preferences(rng)
        top = await self.get_top_attractions(rng, limit=5, sort_by="favorites")
        incidents = await self.get_incident_stats(rng)

        origins = {item.label: item.count for item in languages.translation_origins}
        total_translations = sum(origins.values())
        hits = origins.get("cache", 0) + origins.get("official_phrase", 0)
        summary = DashboardSummaryResponse(
            period=self._period(rng),
            kpis=SummaryKpis(
                active_users=await self._repo.count_active_users(),
                total_translations=total_translations,
                translation_cache_hit_ratio=_percentage(hits, total_translations),
                total_incidents=incidents.total,
                resolution_rate=incidents.resolution_rate,
            ),
            languages=languages,
            preferences=preferences,
            top_attractions=top,
            incidents=incidents,
        )
        await self._cache.set_summary(key, summary)
        return summary
