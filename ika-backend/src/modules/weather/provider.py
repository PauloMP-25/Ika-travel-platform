"""Cliente del proveedor meteorológico (Open-Meteo: gratuito y sin API key).

Una sola petición trae clima actual, pronóstico por horas y por días. El índice UV
no existe en ``current``; se toma de ``hourly`` en la hora local actual.
"""
import asyncio
import logging
from dataclasses import dataclass, field
from datetime import datetime

import httpx

from src.core.config import configuracion
from src.modules.weather.exceptions import WeatherProviderUnavailableException

logger = logging.getLogger(__name__)

NOMBRE_FUENTE = "open-meteo"

# Códigos WMO de Open-Meteo -> descripción en español
_CONDICIONES = {
    0: "Despejado", 1: "Mayormente despejado", 2: "Parcialmente nublado", 3: "Nublado",
    45: "Niebla", 48: "Niebla con escarcha",
    51: "Llovizna ligera", 53: "Llovizna", 55: "Llovizna intensa",
    56: "Llovizna helada", 57: "Llovizna helada intensa",
    61: "Lluvia ligera", 63: "Lluvia", 65: "Lluvia intensa",
    66: "Lluvia helada", 67: "Lluvia helada intensa",
    71: "Nevada ligera", 73: "Nevada", 75: "Nevada intensa", 77: "Granizo fino",
    80: "Chubascos ligeros", 81: "Chubascos", 82: "Chubascos violentos",
    85: "Chubascos de nieve", 86: "Chubascos de nieve intensos",
    95: "Tormenta", 96: "Tormenta con granizo", 99: "Tormenta fuerte con granizo",
}


def describir_condicion(codigo: int | None) -> str:
    return _CONDICIONES.get(codigo, "Desconocido") if codigo is not None else "Desconocido"


@dataclass
class ClimaActual:
    temperature: float
    uv_index: float
    wind_speed: float
    humidity: float
    precipitation: float
    condition: str


@dataclass
class PronosticoHora:
    time: datetime
    temperature: float
    uv_index: float
    wind_speed: float
    precipitation_probability: float
    condition: str


@dataclass
class PronosticoDia:
    date: str
    temp_min: float
    temp_max: float
    uv_index_max: float
    wind_speed_max: float
    precipitation_sum: float
    precipitation_probability_max: float
    condition: str


@dataclass
class DatosClima:
    actual: ClimaActual
    horas: list[PronosticoHora] = field(default_factory=list)  # próximas 24 h
    dias: list[PronosticoDia] = field(default_factory=list)  # 7 días


def _num(valor: object, defecto: float = 0.0) -> float:
    return float(valor) if isinstance(valor, (int, float)) else defecto


def _parsear(carga: dict) -> DatosClima:
    try:
        actual = carga["current"]
        horario = carga["hourly"]
        diario = carga["daily"]

        hora_actual = str(actual["time"])[:13] + ":00"  # "2026-10-04T14:15" -> "2026-10-04T14:00"
        tiempos = horario["time"]
        idx = tiempos.index(hora_actual) if hora_actual in tiempos else 0

        clima = ClimaActual(
            temperature=float(actual["temperature_2m"]),
            uv_index=_num(horario["uv_index"][idx]),
            wind_speed=float(actual["wind_speed_10m"]),
            humidity=_num(actual.get("relative_humidity_2m")),
            precipitation=_num(actual.get("precipitation")),
            condition=describir_condicion(actual.get("weather_code")),
        )
        horas = [
            PronosticoHora(
                time=datetime.fromisoformat(tiempos[i]),
                temperature=_num(horario["temperature_2m"][i]),
                uv_index=_num(horario["uv_index"][i]),
                wind_speed=_num(horario["wind_speed_10m"][i]),
                precipitation_probability=_num(horario["precipitation_probability"][i]),
                condition=describir_condicion(horario["weather_code"][i]),
            )
            for i in range(idx, min(idx + 24, len(tiempos)))
        ]
        dias = [
            PronosticoDia(
                date=diario["time"][i],
                temp_min=_num(diario["temperature_2m_min"][i]),
                temp_max=_num(diario["temperature_2m_max"][i]),
                uv_index_max=_num(diario["uv_index_max"][i]),
                wind_speed_max=_num(diario["wind_speed_10m_max"][i]),
                precipitation_sum=_num(diario["precipitation_sum"][i]),
                precipitation_probability_max=_num(diario["precipitation_probability_max"][i]),
                condition=describir_condicion(diario["weather_code"][i]),
            )
            for i in range(len(diario["time"]))
        ]
    except (KeyError, IndexError, TypeError, ValueError) as exc:
        raise WeatherProviderUnavailableException(
            "El proveedor meteorológico devolvió una respuesta con formato inesperado."
        ) from exc
    return DatosClima(actual=clima, horas=horas, dias=dias)


async def obtener_clima(latitud: float, longitud: float, *, reintentos: int = 2) -> DatosClima:
    """Consulta el clima de una coordenada. Reintenta ante fallos transitorios."""
    parametros = {
        "latitude": latitud,
        "longitude": longitud,
        "current": "temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m",
        "hourly": "temperature_2m,uv_index,wind_speed_10m,precipitation_probability,weather_code",
        "daily": (
            "weather_code,temperature_2m_max,temperature_2m_min,uv_index_max,"
            "wind_speed_10m_max,precipitation_sum,precipitation_probability_max"
        ),
        "wind_speed_unit": "kmh",
        "timezone": configuracion.CLIMA_ZONA_HORARIA,
        "forecast_days": 7,
    }
    ultimo_error: Exception | None = None
    for intento in range(reintentos + 1):
        try:
            async with httpx.AsyncClient(timeout=configuracion.CLIMA_TIMEOUT_SEGUNDOS) as cliente:
                respuesta = await cliente.get(configuracion.CLIMA_URL_BASE, params=parametros)
                respuesta.raise_for_status()
                return _parsear(respuesta.json())
        except WeatherProviderUnavailableException:
            raise  # formato inesperado: reintentar no ayuda
        except (httpx.HTTPError, ValueError) as exc:
            ultimo_error = exc
            logger.warning("Fallo consultando clima (intento %s): %s", intento + 1, exc)
            if intento < reintentos:
                await asyncio.sleep(0.5 * (intento + 1))
    raise WeatherProviderUnavailableException() from ultimo_error
