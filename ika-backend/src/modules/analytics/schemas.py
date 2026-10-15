from __future__ import annotations

from datetime import date
from uuid import UUID

from pydantic import BaseModel, Field


class PeriodResponse(BaseModel):
    date_from: date
    date_to: date


class LabelCount(BaseModel):
    label: str
    count: int = Field(ge=0)
    percentage: float = Field(ge=0, le=100)


class DailyPoint(BaseModel):
    day: date
    count: int = Field(ge=0)


class LanguageStatsResponse(BaseModel):
    period: PeriodResponse
    preferred_language_users: list[LabelCount]      # usuarios activos hoy
    translation_target_languages: list[LabelCount]  # traducciones en el periodo
    interface_languages: list[LabelCount]           # Accept-Language de las consultas
    translation_origins: list[LabelCount]           # mide aciertos de caché y frasebook


class PreferenceStatsResponse(BaseModel):
    period: PeriodResponse
    registered_preferences: list[LabelCount]  # users.preferences (estado actual)
    searched_categories: list[LabelCount]     # eventos de búsqueda del periodo


class TopAttraction(BaseModel):
    attraction_id: UUID
    name: str
    district: str
    views: int
    favorites: int
    reviews: int
    avg_rating: float | None


class TopAttractionsResponse(BaseModel):
    period: PeriodResponse
    sort_by: str
    items: list[TopAttraction]


class IncidentStatsResponse(BaseModel):
    period: PeriodResponse
    total: int
    by_type: list[LabelCount]
    by_status: list[LabelCount]
    resolution_rate: float = Field(ge=0, le=100)
    avg_resolution_hours: float | None
    daily_series: list[DailyPoint]
    top_informal_agencies: list[LabelCount]


class SummaryKpis(BaseModel):
    active_users: int
    total_translations: int
    translation_cache_hit_ratio: float = Field(ge=0, le=100)
    total_incidents: int
    resolution_rate: float = Field(ge=0, le=100)


class DashboardSummaryResponse(BaseModel):
    period: PeriodResponse
    kpis: SummaryKpis
    languages: LanguageStatsResponse
    preferences: PreferenceStatsResponse
    top_attractions: TopAttractionsResponse
    incidents: IncidentStatsResponse
