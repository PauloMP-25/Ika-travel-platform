"""Endpoints del módulo `users` (Auth).

Solo recibe la petición, delega en `service` y devuelve la respuesta:
toda la lógica de negocio vive en `service.py`.
"""

from fastapi import APIRouter, status

from src.core.dependencies import CurrentUser, DbSession
from src.modules.users import service
from src.modules.users.schemas import (
    TokenResponse,
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
def register(data: UserCreate, db: DbSession) -> UserResponse:
    """Registra una cuenta nueva y devuelve el perfil creado."""
    user = service.register_user(db, data)
    return UserResponse.model_validate(user)


@users_router.post(
    "/auth/login",
    response_model=TokenResponse,
    tags=["auth"],
)
def login(data: UserLogin, db: DbSession) -> TokenResponse:
    """Autentica con email/contraseña y emite un JWT."""
    return service.login_user(db, data)


@users_router.get("/users/me", response_model=UserResponse, tags=["users"])
def read_current_user(current_user: CurrentUser) -> UserResponse:
    """Devuelve el perfil del usuario autenticado (alimenta la pantalla Más)."""
    return UserResponse.model_validate(current_user)


@users_router.put("/users/me", response_model=UserResponse, tags=["users"])
def update_current_user(
    data: UserUpdate,
    current_user: CurrentUser,
    db: DbSession,
) -> UserResponse:
    """Actualiza el perfil del usuario autenticado."""
    user = service.update_user_profile(db, current_user, data)
    return UserResponse.model_validate(user)


# TODO(Dev 1 - fuera del sprint): POST /auth/login/social (login con
# Google/Facebook, ver `service.authenticate_oauth`).
