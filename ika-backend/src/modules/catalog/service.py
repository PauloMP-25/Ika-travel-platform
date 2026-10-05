"""Lógica de negocio del catálogo: atractivos, categorías, agencias y tours."""
import logging
import re
import unicodedata
from uuid import UUID

import httpx
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.config import configuracion
from src.modules.catalog import repository
from src.modules.catalog.exceptions import (
    AgencyNotFoundException,
    AgencyNotValidatedException,
    AttractionNotFoundException,
    DircerturSyncFailedException,
    DuplicateResourceException,
    InvalidCategoryFilterException,
    TourNotFoundException,
)
from src.modules.catalog.models import Agency, Attraction, AttractionImage, Category, Tour
from src.modules.catalog.schemas import (
    AgencyCreate,
    AgencyDetailResponse,
    AgencyListItem,
    AgencyUpdate,
    AttractionCreate,
    AttractionDetailResponse,
    AttractionListItem,
    AttractionUpdate,
    CategoryCreate,
    CategoryResponse,
    DircerturSyncSummary,
    PaginatedAttractionsResponse,
    TourCreate,
    TourResponse,
    TourUpdate,
)
from src.shared.pagination import hay_siguiente_pagina
from src.shared.utils import utc_ahora

logger = logging.getLogger(__name__)


# ======================================================================
# Mapeos a DTO
# ======================================================================
def _a_list_item(atractivo: Attraction) -> AttractionListItem:
    return AttractionListItem(
        id=atractivo.id,
        name=atractivo.name,
        district=atractivo.district,
        cover_image_url=atractivo.images[0].url if atractivo.images else None,
        categories=[c.name for c in atractivo.categories],
    )


def _a_tour_response(tour: Tour, agency: Agency, attraction: Attraction | None) -> TourResponse:
    return TourResponse(
        id=tour.id,
        name=tour.name,
        description=tour.description,
        price=tour.price,
        duration_hours=tour.duration_hours,
        agency_id=agency.id,
        agency_name=agency.name,
        attraction_id=attraction.id if attraction else None,
        attraction_name=attraction.name if attraction else None,
    )


def _generar_slug(nombre: str) -> str:
    sin_tildes = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", sin_tildes.lower()).strip("-")


async def _confirmar(db: AsyncSession, mensaje_duplicado: str) -> None:
    """Commit con traducción de violaciones de unicidad a excepción de negocio."""
    try:
        await db.commit()
    except IntegrityError as exc:
        await db.rollback()
        raise DuplicateResourceException(mensaje_duplicado) from exc


# ======================================================================
# Consultas públicas: categorías y atractivos
# ======================================================================
async def list_categories(db: AsyncSession) -> list[CategoryResponse]:
    categorias = await repository.listar_categorias(db)
    return [CategoryResponse.model_validate(c) for c in categorias]


async def get_paginated_attractions(
    db: AsyncSession,
    *,
    category_slug: str | None,
    district: str | None,
    search: str | None,
    page: int,
    page_size: int,
) -> PaginatedAttractionsResponse:
    if category_slug and await repository.obtener_categoria_por_slug(db, category_slug) is None:
        raise InvalidCategoryFilterException(
            f"La categoría '{category_slug}' no existe. Consulta GET /catalog/categories."
        )
    atractivos, total = await repository.listar_atractivos_paginados(
        db,
        category_slug=category_slug,
        district=district,
        search=search,
        page=page,
        page_size=page_size,
    )
    return PaginatedAttractionsResponse(
        items=[_a_list_item(a) for a in atractivos],
        total=total,
        page=page,
        page_size=page_size,
        has_next=hay_siguiente_pagina(total, page, page_size),
    )


