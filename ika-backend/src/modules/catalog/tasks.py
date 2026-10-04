"""Tareas Celery del catálogo."""
import asyncio

from celery import shared_task

from src.modules.catalog import service
from src.modules.catalog.exceptions import DircerturSyncFailedException
from src.shared.utils import ejecutar_con_sesion_aislada


async def _sincronizar(db) -> dict:
    resumen = await service.sync_dircetur_registry(db)
    return resumen.model_dump()


@shared_task(name="catalog.sincronizar_padron_dircetur")
def sincronizar_padron_dircetur() -> dict:
    """Actualiza is_validated / dircetur_registry_number contra el padrón oficial."""
    try:
        return asyncio.run(ejecutar_con_sesion_aislada(_sincronizar))
    except DircerturSyncFailedException as exc:
        # Falla esperable (feed no configurado o caído): se reporta sin romper el worker.
        return {"error": exc.mensaje}
