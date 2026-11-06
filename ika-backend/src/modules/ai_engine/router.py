"""Endpoints del motor de IA: recomendaciones turísticas contextuales (clima + preferencias del turista)."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.database import obtener_bd
from src.modules.users.models import User
from src.modules.weather import service as weather_service
from src.modules.weather.router import obtener_usuario_opcional
from src.modules.weather.schemas import RecomendacionResponse

# Contrato propio del módulo ai_engine. Los alias históricos /weather/recommendations
# y /weather/recommendation-of-the-day se mantienen por compatibilidad con el cliente móvil.
router = APIRouter(prefix="/recommendations", tags=["ai_engine"])


@router.get("", response_model=list[RecomendacionResponse])
async def listar_recomendaciones(
    usuario_opcional: User | None = Depends(obtener_usuario_opcional),
    db: AsyncSession = Depends(obtener_bd),
) -> list[RecomendacionResponse]:
    """Atractivos ordenados por `score` descendente según el clima actual y las preferencias del turista."""
    preferencias = usuario_opcional.preferences if usuario_opcional else None
    return await weather_service.listar_recomendaciones(db, preferencias_usuario=preferencias)


@router.get("/of-the-day", response_model=RecomendacionResponse | None)
async def recomendacion_del_dia(
    usuario_opcional: User | None = Depends(obtener_usuario_opcional),
    db: AsyncSession = Depends(obtener_bd),
) -> RecomendacionResponse | None:
    """Top 1 de recomendaciones con narrativa asistida por Gemini (o fallback determinista)."""
    preferencias = usuario_opcional.preferences if usuario_opcional else None
    idioma = usuario_opcional.preferred_language if usuario_opcional else "es"
    return await weather_service.recomendacion_del_dia(db, preferencias_usuario=preferencias, idioma=idioma)
