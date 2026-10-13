"""Proximidad, validación de cobertura y trazado de rutas."""
import hashlib
import logging
import math
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.catalog import repository as catalog_repo
from src.modules.catalog.exceptions import AttractionNotFoundException, InvalidCategoryFilterException
from src.modules.geo import osrm_client, repository
from src.modules.geo.exceptions import InvalidRouteRequestException, UserTooFarFromAttractionException
from src.modules.geo.schemas import (
    AttractionNearbyItem,
    Coordenada,
    GeoJSONLineString,
    LocationValidationResponse,
    ModoTransporte,
    NearbyResponse,
    NearestAttraction,
    ProximityResponse,
    RouteResponse,
    RouteStep,
)
from src.redis_client import cache_guardar_json, cache_obtener_json
from src.shared.utils import distancia_haversine_m

logger = logging.getLogger(__name__)

# Zona de cobertura de la primera fase (departamento de Ica, caja aproximada).
COBERTURA_LAT = (-15.6, -13.0)
COBERTURA_LON = (-76.5, -74.3)

METROS_POR_GRADO_LAT = 111_320.0
TTL_RUTA_SEGUNDOS = 3600
# Velocidades para estimar tiempos cuando OSRM no está disponible (km/h)
_VELOCIDAD_ESTIMADA_KMH = {
    ModoTransporte.driving: 40.0,
    ModoTransporte.walking: 4.5,
    ModoTransporte.cycling: 14.0,
}


# ======================================================================
# Funciones puras
# ======================================================================
def esta_en_cobertura(latitud: float, longitud: float) -> bool:
    return (
        COBERTURA_LAT[0] <= latitud <= COBERTURA_LAT[1]
        and COBERTURA_LON[0] <= longitud <= COBERTURA_LON[1]
    )


def caja_envolvente(latitud: float, longitud: float, radio_m: float) -> tuple[float, float, float, float]:
    dlat = radio_m / METROS_POR_GRADO_LAT
    coseno = max(math.cos(math.radians(latitud)), 0.01)
    dlon = radio_m / (METROS_POR_GRADO_LAT * coseno)
    return latitud - dlat, latitud + dlat, longitud - dlon, longitud + dlon


def _instruccion(tipo: str, modificador: str | None, nombre: str) -> str:
    direcciones = {
        "left": "a la izquierda", "right": "a la derecha",
        "slight left": "ligeramente a la izquierda", "slight right": "ligeramente a la derecha",
        "sharp left": "en curva cerrada a la izquierda", "sharp right": "en curva cerrada a la derecha",
        "straight": "recto", "uturn": "para dar la vuelta",
    }
    direccion = direcciones.get(modificador or "", "")
    via = f" por {nombre}" if nombre else ""
    if tipo == "depart":
        return f"Inicia el recorrido{via}"
    if tipo == "arrive":
        return "Has llegado a tu destino"
    if modificador == "straight" and tipo in ("turn", "end of road", "new name", "continue"):
        return f"Sigue recto{via}"
    if tipo in ("turn", "end of road"):
        return f"Gira {direccion}{via}".replace("Gira  ", "Gira ").strip()
    if tipo in ("fork",):
        return f"Mantente {direccion}{via}".strip()
    if tipo in ("merge", "on ramp"):
        return f"Incorpórate{via}"
    if tipo == "off ramp":
        return f"Toma la salida{via}"
    if tipo in ("roundabout", "rotary", "roundabout turn"):
        return f"Entra a la rotonda{via}"
    if tipo in ("exit roundabout", "exit rotary"):
        return f"Sal de la rotonda{via}"
    return f"Continúa{via}"


def _longitud_total_m(puntos: list[Coordenada]) -> float:
    return sum(
        distancia_haversine_m(a.latitude, a.longitude, b.latitude, b.longitude)
        for a, b in zip(puntos, puntos[1:])
    )


def estimar_ruta_lineal(puntos: list[Coordenada], modo: ModoTransporte, motivo: str) -> RouteResponse:
    """Plan alterno honesto: línea recta + tiempo estimado, marcada como aproximada."""
    distancia = _longitud_total_m(puntos)
    velocidad_ms = _VELOCIDAD_ESTIMADA_KMH[modo] * 1000 / 3600
    return RouteResponse(
        mode=modo,
        distance_m=round(distancia, 1),
        duration_s=round(distancia / velocidad_ms, 1),
        geometry=GeoJSONLineString(coordinates=[[p.longitude, p.latitude] for p in puntos]),
        steps=[],
        source="estimacion_lineal",
        is_approximate=True,
        notice=(
            f"Ruta referencial en línea recta; no sigue caminos reales. Motivo: {motivo}"
        ),
    )


# ======================================================================
# Proximidad
# ======================================================================
async def find_nearby_attractions(
    db: AsyncSession,
    *,
    latitude: float,
    longitude: float,
    radius_m: int,
    category_slug: str | None,
    limit: int,
) -> NearbyResponse:
    if category_slug and await catalog_repo.obtener_categoria_por_slug(db, category_slug) is None:
        raise InvalidCategoryFilterException(f"La categoría '{category_slug}' no existe.")
    lat_min, lat_max, lon_min, lon_max = caja_envolvente(latitude, longitude, radius_m)
    candidatos = await repository.atractivos_en_caja(
        db, lat_min=lat_min, lat_max=lat_max, lon_min=lon_min, lon_max=lon_max, category_slug=category_slug
    )
    con_distancia = [
        (a, distancia_haversine_m(latitude, longitude, a.latitude, a.longitude)) for a in candidatos
    ]
    dentro = sorted((x for x in con_distancia if x[1] <= radius_m), key=lambda x: (x[1], x[0].name))
    return NearbyResponse(
        origin=Coordenada(latitude=latitude, longitude=longitude),
        radius_m=radius_m,
        in_coverage=esta_en_cobertura(latitude, longitude),
        items=[
            AttractionNearbyItem(
                id=a.id, name=a.name, district=a.district, latitude=a.latitude,
                longitude=a.longitude, distance_m=round(d, 1),
                cover_image_url=a.images[0].url if a.images else None,
                categories=[c.name for c in a.categories],
            )
            for a, d in dentro[:limit]
        ],
    )


