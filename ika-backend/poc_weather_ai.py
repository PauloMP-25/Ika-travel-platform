from __future__ import annotations

import os
import statistics
from dataclasses import dataclass, field
from typing import Optional

import requests

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------

HUACACHINA_LAT = -14.0875
HUACACHINA_LON = -75.7626

OPENWEATHERMAP_API_KEY = os.getenv("OPENWEATHERMAP_API_KEY", "")
WEATHERAPI_API_KEY = os.getenv("WEATHERAPI_API_KEY", "")

REQUEST_TIMEOUT_SECONDS = 8


# ---------------------------------------------------------------------------
# Modelo de datos normalizado
# ---------------------------------------------------------------------------

@dataclass
class WeatherReading:
    """Representa una lectura climática ya normalizada a unidades estándar."""
    source: str
    temperature_c: Optional[float] = None
    humidity_pct: Optional[float] = None
    wind_speed_kmh: Optional[float] = None
    uv_index: Optional[float] = None
    raw_error: Optional[str] = None

    @property
    def is_valid(self) -> bool:
        """Una lectura es útil si al menos trajo temperatura o viento."""
        return self.raw_error is None and (
            self.temperature_c is not None or self.wind_speed_kmh is not None
        )


@dataclass
class AggregatedWeather:
    """Resultado final tras combinar las 3 fuentes."""
    temperature_c: Optional[float]
    humidity_pct: Optional[float]
    wind_speed_kmh: Optional[float]
    uv_index: Optional[float]
    sources_used: list[str] = field(default_factory=list)
    sources_failed: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Clientes de APIs meteorológicas (uno por proveedor, interfaz uniforme)
# ---------------------------------------------------------------------------

class WeatherProviderClient:
    """Clase base: cada proveedor implementa fetch() y retorna un WeatherReading."""

    name = "base"

    def fetch(self, lat: float, lon: float) -> WeatherReading:
        raise NotImplementedError


class OpenMeteoClient(WeatherProviderClient):
    """Open-Meteo: gratuito, sin API key."""

    name = "open-meteo"
    BASE_URL = "https://api.open-meteo.com/v1/forecast"

    def fetch(self, lat: float, lon: float) -> WeatherReading:
        params = {
            "latitude": lat,
            "longitude": lon,
            "current": "temperature_2m,relative_humidity_2m,wind_speed_10m,uv_index",
            "timezone": "America/Lima",
        }
        try:
            resp = requests.get(self.BASE_URL, params=params, timeout=REQUEST_TIMEOUT_SECONDS)
            resp.raise_for_status()
            current = resp.json()["current"]
            return WeatherReading(
                source=self.name,
                temperature_c=current.get("temperature_2m"),
                humidity_pct=current.get("relative_humidity_2m"),
                wind_speed_kmh=current.get("wind_speed_10m"),
                uv_index=current.get("uv_index"),
            )
        except (requests.RequestException, KeyError, ValueError) as exc:
            return WeatherReading(source=self.name, raw_error=str(exc))


class OpenWeatherMapClient(WeatherProviderClient):
    """OpenWeatherMap: requiere API key. No trae UV en el endpoint /weather gratuito,
    así que ese campo queda en None desde esta fuente (se cubre con otra)."""

    name = "openweathermap"
    BASE_URL = "https://api.openweathermap.org/data/2.5/weather"

    def __init__(self, api_key: str):
        self.api_key = api_key

    def fetch(self, lat: float, lon: float) -> WeatherReading:
        if not self.api_key:
            return WeatherReading(source=self.name, raw_error="API key no configurada")
        params = {
            "lat": lat,
            "lon": lon,
            "appid": self.api_key,
            "units": "metric",
        }
        try:
            resp = requests.get(self.BASE_URL, params=params, timeout=REQUEST_TIMEOUT_SECONDS)
            resp.raise_for_status()
            data = resp.json()
            return WeatherReading(
                source=self.name,
                temperature_c=data.get("main", {}).get("temp"),
                humidity_pct=data.get("main", {}).get("humidity"),
                wind_speed_kmh=(data.get("wind", {}).get("speed") or 0) * 3.6,  # m/s -> km/h
                uv_index=None,
            )
        except (requests.RequestException, KeyError, ValueError) as exc:
            return WeatherReading(source=self.name, raw_error=str(exc))


