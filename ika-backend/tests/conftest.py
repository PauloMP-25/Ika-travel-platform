"""Fixtures compartidas de los tests.

Montan la app real (`src.main.aplicacion`) con la sesión de BD sustituida
por una que apunta a la base de datos de pruebas (`ika_travel_test`).

La BD es asíncrona (asyncpg), así que las sesiones se crean con
`poolclass=NullPool`: cada conexión nace y muere en el event loop que la
usa, evitando reutilizar conexiones entre el loop de FastAPI (TestClient)
y los `asyncio.run` de los tests.
"""

import asyncio
import os
from collections.abc import Iterator
from pathlib import Path
from uuid import UUID

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import selectinload
from sqlalchemy.pool import NullPool

from src.core.config import configuracion
from src.core.database import Base, obtener_bd
from src.main import aplicacion

# Importar los modelos pobla `Base.metadata` para poder crear las tablas.
import src.modules.catalog.models  # noqa: F401
import src.modules.emergency.models  # noqa: F401
import src.modules.users.models  # noqa: F401
import src.modules.weather.models  # noqa: F401
import src.modules.reviews.models  # noqa: F401
import src.modules.analytics.models  # noqa: F401

# Misma URL de la BD de trabajo, pero con el esquema de pruebas.
TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    configuracion.URL_BASE_DATOS.rsplit("/", 1)[0] + "/ika_travel_test",
)

TEST_ENGINE = create_async_engine(
    TEST_DATABASE_URL,
    poolclass=NullPool,
    future=True,
)

TestingSessionLocal = async_sessionmaker(
    bind=TEST_ENGINE,
    autoflush=False,
    expire_on_commit=False,
)


# Un único event loop por test. Si cada `run()` usara `asyncio.run()`, cada
# corrutina viviría en un loop distinto y las conexiones/objetos ligados a un
# loop ya cerrado petarían al tocarlos desde otro (p. ej. `session.close()`).
_TEST_LOOP: asyncio.AbstractEventLoop | None = None


@pytest.fixture(autouse=True)
def _test_loop() -> Iterator[asyncio.AbstractEventLoop]:
    """Crea el event loop propio del test y lo cierra al terminar."""
    global _TEST_LOOP
    loop = asyncio.new_event_loop()
    _TEST_LOOP = loop
    try:
        yield loop
    finally:
        _TEST_LOOP = None
        loop.close()


def run(coro):
    """Ejecuta una corrutina desde un test síncrono (sin pytest-asyncio)."""
    if _TEST_LOOP is None:
        return asyncio.run(coro)
    return _TEST_LOOP.run_until_complete(coro)


@pytest.fixture(scope="session")
def app() -> FastAPI:
    """La app real del proyecto, con los manejadores ya registrados."""
    return aplicacion


@pytest.fixture(scope="session", autouse=True)
def _celery_eager_mode() -> None:
    """Ejecuta las tareas Celery en modo síncrono (sin broker Redis).

    Además hay que publicar la app como *default*: `_tls.current_app` es
    *thread-local* y el `TestClient` atiende las peticiones en un hilo
    propio. Sin esta línea, los `shared_task` resuelven la app en ese hilo,
    no encuentran ninguna y Celery crea una app "default" sin *eager* que
    intenta hablar con Redis.
    """
    from celery import _state

    from celery_worker import celery_app

    celery_app.conf.task_always_eager = True
    celery_app.conf.task_eager_propagates = False
    _state.set_default_app(celery_app)
    celery_app.set_current()


@pytest.fixture
def _clean_database() -> None:
    """Recrea el esquema de la BD de tests.

    No es *autouse*: solo se ejecuta para los tests que piden `client` o
    `db_session`, para que las pruebas unitarias (sin BD) sigan corriendo
    aunque no haya PostgreSQL disponible.
    """

    async def _recreate() -> None:
        async with TEST_ENGINE.begin() as conn:
            await conn.run_sync(Base.metadata.drop_all)
            await conn.run_sync(Base.metadata.create_all)

    run(_recreate())


@pytest.fixture
def db_session(_clean_database, _test_loop) -> AsyncSession:
    """Sesión asíncrona para aserciones directas (ver `run()`).

    Se cierra en el mismo event loop en el que se usó (`_test_loop`), que
    sigue abierto durante el *teardown* porque se monta antes que este.
    """
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        run(session.close())


@pytest.fixture
def client(app: FastAPI, _clean_database) -> TestClient:
    """Cliente HTTP con la sesión de BD de tests inyectada."""

    async def override_get_db():
        async with TestingSessionLocal() as session:
            yield session

    app.dependency_overrides[obtener_bd] = override_get_db
    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.clear()
