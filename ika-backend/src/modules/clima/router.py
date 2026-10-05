from fastapi import APIRouter, Query

from src.modules.clima import service
from src.modules.clima.schemas import ClimaActualResponse

router = APIRouter(prefix="/clima", tags=["clima"])


@router.get("/actual", response_model=ClimaActualResponse)
async def obtener_clima_actual(
    destino: str = Query(..., description="Nombre del destino turístico, ej. 'Huacachina'"),
) -> ClimaActualResponse:
    """PoC (RF-06): retorna el clima actual normalizado (12 campos limpios)
    para un destino de Ica.

    Internamente consulta en cascada OpenWeatherMap -> WeatherAPI ->
    Tomorrow.io hasta obtener una respuesta válida. Las excepciones de
    negocio (destino no encontrado, todos los proveedores caídos) las
    traduce a HTTP el manejador global registrado en `core/exceptions.py`.

    Ejemplo Postman: GET /api/v1/clima/actual?destino=Huacachina
    """
    return await service.obtener_clima_destino(destino)