async def _construir_detalle(db: AsyncSession, atractivo: Attraction) -> AttractionDetailResponse:
    promedio = await repository.obtener_promedio_calificacion(db, atractivo.id)
    return AttractionDetailResponse(
        id=atractivo.id,
        name=atractivo.name,
        description=atractivo.description,
        official_recommendation=atractivo.official_recommendation,
        district=atractivo.district,
        latitude=atractivo.latitude,
        longitude=atractivo.longitude,
        images=[i.url for i in atractivo.images],
        categories=[CategoryResponse.model_validate(c) for c in atractivo.categories],
        avg_rating=round(promedio, 1) if promedio is not None else None,
    )


async def get_attraction_detail(db: AsyncSession, attraction_id: UUID) -> AttractionDetailResponse:
    atractivo = await repository.obtener_atractivo_por_id(db, attraction_id)
    if atractivo is None:
        raise AttractionNotFoundException()
    return await _construir_detalle(db, atractivo)


async def list_tours_by_attraction(db: AsyncSession, attraction_id: UUID) -> list[TourResponse]:
    if await repository.obtener_atractivo_por_id(db, attraction_id) is None:
        raise AttractionNotFoundException()
    tours = await repository.listar_tours_por_atractivo(db, attraction_id)
    return [_a_tour_response(t, t.agency, t.attraction) for t in tours]


# ======================================================================
# Consultas públicas: agencias
# ======================================================================
async def search_agencies(
    db: AsyncSession, *, query: str | None, limit: int, offset: int
) -> list[AgencyListItem]:
    # RN-01 ya viene aplicada en el repositorio; aquí solo se mapea el DTO.
    filas = await repository.listar_agencias_validadas(
        db, search_term=query, limit=limit, offset=offset
    )
    return [
        AgencyListItem(id=a.id, name=a.name, is_validated=a.is_validated, tour_count=total)
        for a, total in filas
    ]


async def get_agency_detail(db: AsyncSession, agency_id: UUID) -> AgencyDetailResponse:
    agencia = await repository.obtener_agencia_con_tours(db, agency_id)
    if agencia is None:
        raise AgencyNotFoundException()
    if not agencia.is_validated:  # defensa en profundidad (RN-01)
        raise AgencyNotValidatedException()
    tours = sorted(agencia.tours, key=lambda t: (t.price, t.name))
    return AgencyDetailResponse(
        id=agencia.id,
        name=agencia.name,
        is_validated=agencia.is_validated,
        contact_phone=agencia.contact_phone,
        contact_email=agencia.contact_email,
        tours=[_a_tour_response(t, agencia, t.attraction) for t in tours],
    )


# ======================================================================
# Administración: categorías y atractivos
# ======================================================================
async def create_category(db: AsyncSession, data: CategoryCreate) -> CategoryResponse:
    slug = data.slug or _generar_slug(data.name)
    if not slug:
        raise InvalidCategoryFilterException("No se pudo generar un slug válido para la categoría.")
    categoria = Category(name=data.name.strip(), slug=slug)
    db.add(categoria)
    await _confirmar(db, "Ya existe una categoría con ese nombre o slug.")
    return CategoryResponse.model_validate(categoria)


async def _resolver_categorias(db: AsyncSession, slugs: list[str]) -> list[Category]:
    unicos = list(dict.fromkeys(slugs))
    categorias = await repository.obtener_categorias_por_slugs(db, unicos)
    faltantes = set(unicos) - {c.slug for c in categorias}
    if faltantes:
        raise InvalidCategoryFilterException(
            f"Categorías inexistentes: {', '.join(sorted(faltantes))}."
        )
    return categorias


def _crear_imagenes(urls: list[str]) -> list[AttractionImage]:
    return [AttractionImage(url=url, display_order=i) for i, url in enumerate(urls)]


async def create_attraction(db: AsyncSession, data: AttractionCreate) -> AttractionDetailResponse:
    categorias = await _resolver_categorias(db, data.category_slugs)
    atractivo = Attraction(
        name=data.name.strip(),
        description=data.description,
        latitude=data.latitude,
        longitude=data.longitude,
        district=data.district.strip(),
        official_recommendation=data.official_recommendation,
        is_active=data.is_active,
        categories=categorias,
        images=_crear_imagenes(data.image_urls),
    )
    db.add(atractivo)
    await _confirmar(db, "No se pudo crear el atractivo por un conflicto de datos.")
    recargado = await repository.obtener_atractivo_por_id(db, atractivo.id, solo_activos=False)
    assert recargado is not None
    return await _construir_detalle(db, recargado)


