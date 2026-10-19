import httpx
from datetime import datetime, timezone

from src.modules.weather.adapters.base import AdaptadorClimaBase
from src.modules.weather.schemas import ClimaActual
from src.modules.weather.exceptions import ErrorMapeoClimaException, ProveedorClimaNoDisponibleException


class AdaptadorOpenMeteo(AdaptadorClimaBase):
    """
    Adaptador para Open-Meteo.
    100% Gratuito. Incluye pronóstico general, calidad de aire y variables de superficie.
    """
    nombre_proveedor = "open-meteo"

    def __init__(self):
        self.url_base = "https://api.open-meteo.com/v1/forecast"
        self.url_calidad_aire = "https://air-quality-api.open-meteo.com/v1/air-quality"
        self.url_marina = "https://marine-api.open-meteo.com/v1/marine"

    async def obtener_clima_actual(self, latitud: float, longitud: float) -> ClimaActual:
        parametros = {
            "latitude": latitud,
            "longitude": longitud,
            "current": (
                "temperature_2m,apparent_temperature,precipitation,precipitation_probability,"
                "relative_humidity_2m,wind_speed_10m,wind_gusts_10m,uv_index,"
                "weather_code,visibility,surface_pressure,soil_temperature_0cm"
            ),
            "daily": "sunrise,sunset,sunshine_duration",
            "hourly": "uv_index",
            "timezone": "auto",
        }

        try:
            async with httpx.AsyncClient(timeout=10.0) as cliente:
                # 1. Consulta meteorológica principal
                respuesta = await cliente.get(self.url_base, params=parametros)
                respuesta.raise_for_status()
                datos_crudos = respuesta.json()

                actual = datos_crudos.get("current", {})
                diario = datos_crudos.get("daily", {})
                horario = datos_crudos.get("hourly", {})

                # 2. Consultas complementarias opcionales (tolerantes a fallos)
                calidad_aire_pm10 = None
                try:
                    resp_aq = await cliente.get(
                        self.url_calidad_aire,
                        params={"latitude": latitud, "longitude": longitud, "current": "pm10"},
                    )
                    if resp_aq.status_code == 200:
                        calidad_aire_pm10 = resp_aq.json().get("current", {}).get("pm10")
                except Exception:
                    pass

                altura_ola = None
                # Solo consultar marina si está cerca a la costa (ej. Paracas lon < -76.0)
                if longitud < -76.0:
                    try:
                        resp_marine = await cliente.get(
                            self.url_marina,
                            params={"latitude": latitud, "longitude": longitud, "current": "wave_height"},
                        )
                        if resp_marine.status_code == 200:
                            altura_ola = resp_marine.json().get("current", {}).get("wave_height")
                    except Exception:
                        pass

                # Calcular ventana de pico UV a partir del pronóstico horario de hoy
                ventana_pico = "11:00 - 14:30"
                uv_horas = horario.get("uv_index", [])
                tiempos = horario.get("time", [])
                picos = [
                    tiempos[i].split("T")[1][:5]
                    for i, uv in enumerate(uv_horas[:24])
                    if uv and uv >= 8.0
                ]
                if picos:
                    ventana_pico = f"{picos[0]} - {picos[-1]}"

                # Horas de sol
                duracion_seg = diario.get("sunshine_duration", [0])[0]
                horas_sol = round(duracion_seg / 3600.0, 1) if duracion_seg else None

                return ClimaActual(
                    temperatura_actual=actual.get("temperature_2m", 0.0),
                    sensacion_termica=actual.get("apparent_temperature", 0.0),
                    probabilidad_precipitacion=actual.get("precipitation_probability", 0),
                    humedad=actual.get("relative_humidity_2m", 0),
                    velocidad_viento=actual.get("wind_speed_10m", 0.0),
                    rafagas_viento=actual.get("wind_gusts_10m") or None,
                    indice_uv=actual.get("uv_index", 0.0),
                    descripcion_clima=self._traducir_codigo(actual.get("weather_code", 0)),
                    visibilidad=actual.get("visibility", 10000) / 1000,  # m -> km
                    hora_amanecer=datetime.fromisoformat(diario.get("sunrise", [[""]])[0]),
                    hora_atardecer=datetime.fromisoformat(diario.get("sunset", [[""]])[0]),
                    fecha_hora_pronostico=datetime.now(tz=timezone.utc),
                    origen_api=self.nombre_proveedor,
                    # Variables ampliadas de Ica
                    presion_atmosferica=actual.get("surface_pressure"),
                    precipitacion_mm=actual.get("precipitation"),
                    temperatura_suelo_arena=actual.get("soil_temperature_0cm"),
                    calidad_aire_pm10=calidad_aire_pm10,
                    ventana_pico_uv=ventana_pico,
                    horas_sol_directo=horas_sol,
                    altura_ola_metros=altura_ola,
                )
        except httpx.HTTPError as error:
            raise ProveedorClimaNoDisponibleException(self.nombre_proveedor, str(error)) from error
        except (KeyError, TypeError, ValueError, IndexError) as error:
            raise ErrorMapeoClimaException(self.nombre_proveedor, str(error)) from error

    def _traducir_codigo(self, codigo: int) -> str:
        """Traduce el código WMO a una descripción legible en español."""
        if codigo == 0:
            return "Despejado"
        if codigo in [1, 2, 3]:
            return "Parcialmente nublado"
        if codigo in [45, 48]:
            return "Niebla"
        if codigo in [51, 53, 55]:
            return "Llovizna"
        if codigo in [61, 63, 65]:
            return "Lluvia"
        if codigo in [80, 81, 82]:
            return "Chubascos"
        if codigo >= 95:
            return "Tormenta"
        return "Desconocido"
