from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from src.modules.analytics.date_range import DateRange, get_date_range
from src.modules.analytics.dependencies import get_analytics_service
from src.modules.analytics.repository import SortBy
from src.modules.analytics.schemas import (
    DashboardSummaryResponse,
    IncidentStatsResponse,
    LanguageStatsResponse,
    PreferenceStatsResponse,
    TopAttractionsResponse,
)
from src.modules.analytics.service import AnalyticsService
from src.modules.users.dependencies import require_dircetur_admin

router = APIRouter(
    prefix="/admin/analytics",
    tags=["analytics"],
    dependencies=[Depends(require_dircetur_admin)],
)


@router.get("/summary", response_model=DashboardSummaryResponse)
async def get_summary(
    rng: DateRange = Depends(get_date_range),
    service: AnalyticsService = Depends(get_analytics_service),
) -> DashboardSummaryResponse:
    return await service.get_summary(rng)


@router.get("/languages", response_model=LanguageStatsResponse)
async def get_languages(
    rng: DateRange = Depends(get_date_range),
    service: AnalyticsService = Depends(get_analytics_service),
) -> LanguageStatsResponse:
    return await service.get_languages(rng)


@router.get("/preferences", response_model=PreferenceStatsResponse)
async def get_preferences(
    rng: DateRange = Depends(get_date_range),
    service: AnalyticsService = Depends(get_analytics_service),
) -> PreferenceStatsResponse:
    return await service.get_preferences(rng)


@router.get("/attractions/top", response_model=TopAttractionsResponse)
async def get_top_attractions(
    limit: int = Query(default=10, ge=1, le=50),
    sort_by: SortBy = Query(default="favorites"),
    rng: DateRange = Depends(get_date_range),
    service: AnalyticsService = Depends(get_analytics_service),
) -> TopAttractionsResponse:
    return await service.get_top_attractions(rng, limit, sort_by)


@router.get("/incidents", response_model=IncidentStatsResponse)
async def get_incident_stats(
    rng: DateRange = Depends(get_date_range),
    service: AnalyticsService = Depends(get_analytics_service),
) -> IncidentStatsResponse:
    return await service.get_incident_stats(rng)
