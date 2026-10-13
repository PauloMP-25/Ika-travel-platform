import enum
from uuid import UUID

from pydantic import BaseModel, Field


class ModoTransporte(str, enum.Enum):
    driving = "driving"
    walking = "walking"
    cycling = "cycling"


class Coordenada(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)


class AttractionNearbyItem(BaseModel):
    id: UUID
    name: str
    district: str
    latitude: float
    longitude: float
    distance_m: float
    cover_image_url: str | None
    categories: list[str]


class NearbyResponse(BaseModel):
    origin: Coordenada
    radius_m: int
    in_coverage: bool
    items: list[AttractionNearbyItem]


class ProximityResponse(BaseModel):
    attraction_id: UUID
    attraction_name: str
    distance_m: float
    max_distance_m: int
    is_nearby: bool


class NearestAttraction(BaseModel):
    id: UUID
    name: str
    distance_m: float


class LocationValidationResponse(BaseModel):
    in_coverage: bool = Field(description="¿La coordenada está dentro de la zona de cobertura (Ica)?")
    nearest_attraction: NearestAttraction | None


class RouteRequest(BaseModel):
    waypoints: list[Coordenada] = Field(min_length=2, max_length=10, description="Origen, paradas y destino")
    mode: ModoTransporte = ModoTransporte.driving
    include_steps: bool = True


class RouteStep(BaseModel):
    instruction: str
    distance_m: float
    duration_s: float
    location: Coordenada | None = None


class GeoJSONLineString(BaseModel):
    type: str = "LineString"
    coordinates: list[list[float]] = Field(description="Pares [longitud, latitud]")


class RouteResponse(BaseModel):
    mode: ModoTransporte
    distance_m: float
    duration_s: float
    geometry: GeoJSONLineString
    steps: list[RouteStep]
    source: str = Field(description="osrm | estimacion_lineal")
    is_approximate: bool
    notice: str | None = None
