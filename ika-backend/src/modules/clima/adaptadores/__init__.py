from src.modules.clima.adaptadores.base import AdaptadorClimaBase
from src.modules.clima.adaptadores.openweathermap import AdaptadorOpenWeatherMap
from src.modules.clima.adaptadores.openmeteo import AdaptadorOpenMeteo
from src.modules.clima.adaptadores.weatherapi import AdaptadorWeatherAPI

__all__ = [
    "AdaptadorClimaBase",
    "AdaptadorOpenWeatherMap",
    "AdaptadorWeatherAPI",
    "AdaptadorOpenMeteo",
]
