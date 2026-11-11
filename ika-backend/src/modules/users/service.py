"""Lógica de negocio del módulo `users` (registro, login y perfil)."""

import hashlib
import logging
import secrets
from collections.abc import Mapping
from datetime import datetime, timedelta, timezone

from redis.asyncio import Redis
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from src.core import security
from src.core.config import configuracion
from src.core.rate_limit import limit_by_key
from src.modules.users import repository
from src.modules.users.auth_strategies import ESTRATEGIAS_SOCIALES
from src.modules.users.auth_strategies.base import IdentidadSocial
from src.modules.users.email import (
    Correo,
    EmailSender,
    construir_enlace_reset,
    contenido_plantilla,
)
from src.modules.users.exceptions import (
    ConsentimientoRequeridoException,
    EmailSocialNoVerificadoException,
    InactiveUserException,
    InvalidCredentialsException,
    ProveedorSocialNoSoportadoException,
    ResetTokenInvalidoException,
    UserAlreadyExistsException,
)
from src.modules.users.models import AuthProvider, PasswordResetToken, User, UserRole
from src.modules.users.schemas import (
    ForgotPasswordRequest,
    GoogleLoginRequest,
    ResetPasswordRequest,
    TokenResponse,
    TokenSocialResponse,
    UserCreate,
    UserLogin,
    UserUpdate,
)

logger = logging.getLogger(__name__)


async def register_user(db: AsyncSession, data: UserCreate) -> User:
    """Crea una cuenta nueva con contraseña (valida email único)."""
    existing = await repository.get_user_by_email(db, data.email)
    if existing is not None:
        raise UserAlreadyExistsException(data.email)

    user = User(
        email=data.email,
        password_hash=security.hash_password(data.password),
        full_name=data.full_name,
        phone=data.phone,
        preferred_language=data.preferred_language,
        preferences=[p.value if hasattr(p, "value") else str(p) for p in data.preferences],
        role=UserRole.TOURIST,
        auth_provider=AuthProvider.EMAIL,
    )
    repository.add_user(db, user)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise UserAlreadyExistsException(data.email)
    await db.refresh(user)
    return user


async def authenticate_user(
    db: AsyncSession, email: str, password: str
) -> User:
    """Valida credenciales por email/contraseña y devuelve el usuario."""
    user = await repository.get_user_by_email(db, email)
    if user is None:
        raise InvalidCredentialsException()

    if not user.is_active:
        raise InactiveUserException()

    # Cuentas creadas con login social: sin contraseña que comparar. Se
    # responde el mismo 401 genérico para no revelar que la cuenta existe.
    if user.password_hash is None:
        raise InvalidCredentialsException()

    if not security.verify_password(password, user.password_hash):
        raise InvalidCredentialsException()

    return user


