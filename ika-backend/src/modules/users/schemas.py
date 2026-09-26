"""Esquemas Pydantic del módulo `users`.

Nunca se expone `password_hash` en un esquema de respuesta.
"""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    """Payload de registro (`POST /auth/register`)."""

    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    full_name: str = Field(min_length=1, max_length=120)


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
    created_at: datetime


class UserUpdate(BaseModel):
    """Actualización parcial del perfil (`PUT /users/me`)."""

    full_name: str | None = Field(default=None, min_length=1, max_length=120)
    phone: str | None = Field(default=None, max_length=32)


class TokenResponse(BaseModel):
    """Payload de respuesta tras autenticarse."""

    access_token: str
    token_type: str = "bearer"
    expires_in: int
