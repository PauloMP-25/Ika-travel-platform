"""Entry point de Celery.

Arranque local: `celery -A celery_worker.celery_app worker -l info`
"""

from src.celery_app import celery_app

__all__ = ["celery_app"]
