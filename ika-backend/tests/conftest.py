"""Fixtures compartidas de los tests.

Como `src/main.py` todavía no está escrito (lo hará otro miembro del equipo),
cada módulo de tests monta aquí su propia app FastAPI con sus routers.
Cuando exista `main.py`, este fixture pasará a importarlo directamente.
"""

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import NullPool

from src.config import settings
from src.core.dependencies import get_db
from src.core.exceptions import register_exception_handlers
from src.database import Base
from src.modules.emergency.router import emergency_router
from src.modules.users.router import users_router

# Importar los modelos pobla `Base.metadata` para poder crear las tablas.
import src.modules.emergency.models  # noqa: F401
import src.modules.users.models  # noqa: F401

TEST_ENGINE = create_engine(
    settings.TEST_DATABASE_URL,
    poolclass=NullPool,
    future=True,
)

TestingSessionLocal = sessionmaker(
    bind=TEST_ENGINE,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
)


@pytest.fixture(scope="session")
def app() -> FastAPI:
    """App mínima con los módulos cargados y los manejadores globales."""
    application = FastAPI(title="Ika Travel API (tests)")
    application.include_router(users_router, prefix="/api/v1")
    application.include_router(emergency_router, prefix="/api/v1")
    register_exception_handlers(application)
    return application


@pytest.fixture(scope="session", autouse=True)
def _celery_eager_mode() -> None:
    """Ejecuta las tareas Celery en modo síncrono (sin broker Redis)."""
    from src.celery_app import celery_app

    celery_app.conf.task_always_eager = True
    celery_app.conf.task_eager_propagates = False


@pytest.fixture(autouse=True)
def _clean_database() -> None:
    """Recrea el esquema de la BD de tests antes de cada test."""
    Base.metadata.drop_all(TEST_ENGINE)
    Base.metadata.create_all(TEST_ENGINE)


@pytest.fixture
def db_session(_clean_database):
    """Sesión de la BD de tests para aserciones directas."""
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client(app: FastAPI) -> TestClient:
    """Cliente HTTP con la sesión de BD de tests inyectada."""

    def override_get_db():
        session = TestingSessionLocal()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.clear()
