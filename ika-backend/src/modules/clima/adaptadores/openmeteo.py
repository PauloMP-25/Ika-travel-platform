import httpx
from typing import Optional
from datetime import datetime
from src.modules.clima.adaptadores.base import AdaptadorClimaBase
from src.modules.clima.schemas import ClimaActual
from src.modules.clima.exceptions import ErrorMapeoClimaException, ProveedorClimaNoDisponibleException

class AdaptadorOpenMeteo(AdaptadorClimaBase):
    """
    Adaptador para Open-Meteo.
    100% Gratuito. No requiere API Key.
    """
    nombre_proveedor = "Open-Meteo (Gratuita)"

    def __init__(self):
        self.url_base = "https://api.open-meteo.com/v1/forecast"
        
    async def obtener_clima_actual(self, lat: float, lon: float) -> ClimaActual:
        parametros = {
            "latitude": lat,
            "longitude": lon,
            "current": "temperature_2m,apparent_temperature,precipitation_probability,relative_humidity_2m,wind_speed_10m,wind_gusts_10m,uv_index,weather_code,visibility",
            "daily": "sunrise,sunset",
            "timezone": "auto"
        }
        
        try:
            async with httpx.AsyncClient(timeout=10.0) as cliente:
                respuesta = await cliente.get(self.url_base, params=parametros)
                respuesta.raise_for_status()
                datos_crudos = respuesta.json()
                
                # Mapeo a nuestra entidad estándar
                actual = datos_crudos.get("current", {})
                diario = datos_crudos.get("daily", {})
                
                return ClimaActual(
                    temperatura_actual=actual.get("temperature_2m", 0.0),
                    sensacion_termica=actual.get("apparent_temperature", 0.0),
                    probabilidad_precipitacion=actual.get("precipitation_probability", 0),
                    humedad=actual.get("relative_humidity_2m", 0),
                    velocidad_viento=actual.get("wind_speed_10m", 0.0),
                    rafagas_viento=actual.get("wind_gusts_10m", 0.0),
                    indice_uv=actual.get("uv_index", 0.0),
                    descripcion_clima=self._traducir_codigo(actual.get("weather_code", 0)),
                    visibilidad=actual.get("visibility", 10000) / 1000, # km
                    hora_amanecer=diario.get("sunrise", [""])[0],
                    hora_atardecer=diario.get("sunset", [""])[0],
                    fecha_hora_pronostico=datetime.utcnow(),
                    origen_api="Open-Meteo (Gratuita)"
                )
        except httpx.HTTPError as e:
            raise ProveedorClimaNoDisponibleException("Open-Meteo", str(e))
        except Exception as e:
            raise ErrorMapeoClimaException("Open-Meteo", str(e))
            
    def _traducir_codigo(self, codigo: int) -> str:
        # WMO Weather interpretation codes
        if codigo == 0: return "Despejado"
        if codigo in [1, 2, 3]: return "Parcialmente Nublado"
        if codigo in [45, 48]: return "Niebla"
        if codigo in [51, 53, 55]: return "Llovizna"
        if codigo in [61, 63, 65]: return "Lluvia"
        if codigo in [80, 81, 82]: return "Chubascos"
        if codigo >= 95: return "Tormenta"
        return "Desconocido"
