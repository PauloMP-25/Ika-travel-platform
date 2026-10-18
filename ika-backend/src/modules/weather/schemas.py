from datetime import datetime
from typing import Optional
from uuid import UUID

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
    rafagas_viento: Optional[float] = Field(None, description="km/h")
    indice_uv: float = Field(..., ge=0)
    descripcion_clima: str
    visibilidad: float = Field(..., ge=0, description="km")
    hora_amanecer: datetime
    hora_atardecer: datetime
    fecha_hora_pronostico: datetime = Field(..., description="Bloque de pronóstico (estrategia cada 3h)")
    origen_api: OrigenAPI
    # --- Variables ampliadas para Ica (Sprint 4) ---
    presion_atmosferica: Optional[float] = Field(None, description='hPa (presión a nivel de superficie)')
    precipitacion_mm: Optional[float] = Field(None, ge=0, description='mm acumulados de precipitación')
    temperatura_suelo_arena: Optional[float] = Field(None, description='°C de la arena o superficie')
    calidad_aire_pm10: Optional[float] = Field(None, ge=0, description='µg/m³ partículas PM10 en polvo/arena')
    ventana_pico_uv: Optional[str] = Field(None, description="Rango horario de máxima radiación, ej: '11:00 - 14:30'")
    horas_sol_directo: Optional[float] = Field(None, ge=0, description='Horas estimadas de sol directo')
    altura_ola_metros: Optional[float] = Field(None, ge=0, description='Altura de ola en costa (Paracas/marina)')


class ClimaActualResponse(ClimaActual):
    """DTO de salida del endpoint público. Separado de `ClimaActual` para
    poder agregar campos propios de la API (ej. `destino`) sin acoplar el
    contrato interno que usan los adaptadores."""

    destino: str
    atractivo_id: UUID | None = None
    # True si el dato salió de Redis o de un snapshot previo de BD (útil para depurar en Flutter).
    is_cached: bool = False


class ErrorClimaResponse(BaseModel):
    """Forma del cuerpo de error cuando todos los proveedores fallan."""

    detalle: str
    proveedores_intentados: list[str] = []


class PronosticoHoraResponse(BaseModel):
    time: datetime
    temperature: float
    uv_index: float
    wind_speed: float
    precipitation_probability: float
    condition: str


class PronosticoDiaResponse(BaseModel):
    date: str
    temp_min: float
    temp_max: float
    uv_index_max: float
    wind_speed_max: float
    precipitation_sum: float
    precipitation_probability_max: float
    condition: str


class PronosticoResponse(BaseModel):
    """Pronóstico por horas (24 h) y por días (hasta 7)."""

    destino: str
    atractivo_id: UUID | None = None
    horas: list[PronosticoHoraResponse]
    dias: list[PronosticoDiaResponse]


class AlertaClimaResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    zone: str
    code: str
    severity: str
    message: str
    starts_at: datetime
    ends_at: datetime


class RecomendacionResponse(BaseModel):
    atractivo_id: UUID
    atractivo_nombre: str
    score: float = Field(..., ge=0, le=1)
    nivel: str
    recommendation_text: str
    consejos: list[str] = []
    generated_at: datetime

