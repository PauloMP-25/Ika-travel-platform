from __future__ import annotations

from datetime import date
from enum import Enum
from typing import Any, Literal
from uuid import UUID

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.analytics.date_range import DateRange  # noqa: F401
from src.modules.analytics.models import UsageEvent, UsageEventType
from src.modules.catalog.models import Attraction
from src.modules.emergency.models import IncidentStatus, IncidentType, TouristIncidentReport
from src.modules.reviews.models import Favorite, Review
from src.modules.users.models import User

SortBy = Literal["views", "favorites", "reviews"]

_REGISTERED_PREFERENCES_SQL = text(
    """
    SELECT pref AS label, COUNT(*) AS total
    FROM users AS u
    CROSS JOIN LATERAL json_array_elements_text(
        CASE WHEN json_typeof(u.preferences) = 'array' THEN u.preferences ELSE '[]'::json END
    ) AS pref
    WHERE u.is_active IS TRUE
    GROUP BY pref
    ORDER BY total DESC, label ASC
    """
)


def _label(value: Any) -> str:
    return str(value.value) if isinstance(value, Enum) else str(value)


class AnalyticsRepository:
    """Solo lectura. Todas las métricas se calculan con GROUP BY en PostgreSQL."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    # --- Idiomas y eventos ---

    async def preferred_languages(self) -> list[tuple[str, int]]:
        count = func.count(User.id)
        stmt = (
            select(User.preferred_language, count)
            .where(User.is_active.is_(True))
            .group_by(User.preferred_language)
            .order_by(count.desc(), User.preferred_language.asc())
        )
        return [(_label(lang), int(total)) for lang, total in (await self._session.execute(stmt)).all()]

    async def _event_breakdown(
        self, column: Any, event_type: UsageEventType, rng: Any
    ) -> list[tuple[str, int]]:
        count = func.count(UsageEvent.id)
        stmt = (
            select(column, count)
            .where(
                UsageEvent.event_type == event_type,
                column.is_not(None),
                UsageEvent.created_at >= rng.start_dt,
                UsageEvent.created_at < rng.end_dt_exclusive,
            )
            .group_by(column)
            .order_by(count.desc())
        )
        return [(_label(label), int(total)) for label, total in (await self._session.execute(stmt)).all()]

    async def translation_target_languages(self, rng: Any) -> list[tuple[str, int]]:
        return await self._event_breakdown(UsageEvent.target_lang, UsageEventType.TRANSLATION, rng)

    async def translation_origins(self, rng: Any) -> list[tuple[str, int]]:
        return await self._event_breakdown(
            UsageEvent.translation_origin, UsageEventType.TRANSLATION, rng
        )

    async def interface_languages(self, rng: Any) -> list[tuple[str, int]]:
        count = func.count(UsageEvent.id)
        stmt = (
            select(UsageEvent.ui_language, count)
            .where(
                UsageEvent.event_type.in_(
                    [UsageEventType.ATTRACTION_SEARCH, UsageEventType.ATTRACTION_VIEW]
                ),
                UsageEvent.ui_language.is_not(None),
                UsageEvent.created_at >= rng.start_dt,
                UsageEvent.created_at < rng.end_dt_exclusive,
            )
            .group_by(UsageEvent.ui_language)
            .order_by(count.desc())
        )
        return [(str(lang), int(total)) for lang, total in (await self._session.execute(stmt)).all()]

    async def searched_categories(self, rng: Any) -> list[tuple[str, int]]:
        return await self._event_breakdown(
            UsageEvent.category_slug, UsageEventType.ATTRACTION_SEARCH, rng
        )

    async def count_active_users(self) -> int:
        stmt = select(func.count(User.id)).where(User.is_active.is_(True))
        return int((await self._session.execute(stmt)).scalar_one())

    # --- Preferencias ---

    async def registered_preferences(self) -> list[tuple[str, int]]:
        result = await self._session.execute(_REGISTERED_PREFERENCES_SQL)
        return [(str(row.label), int(row.total)) for row in result.all()]

    # --- Atractivos con mayor interés (subconsultas agregadas: sin producto cartesiano) ---

    async def top_attractions(self, rng: Any, limit: int, sort_by: SortBy) -> list[dict[str, Any]]:
        favorites = (
            select(Favorite.attraction_id.label("attraction_id"), func.count(Favorite.id).label("total"))
            .where(Favorite.created_at >= rng.start_dt, Favorite.created_at < rng.end_dt_exclusive)
            .group_by(Favorite.attraction_id)
            .subquery()
        )
        reviews = (
            select(
                Review.attraction_id.label("attraction_id"),
                func.count(Review.id).label("total"),
                func.avg(Review.rating).label("avg_rating"),
            )
            .where(Review.created_at >= rng.start_dt, Review.created_at < rng.end_dt_exclusive)
            .group_by(Review.attraction_id)
            .subquery()
        )
        views = (
            select(UsageEvent.attraction_id.label("attraction_id"), func.count(UsageEvent.id).label("total"))
            .where(
                UsageEvent.event_type == UsageEventType.ATTRACTION_VIEW,
                UsageEvent.attraction_id.is_not(None),
                UsageEvent.created_at >= rng.start_dt,
                UsageEvent.created_at < rng.end_dt_exclusive,
            )
            .group_by(UsageEvent.attraction_id)
            .subquery()
        )
        views_count = func.coalesce(views.c.total, 0)
        favorites_count = func.coalesce(favorites.c.total, 0)
        reviews_count = func.coalesce(reviews.c.total, 0)
        sort_column = {"views": views_count, "favorites": favorites_count, "reviews": reviews_count}[sort_by]

        stmt = (
            select(
                Attraction.id,
                Attraction.name,
                Attraction.district,
                views_count.label("views"),
                favorites_count.label("favorites"),
                reviews_count.label("reviews"),
                reviews.c.avg_rating,
            )
            .select_from(Attraction)
            .outerjoin(views, views.c.attraction_id == Attraction.id)
            .outerjoin(favorites, favorites.c.attraction_id == Attraction.id)
            .outerjoin(reviews, reviews.c.attraction_id == Attraction.id)
            .where(Attraction.is_active.is_(True), sort_column > 0)
            .order_by(sort_column.desc(), Attraction.name.asc())
            .limit(limit)
        )
        rows = (await self._session.execute(stmt)).all()
        return [
            {
                "attraction_id": row.id,
                "name": row.name,
                "district": row.district,
                "views": int(row.views),
                "favorites": int(row.favorites),
                "reviews": int(row.reviews),
                "avg_rating": round(float(row.avg_rating), 2) if row.avg_rating is not None else None,
            }
            for row in rows
        ]

    # --- Incidentes ---

    async def incidents_by_type(self, rng: Any) -> list[tuple[str, int]]:
        return await self._incident_breakdown(TouristIncidentReport.incident_type, rng)

    async def incidents_by_status(self, rng: Any) -> list[tuple[str, int]]:
        return await self._incident_breakdown(TouristIncidentReport.status, rng)

    async def _incident_breakdown(self, column: Any, rng: Any) -> list[tuple[str, int]]:
        count = func.count(TouristIncidentReport.id)
        stmt = (
            select(column, count)
            .where(
                TouristIncidentReport.created_at >= rng.start_dt,
                TouristIncidentReport.created_at < rng.end_dt_exclusive,
            )
            .group_by(column)
            .order_by(count.desc())
        )
        return [(_label(label), int(total)) for label, total in (await self._session.execute(stmt)).all()]

    async def incidents_daily(self, rng: Any) -> dict[date, int]:
        day = func.date(func.timezone("America/Lima", TouristIncidentReport.created_at)).label("day")
        stmt = (
            select(day, func.count(TouristIncidentReport.id))
            .where(
                TouristIncidentReport.created_at >= rng.start_dt,
                TouristIncidentReport.created_at < rng.end_dt_exclusive,
            )
            .group_by(day)
            .order_by(day)
        )
        return {row[0]: int(row[1]) for row in (await self._session.execute(stmt)).all()}

    async def incidents_resolution(self, rng: Any) -> tuple[int, float | None]:
        """Devuelve (resueltos, horas promedio). Usa updated_at como aproximación de la fecha de resolución."""
        resolved = TouristIncidentReport.status == IncidentStatus.RESOLVED
        stmt = select(
            func.count(TouristIncidentReport.id).filter(resolved),
            func.avg(
                func.extract("epoch", TouristIncidentReport.updated_at - TouristIncidentReport.created_at)
            ).filter(resolved),
        ).where(
            TouristIncidentReport.created_at >= rng.start_dt,
            TouristIncidentReport.created_at < rng.end_dt_exclusive,
        )
        resolved_count, avg_seconds = (await self._session.execute(stmt)).one()
        hours = round(float(avg_seconds) / 3600, 2) if avg_seconds is not None else None
        return int(resolved_count or 0), hours

    async def top_informal_agencies(self, rng: Any, limit: int = 10) -> list[tuple[str, int]]:
        normalized = func.lower(func.trim(TouristIncidentReport.agency_name))
        count = func.count(TouristIncidentReport.id)
        stmt = (
            select(func.min(TouristIncidentReport.agency_name), count)
            .where(
                TouristIncidentReport.incident_type == IncidentType.INFORMAL_SERVICE,
                TouristIncidentReport.agency_name.is_not(None),
                TouristIncidentReport.created_at >= rng.start_dt,
                TouristIncidentReport.created_at < rng.end_dt_exclusive,
            )
            .group_by(normalized)
            .order_by(count.desc(), normalized.asc())
            .limit(limit)
        )
        return [(str(name), int(total)) for name, total in (await self._session.execute(stmt)).all()]
