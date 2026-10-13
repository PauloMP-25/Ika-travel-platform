"""Punto de entrada de Celery.

Worker:  celery -A celery_worker.celery_app worker -l info          (Windows: añadir --pool=solo)
Beat:    celery -A celery_worker.celery_app beat -l info
"""
from celery import Celery

from src.core.config import configuracion

celery_app = Celery(
    "ika_travel",
    broker=configuracion.URL_REDIS,
    # "include" importa los módulos de tareas al arrancar el worker (sin imports circulares).
    include=[
        "src.modules.weather.tasks",
        "src.modules.catalog.tasks",
        "src.modules.emergency.tasks",
    ],
)

celery_app.conf.update(
    timezone="America/Lima",
    enable_utc=True,
    task_ignore_result=True,
    broker_connection_retry_on_startup=True,
    beat_schedule={
        # RN-03: dato climático máximo de 6 h -> refresco cada 5 h.
        "refrescar-clima-cada-5h": {
            "task": "weather.refrescar_cache_clima",
            "schedule": 5 * 60 * 60,
        },
        "purgar-clima-antiguo-diario": {
            "task": "weather.purgar_datos_antiguos",
            "schedule": 24 * 60 * 60,
        },
        "sincronizar-padron-dircetur-diario": {
            "task": "catalog.sincronizar_padron_dircetur",
            "schedule": 24 * 60 * 60,
        },
    },
)
