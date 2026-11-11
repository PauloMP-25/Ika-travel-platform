"""Endpoints del módulo `users` (Auth).

Solo recibe la petición, delega en `service` y devuelve la respuesta:
toda la lógica de negocio vive en `service.py`.
"""

from fastapi import APIRouter, Depends, status
from redis.asyncio import Redis

from src.modules.users import service
from src.modules.users.dependencies import (
    CurrentUser,
    DbSession,
    limit_password_reset_ip,
)
from src.modules.users.email import EmailSender, obtener_email_sender
from src.modules.users.schemas import (
    ForgotPasswordRequest,
    GoogleLoginRequest,
    ResetPasswordRequest,
    SocialLoginRequest,
    TokenResponse,
    TokenSocialResponse,
    UserCreate,
    UserLogin,
    UserResponse,
    UserUpdate,
)
from src.redis_client import obtener_cliente_redis

users_router = APIRouter()


@users_router.post(
    "/auth/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["auth"],
)
async def register(data: UserCreate, db: DbSession) -> UserResponse:
    """Registra una cuenta nueva y devuelve el perfil creado."""
    user = await service.register_user(db, data)
    return UserResponse.model_validate(user)


@users_router.post(
    "/auth/login",
    response_model=TokenResponse,
    tags=["auth"],
)
async def login(data: UserLogin, db: DbSession) -> TokenResponse:
    """Autentica con email/contraseña y emite un JWT."""
    return await service.login_user(db, data)


@users_router.post(
    "/auth/password/forgot",
    status_code=status.HTTP_202_ACCEPTED,
    tags=["auth"],
    # RF-03: 5 solicitudes por IP cada 15 minutos (la IP solo vive en Redis).
    dependencies=[Depends(limit_password_reset_ip)],
)
async def forgot_password(
    data: ForgotPasswordRequest,
    db: DbSession,
    sender: EmailSender = Depends(obtener_email_sender),
    redis_client: Redis = Depends(obtener_cliente_redis),
) -> dict[str, str]:
    """Solicita el enlace de recuperación (RF-03).

    Devuelve **siempre 202** con el mismo mensaje exista o no el correo, esté
    la cuenta inactiva o sea creada exclusivamente con Google: la respuesta
    no permite enumerar usuarios.
    """
    await service.solicitar_recuperacion(
        db, data, sender=sender, redis_client=redis_client
    )
    return {"detail": service.MENSAJE_RECUPERACION_GENERICO}


@users_router.post(
    "/auth/password/reset",
    tags=["auth"],
)
async def reset_password(data: ResetPasswordRequest, db: DbSession) -> dict[str, str]:
    """Establece la contraseña nueva con el token del enlace (RF-03).

    Un token inválido, vencido, usado o invalidado responde 400 con
    `RESET_TOKEN_INVALIDO`. El token nunca aparece en la respuesta.
    """
    await service.restablecer_password(db, data)
    return {"detail": "Tu contraseña ha sido restablecida correctamente."}


@users_router.get("/users/me", response_model=UserResponse, tags=["users"])
async def read_current_user(current_user: CurrentUser) -> UserResponse:
    """Devuelve el perfil del usuario autenticado (alimenta la pantalla Más)."""
    return UserResponse.model_validate(current_user)


@users_router.put("/users/me", response_model=UserResponse, tags=["users"])
async def update_current_user(
    data: UserUpdate,
    current_user: CurrentUser,
    db: DbSession,
) -> UserResponse:
    """Actualiza el perfil del usuario autenticado."""
    user = await service.update_user_profile(db, current_user, data)
    return UserResponse.model_validate(user)


@users_router.post(
    "/auth/login/google",
    response_model=TokenSocialResponse,
    tags=["auth"],
)
async def login_google(data: GoogleLoginRequest, db: DbSession) -> TokenSocialResponse:
    """Login con Google (Sprint 4, F1).

    Verifica el `id_token`, aprovisiona o vincula la cuenta de turista y
    emite el JWT. `es_nuevo_usuario` indica si se creó la cuenta en esta
    petición (el cliente puede mostrar el onboarding).
    """
    return await service.login_con_google(db, data)


@users_router.post(
    "/auth/login/social",
    response_model=TokenSocialResponse,
    tags=["auth"],
)
async def login_social(data: SocialLoginRequest, db: DbSession) -> TokenSocialResponse:
    """Alias genérico del login social (hoy solo `google`); delega en el mismo servicio."""
    return await service.login_con_google(db, data)
