"""Endpoints del módulo `users` (Auth).

Solo recibe la petición, delega en `service` y devuelve la respuesta:
toda la lógica de negocio vive en `service.py`.
"""

from fastapi import APIRouter, status

from src.modules.users import service
from src.modules.users.dependencies import CurrentUser, DbSession
from src.modules.users.schemas import (
    GoogleLoginRequest,
    SocialLoginRequest,
    TokenResponse,
    TokenSocialResponse,
    UserCreate,
    UserLogin,
    UserResponse,
    UserUpdate,
)

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
