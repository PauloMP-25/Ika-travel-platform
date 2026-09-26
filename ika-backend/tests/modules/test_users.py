"""Pruebas unitarias aisladas del módulo `users`.

No usan base de datos, red ni Celery: los repositorios y la sesión se
sustituyen por dobles en memoria. La variable `DATABASE_URL` solo existe
para que `src.core.config` (de Paulo) pueda importarse — nunca se conecta.
"""

import os

os.environ.setdefault(
    "DATABASE_URL", "postgresql+asyncpg://sin_uso:sin_uso@localhost:5432/sin_uso"
)

import asyncio
from datetime import datetime, timezone
from uuid import UUID, uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from pydantic import ValidationError
from sqlalchemy.exc import IntegrityError

from src.core import security
from src.modules.users import repository, service
from src.modules.users.exceptions import (
    InactiveUserException,
    InvalidCredentialsException,
    UserAlreadyExistsException,
    UsersException,
    register_users_exception_handlers,
)
from src.modules.users.models import AuthProvider, User
from src.modules.users.router import users_router
from src.modules.users.schemas import UserCreate, UserResponse, UserUpdate

PLAIN_PASSWORD = "secreto123"


def run(coro):
    """Ejecuta una corrutina desde un test síncrono (sin pytest-asyncio)."""
    return asyncio.run(coro)


class FakeSession:
    """Doble de `AsyncSession` que solo registra las operaciones."""

    def __init__(self) -> None:
        self.added: list[object] = []
        self.commits = 0
        self.rollbacks = 0

    def add(self, obj: object) -> None:
        self.added.append(obj)

    async def commit(self) -> None:
        self.commits += 1

    async def rollback(self) -> None:
        self.rollbacks += 1

    async def refresh(self, obj: object) -> None:
        return None


def make_user(**overrides) -> User:
    now = datetime.now(timezone.utc)
    fields = dict(
        id=uuid4(),
        email="viajero@ika.pe",
        password_hash=security.hash_password(PLAIN_PASSWORD),
        full_name="Francisco Ica",
        auth_provider=AuthProvider.EMAIL,
        is_active=True,
        created_at=now,
        updated_at=now,
    )
    fields.update(overrides)
    return User(**fields)


def patch_user(monkeypatch, user: User | None) -> None:
    """El repositorio siempre devuelve `user` (o nadie si es `None`)."""

    async def _fake_get(db, email):
        return user

    monkeypatch.setattr(service.repository, "get_user_by_email", _fake_get)


# ---------------------------------------------------------------- seguridad


def test_hash_password_y_verify_roundtrip() -> None:
    hashed = security.hash_password(PLAIN_PASSWORD)

    assert hashed != PLAIN_PASSWORD
    assert security.verify_password(PLAIN_PASSWORD, hashed) is True
    assert security.verify_password("otra", hashed) is False


def test_verify_password_sin_hash_devuelve_false() -> None:
    assert security.verify_password(PLAIN_PASSWORD, None) is False


def test_token_jwt_roundtrip() -> None:
    user_id = uuid4()

    token = security.create_access_token(user_id)

    assert security.decode_access_token(token) == user_id


def test_token_con_firma_falsa_es_rechazado() -> None:
    with pytest.raises(InvalidCredentialsException) as exc:
        security.decode_access_token("token-manipulado")

    assert exc.value.status_code == 401


def test_token_expirado_es_rechazado() -> None:
    token = security.create_access_token(uuid4(), expires_minutes=-1)

    with pytest.raises(InvalidCredentialsException):
        security.decode_access_token(token)


# ------------------------------------------------------------------ esquemas


def test_user_create_rechaza_password_corta() -> None:
    with pytest.raises(ValidationError):
        UserCreate(email="a@b.pe", password="corto", full_name="Ana")


def test_user_response_no_expone_password_hash() -> None:
    user = make_user(password_hash="hash-secreto-no-publico")

    body = UserResponse.model_validate(user).model_dump()

    assert "password_hash" not in body
    assert "password" not in body
    assert body["email"] == "viajero@ika.pe"


def test_router_expone_los_endpoints_esperados() -> None:
    rutas = {(route.path, method) for route in users_router.routes for method in route.methods}

    assert ("/auth/register", "POST") in rutas
    assert ("/auth/login", "POST") in rutas
    assert ("/users/me", "GET") in rutas
    assert ("/users/me", "PUT") in rutas


