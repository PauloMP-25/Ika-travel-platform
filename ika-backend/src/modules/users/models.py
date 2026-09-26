"""Modelo SQLAlchemy del módulo `users`."""

import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, Enum, String, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.database import Base


class AuthProvider(str, enum.Enum):
    """Proveedor con el que se autenticó el usuario."""

    EMAIL = "email"
    GOOGLE = "google"
    FACEBOOK = "facebook"


def _enum_values(enum_cls: enum.EnumMeta) -> list[str]:
    """Guarda en BD el valor (`'email'`) y no el nombre del miembro."""
    return [member.value for member in enum_cls]


class User(Base):
    """Cuenta de usuario de la plataforma."""

    __tablename__ = "users"

    # `email` es único vía `unique=True` (genera el índice `ix_users_email`),
    # que es además la última línea de defensa contra registros duplicados.

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    email: Mapped[str] = mapped_column(
        String(255), unique=True, index=True, nullable=False
    )
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(32), nullable=True)
    auth_provider: Mapped[AuthProvider] = mapped_column(
        Enum(AuthProvider, name="auth_provider", values_callable=_enum_values),
        nullable=False,
        default=AuthProvider.EMAIL,
    )
    provider_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="true"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # TODO(Dev 1): añadir las relationships `reviews` y `favorites` cuando
    # exista el modelo `reviews`. Definirlas ahora rompería el mapper de
    # SQLAlchemy porque `Review`/`Favorite` todavía no están registradas.
    sos_reports: Mapped[list["SOSReport"]] = relationship(
        "SOSReport", back_populates="user"
    )
