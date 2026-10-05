from celery import shared_task

@shared_task(name="weather.refrescar_cache_clima")
def refrescar_cache_clima():
    """Tarea programada (RN-03): Refrescar clima de atractivos activos."""
    pass

@shared_task(name="weather.purgar_datos_antiguos")
def purgar_datos_antiguos():
    """Tarea programada: Limpiar snapshots de clima antiguos para ahorrar espacio."""
    pass