async def check_proximity(
    db: AsyncSession, attraction_id: UUID, *, latitude: float, longitude: float, max_distance_m: int
) -> ProximityResponse:
    atractivo = await catalog_repo.obtener_atractivo_por_id(db, attraction_id)
    if atractivo is None:
        raise AttractionNotFoundException()
    distancia = distancia_haversine_m(latitude, longitude, atractivo.latitude, atractivo.longitude)
    return ProximityResponse(
        attraction_id=atractivo.id,
        attraction_name=atractivo.name,
        distance_m=round(distancia, 1),
        max_distance_m=max_distance_m,
        is_nearby=distancia <= max_distance_m,
    )


async def require_proximity(
    db: AsyncSession, attraction_id: UUID, *, latitude: float, longitude: float, max_distance_m: int = 500
) -> ProximityResponse:
    """Para otros módulos: lanza ``UserTooFarFromAttractionException`` si el usuario está lejos."""
    resultado = await check_proximity(
        db, attraction_id, latitude=latitude, longitude=longitude, max_distance_m=max_distance_m
    )
    if not resultado.is_nearby:
        raise UserTooFarFromAttractionException(
            f"Estás a {resultado.distance_m:.0f} m de '{resultado.attraction_name}'; "
            f"debes estar a menos de {max_distance_m} m."
        )
    return resultado


async def validate_location(
    db: AsyncSession, *, latitude: float, longitude: float
) -> LocationValidationResponse:
    """¿Está la coordenada en la zona de cobertura y cuál es el atractivo más cercano (≤ 50 km)?"""
    cercanos = await find_nearby_attractions(
        db, latitude=latitude, longitude=longitude, radius_m=50_000, category_slug=None, limit=1
    )
    mas_cercano = cercanos.items[0] if cercanos.items else None
    return LocationValidationResponse(
        in_coverage=esta_en_cobertura(latitude, longitude),
        nearest_attraction=(
            NearestAttraction(id=mas_cercano.id, name=mas_cercano.name, distance_m=mas_cercano.distance_m)
            if mas_cercano
            else None
        ),
    )


# ======================================================================
# Rutas
# ======================================================================
def _clave_cache(puntos: list[Coordenada], modo: ModoTransporte, con_pasos: bool) -> str:
    huella = "|".join(f"{p.latitude:.5f},{p.longitude:.5f}" for p in puntos)
    resumen = hashlib.sha1(f"{modo.value}|{con_pasos}|{huella}".encode()).hexdigest()
    return f"geo:ruta:{resumen}"


async def trace_route(
    puntos: list[Coordenada], modo: ModoTransporte, *, include_steps: bool = True
) -> RouteResponse:
    for a, b in zip(puntos, puntos[1:]):
        if distancia_haversine_m(a.latitude, a.longitude, b.latitude, b.longitude) < 1:
            raise InvalidRouteRequestException("Dos puntos consecutivos de la ruta son idénticos.")

    clave = _clave_cache(puntos, modo, include_steps)
    en_cache = await cache_obtener_json(clave)
    if en_cache is not None:
        return RouteResponse.model_validate(en_cache)

    try:
        cruda = await osrm_client.solicitar_ruta(puntos, modo, con_pasos=include_steps)
    except osrm_client.OSRMNoDisponibleError as exc:
        logger.warning("OSRM no disponible; se devuelve ruta estimada: %s", exc)
        # No se cachea la estimación: en el próximo intento se vuelve a probar OSRM.
        return estimar_ruta_lineal(puntos, modo, str(exc))

    respuesta = RouteResponse(
        mode=modo,
        distance_m=round(cruda.distancia, 1),
        duration_s=round(cruda.duracion, 1),
        geometry=GeoJSONLineString(coordinates=cruda.coordenadas),
        steps=[
            RouteStep(
                instruction=_instruccion(p.tipo, p.modificador, p.nombre),
                distance_m=round(p.distancia, 1),
                duration_s=round(p.duracion, 1),
                location=p.ubicacion,
            )
            for p in cruda.pasos
        ],
        source="osrm",
        is_approximate=False,
    )
    await cache_guardar_json(clave, respuesta.model_dump(mode="json"), TTL_RUTA_SEGUNDOS)
    return respuesta


async def trace_route_to_attraction(
    db: AsyncSession,
    attraction_id: UUID,
    *,
    origin: Coordenada,
    modo: ModoTransporte,
    include_steps: bool,
) -> RouteResponse:
    atractivo = await catalog_repo.obtener_atractivo_por_id(db, attraction_id)
    if atractivo is None:
        raise AttractionNotFoundException()
    destino = Coordenada(latitude=atractivo.latitude, longitude=atractivo.longitude)
    return await trace_route([origin, destino], modo, include_steps=include_steps)
