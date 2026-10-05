"""Tareas Celery del módulo weather (programadas con Celery Beat en celery_worker.py)."""
import asyncio

from celery import shared_task

from src.modules.weather import service
from src.modules.weather.exceptions import WeatherProviderUnavailableException
from src.shared.utils import ejecutar_con_sesion_aislada


async def _refrescar(db) -> dict:
    return (await service.refresh_weather_cache(db)).model_dump()


async def _purgar(db) -> dict:
    return await service.purge_old_weather_data(db, days=14)


@shared_task(
    name="weather.refrescar_cache_clima",
    autoretry_for=(WeatherProviderUnavailableException,),
    retry_backoff=60,
    retry_kwargs={"max_retries": 3},
)
def refrescar_cache_clima() -> dict:
    """RN-03: se programa cada 5 h para que ningún dato supere las 6 h."""
    return asyncio.run(ejecutar_con_sesion_aislada(_refrescar))


@shared_task(name="weather.purgar_datos_antiguos")
def purgar_datos_antiguos() -> dict:
    return asyncio.run(ejecutar_con_sesion_aislada(_purgar))
