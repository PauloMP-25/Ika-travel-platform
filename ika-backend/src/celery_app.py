"""Instancia única de Celery compartida por todos los módulos.

Uso: `celery -A celery_worker.celery_app worker -l info`
"""

from celery import Celery

from src.config import settings

celery_app = Celery(
    "ika_travel",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["src.modules.emergency.tasks"],
)

celery_app.conf.update(
    task_track_started=True,
    result_expires=3600,
    timezone="UTC",
    enable_utc=True,
    task_always_eager=settings.CELERY_TASK_ALWAYS_EAGER,
    # En modo eager (tests) las fallas no deben romper la petición HTTP:
    # la tarea registra el error en la propia tabla de notificaciones.
    task_eager_propagates=False,
)
