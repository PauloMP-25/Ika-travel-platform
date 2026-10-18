"""Tests del login con Google (Sprint 4, F1).

La verificación del token de Google se sustituye por dobles: **ningún test
del paquete por defecto llama a Google**. Los que usan un token real llevan
`@pytest.mark.live` y se ejecutan a mano.
"""

from datetime import datetime, timezone
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from src.core import security
from src.modules.users import service
from src.modules.users.auth_strategies import ESTRATEGIAS_SOCIALES
from src.modules.users.auth_strategies.base import IdentidadSocial
from src.modules.users.auth_strategies.google import GoogleAuthStrategy
from src.modules.users.exceptions import (
    ConsentimientoRequeridoException,
    EmailSocialNoVerificadoException,
    InactiveUserException,
    InvalidCredentialsException,
    ProveedorSocialNoSoportadoException,
    TokenSocialInvalidoException,
)
from src.modules.users.models import AuthProvider, User, UserRole
from src.modules.users.schemas import GoogleLoginRequest
from tests.conftest import run

API = "/api/v1"
CLIENT_ID_PRUEBA = ".apps.googleusercontent.com"


# ----------------------------------------------------------------------
# Dobles
# ----------------------------------------------------------------------
class EstrategiaFalsa:
    """Devolución controlable de una identidad social verificada."""

    proveedor = "google"

    def __init__(self, identidad: IdentidadSocial | Exception = None) -> None:
        self.identidad = identidad or IdentidadSocial(
            proveedor="google",
            id_proveedor="sub-123",
            email="viajera@ika.pe",
            email_verificado=True,
            nombre_completo="Viajera Ica",
        )

    async def verificar(self, token: str) -> IdentidadSocial:
        if isinstance(self.identidad, Exception):
            raise self.identidad
        return self.identidad


def _usuario(**overrides) -> User:
    ahora = datetime.now(timezone.utc)
    campos = dict(
        id=uuid4(),
        email="viajera@ika.pe",
        password_hash=None,
        full_name="Viajera Ica",
        auth_provider=AuthProvider.GOOGLE,
        provider_id="sub-123",
        role=UserRole.TOURIST,
        preferred_language="es",
        preferences=[],
        is_active=True,
        created_at=ahora,
        updated_at=ahora,
    )
    campos.update(overrides)
    return User(**campos)


class FakeSession:
    """Doble de `AsyncSession` que solo registra las operaciones."""

    def __init__(self) -> None:
        self.added: list[object] = []
        self.commits = 0

    def add(self, obj: object) -> None:
        self.added.append(obj)

    async def commit(self) -> None:
        self.commits += 1

    async def rollback(self) -> None:
        return None

    async def refresh(self, obj: object) -> None:
        # Imita a la BD: el `id` se asigna al persistir.
        if getattr(obj, "id", None) is None:
            obj.id = uuid4()


def _con_repositorio(monkeypatch, *, por_provider_id=None, por_email=None) -> FakeSession:
    """Sustituye las búsquedas del repositorio y devuelve la sesión falsa."""

    async def _por_provider(db, provider_id):
        return por_provider_id

    async def _por_email(db, email):
        return por_email

    monkeypatch.setattr(service.repository, "get_user_by_provider_id", _por_provider)
    monkeypatch.setattr(service.repository, "get_user_by_email", _por_email)
    return FakeSession()


def _login(db, estrategia, **campos) -> service.TokenSocialResponse:
    return run(service.autenticar_social(
        db,
        proveedor="google",
        token="token-de-google-suficientemente-largo",
        estrategias={"google": estrategia},
        **campos,
    ))


