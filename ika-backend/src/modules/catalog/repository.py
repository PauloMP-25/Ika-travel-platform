"""Consultas SQLAlchemy puras del catálogo (sin reglas de negocio de presentación)."""
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from src.modules.catalog.models import Agency, Attraction, Category, Tour
from src.shared.utils import escapar_like


# ----------------------------------------------------------------------
# Categorías
# ----------------------------------------------------------------------
async def listar_categorias(db: AsyncSession) -> list[Category]:
    resultado = await db.execute(select(Category).order_by(Category.name))
    return list(resultado.scalars().all())


async def obtener_categoria_por_slug(db: AsyncSession, slug: str) -> Category | None:
    resultado = await db.execute(select(Category).where(Category.slug == slug))
    return resultado.scalar_one_or_none()


async def obtener_categorias_por_slugs(db: AsyncSession, slugs: list[str]) -> list[Category]:
    if not slugs:
        return []
    resultado = await db.execute(select(Category).where(Category.slug.in_(slugs)))
    return list(resultado.scalars().all())


# ----------------------------------------------------------------------
# Atractivos
# ----------------------------------------------------------------------
async def listar_atractivos_paginados(
    db: AsyncSession,
    *,
    category_slug: str | None,
    district: str | None,
    search: str | None,
    page: int,
    page_size: int,
) -> tuple[list[Attraction], int]:
    filtros = [Attraction.is_active.is_(True)]
    if category_slug:
        # EXISTS: evita duplicados y mantiene correcto el conteo total.
        filtros.append(Attraction.categories.any(Category.slug == category_slug))
    if district:
        filtros.append(func.lower(Attraction.district) == district.strip().lower())
    if search:
        filtros.append(Attraction.name.ilike(f"%{escapar_like(search.strip())}%", escape="\\"))

    # El total se calcula en la BD, nunca trayendo los registros a memoria.
    total = await db.scalar(select(func.count()).select_from(Attraction).where(*filtros)) or 0

    consulta = (
        select(Attraction)
        .where(*filtros)
        .options(selectinload(Attraction.images), selectinload(Attraction.categories))
        .order_by(Attraction.name, Attraction.id)
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    resultado = await db.execute(consulta)
    return list(resultado.scalars().all()), total


async def obtener_atractivo_por_id(
    db: AsyncSession, attraction_id: UUID, *, solo_activos: bool = True
) -> Attraction | None:
    consulta = (
        select(Attraction)
        .where(Attraction.id == attraction_id)
        .options(selectinload(Attraction.images), selectinload(Attraction.categories))
        .execution_options(populate_existing=True)
    )
    if solo_activos:
        consulta = consulta.where(Attraction.is_active.is_(True))
    resultado = await db.execute(consulta)
    return resultado.scalar_one_or_none()


def _modelo_review():
    """El módulo ``reviews`` es de otro desarrollador y puede no existir aún."""
    try:
        from src.modules.reviews.models import Review  # type: ignore[attr-defined]
    except ImportError:
        return None
    return Review


async def obtener_promedio_calificacion(db: AsyncSession, attraction_id: UUID) -> float | None:
    """Promedio de calificaciones; ``None`` si no hay reseñas o el módulo reviews no está listo."""
    review = _modelo_review()
    if review is None:
        return None
    promedio = await db.scalar(
        select(func.avg(review.rating)).where(review.attraction_id == attraction_id)
    )
    return float(promedio) if promedio is not None else None


# ----------------------------------------------------------------------
# Tours
# ----------------------------------------------------------------------
async def listar_tours_por_atractivo(db: AsyncSession, attraction_id: UUID) -> list[Tour]:
    """Solo tours de agencias validadas (RN-01)."""
    consulta = (
        select(Tour)
        .join(Agency, Tour.agency_id == Agency.id)
        .where(Tour.attraction_id == attraction_id, Agency.is_validated.is_(True))
        .options(joinedload(Tour.agency), joinedload(Tour.attraction))
        .order_by(Tour.price, Tour.name)
    )
    resultado = await db.execute(consulta)
    return list(resultado.scalars().all())


async def obtener_tour_por_id(db: AsyncSession, tour_id: UUID) -> Tour | None:
    consulta = (
        select(Tour)
        .where(Tour.id == tour_id)
        .options(joinedload(Tour.agency), joinedload(Tour.attraction))
        .execution_options(populate_existing=True)
    )
    resultado = await db.execute(consulta)
    return resultado.scalar_one_or_none()


# ----------------------------------------------------------------------
# Agencias
# ----------------------------------------------------------------------
async def listar_agencias_validadas(
    db: AsyncSession, *, search_term: str | None, limit: int, offset: int
) -> list[tuple[Agency, int]]:
    """RN-01 aplicada aquí: la consulta base SOLO contiene agencias validadas."""
    conteo = (
        select(Tour.agency_id, func.count(Tour.id).label("total"))
        .group_by(Tour.agency_id)
        .subquery()
    )
    consulta = (
        select(Agency, func.coalesce(conteo.c.total, 0))
        .outerjoin(conteo, conteo.c.agency_id == Agency.id)
        .where(Agency.is_validated.is_(True))
    )
    if search_term:
        consulta = consulta.where(
            Agency.name.ilike(f"%{escapar_like(search_term.strip())}%", escape="\\")
        )
    consulta = consulta.order_by(Agency.name, Agency.id).offset(offset).limit(limit)
    resultado = await db.execute(consulta)
    return [(agencia, int(total)) for agencia, total in resultado.all()]


async def obtener_agencia_con_tours(db: AsyncSession, agency_id: UUID) -> Agency | None:
    consulta = (
        select(Agency)
        .where(Agency.id == agency_id)
        .options(selectinload(Agency.tours).joinedload(Tour.attraction))
        .execution_options(populate_existing=True)
    )
    resultado = await db.execute(consulta)
    return resultado.scalar_one_or_none()


async def obtener_agencia_por_ruc(db: AsyncSession, ruc: str) -> Agency | None:
    resultado = await db.execute(select(Agency).where(Agency.ruc == ruc))
    return resultado.scalar_one_or_none()


async def listar_todas_las_agencias(db: AsyncSession) -> list[Agency]:
    resultado = await db.execute(select(Agency))
    return list(resultado.scalars().all())
