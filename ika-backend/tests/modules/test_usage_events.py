from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.exc import OperationalError

from src.modules.analytics.models import UsageEvent, UsageEventType
from src.modules.analytics.recorder import PostgresUsageRecorder
from src.shared.usage_events import UsageEventData
from tests.conftest import TestingSessionLocal, run


def test_usage_events_model_and_recorder(db_session):
    """A-18/A-19/A-20: Verifica que PostgresUsageRecorder persiste eventos anónimos sin datos sensibles."""
    recorder = PostgresUsageRecorder(TestingSessionLocal)

    event_data = UsageEventData(
        event_type="attraction_search",
        category_slug="aventura",
        district="Ica",
        ui_language="es",
    )

    run(recorder.record(event_data))

    async def _check():
        stmt = select(UsageEvent).where(UsageEvent.event_type == UsageEventType.ATTRACTION_SEARCH)
        result = await db_session.execute(stmt)
        return result.scalars().all()

    events = run(_check())
    assert len(events) == 1
    event = events[0]
    assert event.category_slug == "aventura"
    assert event.district == "Ica"
    assert event.ui_language == "es"
    assert event.event_type == UsageEventType.ATTRACTION_SEARCH

    # Ley N° 29733: A-20 - Verificar anonimización (no existen columnas de IP, user_id ni texto)
    columns = [c.name for c in UsageEvent.__table__.columns]
    assert "user_id" not in columns
    assert "ip" not in columns
    assert "ip_address" not in columns
    assert "email" not in columns
    assert "text" not in columns
    assert "source_text" not in columns


def test_recorder_fails_gracefully_on_db_error():
    """A-22: Un fallo de persistencia en analítica no lanza excepción ni rompe el flujo."""
    class FailingSessionFactory:
        def __call__(self):
            raise OperationalError("SELECT 1", {}, Exception("DB down"))

    recorder = PostgresUsageRecorder(FailingSessionFactory())
    event_data = UsageEventData(
        event_type="translation",
        source_lang="es",
        target_lang="en",
        translation_origin="cache",
    )

    # Debe capturar SQLAlchemyError y no elevar excepción
    run(recorder.record(event_data))