# ----------------------------------------------------------------------
# Flujo find-or-link-or-create
# ----------------------------------------------------------------------
def test_usuario_nuevo_con_consentimiento_crea_turista(monkeypatch) -> None:
    db = _con_repositorio(monkeypatch)

    usuario, es_nuevo = _login(db, EstrategiaFalsa(), consentimiento=True)

    assert es_nuevo is True
    assert usuario.role == UserRole.TOURIST
    assert usuario.auth_provider == AuthProvider.GOOGLE
    assert usuario.password_hash is None
    assert usuario.preferred_language == "es"
    assert usuario.preferences == []
    assert usuario.provider_id == "sub-123"
    assert db.commits == 1


def test_usuario_nuevo_sin_consentimiento_no_crea_fila(monkeypatch) -> None:
    """RN datos personales: sin `acepta_politica_datos` no se aprovisiona."""
    db = _con_repositorio(monkeypatch)

    with pytest.raises(ConsentimientoRequeridoException) as exc:
        _login(db, EstrategiaFalsa(), consentimiento=False)

    assert exc.value.status_code == 428
    assert exc.value.codigo == "CONSENTIMIENTO_REQUERIDO"
    assert db.added == []
    assert db.commits == 0


def test_usuario_ya_vinculado_no_se_duplica(monkeypatch) -> None:
    existente = _usuario()
    db = _con_repositorio(monkeypatch, por_provider_id=existente)

    usuario, es_nuevo = _login(db, EstrategiaFalsa(), consentimiento=False)

    assert es_nuevo is False
    assert usuario.id == existente.id
    assert db.added == []


def test_email_existente_se_vincula_sin_crear_otro_usuario(monkeypatch) -> None:
    """Email registrado con contraseña: se completa `provider_id` y nada más."""
    existente = _usuario(
        provider_id=None,
        auth_provider=AuthProvider.EMAIL,
        password_hash="hash-previo",
    )
    db = _con_repositorio(monkeypatch, por_email=existente)

    usuario, es_nuevo = _login(db, EstrategiaFalsa(), consentimiento=False)

    assert es_nuevo is False
    assert usuario.provider_id == "sub-123"
    assert usuario.auth_provider == AuthProvider.EMAIL  # la contraseña sigue funcionando
    assert usuario.password_hash == "hash-previo"
    assert db.commits == 1


def test_token_invalido_da_401(monkeypatch) -> None:
    db = _con_repositorio(monkeypatch)

    with pytest.raises(TokenSocialInvalidoException) as exc:
        _login(db, EstrategiaFalsa(TokenSocialInvalidoException()), consentimiento=True)

    assert exc.value.status_code == 401
    assert exc.value.codigo == "TOKEN_SOCIAL_INVALIDO"


def test_email_no_verificado_da_403(monkeypatch) -> None:
    db = _con_repositorio(monkeypatch)

    with pytest.raises(EmailSocialNoVerificadoException) as exc:
        _login(db, EstrategiaFalsa(EmailSocialNoVerificadoException()), consentimiento=True)

    assert exc.value.status_code == 403
    assert exc.value.codigo == "EMAIL_NO_VERIFICADO"


def test_cuenta_inactiva_da_403(monkeypatch) -> None:
    db = _con_repositorio(monkeypatch, por_provider_id=_usuario(is_active=False))

    with pytest.raises(InactiveUserException) as exc:
        _login(db, EstrategiaFalsa(), consentimiento=True)

    assert exc.value.status_code == 403


def test_proveedor_no_soportado_da_400(monkeypatch) -> None:
    db = _con_repositorio(monkeypatch)

    with pytest.raises(ProveedorSocialNoSoportadoException) as exc:
        run(service.autenticar_social(
            db,
            proveedor="facebook",
            token="token-suficientemente-largo",
            consentimiento=True,
        ))

    assert exc.value.status_code == 400
    assert exc.value.codigo == "PROVEEDOR_NO_SOPORTADO"


def test_login_con_google_emite_jwt_valido(monkeypatch) -> None:
    db = _con_repositorio(monkeypatch)
    respuesta = run(service.login_con_google(
        db,
        GoogleLoginRequest(id_token="token-de-google-suficientemente-largo", acepta_politica_datos=True),
        estrategias={"google": EstrategiaFalsa()},
    ))

    assert respuesta.es_nuevo_usuario is True
    assert security.decode_access_token(respuesta.access_token)