async def update_attraction(
    db: AsyncSession, attraction_id: UUID, data: AttractionUpdate
) -> AttractionDetailResponse:
    atractivo = await repository.obtener_atractivo_por_id(db, attraction_id, solo_activos=False)
    if atractivo is None:
        raise AttractionNotFoundException()

    campos = data.model_dump(exclude_unset=True)
    slugs = campos.pop("category_slugs", None)
    urls = campos.pop("image_urls", None)

    for campo, valor in campos.items():
        if valor is None and campo != "official_recommendation":
            continue  # campos obligatorios: un null explícito se ignora
        setattr(atractivo, campo, valor)
    if slugs is not None:
        atractivo.categories = await _resolver_categorias(db, slugs)
    if urls is not None:
        atractivo.images = _crear_imagenes(urls)  # delete-orphan elimina las anteriores
    atractivo.updated_at = utc_ahora()

    await _confirmar(db, "No se pudo actualizar el atractivo por un conflicto de datos.")
    recargado = await repository.obtener_atractivo_por_id(db, attraction_id, solo_activos=False)
    assert recargado is not None
    return await _construir_detalle(db, recargado)


async def delete_attraction(db: AsyncSession, attraction_id: UUID) -> None:
    atractivo = await repository.obtener_atractivo_por_id(db, attraction_id, solo_activos=False)
    if atractivo is None:
        raise AttractionNotFoundException()
    await db.delete(atractivo)
    await db.commit()


# ======================================================================
# Administración: agencias y tours
# ======================================================================
async def create_agency(db: AsyncSession, data: AgencyCreate) -> Agency:
    if await repository.obtener_agencia_por_ruc(db, data.ruc):
        raise DuplicateResourceException(f"Ya existe una agencia con RUC {data.ruc}.")
    # Toda agencia nace sin validar: solo DIRCETUR (o el admin) la habilita (RN-01).
    agencia = Agency(
        name=data.name.strip(),
        ruc=data.ruc,
        contact_phone=data.contact_phone,
        contact_email=str(data.contact_email) if data.contact_email else None,
        is_validated=False,
    )
    db.add(agencia)
    await _confirmar(db, f"Ya existe una agencia con RUC {data.ruc}.")
    await db.refresh(agencia)
    return agencia


async def update_agency(db: AsyncSession, agency_id: UUID, data: AgencyUpdate) -> Agency:
    agencia = await repository.obtener_agencia_con_tours(db, agency_id)
    if agencia is None:
        raise AgencyNotFoundException()
    for campo, valor in data.model_dump(exclude_unset=True).items():
        if valor is None and campo == "name":
            continue
        setattr(agencia, campo, str(valor) if campo == "contact_email" and valor else valor)
    await db.commit()
    await db.refresh(agencia)
    return agencia


async def set_agency_validation(
    db: AsyncSession, agency_id: UUID, *, validated: bool, registry_number: str | None = None
) -> Agency:
    agencia = await repository.obtener_agencia_con_tours(db, agency_id)
    if agencia is None:
        raise AgencyNotFoundException()
    agencia.is_validated = validated
    agencia.dircetur_registry_number = registry_number if validated else None
    agencia.validated_at = utc_ahora() if validated else None
    await db.commit()
    await db.refresh(agencia)
    return agencia


