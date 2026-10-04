"""Cliente de enrutamiento OSRM (servidores públicos de FOSSGIS).

Política de uso del servidor público: uso razonable y máx. ~1 petición/segundo,
por eso se serializa el acceso y el servicio cachea los resultados en Redis.
Para producción se recomienda desplegar una instancia propia (RUTAS_URL_BASE).
"""
import asyncio
import logging
import time
from dataclasses import dataclass, field

import httpx

from src.core.config import configuracion
from src.modules.geo.schemas import Coordenada, ModoTransporte

logger = logging.getLogger(__name__)

# El servidor de FOSSGIS ignora el perfil de la URL: el modo se elige con el prefijo "routed-*".
_PREFIJOS = {
    ModoTransporte.driving: "routed-car",
    ModoTransporte.walking: "routed-foot",
    ModoTransporte.cycling: "routed-bike",
}
_INTERVALO_MIN_S = 1.0
_candado = asyncio.Lock()
_ultima_peticion = 0.0


class OSRMNoDisponibleError(Exception):
    """OSRM no respondió o no encontró ruta. El servicio decide el plan alterno."""


@dataclass
class PasoCrudo:
    tipo: str
    modificador: str | None
    nombre: str
    distancia: float
    duracion: float
    ubicacion: Coordenada | None


@dataclass
class RutaCruda:
    distancia: float
    duracion: float
    coordenadas: list[list[float]]
    pasos: list[PasoCrudo] = field(default_factory=list)


async def _esperar_turno() -> None:
    global _ultima_peticion
    async with _candado:
        espera = _INTERVALO_MIN_S - (time.monotonic() - _ultima_peticion)
        if espera > 0:
            await asyncio.sleep(espera)
        _ultima_peticion = time.monotonic()


async def solicitar_ruta(
    puntos: list[Coordenada], modo: ModoTransporte, *, con_pasos: bool
) -> RutaCruda:
    coordenadas = ";".join(f"{p.longitude:.6f},{p.latitude:.6f}" for p in puntos)
    url = f"{configuracion.RUTAS_URL_BASE.rstrip('/')}/{_PREFIJOS[modo]}/route/v1/driving/{coordenadas}"
    parametros = {
        "overview": "full",
        "geometries": "geojson",
        "steps": "true" if con_pasos else "false",
        "alternatives": "false",
    }
    await _esperar_turno()
    try:
        async with httpx.AsyncClient(timeout=configuracion.RUTAS_TIMEOUT_SEGUNDOS) as cliente:
            respuesta = await cliente.get(url, params=parametros)
            carga = respuesta.json()
            if respuesta.status_code >= 500:
                raise OSRMNoDisponibleError(f"OSRM respondió HTTP {respuesta.status_code}")
    except (httpx.HTTPError, ValueError) as exc:
        raise OSRMNoDisponibleError(f"No se pudo contactar a OSRM: {exc}") from exc

    if carga.get("code") != "Ok" or not carga.get("routes"):
        raise OSRMNoDisponibleError(f"OSRM no encontró ruta ({carga.get('code', 'sin código')}).")

    try:
        ruta = carga["routes"][0]
        pasos: list[PasoCrudo] = []
        for tramo in ruta.get("legs", []):
            for paso in tramo.get("steps", []):
                man = paso.get("maneuver", {})
                loc = man.get("location")
                pasos.append(
                    PasoCrudo(
                        tipo=man.get("type", "continue"),
                        modificador=man.get("modifier"),
                        nombre=paso.get("name", ""),
                        distancia=float(paso.get("distance", 0)),
                        duracion=float(paso.get("duration", 0)),
                        ubicacion=Coordenada(latitude=loc[1], longitude=loc[0]) if loc else None,
                    )
                )
        return RutaCruda(
            distancia=float(ruta["distance"]),
            duracion=float(ruta["duration"]),
            coordenadas=[[float(x), float(y)] for x, y in ruta["geometry"]["coordinates"]],
            pasos=pasos,
        )
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise OSRMNoDisponibleError("Respuesta de OSRM con formato inesperado.") from exc
