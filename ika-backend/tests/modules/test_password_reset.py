"""Pruebas del RF-03 (recuperación de cuenta por correo).

Etapa 1: servicio de correo (`EmailSender`, `SMTPEmailSender`,
`MockEmailSender`), validación de configuración y construcción del enlace
desde `PASSWORD_RESET_URL_TEMPLATE`.

Etapa 2: persistencia (`PasswordResetToken`, `users.password_changed_at`),
repositorio y migración Alembic reversible.

Ningún test de este archivo abre una conexión de red: el SMTP se sustituye
por un doble y el envío real se cubre con `MockEmailSender`.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import subprocess
import sys
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.schema import UniqueConstraint

from src.core import security
from src.core.config import Configuracion, configuracion
from src.core.database import Base
from src.modules.users import service
from src.modules.users.email import (
    ConfiguracionEmailInvalida,
    Correo,
    EmailSender,
    SMTPEmailSender,
    construir_enlace_reset,
    contenido_plantilla,
    obtener_email_sender,
    validar_configuracion_email,
)
from src.modules.users.exceptions import ResetTokenInvalidoException
from src.modules.users.models import (
    AuthProvider,
    PasswordResetToken,
    User,
    UserRole,
)
from src.modules.users import repository
from src.modules.users.schemas import (
    ForgotPasswordRequest,
    ResetPasswordRequest,
)
from src.redis_client import obtener_cliente_redis
from tests.conftest import TestingSessionLocal, run
from tests.modules.fakes import FakeRedis, MockEmailSender

RAIZ_BACKEND = Path(__file__).resolve().parents[2]

URL_FORGOT = "/api/v1/auth/password/forgot"
URL_RESET = "/api/v1/auth/password/reset"
MENSAJE_GENERICO = (
    "Si el correo está registrado, recibirás instrucciones para recuperar tu cuenta."
)
CLAVE_NUEVA = "NuevaClaveSegura"

# ----------------------------------------------------------------------
# Dobles
# ----------------------------------------------------------------------
class SMTPFalso:
    """Doble de `smtplib.SMTP` que registra las llamadas, sin red."""

    instancias: list["SMTPFalso"] = []

    def __init__(self, host, port, timeout=None) -> None:
        self.host = host
        self.port = port
        self.timeout = timeout
        self.starttls_contexto = None
        self.login_usuario = None
        self.login_clave = None
        self.mensaje = None
        self.hilo = threading.get_ident()
        self.cerrado = False
        SMTPFalso.instancias.append(self)

    def starttls(self, context=None) -> None:
        self.starttls_contexto = context

    def login(self, user, password) -> None:
        self.login_usuario = user
        self.login_clave = password

    def send_message(self, mensaje) -> None:
        self.mensaje = mensaje

    def quit(self) -> None:
        self.cerrado = True

    def __enter__(self) -> "SMTPFalso":
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        self.quit()
        return False


@pytest.fixture(autouse=True)
def _limpiar_smtp_falso():
    SMTPFalso.instancias.clear()
    yield
    SMTPFalso.instancias.clear()


def _cfg(**overrides) -> Configuracion:
    """Configuración controlada (no lee las credenciales reales del `.env`)."""
    base = dict(
        URL_BASE_DATOS="postgresql+asyncpg://usuario:clave@localhost:5432/db",
        SMTP_HOST="smtp.gmail.com",
        SMTP_PORT=587,
        SMTP_STARTTLS=True,
        SMTP_USER="no-reply@ika.pe",
        SMTP_PASSWORD="clave-de-aplicacion-falsa",
        SMTP_FROM="",
        SMTP_TIMEOUT_SEGUNDOS=5.0,
        PASSWORD_RESET_URL_TEMPLATE="ikatravel://reset-password?token={token}",
    )
    base.update(overrides)
    return Configuracion(**base)


# ----------------------------------------------------------------------
# Validación de la configuración (al iniciar)
# ----------------------------------------------------------------------
def test_config_valida_no_lanza():
    validar_configuracion_email(_cfg())


@pytest.mark.parametrize(
    "overrides,esperado",
    [
        ({"SMTP_HOST": ""}, "SMTP_HOST"),
        ({"SMTP_PORT": 0}, "SMTP_PORT"),
        ({"SMTP_USER": ""}, "SMTP_USER"),
        ({"SMTP_PASSWORD": ""}, "SMTP_PASSWORD"),
        ({"SMTP_STARTTLS": False}, "SMTP_STARTTLS"),
        (
            {"PASSWORD_RESET_URL_TEMPLATE": "https://ika.pe/reset"},
            "PASSWORD_RESET_URL_TEMPLATE({token})",
        ),
    ],
)
def test_config_invalida_indica_la_variable(overrides, esperado):
    """La validación nombra la variable, jamás su valor."""
    with pytest.raises(ConfiguracionEmailInvalida) as exc:
        validar_configuracion_email(_cfg(**overrides))
    assert esperado in str(exc.value)


def test_config_invalida_no_filtra_la_clave():
    """El mensaje de error no contiene la contraseña SMTP."""
    with pytest.raises(ConfiguracionEmailInvalida) as exc:
        validar_configuracion_email(_cfg(SMTP_PASSWORD=""))
    assert "clave-de-aplicacion-falsa" not in str(exc.value)


def test_sender_falla_al_iniciar_sin_config():
    """`SMTPEmailSender` valida en `__init__`, antes de poder enviar nada."""
    with pytest.raises(ConfiguracionEmailInvalida):
        SMTPEmailSender(_cfg(SMTP_USER=""))


# ----------------------------------------------------------------------
# Envío SMTP real (con doble, sin red)
# ----------------------------------------------------------------------
def test_smtp_usa_starttls_login_y_send_message(monkeypatch):
    monkeypatch.setattr("smtplib.SMTP", SMTPFalso)
    sender = SMTPEmailSender(_cfg())

    run(sender.enviar(Correo("viajera@ika.pe", "Asunto", "Cuerpo del correo")))

    assert len(SMTPFalso.instancias) == 1
    smtp = SMTPFalso.instancias[0]
    assert smtp.host == "smtp.gmail.com"
    assert smtp.port == 587
    assert smtp.starttls_contexto is not None, "STARTTLS no se habilitó"
    assert smtp.login_usuario == "no-reply@ika.pe"
    assert smtp.login_clave == "clave-de-aplicacion-falsa"
    assert smtp.mensaje["To"] == "viajera@ika.pe"
    assert smtp.cerrado is True


def test_el_envio_bloqueante_corre_en_otro_hilo(monkeypatch):
    """`smtplib` bloquea: se ejecuta vía `anyio.to_thread` (hilo distinto)."""
    monkeypatch.setattr("smtplib.SMTP", SMTPFalso)
    sender = SMTPEmailSender(_cfg())

    run(sender.enviar(Correo("viajera@ika.pe", "Asunto", "Cuerpo")))

    assert SMTPFalso.instancias[0].hilo != threading.get_ident()


def test_smtp_from_por_defecto_es_el_usuario():
    """Si `SMTP_FROM` se omite, se usa `SMTP_USER`."""
    sender = SMTPEmailSender(_cfg(SMTP_FROM=""))
    assert sender._remitente == "no-reply@ika.pe"


# ----------------------------------------------------------------------
# MockEmailSender (pruebas sin conexión a Gmail)
# ----------------------------------------------------------------------
def test_mock_email_sender_captura_sin_red(monkeypatch):
    def _sin_red(*args, **kwargs):  # pragma: no cover - red de seguridad
        raise AssertionError("Los tests no deben abrir conexiones SMTP")

    monkeypatch.setattr("smtplib.SMTP", _sin_red)
    mock = MockEmailSender()

    run(mock.enviar(Correo("a@ika.pe", "Asunto", "Cuerpo")))
    run(mock.enviar(Correo("b@ika.pe", "Asunto 2", "Cuerpo 2")))

    assert mock.cantidad == 2
    assert mock.ultimo().destino == "b@ika.pe"


# ----------------------------------------------------------------------
# Logs sin datos sensibles
# ----------------------------------------------------------------------
def test_logs_no_contienen_clave_ni_cuerpo(monkeypatch, caplog):
    monkeypatch.setattr("smtplib.SMTP", SMTPFalso)
    sender = SMTPEmailSender(_cfg())

    with caplog.at_level(logging.INFO):
        run(
            sender.enviar(
                Correo(
                    "viajera@ika.pe",
                    "Recupera tu contraseña",
                    "Usa el enlace ikatravel://reset-password?token=SECRETO123",
                )
            )
        )

    texto = caplog.text
    assert "clave-de-aplicacion-falsa" not in texto
    assert "SECRETO123" not in texto
    assert "ikatravel://" not in texto
    assert "Usa el enlace" not in texto
    # El destino aparece enmascarado, nunca completo.
    assert "viajera@ika.pe" not in texto
    assert "v***@ika.pe" in texto


# ----------------------------------------------------------------------
# Plantillas y enlace (solo desde la variable de entorno)
# ----------------------------------------------------------------------
def test_plantillas_es_en():
    asunto_es, cuerpo_es = contenido_plantilla("reset", "es")
    asunto_en, cuerpo_en = contenido_plantilla("reset", "en")
    assert "contraseña" in asunto_es
    assert "password" in asunto_en
    assert cuerpo_es != cuerpo_en


def test_plantilla_con_idioma_desconocido_usa_es():
    asunto, _ = contenido_plantilla("reset", "fr")
    assert asunto == contenido_plantilla("reset", "es")[0]


def test_plantilla_aviso_google():
    asunto_es, cuerpo_es = contenido_plantilla("google", "es")
    assert "Google" in asunto_es
    assert "Google" in cuerpo_es


def test_enlace_se_construye_solo_desde_la_variable_de_entorno():
    cfg = _cfg(PASSWORD_RESET_URL_TEMPLATE="mimovil://reset?token={token}")
    assert (
        construir_enlace_reset("ABC123", cfg)
        == "mimovil://reset?token=ABC123"
    )
    assert construir_enlace_reset("ABC123", _cfg()) == (
        "ikatravel://reset-password?token=ABC123"
    )


def test_enlace_sin_token_en_la_plantilla_falla():
    cfg = _cfg(PASSWORD_RESET_URL_TEMPLATE="https://ika.pe/reset")
    with pytest.raises(ConfiguracionEmailInvalida):
        construir_enlace_reset("ABC123", cfg)


# ======================================================================
# Etapa 2 — Persistencia
# ======================================================================
def _usuario(**overrides) -> User:
    ahora = datetime.now(timezone.utc)
    campos = dict(
        email="viajera@ika.pe",
        password_hash=security.hash_password("secreto123"),
        full_name="Viajera Ica",
        auth_provider=AuthProvider.EMAIL,
        role=UserRole.TOURIST,
        preferred_language="es",
        preferences=[],
        is_active=True,
        created_at=ahora,
        updated_at=ahora,
    )
    campos.update(overrides)
    return User(**campos)


def _hash(texto: str) -> str:
    return hashlib.sha256(texto.encode("utf-8")).hexdigest()


def _token(user_id, token_hash: str, *, minutos: int = 30, usado: bool = False):
    ahora = datetime.now(timezone.utc)
    return PasswordResetToken(
        user_id=user_id,
        token_hash=token_hash,
        created_at=ahora,
        expires_at=ahora + timedelta(minutes=minutos),
        used_at=ahora if usado else None,
    )


def test_esquema_de_password_reset_tokens():
    """Columnas, unicidad y FK en cascada exigidas por el RF-03."""
    tabla = Base.metadata.tables["password_reset_tokens"]

    assert tabla.c.token_hash.nullable is False, "token_hash debe ser NOT NULL"
    assert tabla.c.token_hash.type.length == 64, "SHA-256 en hex = 64 caracteres"
    assert tabla.c.used_at.nullable is True, "used_at debe ser anulable"
    assert tabla.c.expires_at.nullable is False
    assert tabla.c.created_at.nullable is False

    restricciones = [c for c in tabla.constraints if isinstance(c, UniqueConstraint)]
    assert any("token_hash" in r.columns.keys() for r in restricciones), (
        "token_hash debe ser único"
    )

    fk = next(iter(tabla.c.user_id.foreign_keys))
    assert fk.target_fullname == "users.id"
    assert fk.ondelete == "CASCADE", "eliminación en cascada hacia users.id"


def test_usuario_tiene_password_changed_at():
    columna = Base.metadata.tables["users"].c.password_changed_at
    assert columna.nullable is True
    assert columna.type.timezone is True


def test_solo_se_almacena_el_hash_sha256(db_session):
    """En PostgreSQL nunca aparece el token en claro, solo su hash SHA-256."""
    token_claro = "TOKEN-CLARO-QUE-NUNCA-DEBE-ALMACENARSE"
    esperado = _hash(token_claro)

    async def _guardar():
        usuario = _usuario()
        repository.add_user(db_session, usuario)
        await db_session.commit()
        await db_session.refresh(usuario)
        repository.add_password_reset_token(
            db_session, _token(usuario.id, esperado)
        )
        await db_session.commit()
        return await repository.get_password_reset_token_by_hash(
            db_session, esperado
        )

    fila = run(_guardar())

    assert fila is not None
    assert fila.token_hash == esperado
    assert len(fila.token_hash) == 64
    valores = " ".join(
        str(getattr(fila, columna.name)) for columna in fila.__table__.columns
    )
    assert token_claro not in valores, "el token en claro apareció en la BD"
    assert _hash(token_claro) == hashlib.sha256(
        token_claro.encode("utf-8")
    ).hexdigest()


def test_token_hash_es_unico(db_session):
    async def _duplicar():
        usuario = _usuario()
        repository.add_user(db_session, usuario)
        await db_session.commit()
        await db_session.refresh(usuario)
        repository.add_password_reset_token(
            db_session, _token(usuario.id, "a" * 64)
        )
        await db_session.commit()
        repository.add_password_reset_token(
            db_session, _token(usuario.id, "a" * 64)
        )
        await db_session.commit()

    with pytest.raises(IntegrityError):
        run(_duplicar())
    run(db_session.rollback())


def test_tokens_se_eliminan_en_cascada_con_el_usuario(db_session):
    async def _borrar_usuario():
        usuario = _usuario()
        repository.add_user(db_session, usuario)
        await db_session.commit()
        await db_session.refresh(usuario)
        repository.add_password_reset_token(
            db_session, _token(usuario.id, "b" * 64)
        )
        await db_session.commit()

        await db_session.delete(usuario)
        await db_session.commit()

        tokens = await repository.get_password_reset_token_by_hash(
            db_session, "b" * 64
        )
        return tokens

    assert run(_borrar_usuario()) is None


def test_invalidar_tokens_previos_deja_un_solo_activo(db_session):
    """Cada solicitud nueva invalida los tokens anteriores en la transacción."""
    viejo = _hash("token-viejo")
    reciente = _hash("token-reciente")
    ya_usado = _hash("token-ya-usado")
    usado_hace_rato = datetime.now(timezone.utc) - timedelta(minutes=5)

    async def _preparar():
        usuario = _usuario()
        repository.add_user(db_session, usuario)
        await db_session.commit()
        await db_session.refresh(usuario)
        for hash_ in (viejo, reciente):
            repository.add_password_reset_token(
                db_session, _token(usuario.id, hash_)
            )
        token_usado = _token(usuario.id, ya_usado, usado=True)
        token_usado.used_at = usado_hace_rato
        repository.add_password_reset_token(db_session, token_usado)
        await db_session.commit()

        afectados = await repository.invalidate_active_tokens(db_session, usuario.id)
        await db_session.commit()
        return usuario, afectados, token_usado

    usuario, afectados, token_usado = run(_preparar())

    assert afectados == 2, "solo deben invalidarse los dos tokens activos"

    async def _consultar():
        activos = []
        for hash_ in (viejo, reciente, ya_usado):
            fila = await repository.get_password_reset_token_by_hash(db_session, hash_)
            activos.append(fila)
        return activos

    viejo_fila, reciente_fila, usado_fila = run(_consultar())

    assert viejo_fila.used_at is not None, "el token viejo quedó invalidado"
    assert reciente_fila.used_at is not None
    assert usado_fila.used_at == usado_hace_rato, (
        "un token ya usado no debe re-marcarse"
    )


def test_marcar_token_usado_es_atomico(db_session):
    """Compare-and-set: la segunda petición con el mismo token pierde."""
    hash_ = _hash("token-doble-uso")

    async def _preparar():
        usuario = _usuario()
        repository.add_user(db_session, usuario)
        await db_session.commit()
        await db_session.refresh(usuario)
        token = _token(usuario.id, hash_)
        repository.add_password_reset_token(db_session, token)
        await db_session.commit()
        return token

    token = run(_preparar())

    primera = run(repository.mark_token_used(db_session, token.id))
    run(db_session.commit())
    segunda = run(repository.mark_token_used(db_session, token.id))
    run(db_session.commit())

    assert primera is True, "la primera petición debe ganar la carrera"
    assert segunda is False, "el token ya no puede reutilizarse"

    async def _leer():
        return await repository.get_password_reset_token_by_hash(db_session, hash_)

    assert run(_leer()).used_at is not None


def _alembic_sql(*args: str) -> str:
    """Genera SQL en modo offline (sin tocar ninguna base de datos)."""
    proceso = subprocess.run(
        [sys.executable, "-m", "alembic", *args, "--sql"],
        cwd=RAIZ_BACKEND,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    assert proceso.returncode == 0, proceso.stderr
    return proceso.stdout


def test_migracion_rf_03_es_reversible():
    """`upgrade` crea lo que `downgrade` deshace, y no toca nada más."""
    sql_subida = _alembic_sql("upgrade", "head")

    assert "CREATE TABLE password_reset_tokens" in sql_subida
    assert "password_changed_at" in sql_subida
    assert "uq_password_reset_tokens_token_hash" in sql_subida
    assert "ix_password_reset_tokens_user_id" in sql_subida
    assert "FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE" in sql_subida

    sql_bajada = _alembic_sql(
        "downgrade", "e5c1a7b93f28:d4af4f66c370"
    )

    assert "DROP TABLE password_reset_tokens" in sql_bajada
    assert "ALTER TABLE users DROP COLUMN password_changed_at" in sql_bajada
    # El downgrade solo revierte la migración RF-03.
    assert "DROP TABLE users" not in sql_bajada
    assert "DROP TABLE weather_alert" not in sql_bajada


# ======================================================================
# Etapa 3 — Endpoints, rate limit, tokens de un solo uso y JWT
# ======================================================================
@pytest.fixture
def mock_sender() -> MockEmailSender:
    """Doble de correo: los tests nunca abren una conexión con Gmail."""
    return MockEmailSender()


@pytest.fixture
def sender_en_app(client, app, mock_sender) -> MockEmailSender:
    app.dependency_overrides[obtener_email_sender] = lambda: mock_sender
    return mock_sender


@pytest.fixture
def redis_falso(client, app) -> FakeRedis:
    """Redis sustituido por un contador en memoria (no hay Redis en local)."""
    fake = FakeRedis()
    app.dependency_overrides[obtener_cliente_redis] = lambda: fake
    return fake


async def _guardar_en_bd(usuario: User) -> User:
    async with TestingSessionLocal() as db:
        db.add(usuario)
        await db.commit()
        await db.refresh(usuario)
        return usuario


def _crear_usuario(**overrides) -> User:
    return run(_guardar_en_bd(_usuario(**overrides)))


def _usuario_bd(email: str = "viajera@ika.pe") -> User | None:
    async def _buscar():
        async with TestingSessionLocal() as db:
            resultado = await db.execute(select(User).where(User.email == email))
            return resultado.scalar_one_or_none()

    return run(_buscar())


async def _tokens_en_bd() -> list[PasswordResetToken]:
    async with TestingSessionLocal() as db:
        resultado = await db.execute(select(PasswordResetToken))
        return list(resultado.scalars().all())


def _insertar_token_bd(user_id, token_hash: str, **kwargs) -> PasswordResetToken:
    async def _crear():
        async with TestingSessionLocal() as db:
            token = _token(user_id, token_hash, **kwargs)
            db.add(token)
            await db.commit()
            await db.refresh(token)
            return token

    return run(_crear())


def _token_del_enlace(correo: Correo) -> str:
    """Extrae el token de la línea del enlace del cuerpo del correo."""
    linea = next((l for l in correo.cuerpo.splitlines() if "://" in l), None)
    assert linea, "el correo no contiene el enlace de recuperación"
    assert "token=" in linea
    return linea.split("token=", 1)[1]


def _solicitar_token(client, mock_sender, email: str = "viajera@ika.pe") -> str:
    r = client.post(URL_FORGOT, json={"email": email})
    assert r.status_code == 202, r.text
    return _token_del_enlace(mock_sender.ultimo())


def _reset(client, token: str, clave: str = CLAVE_NUEVA):
    return client.post(URL_RESET, json={"token": token, "new_password": clave})


# ----------------------------------------------------------------------
# POST /auth/password/forgot
# ----------------------------------------------------------------------
def test_forgot_correo_existente_devuelve_202_y_envia_enlace(
    client, sender_en_app, mock_sender
):
    _crear_usuario()

    r = client.post(URL_FORGOT, json={"email": "viajera@ika.pe"})

    assert r.status_code == 202
    assert r.json() == {"detail": MENSAJE_GENERICO}
    assert mock_sender.cantidad == 1

    token_claro = _token_del_enlace(mock_sender.ultimo())
    assert token_claro

    filas = run(_tokens_en_bd())
    assert len(filas) == 1, "solo debe existir un token activo"
    assert filas[0].token_hash == hashlib.sha256(
        token_claro.encode("utf-8")
    ).hexdigest()
    assert len(filas[0].token_hash) == 64
    assert token_claro not in filas[0].token_hash, "el token en claro no se guarda"
    assert filas[0].used_at is None

    # Duración del token: 30 minutos.
    restante = filas[0].expires_at - filas[0].created_at
    assert timedelta(minutes=29) <= restante <= timedelta(minutes=31)


def test_forgot_correo_inexistente_misma_respuesta(client, sender_en_app, mock_sender):
    r = client.post(URL_FORGOT, json={"email": "nadie@ika.pe"})

    assert r.status_code == 202
    assert r.json() == {"detail": MENSAJE_GENERICO}
    assert mock_sender.cantidad == 0, "no se envía correo a cuentas inexistentes"
    assert run(_tokens_en_bd()) == []


def test_forgot_cuenta_inactiva_misma_respuesta(client, sender_en_app, mock_sender):
    _crear_usuario(is_active=False)

    r = client.post(URL_FORGOT, json={"email": "viajera@ika.pe"})

    assert r.status_code == 202
    assert r.json() == {"detail": MENSAJE_GENERICO}
    assert mock_sender.cantidad == 0
    assert run(_tokens_en_bd()) == [], "una cuenta inactiva no recibe token"


def test_forgot_cuenta_exclusivamente_google(client, sender_en_app, mock_sender):
    _crear_usuario(
        auth_provider=AuthProvider.GOOGLE,
        provider_id="sub-google-1",
        password_hash=None,
    )

    r = client.post(URL_FORGOT, json={"email": "viajera@ika.pe"})

    # Misma respuesta 202 que cualquier otra cuenta (evita enumeración).
    assert r.status_code == 202
    assert r.json() == {"detail": MENSAJE_GENERICO}
    assert run(_tokens_en_bd()) == [], "Google-only no recibe token de reset"

    assert mock_sender.cantidad == 1
    aviso = mock_sender.ultimo()
    assert "Google" in aviso.cuerpo
    assert "token=" not in aviso.cuerpo, "no debe incluir enlace de reset"


def test_respuesta_identica_en_los_cuatro_casos(client, sender_en_app, mock_sender):
    """Existente, inexistente, inactiva y solo-Google: misma respuesta."""
    _crear_usuario(email="local@ika.pe")
    _crear_usuario(email="inactiva@ika.pe", is_active=False)
    _crear_usuario(
        email="google@ika.pe",
        auth_provider=AuthProvider.GOOGLE,
        provider_id="sub-google-2",
        password_hash=None,
    )

    correos = [
        "local@ika.pe",
        "nadie@ika.pe",
        "inactiva@ika.pe",
        "google@ika.pe",
    ]
    respuestas = [
        client.post(URL_FORGOT, json={"email": correo}).json()
        for correo in correos
    ]

    assert len({json.dumps(r, sort_keys=True) for r in respuestas}) == 1, respuestas


# ----------------------------------------------------------------------
# POST /auth/password/reset
# ----------------------------------------------------------------------
def test_reset_con_token_valido_y_login_con_password_nueva(
    client, sender_en_app, mock_sender
):
    _crear_usuario()
    token = _solicitar_token(client, mock_sender)

    r = _reset(client, token)

    assert r.status_code == 200
    assert token not in r.text, "el token no debe aparecer en la respuesta"
    assert set(r.json()) == {"detail"}

    ok = client.post(
        "/api/v1/auth/login",
        json={"email": "viajera@ika.pe", "password": CLAVE_NUEVA},
    )
    assert ok.status_code == 200, "la contraseña nueva debe permitir entrar"


def test_reset_rechaza_la_password_anterior(client, sender_en_app, mock_sender):
    _crear_usuario()
    token = _solicitar_token(client, mock_sender)
    assert _reset(client, token).status_code == 200

    ko = client.post(
        "/api/v1/auth/login",
        json={"email": "viajera@ika.pe", "password": "secreto123"},
    )
    assert ko.status_code == 401, "la contraseña anterior debe dejar de servir"
    assert ko.json()["codigo"] == "credenciales_invalidas"


def test_reset_token_vencido_da_error_generico(client):
    _crear_usuario()
    usuario = _usuario_bd()
    _insertar_token_bd(usuario.id, _hash("token-vencido"), minutos=-5)

    r = _reset(client, "token-vencido")

    assert r.status_code == 400
    assert r.json() == {
        "detail": "El enlace de recuperación no es válido o ha expirado.",
        "codigo": "RESET_TOKEN_INVALIDO",
    }
    assert "token-vencido" not in r.text


def test_reset_token_reutilizado_da_error_generico(client, sender_en_app, mock_sender):
    _crear_usuario()
    token = _solicitar_token(client, mock_sender)

    assert _reset(client, token).status_code == 200

    segundo = _reset(client, token, "OtraClaveSegura7")
    assert segundo.status_code == 400
    assert segundo.json()["codigo"] == "RESET_TOKEN_INVALIDO"

    # La primera contraseña sigue siendo la válida.
    assert (
        client.post(
            "/api/v1/auth/login",
            json={"email": "viajera@ika.pe", "password": CLAVE_NUEVA},
        ).status_code
        == 200
    )
    assert (
        client.post(
            "/api/v1/auth/login",
            json={"email": "viajera@ika.pe", "password": "OtraClaveSegura7"},
        ).status_code
        == 401
    )


def test_reset_token_invalidado_por_nueva_solicitud(
    client, sender_en_app, mock_sender
):
    _crear_usuario()
    viejo = _solicitar_token(client, mock_sender)
    nuevo = _solicitar_token(client, mock_sender)
    assert viejo != nuevo

    rechazado = _reset(client, viejo)
    assert rechazado.status_code == 400
    assert rechazado.json()["codigo"] == "RESET_TOKEN_INVALIDO"

    assert _reset(client, nuevo).status_code == 200, "el token nuevo sí vale"


def test_dos_solicitudes_simultaneas_con_el_mismo_token(
    client, sender_en_app, mock_sender
):
    """Solo una de las dos peticiones concurrentes gana el compare-and-set."""
    _crear_usuario()
    token = _solicitar_token(client, mock_sender)

    async def _intentar(db):
        try:
            await service.restablecer_password(
                db, ResetPasswordRequest(token=token, new_password=CLAVE_NUEVA)
            )
            return "ganado"
        except ResetTokenInvalidoException:
            return "rechazado"

    async def _carrera():
        async with TestingSessionLocal() as izq, TestingSessionLocal() as der:
            return await asyncio.gather(_intentar(izq), _intentar(der))

    resultados = run(_carrera())

    assert resultados.count("ganado") == 1, resultados
    assert resultados.count("rechazado") == 1, resultados


# ----------------------------------------------------------------------
# Invalidación de JWT
# ----------------------------------------------------------------------
def test_jwt_emitido_antes_del_cambio_es_rechazado(client, sender_en_app, mock_sender):
    _crear_usuario()

    login_viejo = client.post(
        "/api/v1/auth/login",
        json={"email": "viajera@ika.pe", "password": "secreto123"},
    )
    assert login_viejo.status_code == 200
    jwt_viejo = login_viejo.json()["access_token"]

    # Se separa en el tiempo para que `iat` caiga en un segundo anterior
    # al del cambio (la comparación es en segundos enteros).
    time.sleep(1.1)

    token = _solicitar_token(client, mock_sender)
    assert _reset(client, token).status_code == 200

    r = client.get(
        "/api/v1/users/me", headers={"Authorization": f"Bearer {jwt_viejo}"}
    )
    assert r.status_code == 401, "el JWT anterior al cambio debe rechazarse"
    assert r.json()["codigo"] == "credenciales_invalidas"


def test_jwt_emitido_despues_del_cambio_funciona(client, sender_en_app, mock_sender):
    _crear_usuario()
    token = _solicitar_token(client, mock_sender)
    assert _reset(client, token).status_code == 200

    login_nuevo = client.post(
        "/api/v1/auth/login",
        json={"email": "viajera@ika.pe", "password": CLAVE_NUEVA},
    )
    assert login_nuevo.status_code == 200
    jwt_nuevo = login_nuevo.json()["access_token"]

    r = client.get(
        "/api/v1/users/me", headers={"Authorization": f"Bearer {jwt_nuevo}"}
    )
    assert r.status_code == 200, "el JWT emitido después del cambio debe valer"
    assert r.json()["email"] == "viajera@ika.pe"


def test_jwt_anterior_no_autentica_ni_personaliza_el_clima(
    client, sender_en_app, mock_sender, monkeypatch
):
    """RF-03: un JWT previo al cambio deja de aportar usuario en /weather.

    Los endpoints de clima siguen siendo públicos: con el JWT viejo la
    respuesta no cambia (200), pero la dependencia ya no devuelve el
    usuario, así que no se personaliza ni se autentica.
    """
    _crear_usuario(preferred_language="en", preferences=["playa"])

    login_viejo = client.post(
        "/api/v1/auth/login",
        json={"email": "viajera@ika.pe", "password": "secreto123"},
    )
    assert login_viejo.status_code == 200
    jwt_viejo = login_viejo.json()["access_token"]

    # `iat` debe caer en un segundo anterior al del cambio (segundos enteros).
    time.sleep(1.1)

    token = _solicitar_token(client, mock_sender)
    assert _reset(client, token).status_code == 200

    # Doblos que capturan la personalización que llega al servicio de clima.
    capturas: dict[str, dict] = {}

    async def _recomendaciones_falsas(db, preferencias_usuario=None):
        capturas["recomendaciones"] = {"preferencias": preferencias_usuario}
        return []

    async def _recomendacion_del_dia_falsa(db, preferencias_usuario=None, idioma="es"):
        capturas["del_dia"] = {
            "preferencias": preferencias_usuario,
            "idioma": idioma,
        }
        return None

    monkeypatch.setattr(
        "src.modules.weather.service.listar_recomendaciones",
        _recomendaciones_falsas,
    )
    monkeypatch.setattr(
        "src.modules.weather.service.recomendacion_del_dia",
        _recomendacion_del_dia_falsa,
    )

    # Con el JWT anterior al cambio: respuesta pública (200) pero anónima.
    r_recs = client.get(
        "/api/v1/weather/recommendations",
        headers={"Authorization": f"Bearer {jwt_viejo}"},
    )
    r_dia = client.get(
        "/api/v1/weather/recommendation-of-the-day",
        headers={"Authorization": f"Bearer {jwt_viejo}"},
    )
    assert r_recs.status_code == 200, "los endpoints de clima siguen siendo públicos"
    assert r_dia.status_code == 200
    assert r_recs.json() == []
    assert r_dia.json() is None
    assert capturas["recomendaciones"]["preferencias"] is None, (
        "el JWT anterior al cambio no debe personalizar"
    )
    assert capturas["del_dia"] == {"preferencias": None, "idioma": "es"}

    # Con un JWT emitido tras el cambio sí se personaliza.
    login_nuevo = client.post(
        "/api/v1/auth/login",
        json={"email": "viajera@ika.pe", "password": CLAVE_NUEVA},
    )
    assert login_nuevo.status_code == 200
    jwt_nuevo = login_nuevo.json()["access_token"]

    client.get(
        "/api/v1/weather/recommendations",
        headers={"Authorization": f"Bearer {jwt_nuevo}"},
    )
    client.get(
        "/api/v1/weather/recommendation-of-the-day",
        headers={"Authorization": f"Bearer {jwt_nuevo}"},
    )
    assert capturas["recomendaciones"]["preferencias"] == ["playa"]
    assert capturas["del_dia"] == {"preferencias": ["playa"], "idioma": "en"}

    # Sin cabecera Authorization el comportamiento anónimo es el mismo.
    capturas.clear()
    client.get("/api/v1/weather/recommendations")
    client.get("/api/v1/weather/recommendation-of-the-day")
    assert capturas["recomendaciones"]["preferencias"] is None
    assert capturas["del_dia"] == {"preferencias": None, "idioma": "es"}


# ----------------------------------------------------------------------
# Rate limit
# ----------------------------------------------------------------------
def test_rate_limit_por_ip(client, sender_en_app, redis_falso):
    maximo = configuracion.PASSWORD_RESET_MAX_POR_IP

    for i in range(maximo):
        r = client.post(URL_FORGOT, json={"email": f"inexistente{i}@ika.pe"})
        assert r.status_code == 202, f"la solicitud {i + 1} debía pasar"

    excedida = client.post(URL_FORGOT, json={"email": "inexistente99@ika.pe"})

    assert excedida.status_code == 429
    assert excedida.json()["codigo"] == "LIMITE_SOLICITUDES_EXCEDIDO"
    # La IP solo se guarda en Redis (con TTL), jamás en PostgreSQL.
    assert any(
        clave.startswith("limite:password_reset_ip:")
        for clave in redis_falso.conteos
    )
    assert all("@ika.pe" not in clave for clave in redis_falso.conteos if "ip:" in clave)


def test_rate_limit_por_correo(client, sender_en_app, mock_sender, redis_falso):
    maximo = configuracion.PASSWORD_RESET_MAX_POR_CORREO

    for i in range(maximo):
        r = client.post(URL_FORGOT, json={"email": "viajera@ika.pe"})
        assert r.status_code == 202, f"la solicitud {i + 1} debía pasar"

    excedida = client.post(URL_FORGOT, json={"email": "viajera@ika.pe"})

    assert excedida.status_code == 429
    assert excedida.json()["codigo"] == "LIMITE_SOLICITUDES_EXCEDIDO"
    assert (
        redis_falso.conteos["limite:password_reset_email:viajera@ika.pe"]
        == maximo + 1
    )


# ======================================================================
# Etapa 4 — Batería completa y revisión final
# ======================================================================
class SenderFalla(EmailSender):
    """Sender cuyo envío siempre falla (simula Gmail caído o sin red)."""

    async def enviar(self, correo: Correo) -> None:
        raise ConnectionError("smtp no disponible")


def test_fallo_de_envio_sigue_respondiendo_202(client, app, mock_sender):
    """Un fallo de SMTP no cambia la respuesta: sigue siendo 202 genérico."""
    _crear_usuario()
    app.dependency_overrides[obtener_email_sender] = lambda: SenderFalla()

    r = client.post(URL_FORGOT, json={"email": "viajera@ika.pe"})

    assert r.status_code == 202
    assert r.json() == {"detail": MENSAJE_GENERICO}


def test_payload_invalido_de_forgot_devuelve_422(client, sender_en_app):
    """Fuera del 202 solo están el rate limit y la petición malformada."""
    assert client.post(URL_FORGOT, json={}).status_code == 422
    assert (
        client.post(URL_FORGOT, json={"email": "no-es-un-correo"}).status_code
        == 422
    )
    assert client.post(URL_FORGOT, content=b"{}", headers={"content-type": "application/json"}).status_code == 422


def test_payload_invalido_de_reset_devuelve_422(client, sender_en_app):
    assert client.post(URL_RESET, json={}).status_code == 422
    assert (
        client.post(URL_RESET, json={"token": "x", "new_password": "corta"})
        .status_code
        == 422
    )


def test_respuesta_de_exito_de_reset(client, sender_en_app, mock_sender):
    _crear_usuario()
    token = _solicitar_token(client, mock_sender)

    r = _reset(client, token)

    assert r.status_code == 200
    assert r.json() == {
        "detail": "Tu contraseña ha sido restablecida correctamente."
    }


def test_reset_actualiza_password_changed_at(client, sender_en_app, mock_sender):
    """Tras el cambio la marca se fija: es lo que invalida los JWT antiguos."""
    _crear_usuario()
    assert _usuario_bd().password_changed_at is None

    token = _solicitar_token(client, mock_sender)
    assert _reset(client, token).status_code == 200

    usuario = _usuario_bd()
    assert usuario.password_changed_at is not None
    assert (
        security.segundos_enteros(usuario.password_changed_at)
        <= int(time.time())
    )


def test_correo_en_espanol_por_preferred_language(client, sender_en_app, mock_sender):
    _crear_usuario(preferred_language="es")

    client.post(URL_FORGOT, json={"email": "viajera@ika.pe"})

    correo = mock_sender.ultimo()
    assert "contraseña" in correo.asunto
    assert "Recibimos una solicitud" in correo.cuerpo


def test_correo_en_ingles_por_preferred_language(client, sender_en_app, mock_sender):
    _crear_usuario(preferred_language="en")

    client.post(URL_FORGOT, json={"email": "viajera@ika.pe"})

    correo = mock_sender.ultimo()
    assert "password" in correo.asunto
    assert "We received a request" in correo.cuerpo
    assert "Recibimos una solicitud" not in correo.cuerpo


def test_idioma_desconocido_usa_espanol_en_el_flujo(
    client, sender_en_app, mock_sender
):
    _crear_usuario(preferred_language="fr")

    client.post(URL_FORGOT, json={"email": "viajera@ika.pe"})

    assert "contraseña" in mock_sender.ultimo().asunto


def test_enlace_del_correo_sale_de_la_plantilla_de_entorno(
    client, sender_en_app, mock_sender
):
    """El enlace completo del correo proviene SOLO de la variable de entorno."""
    _crear_usuario()

    token = _solicitar_token(client, mock_sender)

    enlace_esperado = configuracion.PASSWORD_RESET_URL_TEMPLATE.format(
        token=token
    )
    assert enlace_esperado in mock_sender.ultimo().cuerpo
    # La cabecera Host de la petición no participa en la construcción.
    r = client.post(
        URL_FORGOT,
        json={"email": "viajera@ika.pe"},
        headers={"Host": "atacante.ejemplo"},
    )
    assert r.status_code == 202
    assert configuracion.PASSWORD_RESET_URL_TEMPLATE.format(
        token=_token_del_enlace(mock_sender.ultimo())
    ) in mock_sender.ultimo().cuerpo


def test_logs_del_flujo_no_contienen_token_ni_password(
    client, app, sender_en_app, mock_sender, monkeypatch, caplog
):
    """Ni el token, ni la contraseña, ni el enlace aparecen en logs."""
    monkeypatch.setattr("smtplib.SMTP", SMTPFalso)
    _crear_usuario()

    with caplog.at_level(logging.DEBUG):
        token = _solicitar_token(client, mock_sender)
        assert _reset(client, token).status_code == 200
        # Also the failure path: an invalid token must not be echoed either.
        assert _reset(client, "token-falso-que-no-debe-registrarse").status_code == 400
        # Y el sender real deja su rastro («Correo enviado») con destino
        # enmascarado: la vía de logs sí queda ejercitada.
        run(SMTPEmailSender(_cfg()).enviar(
            Correo("viajera@ika.pe", "Asunto", f"enlace {token}")
        ))

    assert caplog.records, "el test debe ejercitar al menos un registro de log"
    texto = caplog.text
    assert token not in texto, "el token de recuperación apareció en logs"
    assert CLAVE_NUEVA not in texto, "la contraseña nueva apareció en logs"
    assert "secreto123" not in texto, "la contraseña antigua apareció en logs"
    assert "token-falso-que-no-debe-registrarse" not in texto
    assert "ikatravel://" not in texto, "el enlace completo apareció en logs"


def test_logs_no_contienen_credenciales_smtp_durante_el_flujo(
    client, sender_en_app, mock_sender, caplog
):
    """Las credenciales SMTP (si las hay en el entorno) jamás se registran."""
    _crear_usuario()

    with caplog.at_level(logging.DEBUG):
        token = _solicitar_token(client, mock_sender)
        _reset(client, token)

    texto = caplog.text
    if configuracion.SMTP_PASSWORD:
        assert configuracion.SMTP_PASSWORD not in texto
    if configuracion.SMTP_USER:
        assert configuracion.SMTP_USER not in texto


def test_la_ip_no_se_persiste_en_postgresql():
    """La IP solo vive en Redis: ninguna columna de PG la guarda."""
    nombres = {
        columna.name
        for tabla in Base.metadata.tables.values()
        for columna in tabla.columns
    }
    assert not any(
        nombre in {"ip", "client_ip", "ip_address", "remote_addr", "last_ip"}
        for nombre in nombres
    ), f"columnas de IP encontradas en PostgreSQL: {sorted(nombres)}"


def test_migracion_no_modifica_tablas_ajenas():
    """La migración RF-03 solo toca `users` y crea `password_reset_tokens`."""
    sql = _alembic_sql("upgrade", "d4af4f66c370:head")

    assert "CREATE TABLE password_reset_tokens" in sql
    assert "ALTER TABLE users ADD COLUMN password_changed_at" in sql
    # Nada de tablas de otros módulos (en particular, el meteorológico).
    for tabla_ajena in ("weather", "catalog", "emergency", "review", "analytics"):
        assert tabla_ajena not in sql.lower().replace("password_reset", ""), (
            f"la migración RF-03 toca la tabla {tabla_ajena}"
        )