# ----------------------------------------------------------------------
# Endurecimiento del login por email/contraseña
# ----------------------------------------------------------------------
def test_cuenta_social_no_puede_entrar_con_password(monkeypatch) -> None:
    """Mismo 401 genérico: no se revela que la cuenta existe (es social)."""
    db = FakeSession()
    social = _usuario(password_hash=None)

    async def _por_email(_db, _email):
        return social

    monkeypatch.setattr(service.repository, "get_user_by_email", _por_email)

    with pytest.raises(InvalidCredentialsException) as exc:
        run(service.authenticate_user(db, "viajera@ika.pe", "cualquier-clave"))

    assert exc.value.status_code == 401
    assert exc.value.detail == InvalidCredentialsException.default_detail


# ----------------------------------------------------------------------
# GoogleAuthStrategy (verificación real del token, con claims simulados)
# ----------------------------------------------------------------------
def _claims(**overrides) -> dict:
    base = {
        "iss": "accounts.google.com",
        "aud": CLIENT_ID_PRUEBA,
        "sub": "sub-123",
        "email": "Viajera@Ika.pe",
        "email_verified": True,
        "name": "Viajera Ica",
    }
    base.update(overrides)
    return base


@pytest.mark.anyio
async def test_estrategia_google_devuelve_identidad_normalizada(monkeypatch) -> None:
    estrategia = GoogleAuthStrategy([CLIENT_ID_PRUEBA])
    monkeypatch.setattr(GoogleAuthStrategy, "_verificar_sync", staticmethod(lambda t: _claims()))

    identidad = await estrategia.verificar("token-de-google-suficientemente-largo")

    assert identidad.id_proveedor == "sub-123"
    assert identidad.email == "viajera@ika.pe"  # minúsculas
    assert identidad.email_verificado is True


@pytest.mark.anyio
async def test_estrategia_google_rechaza_firma_invalida(monkeypatch) -> None:
    def _romper(token: str) -> dict:
        raise ValueError("Token signature not verified.")

    estrategia = GoogleAuthStrategy([CLIENT_ID_PRUEBA])
    monkeypatch.setattr(GoogleAuthStrategy, "_verificar_sync", staticmethod(_romper))

    with pytest.raises(TokenSocialInvalidoException):
        await estrategia.verificar("token-de-google-suficientemente-largo")


@pytest.mark.anyio
@pytest.mark.parametrize("claims", [
    _claims(aud="otro-client-id.apps.googleusercontent.com"),  # aud no permitido
    _claims(iss="https://cuenta-mala.example.com"),            # emisor inválido
    _claims(email_verified=False),                             # email sin verificar
    _claims(email=None),                                       # sin email
])
async def test_estrategia_google_rechaza_claims_invalidos(monkeypatch, claims: dict) -> None:
    estrategia = GoogleAuthStrategy([CLIENT_ID_PRUEBA])
    monkeypatch.setattr(GoogleAuthStrategy, "_verificar_sync", staticmethod(lambda t: claims))

    with pytest.raises((TokenSocialInvalidoException, EmailSocialNoVerificadoException)):
        await estrategia.verificar("token-de-google-suficientemente-largo")


# ----------------------------------------------------------------------
# End-to-end (app real + BD de tests), con la estrategia sustituida
# ----------------------------------------------------------------------
def _instalar_estrategia_falsa(monkeypatch) -> None:
    reemplazo = dict(ESTRATEGIAS_SOCIALES)
    reemplazo["google"] = EstrategiaFalsa()
    monkeypatch.setattr(service, "ESTRATEGIAS_SOCIALES", reemplazo)


