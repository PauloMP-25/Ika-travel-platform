from datetime import datetime

import httpx

from src.core.config import configuracion
from src.modules.clima.adaptadores.base import AdaptadorClimaBase
from src.modules.clima.exceptions import (
    ErrorMapeoClimaException,
    ProveedorClimaNoDisponibleException,
    ProveedorClimaTimeoutException,
)
from src.modules.clima.schemas import ClimaActual

URL_BASE = "https://api.weatherapi.com/v1/forecast.json"


class AdaptadorWeatherAPI(AdaptadorClimaBase):
    nombre_proveedor = "weatherapi"

    async def obtener_clima_actual(self, latitud: float, longitud: float) -> ClimaActual:
        parametros = {
            "key": configuracion.WEATHERAPI_API_KEY,
            "q": f"{latitud},{longitud}",
            "days": 1,
            "aqi": "no",
            "alerts": "no",
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
        except (KeyError, TypeError, ValueError, IndexError) as error:
            raise ErrorMapeoClimaException(self.nombre_proveedor, str(error)) from error

    def _mapear_a_entidad_estandar(self, datos_crudos: dict) -> ClimaActual:
        """Traduce la respuesta 'sucia' de WeatherAPI al esquema estándar."""
        actual = datos_crudos["current"]
        pronostico_dia = datos_crudos["forecast"]["forecastday"][0]
        astro = pronostico_dia["astro"]
        hora_del_dia = pronostico_dia["hour"][datetime.now().hour]

        return ClimaActual(
            temperatura_actual=actual["temp_c"],
            sensacion_termica=actual["feelslike_c"],
            probabilidad_precipitacion=hora_del_dia.get("chance_of_rain", 0.0),
            humedad=actual["humidity"],
            velocidad_viento=actual["wind_kph"],
            rafagas_viento=actual.get("gust_kph"),
            indice_uv=actual["uv"],
            descripcion_clima=actual["condition"]["text"],
            visibilidad=actual["vis_km"],
            hora_amanecer=self._parsear_hora_astro(pronostico_dia["date"], astro["sunrise"]),
            hora_atardecer=self._parsear_hora_astro(pronostico_dia["date"], astro["sunset"]),
            fecha_hora_pronostico=datetime.fromisoformat(actual["last_updated"]),
            origen_api=self.nombre_proveedor,
        )

    @staticmethod
    def _parsear_hora_astro(fecha: str, hora_12h: str) -> datetime:
        # WeatherAPI entrega la hora en formato "06:15 AM"
        return datetime.strptime(f"{fecha} {hora_12h}", "%Y-%m-%d %I:%M %p")
