from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.database import obtener_bd
from src.modules.catalog import service
from src.modules.catalog.schemas import (
    AgencyAdminResponse,
    AgencyCreate,
    AgencyDetailResponse,
    AgencyListItem,
    AgencyUpdate,
    AgencyValidationRequest,
    AttractionCreate,
    AttractionDetailResponse,
    AttractionUpdate,
    CategoryCreate,
    CategoryResponse,
    DircerturSyncSummary,
    PaginatedAttractionsResponse,
    TourCreate,
    TourResponse,
    TourUpdate,
)
from src.shared.admin import requerir_admin
from src.shared.pagination import ParametrosPaginacion

router = APIRouter(prefix="/catalog")

# ======================================================================
# Endpoints públicos (RN-02: no requieren autenticación)
# ======================================================================


@router.get("/attractions", response_model=PaginatedAttractionsResponse, tags=["catalog"])
async def listar_atractivos(
    category: str | None = Query(None, description="Slug de categoría, ej. sandboarding"),
    district: str | None = Query(None, description="Distrito, ej. Ica"),
    search: str | None = Query(None, min_length=2, max_length=100, description="Texto en el nombre"),
    paginacion: ParametrosPaginacion = Depends(),
    db: AsyncSession = Depends(obtener_bd),
):
    return await service.get_paginated_attractions(
        db,
        category_slug=category,
        district=district,
        search=search,
        page=paginacion.page,
        page_size=paginacion.page_size,
    )


@router.get("/categories", response_model=list[CategoryResponse], tags=["catalog"])
async def listar_categorias(db: AsyncSession = Depends(obtener_bd)):
    return await service.list_categories(db)


@router.get(
    "/attractions/{attraction_id}", response_model=AttractionDetailResponse, tags=["catalog"]
)
async def detalle_atractivo(attraction_id: UUID, db: AsyncSession = Depends(obtener_bd)):
    return await service.get_attraction_detail(db, attraction_id)


@router.get(
    "/attractions/{attraction_id}/tours", response_model=list[TourResponse], tags=["catalog"]
)
async def tours_del_atractivo(attraction_id: UUID, db: AsyncSession = Depends(obtener_bd)):
    return await service.list_tours_by_attraction(db, attraction_id)


@router.get("/agencies", response_model=list[AgencyListItem], tags=["catalog"])
async def buscar_agencias(
    query: str | None = Query(None, min_length=2, max_length=100, description="Nombre de la agencia"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(obtener_bd),
):
    return await service.search_agencies(db, query=query, limit=limit, offset=offset)


@router.get("/agencies/{agency_id}", response_model=AgencyDetailResponse, tags=["catalog"])
async def detalle_agencia(agency_id: UUID, db: AsyncSession = Depends(obtener_bd)):
    return await service.get_agency_detail(db, agency_id)


# ======================================================================
# Endpoints administrativos (header X-Admin-Key)
# ======================================================================
admin = APIRouter(
    prefix="/catalog/admin", tags=["catalog-admin"], dependencies=[Depends(requerir_admin)]
)


@admin.post("/categories", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
async def crear_categoria(data: CategoryCreate, db: AsyncSession = Depends(obtener_bd)):
    return await service.create_category(db, data)


@admin.post(
    "/attractions", response_model=AttractionDetailResponse, status_code=status.HTTP_201_CREATED
)
async def crear_atractivo(data: AttractionCreate, db: AsyncSession = Depends(obtener_bd)):
    return await service.create_attraction(db, data)


@admin.put("/attractions/{attraction_id}", response_model=AttractionDetailResponse)
async def actualizar_atractivo(
    attraction_id: UUID, data: AttractionUpdate, db: AsyncSession = Depends(obtener_bd)
):
    return await service.update_attraction(db, attraction_id, data)


@admin.delete("/attractions/{attraction_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_atractivo(attraction_id: UUID, db: AsyncSession = Depends(obtener_bd)):
    await service.delete_attraction(db, attraction_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@admin.post(
    "/agencies", response_model=AgencyAdminResponse, status_code=status.HTTP_201_CREATED
)
async def crear_agencia(data: AgencyCreate, db: AsyncSession = Depends(obtener_bd)):
    return await service.create_agency(db, data)


@admin.put("/agencies/{agency_id}", response_model=AgencyAdminResponse)
async def actualizar_agencia(
    agency_id: UUID, data: AgencyUpdate, db: AsyncSession = Depends(obtener_bd)
):
    return await service.update_agency(db, agency_id, data)


@admin.post("/agencies/{agency_id}/validate", response_model=AgencyAdminResponse)
async def validar_agencia(
    agency_id: UUID, data: AgencyValidationRequest, db: AsyncSession = Depends(obtener_bd)
):
    return await service.set_agency_validation(
        db, agency_id, validated=True, registry_number=data.dircetur_registry_number
    )


@admin.post("/agencies/{agency_id}/revoke", response_model=AgencyAdminResponse)
async def revocar_agencia(agency_id: UUID, db: AsyncSession = Depends(obtener_bd)):
    return await service.set_agency_validation(db, agency_id, validated=False)


@admin.post("/agencies/sync-dircetur", response_model=DircerturSyncSummary)
async def sincronizar_dircetur(db: AsyncSession = Depends(obtener_bd)):
    return await service.sync_dircetur_registry(db)


@admin.post("/tours", response_model=TourResponse, status_code=status.HTTP_201_CREATED)
async def crear_tour(data: TourCreate, db: AsyncSession = Depends(obtener_bd)):
    return await service.create_tour(db, data)


@admin.put("/tours/{tour_id}", response_model=TourResponse)
async def actualizar_tour(tour_id: UUID, data: TourUpdate, db: AsyncSession = Depends(obtener_bd)):
    return await service.update_tour(db, tour_id, data)


@admin.delete("/tours/{tour_id}", status_code=status.HTTP_204_NO_CONTENT)
async def eliminar_tour(tour_id: UUID, db: AsyncSession = Depends(obtener_bd)):
    await service.delete_tour(db, tour_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
