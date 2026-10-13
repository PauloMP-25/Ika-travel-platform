from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from src.modules.catalog.models import Attraction, Category


async def atractivos_en_caja(
    db: AsyncSession,
    *,
    lat_min: float,
    lat_max: float,
    lon_min: float,
    lon_max: float,
    category_slug: str | None,
) -> list[Attraction]:
    """Prefiltro por caja envolvente (usa el índice lat/lon); la distancia exacta se calcula luego."""
    consulta = (
        select(Attraction)
        .where(
            Attraction.is_active.is_(True),
            Attraction.latitude.between(lat_min, lat_max),
            Attraction.longitude.between(lon_min, lon_max),
        )
        .options(selectinload(Attraction.images), selectinload(Attraction.categories))
    )
    if category_slug:
        consulta = consulta.where(Attraction.categories.any(Category.slug == category_slug))
    return list((await db.execute(consulta)).scalars().all())
