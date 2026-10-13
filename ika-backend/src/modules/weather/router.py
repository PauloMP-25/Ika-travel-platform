from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.database import obtener_bd
from src.modules.weather import service
from src.modules.weather.schemas import (
    AlertaClimaResponse,
    ClimaActualResponse,
    PronosticoResponse,
    RecomendacionResponse,
)

# Todos los endpoints son públicos: ya no hay reservas ni pagos, solo información (RN-02).
router = APIRouter(prefix="/weather", tags=["weather"])


@router.get("/current", response_model=ClimaActualResponse)
async def obtener_clima_actual(
    attraction_id: UUID | None = Query(None, description="Atractivo del catálogo"),
    destino: str | None = Query(None, description="Nombre de destino conocido, ej. 'Huacachina'"),
    db: AsyncSession = Depends(obtener_bd),
) -> ClimaActualResponse:
    """RF-06: clima actual consensuado (OpenWeatherMap, WeatherAPI, Open-Meteo).

    Sin parámetros devuelve el clima de la región. RN-03: el dato nunca supera
    las 6 h; si no se puede refrescar responde 503. `is_cached` indica si salió
    de Redis o de un snapshot reciente.
    """
    return await service.obtener_clima_actual(db, atractivo_id=attraction_id, destino=destino)


@router.get("/forecast", response_model=PronosticoResponse)
async def obtener_pronostico(
    attraction_id: UUID | None = Query(None),
    destino: str | None = Query(None),
    days: int = Query(3, ge=1, le=7),
    db: AsyncSession = Depends(obtener_bd),
) -> PronosticoResponse:
    """Pronóstico por horas (próximas 24 h) y por días (1–7)."""
    return await service.obtener_pronostico(db, atractivo_id=attraction_id, destino=destino, dias=days)


@router.get("/alerts", response_model=list[AlertaClimaResponse])
async def listar_alertas(db: AsyncSession = Depends(obtener_bd)) -> list[AlertaClimaResponse]:
    """Alertas meteorológicas activas (`ends_at > now()`)."""
    alertas = await service.listar_alertas_activas(db)
    return [AlertaClimaResponse.model_validate(a) for a in alertas]


@router.get("/recommendations", response_model=list[RecomendacionResponse])
async def listar_recomendaciones(
    db: AsyncSession = Depends(obtener_bd),
) -> list[RecomendacionResponse]:
    """Atractivos ordenados por `score` descendente según el clima actual."""
    return await service.listar_recomendaciones(db)


@router.get("/recommendation-of-the-day", response_model=RecomendacionResponse | None)
async def recomendacion_del_dia(
    db: AsyncSession = Depends(obtener_bd),
) -> RecomendacionResponse | None:
    """Top 1 de recomendaciones; alimenta la tarjeta «Recomendación del día»."""
    return await service.recomendacion_del_dia(db)
