from datetime import datetime
from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


# ----------------------------------------------------------------------
# Categorías
# ----------------------------------------------------------------------
class CategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    slug: str


class CategoryCreate(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    slug: str | None = Field(
        default=None,
        pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$",
        max_length=120,
        description="Si se omite se genera a partir del nombre.",
    )


# ----------------------------------------------------------------------
# Atractivos
# ----------------------------------------------------------------------
class AttractionListItem(BaseModel):
    id: UUID
    name: str
    district: str
    cover_image_url: str | None
    categories: list[str]


class PaginatedAttractionsResponse(BaseModel):
    items: list[AttractionListItem]
    total: int
    page: int
    page_size: int
    has_next: bool


class AttractionDetailResponse(BaseModel):
    id: UUID
    name: str
    description: str
    official_recommendation: str | None
    district: str
    latitude: float
    longitude: float
    images: list[str]
    categories: list[CategoryResponse]
    avg_rating: float | None


class AttractionCreate(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    description: str = Field(min_length=1)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    district: str = Field(min_length=2, max_length=100)
    official_recommendation: str | None = None
    category_slugs: list[str] = Field(default_factory=list)
    image_urls: list[str] = Field(default_factory=list, description="La primera es la portada.")
    is_active: bool = True


class AttractionUpdate(BaseModel):
    """Todos los campos son opcionales. Si se envían ``category_slugs`` o
    ``image_urls`` se reemplaza la lista completa."""

    name: str | None = Field(default=None, min_length=2, max_length=200)
    description: str | None = Field(default=None, min_length=1)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    district: str | None = Field(default=None, min_length=2, max_length=100)
    official_recommendation: str | None = None
    category_slugs: list[str] | None = None
    image_urls: list[str] | None = None
    is_active: bool | None = None


# ----------------------------------------------------------------------
# Tours y agencias
# ----------------------------------------------------------------------
class TourResponse(BaseModel):
    id: UUID
    name: str
    description: str
    price: Decimal
    duration_hours: int
    agency_id: UUID
    agency_name: str
    attraction_id: UUID | None
    attraction_name: str | None


class AgencyListItem(BaseModel):
    id: UUID
    name: str
    is_validated: bool
    tour_count: int


class AgencyDetailResponse(BaseModel):
    id: UUID
    name: str
    is_validated: bool
    contact_phone: str | None
    contact_email: str | None
    tours: list[TourResponse]


class AgencyCreate(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    ruc: str = Field(pattern=r"^\d{11}$", description="RUC peruano de 11 dígitos")
    contact_phone: str | None = Field(default=None, max_length=30)
    contact_email: EmailStr | None = None


class AgencyUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=200)
    contact_phone: str | None = Field(default=None, max_length=30)
    contact_email: EmailStr | None = None


class AgencyValidationRequest(BaseModel):
    dircetur_registry_number: str = Field(min_length=1, max_length=50)


class AgencyAdminResponse(BaseModel):
    """Vista administrativa (incluye RUC y estado de validación)."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    ruc: str
    dircetur_registry_number: str | None
    is_validated: bool
    validated_at: datetime | None
    contact_phone: str | None
    contact_email: str | None
    created_at: datetime


class TourCreate(BaseModel):
    agency_id: UUID
    attraction_id: UUID | None = None
    name: str = Field(min_length=2, max_length=200)
    description: str = Field(min_length=1)
    price: Decimal = Field(ge=0, max_digits=10, decimal_places=2)
    duration_hours: int = Field(gt=0, le=240)


class TourUpdate(BaseModel):
    attraction_id: UUID | None = None
    name: str | None = Field(default=None, min_length=2, max_length=200)
    description: str | None = Field(default=None, min_length=1)
    price: Decimal | None = Field(default=None, ge=0, max_digits=10, decimal_places=2)
    duration_hours: int | None = Field(default=None, gt=0, le=240)


class DircerturSyncSummary(BaseModel):
    total_en_padron: int
    validadas: int
    revocadas: int
    sin_cambios: int