class WeatherAPIClient(WeatherProviderClient):
    """WeatherAPI.com: requiere API key. Trae UV directamente."""

    name = "weatherapi"
    BASE_URL = "https://api.weatherapi.com/v1/current.json"

    def __init__(self, api_key: str):
        self.api_key = api_key

    def fetch(self, lat: float, lon: float) -> WeatherReading:
        if not self.api_key:
            return WeatherReading(source=self.name, raw_error="API key no configurada")
        params = {
            "key": self.api_key,
            "q": f"{lat},{lon}",
            "aqi": "no",
        }
        try:
            resp = requests.get(self.BASE_URL, params=params, timeout=REQUEST_TIMEOUT_SECONDS)
            resp.raise_for_status()
            current = resp.json()["current"]
            return WeatherReading(
                source=self.name,
                temperature_c=current.get("temp_c"),
                humidity_pct=current.get("humidity"),
                wind_speed_kmh=current.get("wind_kph"),
                uv_index=current.get("uv"),
            )
        except (requests.RequestException, KeyError, ValueError) as exc:
            return WeatherReading(source=self.name, raw_error=str(exc))


# ---------------------------------------------------------------------------
# Normalización / agregación
# ---------------------------------------------------------------------------

class WeatherAggregator:
    """Combina lecturas de varias fuentes en un solo dato confiable.

    Estrategia: promedio simple entre las fuentes válidas para cada variable.
    Si ninguna fuente trae un dato (ej. UV en OpenWeatherMap), se ignora esa
    fuente para esa variable específica en lugar de romper el cálculo.
    """

    @staticmethod
    def aggregate(readings: list[WeatherReading]) -> AggregatedWeather:
        valid_readings = [r for r in readings if r.is_valid]
        sources_used = [r.source for r in valid_readings]
        sources_failed = [r.source for r in readings if not r.is_valid]

        def avg(values: list[Optional[float]]) -> Optional[float]:
            clean = [v for v in values if v is not None]
            return round(statistics.mean(clean), 1) if clean else None

        return AggregatedWeather(
            temperature_c=avg([r.temperature_c for r in valid_readings]),
            humidity_pct=avg([r.humidity_pct for r in valid_readings]),
            wind_speed_kmh=avg([r.wind_speed_kmh for r in valid_readings]),
            uv_index=avg([r.uv_index for r in valid_readings]),
            sources_used=sources_used,
            sources_failed=sources_failed,
        )


# ---------------------------------------------------------------------------
# Capa de IA: construcción de prompt + llamada (mock en esta POC)
# ---------------------------------------------------------------------------

class WeatherPromptBuilder:
    """Construye el prompt dinámico que se enviará al modelo de IA."""

    @staticmethod
    def build(weather: AggregatedWeather, activity: str = "Sandboarding en Huacachina") -> str:
        return (
            "Eres un asistente de turismo experto en la región de Ica, Perú. "
            f"Un turista está evaluando si es buen momento para: {activity}.\n\n"
            "Datos climáticos actuales (promediados de múltiples fuentes):\n"
            f"- Temperatura: {weather.temperature_c} °C\n"
            f"- Humedad relativa: {weather.humidity_pct} %\n"
            f"- Velocidad del viento: {weather.wind_speed_kmh} km/h\n"
            f"- Índice UV: {weather.uv_index}\n\n"
            "Con base en estos datos, responde en máximo 3 frases cortas cubriendo:\n"
            "1. Qué tipo de ropa/equipo usar.\n"
            "2. Si es un buen momento para la actividad (sí/no y por qué).\n"
            "3. Una precaución concreta a tomar (ej. protector solar, hidratación, horario).\n"
            "Responde en español, tono cercano y directo, sin rodeos técnicos."
        )


