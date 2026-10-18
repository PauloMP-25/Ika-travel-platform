"""Esquemas Pydantic del módulo `users`.

Nunca se expone `password_hash` en un esquema de respuesta.
"""

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from src.modules.users.models import CategoriaTuristicaIca, UserRole


class UserCreate(BaseModel):
    """Payload de registro (`POST /auth/register`)."""

    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    full_name: str = Field(min_length=1, max_length=120)
    phone: str | None = Field(default=None, max_length=32)
    preferred_language: str = Field(default="es", max_length=5, pattern=r"^(es|en)$")
    preferences: list[CategoriaTuristicaIca] = Field(default_factory=list)


class UserLogin(BaseModel):
    """Payload de login (`POST /auth/login`)."""

    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserResponse(BaseModel):
    """Perfil público de usuario. Jamás incluye `password_hash`."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    email: EmailStr
    full_name: str
    phone: str | None = None
    role: UserRole = UserRole.TOURIST
    preferred_language: str = "es"
    preferences: list[str] = Field(default_factory=list)
    created_at: datetime


class UserUpdate(BaseModel):
    """Actualización parcial del perfil (`PUT /users/me`)."""

    full_name: str | None = Field(default=None, min_length=1, max_length=120)
    phone: str | None = Field(default=None, max_length=32)
    preferred_language: str | None = Field(default=None, max_length=5, pattern=r"^(es|en)$")
    preferences: list[CategoriaTuristicaIca] | None = None


class TokenResponse(BaseModel):
    """Payload de respuesta tras autenticarse."""

    access_token: str
    token_type: str = "bearer"
    expires_in: int


class GoogleLoginRequest(BaseModel):
    """Payload del login con Google (`POST /auth/login/google`).

    `acepta_politica_datos` es obligatorio la primera vez que se crea la
    cuenta (RN de datos personales, Ley N° 29733).
    """

    id_token: str = Field(min_length=20, max_length=4096)
    preferred_language: Literal["es", "en"] | None = None
    acepta_politica_datos: bool = False


class SocialLoginRequest(GoogleLoginRequest):
    """Alias genérico `POST /auth/login/social` (hoy solo `google`)."""

    provider: Literal["google"] = "google"


class TokenSocialResponse(TokenResponse):
    """JWT emitido tras un login social; `es_nuevo_usuario` indica alta nueva."""

    es_nuevo_usuario: bool = False
