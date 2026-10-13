from celery import shared_task

@shared_task(name="catalog.sincronizar_padron_dircetur")
def sincronizar_padron_dircetur():
    """Tarea programada: Sincronizar listado de agencias con el padrón Mincetur."""
    pass
