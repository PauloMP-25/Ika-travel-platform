from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

OrigenAPI = str


class ClimaActual(BaseModel):
    """Entidad estándar y 'limpia' de clima, independiente del proveedor de origen.

    Todos los adaptadores DEBEN devolver instancias de este esquema — es el
    único contrato que conoce el resto del sistema (servicio, router, IA de
    recomendaciones). Contiene los 12 campos obligatorios + `origen_api`.
    """

    model_config = ConfigDict(from_attributes=True)

    temperatura_actual: float = Field(..., description="°C")
    sensacion_termica: float = Field(..., description="°C")
    probabilidad_precipitacion: float = Field(..., ge=0, le=100, description="% (0-100)")
    humedad: float = Field(..., ge=0, le=100, description="% (0-100)")
    velocidad_viento: float = Field(..., ge=0, description="km/h")
    rafagas_viento: float | None = Field(None, description="km/h")
    indice_uv: float = Field(..., ge=0)
    descripcion_clima: str
    visibilidad: float = Field(..., ge=0, description="km")
    hora_amanecer: datetime
    hora_atardecer: datetime
    fecha_hora_pronostico: datetime = Field(..., description="Bloque de pronóstico (estrategia cada 3h)")
    origen_api: OrigenAPI


class ClimaActualResponse(ClimaActual):
    """DTO de salida del endpoint público. Separado de `ClimaActual` para
    poder agregar campos propios de la API (ej. `destino`) sin acoplar el
    contrato interno que usan los adaptadores."""

    destino: str


class ErrorClimaResponse(BaseModel):
    """Forma del cuerpo de error cuando todos los proveedores fallan."""

    detalle: str
    proveedores_intentados: list[str] = []