async def create_tour(db: AsyncSession, data: TourCreate) -> TourResponse:
    agencia = await repository.obtener_agencia_con_tours(db, data.agency_id)
    if agencia is None:
        raise AgencyNotFoundException()
    if data.attraction_id and not await repository.obtener_atractivo_por_id(
        db, data.attraction_id, solo_activos=False
    ):
        raise AttractionNotFoundException()
    tour = Tour(
        agency_id=data.agency_id,
        attraction_id=data.attraction_id,
        name=data.name.strip(),
        description=data.description,
        price=data.price,
        duration_hours=data.duration_hours,
    )
    db.add(tour)
    await _confirmar(db, "No se pudo crear el tour por un conflicto de datos.")
    recargado = await repository.obtener_tour_por_id(db, tour.id)
    assert recargado is not None
    return _a_tour_response(recargado, recargado.agency, recargado.attraction)


async def update_tour(db: AsyncSession, tour_id: UUID, data: TourUpdate) -> TourResponse:
    tour = await repository.obtener_tour_por_id(db, tour_id)
    if tour is None:
        raise TourNotFoundException()
    campos = data.model_dump(exclude_unset=True)
    if campos.get("attraction_id") and not await repository.obtener_atractivo_por_id(
        db, campos["attraction_id"], solo_activos=False
    ):
        raise AttractionNotFoundException()
    for campo, valor in campos.items():
        if valor is None and campo != "attraction_id":
            continue
        setattr(tour, campo, valor)
    await _confirmar(db, "No se pudo actualizar el tour por un conflicto de datos.")
    recargado = await repository.obtener_tour_por_id(db, tour_id)
    assert recargado is not None
    return _a_tour_response(recargado, recargado.agency, recargado.attraction)


async def delete_tour(db: AsyncSession, tour_id: UUID) -> None:
    tour = await repository.obtener_tour_por_id(db, tour_id)
    if tour is None:
        raise TourNotFoundException()
    await db.delete(tour)
    await db.commit()


# ======================================================================
# Sincronización con el padrón DIRCETUR (invocada por la tarea Celery)
# ======================================================================
async def _descargar_padron() -> dict[str, str]:
    url = configuracion.DIRCETUR_URL_PADRON
    if not url:
        raise DircerturSyncFailedException(
            "DIRCETUR_URL_PADRON no está configurada; la sincronización automática está deshabilitada."
        )
    try:
        async with httpx.AsyncClient(timeout=30.0) as cliente:
            respuesta = await cliente.get(url)
            respuesta.raise_for_status()
            datos = respuesta.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise DircerturSyncFailedException(f"No se pudo leer el padrón: {exc}") from exc

    if not isinstance(datos, list):
        raise DircerturSyncFailedException("Formato inesperado: se esperaba una lista JSON.")
    padron: dict[str, str] = {}
    for fila in datos:
        if not isinstance(fila, dict) or not fila.get("ruc"):
            continue
        padron[str(fila["ruc"]).strip()] = str(fila.get("numero_registro") or "").strip()
    if not padron:
        # Evita revocar a TODAS las agencias por un padrón vacío o mal formado.
        raise DircerturSyncFailedException("El padrón descargado no contiene registros válidos.")
    return padron


async def sync_dircetur_registry(db: AsyncSession) -> DircerturSyncSummary:
    padron = await _descargar_padron()
    validadas = revocadas = sin_cambios = 0
    for agencia in await repository.listar_todas_las_agencias(db):
        if agencia.ruc in padron:
            numero = padron[agencia.ruc] or agencia.dircetur_registry_number
            if agencia.is_validated and agencia.dircetur_registry_number == numero:
                sin_cambios += 1
                continue
            agencia.is_validated = True
            agencia.dircetur_registry_number = numero
            agencia.validated_at = agencia.validated_at or utc_ahora()
            validadas += 1
        elif agencia.is_validated:
            agencia.is_validated = False
            agencia.dircetur_registry_number = None
            agencia.validated_at = None
            revocadas += 1
        else:
            sin_cambios += 1
    await db.commit()
    logger.info("Sincronización DIRCETUR: +%s validadas, -%s revocadas", validadas, revocadas)
    return DircerturSyncSummary(
        total_en_padron=len(padron),
        validadas=validadas,
        revocadas=revocadas,
        sin_cambios=sin_cambios,
    )