def test_endpoint_login_google_crea_cuenta_y_devuelve_jwt(client, monkeypatch) -> None:
    _instalar_estrategia_falsa(monkeypatch)

    respuesta = client.post(
        f"{API}/auth/login/google",
        json={"id_token": "token-de-google-suficientemente-largo", "acepta_politica_datos": True},
    )

    assert respuesta.status_code == 200
    cuerpo = respuesta.json()
    assert cuerpo["es_nuevo_usuario"] is True

    perfil = client.get(
        f"{API}/users/me", headers={"Authorization": f"Bearer {cuerpo['access_token']}"}
    )
    assert perfil.status_code == 200
    assert perfil.json()["email"] == "viajera@ika.pe"


def test_endpoint_login_google_segunda_vez_no_duplica(client, monkeypatch) -> None:
    _instalar_estrategia_falsa(monkeypatch)
    payload = {"id_token": "token-de-google-suficientemente-largo", "acepta_politica_datos": True}

    primera = client.post(f"{API}/auth/login/google", json=payload)
    segunda = client.post(f"{API}/auth/login/google", json=payload)

    assert primera.status_code == segunda.status_code == 200
    assert segunda.json()["es_nuevo_usuario"] is False


def test_endpoint_login_google_sin_consentimiento_da_428(client, monkeypatch) -> None:
    _instalar_estrategia_falsa(monkeypatch)

    respuesta = client.post(
        f"{API}/auth/login/google",
        json={"id_token": "token-de-google-suficientemente-largo"},
    )

    assert respuesta.status_code == 428
    assert respuesta.json()["codigo"] == "CONSENTIMIENTO_REQUERIDO"


def test_endpoint_alias_login_social_delega_en_el_mismo_servicio(client, monkeypatch) -> None:
    _instalar_estrategia_falsa(monkeypatch)

    respuesta = client.post(
        f"{API}/auth/login/social",
        json={
            "provider": "google",
            "id_token": "token-de-google-suficientemente-largo",
            "acepta_politica_datos": True,
        },
    )

    assert respuesta.status_code == 200
    assert respuesta.json()["es_nuevo_usuario"] is True


def test_endpoint_login_google_token_invalido_da_401(client, monkeypatch) -> None:
    reemplazo = dict(ESTRATEGIAS_SOCIALES)
    reemplazo["google"] = EstrategiaFalsa(TokenSocialInvalidoException())
    monkeypatch.setattr(service, "ESTRATEGIAS_SOCIALES", reemplazo)

    respuesta = client.post(
        f"{API}/auth/login/google",
        json={"id_token": "token-de-google-suficientemente-largo", "acepta_politica_datos": True},
    )

    assert respuesta.status_code == 401
    assert respuesta.json()["codigo"] == "TOKEN_SOCIAL_INVALIDO"


@pytest.mark.live
@pytest.mark.anyio
async def test_token_real_de_google_es_validado(monkeypatch) -> None:
    """Prueba manual: requiere `GOOGLE_CLIENT_IDS` y un id_token real en el entorno."""
    import os

    token_real = os.getenv("GOOGLE_ID_TOKEN_PRUEBA")
    ids = [i for i in os.getenv("GOOGLE_CLIENT_IDS", "").split(",") if i]
    if not token_real or not ids:
        pytest.skip("Sin GOOGLE_ID_TOKEN_PRUEBA ni GOOGLE_CLIENT_IDS en el entorno")
    monkeypatch.setattr(service, "ESTRATEGIAS_SOCIALES", {"google": GoogleAuthStrategy(ids)})

    async def _por_provider(db, provider_id):
        return None

    async def _por_email(db, email):
        return None

    monkeypatch.setattr(service.repository, "get_user_by_provider_id", _por_provider)
    monkeypatch.setattr(service.repository, "get_user_by_email", _por_email)

    usuario, es_nuevo = await service.autenticar_social(
        FakeSession(),
        proveedor="google",
        token=token_real,
        consentimiento=True,
        estrategias={"google": GoogleAuthStrategy(ids)},
    )
    assert es_nuevo is True
    assert usuario.email
