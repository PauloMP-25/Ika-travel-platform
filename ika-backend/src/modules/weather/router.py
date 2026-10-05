from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.database import obtener_bd
from src.modules.weather import service
from src.modules.weather.schemas import (
    AIRecommendationResponse,
    RefreshSummary,
    WeatherAlertCreate,
    WeatherAlertResponse,
    WeatherCurrentResponse,
    WeatherForecastResponse,
)
from src.shared.admin import requerir_admin

router = APIRouter(prefix="/weather", tags=["weather"])


@router.get("/current", response_model=WeatherCurrentResponse)
async def clima_actual(
    attraction_id: UUID | None = Query(None, description="Si se omite, clima general de Ica"),
    db: AsyncSession = Depends(obtener_bd),
):
    return await service.get_current_weather(db, attraction_id)


@router.get("/forecast", response_model=WeatherForecastResponse)
async def pronostico(
    attraction_id: UUID | None = Query(None, description="Si se omite, pronóstico general de Ica"),
    db: AsyncSession = Depends(obtener_bd),
):
    return await service.get_forecast(db, attraction_id)


@router.get("/alerts", response_model=list[WeatherAlertResponse])
async def alertas_activas(
    zone: str | None = Query(None, description="Distrito o zona, ej. Ica"),
    db: AsyncSession = Depends(obtener_bd),
):
    return await service.get_active_alerts(db, zone)


@router.get("/recommendations", response_model=list[AIRecommendationResponse])
async def recomendaciones(
    category: str | None = Query(None, description="Slug de categoría"),
    limit: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(obtener_bd),
):
    """Atractivos ordenados por lo recomendable que es visitarlos con el clima de ahora."""
    return await service.get_ranked_recommendations(db, category_slug=category, limit=limit)


@router.get("/attractions/{attraction_id}/recommendation", response_model=AIRecommendationResponse)
async def recomendacion_atractivo(attraction_id: UUID, db: AsyncSession = Depends(obtener_bd)):
    return await service.get_recommendation_for_attraction(db, attraction_id)


# ----------------------------------------------------------------------
# Administración (header X-Admin-Key)
# ----------------------------------------------------------------------
@router.post(
    "/admin/refresh",
    response_model=RefreshSummary,
    tags=["weather-admin"],
    dependencies=[Depends(requerir_admin)],
)
async def refrescar_clima(db: AsyncSession = Depends(obtener_bd)):
    return await service.refresh_weather_cache(db)


@router.post(
    "/admin/alerts",
    response_model=WeatherAlertResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["weather-admin"],
    dependencies=[Depends(requerir_admin)],
)
async def crear_alerta_manual(data: WeatherAlertCreate, db: AsyncSession = Depends(obtener_bd)):
    return await service.create_manual_alert(db, data)
