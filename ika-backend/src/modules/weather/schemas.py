from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from src.modules.weather.models import AlertSeverity


class WeatherCurrentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    attraction_id: UUID | None
    location: str | None = None
    temperature: float = Field(description="°C")
    uv_index: float
    wind_speed: float = Field(description="km/h")
    humidity: float = Field(description="%")
    precipitation: float = Field(description="mm")
    condition: str
    fetched_at: datetime
    source: str


class ForecastHour(BaseModel):
    time: datetime
    temperature: float
    uv_index: float
    wind_speed: float
    precipitation_probability: float
    condition: str


class ForecastDay(BaseModel):
    date: str
    temp_min: float
    temp_max: float
    uv_index_max: float
    wind_speed_max: float
    precipitation_sum: float
    precipitation_probability_max: float
    condition: str


class WeatherForecastResponse(BaseModel):
    attraction_id: UUID | None
    location: str
    generated_at: datetime
    hourly: list[ForecastHour]
    daily: list[ForecastDay]


class WeatherAlertResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    zone: str
    severity: AlertSeverity
    message: str
    starts_at: datetime
    ends_at: datetime


class WeatherAlertCreate(BaseModel):
    zone: str = Field(min_length=2, max_length=100)
    severity: AlertSeverity
    message: str = Field(min_length=3, max_length=1000)
    duration_hours: int = Field(default=6, ge=1, le=72)


class WeatherSummary(BaseModel):
    temperature: float
    uv_index: float
    wind_speed: float
    condition: str
    fetched_at: datetime


class AIRecommendationResponse(BaseModel):
    attraction_id: UUID
    attraction_name: str
    recommendation_text: str
    score: float = Field(ge=0, le=1)
    level: str = Field(description="excelente | bueno | regular | no_recomendado")
    text_source: str = Field(description="reglas | gemini")
    generated_at: datetime
    weather: WeatherSummary


class RefreshSummary(BaseModel):
    snapshots_creados: int
    zonas_fallidas: int
    recomendaciones_generadas: int
    texto_con_gemini: int
