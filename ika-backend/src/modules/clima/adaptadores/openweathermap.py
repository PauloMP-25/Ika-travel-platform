from datetime import datetime, timezone

import httpx

from src.core.config import configuracion
from src.modules.clima.adaptadores.base import AdaptadorClimaBase
from src.modules.clima.exceptions import (
    ErrorMapeoClimaException,
    ProveedorClimaNoDisponibleException,
    ProveedorClimaTimeoutException,
)
from src.modules.clima.schemas import ClimaActual

URL_BASE = "https://api.openweathermap.org/data/2.5/onecall"


class AdaptadorOpenWeatherMap(AdaptadorClimaBase):
    nombre_proveedor = "openweathermap"

    async def obtener_clima_actual(self, latitud: float, longitud: float) -> ClimaActual:
        parametros = {
            "lat": latitud,
            "lon": longitud,
            "appid": configuracion.OPENWEATHERMAP_API_KEY,
            "units": "metric",
            "lang": "es",
            "exclude": "minutely,hourly,daily,alerts",
        }
        try:
            async with httpx.AsyncClient(timeout=configuracion.TIMEOUT_CLIMA_SEGUNDOS) as cliente:
                respuesta = await cliente.get(URL_BASE, params=parametros)
                respuesta.raise_for_status()
        except httpx.TimeoutException as error:
            raise ProveedorClimaTimeoutException(self.nombre_proveedor, str(error)) from error
        except (httpx.HTTPStatusError, httpx.ConnectError, httpx.RequestError) as error:
            raise ProveedorClimaNoDisponibleException(self.nombre_proveedor, str(error)) from error

        try:
            return self._mapear_a_entidad_estandar(respuesta.json())
        except (KeyError, TypeError, ValueError) as error:
            raise ErrorMapeoClimaException(self.nombre_proveedor, str(error)) from error

    def _mapear_a_entidad_estandar(self, datos_crudos: dict) -> ClimaActual:
        """Traduce la respuesta 'sucia' de OpenWeatherMap al esquema estándar."""
        actual = datos_crudos["current"]
        return ClimaActual(
            temperatura_actual=actual["temp"],
            sensacion_termica=actual["feels_like"],
            # El endpoint 'current' de OneCall no trae probabilidad de lluvia;
            # se deja en 0 en este PoC (el bloque horario sí la trae, ver TODO).
            probabilidad_precipitacion=0.0,
            humedad=actual["humidity"],
            velocidad_viento=actual["wind_speed"] * 3.6,  # m/s -> km/h
            rafagas_viento=(actual["wind_gust"] * 3.6) if actual.get("wind_gust") else None,
            indice_uv=actual["uvi"],
            descripcion_clima=actual["weather"][0]["description"],
            visibilidad=actual["visibility"] / 1000,  # m -> km
            hora_amanecer=datetime.fromtimestamp(actual["sunrise"], tz=timezone.utc),
            hora_atardecer=datetime.fromtimestamp(actual["sunset"], tz=timezone.utc),
            fecha_hora_pronostico=datetime.fromtimestamp(actual["dt"], tz=timezone.utc),
            origen_api=self.nombre_proveedor,
        )
