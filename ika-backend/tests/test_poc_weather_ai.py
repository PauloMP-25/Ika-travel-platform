import pytest
from unittest.mock import patch, MagicMock

# Importamos las clases del POC
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from poc_weather_ai import (
    OpenMeteoClient,
    OpenWeatherMapClient,
    WeatherAPIClient,
    WeatherAggregator,
    WeatherReading,
    WeatherRecommendationEngine,
    MockAIClient
)

@patch('requests.get')
def test_open_meteo_client_success(mock_get):
    # Configurar el mock
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "current": {
            "temperature_2m": 22.5,
            "relative_humidity_2m": 60,
            "wind_speed_10m": 15.0,
            "uv_index": 5.0
        }
    }
    mock_resp.raise_for_status.return_value = None
    mock_get.return_value = mock_resp

    client = OpenMeteoClient()
    reading = client.fetch(0.0, 0.0)

    assert reading.is_valid is True
    assert reading.source == "open-meteo"
    assert reading.temperature_c == 22.5
    assert reading.humidity_pct == 60
    assert reading.wind_speed_kmh == 15.0
    assert reading.uv_index == 5.0
    assert reading.raw_error is None

@patch('requests.get')
def test_openweathermap_client_success(mock_get):
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "main": {
            "temp": 23.0,
            "humidity": 55
        },
        "wind": {
            "speed": 5.0  # m/s -> 18.0 km/h
        }
    }
    mock_resp.raise_for_status.return_value = None
    mock_get.return_value = mock_resp

    client = OpenWeatherMapClient(api_key="fake_key")
    reading = client.fetch(0.0, 0.0)

    assert reading.is_valid is True
    assert reading.source == "openweathermap"
    assert reading.temperature_c == 23.0
    assert reading.humidity_pct == 55
    assert reading.wind_speed_kmh == 18.0
    assert reading.uv_index is None

@patch('requests.get')
def test_weatherapi_client_success(mock_get):
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "current": {
            "temp_c": 24.0,
            "humidity": 50,
            "wind_kph": 20.0,
            "uv": 6.0
        }
    }
    mock_resp.raise_for_status.return_value = None
    mock_get.return_value = mock_resp

    client = WeatherAPIClient(api_key="fake_key")
    reading = client.fetch(0.0, 0.0)

    assert reading.is_valid is True
    assert reading.source == "weatherapi"
    assert reading.temperature_c == 24.0
    assert reading.humidity_pct == 50
    assert reading.wind_speed_kmh == 20.0
    assert reading.uv_index == 6.0

def test_weather_aggregator():
    readings = [
        WeatherReading("open-meteo", 20.0, 50, 10.0, 5.0),
        WeatherReading("openweathermap", 22.0, 60, 15.0, None),  # Sin UV
        WeatherReading("weatherapi", 24.0, 70, 20.0, 7.0),
        WeatherReading("failed-source", None, None, None, None, "Error") # Invalido
    ]

    aggregated = WeatherAggregator.aggregate(readings)

    # Promedio de temp: (20 + 22 + 24) / 3 = 22.0
    assert aggregated.temperature_c == 22.0
    # Promedio de hum: (50 + 60 + 70) / 3 = 60.0
    assert aggregated.humidity_pct == 60.0
    # Promedio de viento: (10 + 15 + 20) / 3 = 15.0
    assert aggregated.wind_speed_kmh == 15.0
    # Promedio de uv: (5 + 7) / 2 = 6.0
    assert aggregated.uv_index == 6.0
    
    assert "failed-source" in aggregated.sources_failed
    assert "open-meteo" in aggregated.sources_used

def test_engine_run(monkeypatch):
    # Mockear las lecturas para evitar llamadas reales
    class MockProvider:
        def __init__(self, name):
            self.name = name
        def fetch(self, lat, lon):
            return WeatherReading(self.name, 25.0, 60, 15.0, 8.0)

    providers = [MockProvider("mock_prov")]
    engine = WeatherRecommendationEngine(providers, MockAIClient())

    result = engine.run(0.0, 0.0, "Prueba")

    assert "raw_readings" in result
    assert "aggregated_weather" in result
    assert "prompt_sent" in result
    assert "recommendation" in result
    assert result["aggregated_weather"].temperature_c == 25.0
