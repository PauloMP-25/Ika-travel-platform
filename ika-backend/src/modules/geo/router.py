from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.database import obtener_bd
from src.modules.geo import service
from src.modules.geo.schemas import (
    Coordenada,
    LocationValidationResponse,
    ModoTransporte,
    NearbyResponse,
    ProximityResponse,
    RouteRequest,
    RouteResponse,
)

router = APIRouter(prefix="/geo", tags=["geo"])


@router.get("/nearby", response_model=NearbyResponse)
async def atractivos_cercanos(
    lat: float = Query(..., ge=-90, le=90, description="Latitud del usuario"),
    lon: float = Query(..., ge=-180, le=180, description="Longitud del usuario"),
    radius_m: int = Query(10_000, ge=100, le=100_000, description="Radio de búsqueda en metros"),
    category: str | None = Query(None, description="Slug de categoría"),
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(obtener_bd),
):
    return await service.find_nearby_attractions(
        db, latitude=lat, longitude=lon, radius_m=radius_m, category_slug=category, limit=limit
    )


@router.get("/attractions/{attraction_id}/proximity", response_model=ProximityResponse)
async def verificar_proximidad(
    attraction_id: UUID,
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    max_distance_m: int = Query(500, ge=10, le=50_000),
    db: AsyncSession = Depends(obtener_bd),
):
    return await service.check_proximity(
        db, attraction_id, latitude=lat, longitude=lon, max_distance_m=max_distance_m
    )


@router.get("/validate-location", response_model=LocationValidationResponse)
async def validar_ubicacion(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    db: AsyncSession = Depends(obtener_bd),
):
    return await service.validate_location(db, latitude=lat, longitude=lon)


@router.get("/route/to-attraction/{attraction_id}", response_model=RouteResponse)
async def ruta_hacia_atractivo(
    attraction_id: UUID,
    origin_lat: float = Query(..., ge=-90, le=90),
    origin_lon: float = Query(..., ge=-180, le=180),
    mode: ModoTransporte = ModoTransporte.driving,
    include_steps: bool = True,
    db: AsyncSession = Depends(obtener_bd),
):
    return await service.trace_route_to_attraction(
        db,
        attraction_id,
        origin=Coordenada(latitude=origin_lat, longitude=origin_lon),
        modo=mode,
        include_steps=include_steps,
    )


@router.post("/route", response_model=RouteResponse)
async def trazar_ruta(data: RouteRequest):
    """Ruta entre 2 y 10 puntos (origen, paradas intermedias y destino)."""
    return await service.trace_route(data.waypoints, data.mode, include_steps=data.include_steps)
