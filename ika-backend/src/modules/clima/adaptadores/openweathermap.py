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

URL_BASE = "https://api.openweathermap.org/data/2.5/weather"

class AdaptadorOpenWeatherMap(AdaptadorClimaBase):
    nombre_proveedor = "openweathermap"

    async def obtener_clima_actual(self, latitud: float, longitud: float) -> ClimaActual:
        parametros = {
            "lat": latitud,
            "lon": longitud,
            "appid": configuracion.OPENWEATHERMAP_API_KEY,
            "units": "metric",
            "lang": "es",
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
        main_data = datos_crudos["main"]
        wind_data = datos_crudos.get("wind", {})
        sys_data = datos_crudos.get("sys", {})

        return ClimaActual(
            temperatura_actual=main_data["temp"],
            sensacion_termica=main_data["feels_like"],
            probabilidad_precipitacion=0.0,
            humedad=main_data["humidity"],
            velocidad_viento=wind_data.get("speed", 0) * 3.6,  # m/s -> km/h
            rafagas_viento=(wind_data.get("gust", 0) * 3.6) if wind_data.get("gust") else None,
            indice_uv=0.0,  # El endpoint 'weather' gratuito no trae UV
            descripcion_clima=datos_crudos["weather"][0]["description"],
            visibilidad=datos_crudos.get("visibility", 10000) / 1000,  # m -> km
            hora_amanecer=datetime.fromtimestamp(sys_data.get("sunrise", 0), tz=timezone.utc),
            hora_atardecer=datetime.fromtimestamp(sys_data.get("sunset", 0), tz=timezone.utc),
            fecha_hora_pronostico=datetime.fromtimestamp(datos_crudos.get("dt", 0), tz=timezone.utc),
            origen_api=self.nombre_proveedor,
        )
