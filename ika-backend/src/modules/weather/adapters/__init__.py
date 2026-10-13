from src.modules.weather.adapters.base import AdaptadorClimaBase
from src.modules.weather.adapters.openweathermap import AdaptadorOpenWeatherMap
from src.modules.weather.adapters.openmeteo import AdaptadorOpenMeteo
from src.modules.weather.adapters.weatherapi import AdaptadorWeatherAPI

__all__ = [
    "AdaptadorClimaBase",
    "AdaptadorOpenWeatherMap",
    "AdaptadorWeatherAPI",
    "AdaptadorOpenMeteo",
]