async def login_user(db: AsyncSession, data: UserLogin) -> TokenResponse:
    """Orquesta la autenticación y la emisión del token JWT."""
    user = await authenticate_user(db, data.email, data.password)
    token = security.create_access_token(user.id)
    return TokenResponse(
        access_token=token,
        expires_in=security.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


async def update_user_profile(
    db: AsyncSession, user: User, data: UserUpdate
) -> User:
    """Actualiza únicamente los campos enviados (no-`None`)."""
    updates = data.model_dump(exclude_unset=True)
    for field, value in updates.items():
        if value is not None:
            if field == "preferences" and isinstance(value, list):
                value = [p.value if hasattr(p, "value") else str(p) for p in value]
            setattr(user, field, value)

    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


# ----------------------------------------------------------------------
# Autenticación social (Sprint 4, F1)
# ----------------------------------------------------------------------
def _emitir_token_social(user: User, *, es_nuevo_usuario: bool) -> TokenSocialResponse:
    return TokenSocialResponse(
        access_token=security.create_access_token(user.id),
        expires_in=security.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        es_nuevo_usuario=es_nuevo_usuario,
    )


async def _vincular_cuenta_existente(db: AsyncSession, user: User, identidad: IdentidadSocial) -> User:
    """Vincula el proveedor social a una cuenta de email ya registrada.

    Decisión (Sprint 4, F1): `auth_provider` se conserva en `email` para que
    la contraseña siga funcionando; solo se completa `provider_id`. Una tabla
    `social_identities` queda para una futura iteración.
    """
    user.provider_id = identidad.id_proveedor
    db.add(user)
    try:
        await db.commit()
    except IntegrityError as exc:  # carrera con otra petición que vinculó el mismo `sub`
        await db.rollback()
        raise UserAlreadyExistsException(user.email) from exc
    await db.refresh(user)
    return user


async def autenticar_social(
    db: AsyncSession,
    *,
    proveedor: str,
    token: str,
    consentimiento: bool,
    preferred_language: str | None = None,
    estrategias: Mapping[str, object] | None = None,
) -> tuple[User, bool]:
    """Find-or-link-or-create de una identidad social. Devuelve `(usuario, es_nuevo)`.

    - Busca por `provider_id` (`sub`); si existe, ese es el usuario.
    - Si no, busca por email: con email verificado **vincula** la cuenta.
    - Si no existe, crea un turista nuevo (requiere `consentimiento`).
    """
    estrategia = (estrategias if estrategias is not None else ESTRATEGIAS_SOCIALES).get(proveedor)
    if estrategia is None:
        raise ProveedorSocialNoSoportadoException()

    identidad: IdentidadSocial = await estrategia.verificar(token)  # type: ignore[attr-defined]

    usuario = await repository.get_user_by_provider_id(db, identidad.id_proveedor)
    if usuario is not None:
        if not usuario.is_active:
            raise InactiveUserException()
        return usuario, False

    existente = await repository.get_user_by_email(db, identidad.email)
    if existente is not None:
        if not existente.is_active:
            raise InactiveUserException()
        if identidad.email_verificado:
            return await _vincular_cuenta_existente(db, existente, identidad), False
        # Email sin verificar y cuenta existente: no se vincula ni se crea nada.
        raise EmailSocialNoVerificadoException()

    if not consentimiento:
        # RN datos personales (Ley N° 29733): no se crea la cuenta sin consentimiento.
        raise ConsentimientoRequeridoException()

    usuario = User(
        email=identidad.email,
        password_hash=None,  # cuenta social: nunca hay contraseña que comparar
        full_name=identidad.nombre_completo[:120],
        auth_provider=AuthProvider.GOOGLE if proveedor == "google" else AuthProvider.EMAIL,
        provider_id=identidad.id_proveedor,
        role=UserRole.TOURIST,
        preferred_language=preferred_language or "es",
        preferences=[],
    )
    repository.add_user(db, usuario)
    try:
        await db.commit()
    except IntegrityError as exc:  # carrera con otra petición que creó la misma cuenta
        await db.rollback()
        raise UserAlreadyExistsException(identidad.email) from exc
    await db.refresh(usuario)
    return usuario, True


async def login_con_google(
    db: AsyncSession,
    data: GoogleLoginRequest,
    estrategias: Mapping[str, object] | None = None,
) -> TokenSocialResponse:
    """Orquesta el login con Google: verifica el token, aprovisiona y emite el JWT."""
    usuario, es_nuevo = await autenticar_social(
        db,
        proveedor="google",
        token=data.id_token,
        consentimiento=data.acepta_politica_datos,
        preferred_language=data.preferred_language,
        estrategias=estrategias,
    )
    return _emitir_token_social(usuario, es_nuevo_usuario=es_nuevo)


# ----------------------------------------------------------------------
# Recuperación de contraseña (RF-03)
# ----------------------------------------------------------------------
MENSAJE_RECUPERACION_GENERICO = (
    "Si el correo está registrado, recibirás instrucciones para recuperar tu cuenta."
)


def admite_password_local(usuario: User) -> bool:
    """`False` solo para cuentas creadas **exclusivamente** con Google.

    Esas cuentas no tienen contraseña local y este flujo no puede fijarles una.
    """
    return not (
        usuario.auth_provider == AuthProvider.GOOGLE
        and usuario.password_hash is None
    )


async def _enviar_correo(sender: EmailSender, correo: Correo) -> None:
    """Envía el correo sin que un fallo de SMTP cambie la respuesta HTTP.

    Si falla el envío se responde igual (202) para no revelar si la cuenta
    existe. En logs solo va el tipo de error: nunca el cuerpo, el enlace ni
    las credenciales.
    """
    try:
        await sender.enviar(correo)
    except Exception as exc:  # noqa: BLE001 - cualquier fallo de red/SMTP
        logger.error(
            "No se pudo enviar el correo de recuperación (%s)", type(exc).__name__
        )


async def solicitar_recuperacion(
    db: AsyncSession,
    data: ForgotPasswordRequest,
    *,
    sender: EmailSender,
    redis_client: Redis | None = None,
) -> None:
    """RF-03: procesa `POST /auth/password/forgot`.

    Termina **siempre** sin excepción para que el endpoint responda 202 con
    el mismo mensaje exista o no el correo, esté la cuenta inactiva o sea
    creada exclusivamente con Google.
    """
    # Límite por correo: 3 solicitudes cada hora. La clave vive solo en Redis.
    if redis_client is not None:
        await limit_by_key(
            redis_client,
            "password_reset_email",
            data.email.lower(),
            configuracion.PASSWORD_RESET_MAX_POR_CORREO,
            configuracion.PASSWORD_RESET_VENTANA_CORREO_SEGUNDOS,
        )

    usuario = await repository.get_user_by_email(db, data.email)

    if usuario is None or not usuario.is_active:
        # Correo inexistente o cuenta inactiva: sin token, sin correo, mismo 202.
        logger.info("Solicitud de recuperación sin efecto (cuenta no elegible)")
        return

    if not admite_password_local(usuario):
        # Cuenta creada exclusivamente con Google: se avisa para que entre con
        # Google. No se crea token ni se establece contraseña. Mismo 202.
        asunto, cuerpo = contenido_plantilla("google", usuario.preferred_language)
        await _enviar_correo(
            sender, Correo(destino=usuario.email, asunto=asunto, cuerpo=cuerpo)
        )
        return

    token_claro = secrets.token_urlsafe(32)
    ahora = datetime.now(timezone.utc)
    registro = PasswordResetToken(
        user_id=usuario.id,
        token_hash=security.hash_token_reset(token_claro),
        created_at=ahora,
        expires_at=ahora
        + timedelta(minutes=configuracion.PASSWORD_RESET_TOKEN_TTL_MINUTES),
    )

    # Misma transacción: se invalidan los tokens anteriores y se guarda el nuevo.
    await repository.invalidate_active_tokens(db, usuario.id)
    repository.add_password_reset_token(db, registro)
    await db.commit()

    enlace = construir_enlace_reset(token_claro)
    asunto, cuerpo = contenido_plantilla("reset", usuario.preferred_language)
    await _enviar_correo(
        sender,
        Correo(
            destino=usuario.email,
            asunto=asunto,
            cuerpo=cuerpo.format(enlace=enlace),
        ),
    )


async def restablecer_password(
    db: AsyncSession, data: ResetPasswordRequest
) -> None:
    """RF-03: procesa `POST /auth/password/reset`.

    Un token inválido, vencido, usado o invalidado lanza **siempre** el mismo
    error genérico (`RESET_TOKEN_INVALIDO`, HTTP 400) y nunca se devuelve el
    token en la respuesta.
    """
    registro = await repository.get_password_reset_token_by_hash(
        db, security.hash_token_reset(data.token)
    )
    ahora = datetime.now(timezone.utc)

    if registro is None or registro.used_at is not None:
        raise ResetTokenInvalidoException()
    if (
        security.segundos_enteros(registro.expires_at)
        <= security.segundos_enteros(ahora)
    ):
        raise ResetTokenInvalidoException()

    usuario = await repository.get_user_by_id(db, registro.user_id)
    if (
        usuario is None
        or not usuario.is_active
        or not admite_password_local(usuario)
    ):
        raise ResetTokenInvalidoException()

    # Compare-and-set: ante dos peticiones simultáneas con el mismo token,
    # solo una obtiene `rowcount == 1` y restablece la contraseña.
    if not await repository.mark_token_used(db, registro.id):
        raise ResetTokenInvalidoException()

    usuario.password_hash = security.hash_password(data.new_password)
    usuario.password_changed_at = ahora
    db.add(usuario)
    # El cambio deja sin efecto cualquier otro token activo del usuario.
    await repository.invalidate_active_tokens(db, usuario.id)
    await db.commit()