# ------------------------------------------------------------------ service


def test_register_user_crea_cuenta(monkeypatch) -> None:
    db = FakeSession()
    patch_user(monkeypatch, None)

    user = run(service.register_user(db, UserCreate(
        email="nuevo@ika.pe", password=PLAIN_PASSWORD, full_name="Nueva Persona"
    )))

    assert db.commits == 1
    assert user.email == "nuevo@ika.pe"
    assert user.auth_provider == AuthProvider.EMAIL
    assert user.password_hash != PLAIN_PASSWORD


def test_register_email_duplicado_lanza_409(monkeypatch) -> None:
    db = FakeSession()
    patch_user(monkeypatch, make_user())

    with pytest.raises(UserAlreadyExistsException) as exc:
        run(service.register_user(db, UserCreate(
            email="viajero@ika.pe", password=PLAIN_PASSWORD, full_name="Otra"
        )))

    assert exc.value.status_code == 409
    assert db.commits == 0


def test_register_por_carrera_en_bd_tambien_da_409(monkeypatch) -> None:
    """La restricción única de la BD se traduce en la excepción de dominio."""

    class SesionaConCommitFallido(FakeSession):
        async def commit(self) -> None:
            raise IntegrityError(
                "INSERT INTO users", {}, Exception("duplicate")
            )

    db = SesionaConCommitFallido()
    patch_user(monkeypatch, None)

    with pytest.raises(UserAlreadyExistsException):
        run(service.register_user(db, UserCreate(
            email="carrera@ika.pe", password=PLAIN_PASSWORD, full_name="C"
        )))

    assert db.rollbacks == 1


def test_authenticate_password_incorrecta_da_401(monkeypatch) -> None:
    db = FakeSession()
    patch_user(monkeypatch, make_user())

    with pytest.raises(InvalidCredentialsException) as exc:
        run(service.authenticate_user(db, "viajero@ika.pe", "incorrecta"))

    assert exc.value.status_code == 401


def test_authenticate_email_desconocido_da_mismo_401(monkeypatch) -> None:
    """No se revela si el email existe: mismo error genérico."""
    db = FakeSession()
    patch_user(monkeypatch, None)

    with pytest.raises(InvalidCredentialsException) as exc:
        run(service.authenticate_user(db, "nadie@ika.pe", PLAIN_PASSWORD))

    assert exc.value.status_code == 401


def test_authenticate_cuenta_inactiva_da_403(monkeypatch) -> None:
    db = FakeSession()
    patch_user(monkeypatch, make_user(is_active=False))

    with pytest.raises(InactiveUserException) as exc:
        run(service.authenticate_user(db, "viajero@ika.pe", PLAIN_PASSWORD))

    assert exc.value.status_code == 403


def test_authenticate_correcto_devuelve_usuario(monkeypatch) -> None:
    db = FakeSession()
    esperado = make_user()
    patch_user(monkeypatch, esperado)

    obtenido = run(service.authenticate_user(
        db, "viajero@ika.pe", PLAIN_PASSWORD
    ))

    assert obtenido.id == esperado.id


def test_update_profile_solo_cambia_lo_enviado(monkeypatch) -> None:
    db = FakeSession()
    user = make_user()

    actualizado = run(service.update_user_profile(
        db, user, UserUpdate(phone="+51999888777")
    ))

    assert actualizado.phone == "+51999888777"
    assert actualizado.full_name == "Francisco Ica"  # intacto
    assert db.commits == 1


# ------------------------------------------------------------- manejador HTTP


@pytest.mark.parametrize(
    "excepcion,codigo_esperado",
    [
        (UserAlreadyExistsException("duplicado@ika.pe"), 409),
        (InvalidCredentialsException(), 401),
        (InactiveUserException(), 403),
    ],
)
def test_manejador_http_de_users(excepcion, codigo_esperado) -> None:
    """Las excepciones del servicio se traducen a su código HTTP."""
    app = FastAPI()
    register_users_exception_handlers(app)

    @app.get("/disparador")
    async def _disparador():
        raise excepcion

    response = TestClient(app).get("/disparador")

    assert response.status_code == codigo_esperado
    assert response.json()["detail"] == excepcion.detail


def test_excepciones_de_users_no_necesitan_core() -> None:
    """El módulo no depende de `src/core/exceptions.py` (es de Paulo)."""
    assert issubclass(InvalidCredentialsException, UsersException)
    assert issubclass(UsersException, Exception)
