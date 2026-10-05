from fastapi import APIRouter, Query

from src.modules.weather import service
from src.modules.weather.schemas import ClimaActualResponse

router = APIRouter(prefix="/weather", tags=["weather"])


@router.get("/current", response_model=ClimaActualResponse)
async def obtener_clima_actual(
    destino: str = Query(..., description="Nombre del destino turístico, ej. 'Huacachina'"),
) -> ClimaActualResponse:
    """RF-06: retorna el clima actual normalizado (12 campos limpios + destino)
    para cualquier destino turístico de Ica.

    Consulta en paralelo hasta 3 proveedores (OpenWeatherMap, WeatherAPI,
    Open-Meteo) y devuelve el promedio consensuado. Si un proveedor falla,
    los demás compensan (resiliencia).

    Ejemplo Postman: GET /api/v1/weather/current?destino=Huacachina
    """
    return await service.obtener_clima_destino(destino)