class MockAIClient:
    """Simula una llamada a un modelo generativo (ej. google.generativeai / Gemini).

    En la integración real esto se reemplaza por algo como:

        import google.generativeai as genai
        genai.configure(api_key=GEMINI_API_KEY)
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(prompt)
        return response.text

    Aquí devolvemos una respuesta determinística basada en reglas simples,
    solo para poder probar el flujo completo sin gastar cuota de API.
    """

    def generate_content(self, prompt: str, weather: AggregatedWeather) -> str:
        temp = weather.temperature_c or 0
        uv = weather.uv_index or 0
        wind = weather.wind_speed_kmh or 0

        ropa = "ropa ligera y transpirable" if temp >= 24 else "una capa ligera para el viento del desierto"
        buen_momento = wind < 30 and uv < 9
        veredicto = "Sí, es un buen momento" if buen_momento else "Se recomienda esperar o ir con precaución"
        precaucion = "usa protector solar UV alto y mantente hidratado" if uv >= 6 else "lleva agua contigo por el calor seco"

        return (
            f"[MOCK-IA] Ropa recomendada: {ropa}. "
            f"{veredicto} para el sandboarding con temperatura de {temp}°C y viento de {wind} km/h. "
            f"Precaución: {precaucion}."
        )


# ---------------------------------------------------------------------------
# Orquestador principal
# ---------------------------------------------------------------------------

class WeatherRecommendationEngine:
    """Clase de alto nivel que junta todo el pipeline: fetch -> aggregate -> prompt -> IA.

    Esta es la clase que, en la versión oficial, se convertirá en
    src/modules/weather/ai_recommender.py::generate_ai_recommendation().
    """

    def __init__(self, providers: list[WeatherProviderClient], ai_client: MockAIClient):
        self.providers = providers
        self.ai_client = ai_client

    def run(self, lat: float, lon: float, activity: str) -> dict:
        readings = [provider.fetch(lat, lon) for provider in self.providers]
        aggregated = WeatherAggregator.aggregate(readings)
        prompt = WeatherPromptBuilder.build(aggregated, activity)
        recommendation_text = self.ai_client.generate_content(prompt, aggregated)

        return {
            "raw_readings": readings,
            "aggregated_weather": aggregated,
            "prompt_sent": prompt,
            "recommendation": recommendation_text,
        }


# ---------------------------------------------------------------------------
# Ejecución de la POC
# ---------------------------------------------------------------------------

def main() -> None:
    providers = [
        OpenMeteoClient(),
        OpenWeatherMapClient(api_key=OPENWEATHERMAP_API_KEY),
        WeatherAPIClient(api_key=WEATHERAPI_API_KEY),
    ]
    engine = WeatherRecommendationEngine(providers=providers, ai_client=MockAIClient())

    result = engine.run(
        lat=HUACACHINA_LAT,
        lon=HUACACHINA_LON,
        activity="Sandboarding en Huacachina",
    )

    print("=" * 60)
    print("LECTURAS POR FUENTE")
    print("=" * 60)
    for reading in result["raw_readings"]:
        if reading.raw_error:
            print(f"[{reading.source}] ERROR: {reading.raw_error}")
        else:
            print(
                f"[{reading.source}] temp={reading.temperature_c}°C  "
                f"humedad={reading.humidity_pct}%  viento={reading.wind_speed_kmh}km/h  "
                f"uv={reading.uv_index}"
            )

    agg = result["aggregated_weather"]
    print("\n" + "=" * 60)
    print("DATO AGREGADO (usado para el prompt)")
    print("=" * 60)
    print(f"Temperatura: {agg.temperature_c} °C")
    print(f"Humedad: {agg.humidity_pct} %")
    print(f"Viento: {agg.wind_speed_kmh} km/h")
    print(f"UV: {agg.uv_index}")
    print(f"Fuentes usadas: {agg.sources_used}")
    print(f"Fuentes fallidas: {agg.sources_failed}")

    print("\n" + "=" * 60)
    print("PROMPT ENVIADO A LA IA")
    print("=" * 60)
    print(result["prompt_sent"])

    print("\n" + "=" * 60)
    print("RECOMENDACIÓN GENERADA")
    print("=" * 60)
    print(result["recommendation"])


if __name__ == "__main__":
    main()
