from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.database import obtener_bd
from src.core.security import decode_access_token
from src.modules.users.models import User
from src.modules.weather import service
from src.modules.weather.schemas import (
    AlertaClimaResponse,
    ClimaActualResponse,
    PronosticoResponse,
    RecomendacionResponse,
)

# Los endpoints son públicos (RN-02). Si se provee token en Authorization,
# se obtienen las preferencias e idioma del turista para personalizar las recomendaciones.
router = APIRouter(prefix="/weather", tags=["weather"])


async def obtener_usuario_opcional(
    authorization: Annotated[str | None, Header()] = None,
    db: AsyncSession = Depends(obtener_bd),
) -> User | None:
    """Extrae el usuario si se envía un Bearer token válido; de lo contrario devuelve None."""
    if not authorization or not authorization.startswith("Bearer "):
        return None
    token = authorization.split(" ", 1)[1]
    try:
        user_id = decode_access_token(token)
        return await db.get(User, user_id)
    except Exception:
        return None


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
    usuario_opcional: User | None = Depends(obtener_usuario_opcional),
    db: AsyncSession = Depends(obtener_bd),
) -> list[RecomendacionResponse]:
    """Atractivos ordenados por `score` descendente según el clima actual y preferencias del turista."""
    preferencias = usuario_opcional.preferences if usuario_opcional else None
    return await service.listar_recomendaciones(db, preferencias_usuario=preferencias)


@router.get("/recommendation-of-the-day", response_model=RecomendacionResponse | None)
async def recomendacion_del_dia(
    usuario_opcional: User | None = Depends(obtener_usuario_opcional),
    db: AsyncSession = Depends(obtener_bd),
) -> RecomendacionResponse | None:
    """Top 1 de recomendaciones; alimentado por IA con personalización según perfil del turista."""
    preferencias = usuario_opcional.preferences if usuario_opcional else None
    idioma = usuario_opcional.preferred_language if usuario_opcional else "es"
    return await service.recomendacion_del_dia(db, preferencias_usuario=preferencias, idioma=idioma)
