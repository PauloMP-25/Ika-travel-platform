"""Modelo SQLAlchemy del módulo `users`."""

import enum
from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    JSON,
    String,
    UniqueConstraint,
    Uuid,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from src.core.database import Base


class AuthProvider(str, enum.Enum):
    """Proveedor con el que se autenticó el usuario."""

    EMAIL = "email"
    GOOGLE = "google"
    FACEBOOK = "facebook"


class UserRole(str, enum.Enum):
    """Rol de usuario en la plataforma."""

    TOURIST = "tourist"
    DIRCETUR_ADMIN = "dircetur_admin"


class CategoriaTuristicaIca(str, enum.Enum):
    """Categorías oficiales de actividades y preferencias turísticas en Ica.
    
    Alineadas al PERTUR Ica y PROMPERÚ ("Y tú qué planes"):
    - AVENTURA_DESIERTO: Sandboarding, tubulares (buggies), expediciones en dunas y Cañón de los Perdidos.
    - ENOTURISMO_GASTRONOMIA: Ruta del pisco y vino, catas en bodegas vitivinícolas y gastronomía tradicional.
    - CULTURA_MISTICA: Pueblo místico de Cachiche, Santuario de Luren, Museo Regional y patrimonio histórico.
    - NATURALEZA_MARINA: Excursiones a Islas Ballestas, fauna marina y Reserva Nacional de Paracas.
    - ARQUEOLOGIA_ENIGMAS: Líneas de Nasca y Palpa, geoglifos, Cahuachi y acueductos milenarios.
    """

    AVENTURA_DESIERTO = "aventura_desierto"
    ENOTURISMO_GASTRONOMIA = "enoturismo_gastronomia"
    CULTURA_MISTICA = "cultura_mistica"
    NATURALEZA_MARINA = "naturaleza_marina"
    ARQUEOLOGIA_ENIGMAS = "arqueologia_enigmas"


def _enum_values(enum_cls: enum.EnumMeta) -> list[str]:
    """Guarda en BD el valor (`'email'`) y no el nombre del miembro."""
    return [member.value for member in enum_cls]


class User(Base):
    """Cuenta de usuario de la plataforma."""

    __tablename__ = "users"
    __table_args__ = (
        # Sprint 4: el `sub` del proveedor social es único entre los usuarios
        # que tienen uno (índice parcial: los usuarios por email no chocan).
        Index(
            "uq_users_provider_id",
            "provider_id",
            unique=True,
            postgresql_where=text("provider_id IS NOT NULL"),
        ),
    )

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
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole, name="user_role", values_callable=_enum_values),
        nullable=False,
        default=UserRole.TOURIST,
        server_default="tourist",
    )
    preferred_language: Mapped[str] = mapped_column(
        String(5), nullable=False, default="es", server_default="es"
    )
    preferences: Mapped[list[str]] = mapped_column(
        JSON, nullable=False, default=list, server_default="[]"
    )
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
    # RF-03: cualquier JWT con `iat` anterior a esta marca se rechaza.
    password_changed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    sos_reports: Mapped[list["SOSReport"]] = relationship(
        "SOSReport", back_populates="user"
    )


class PasswordResetToken(Base):
    """Token de recuperación de contraseña (RF-03).

    En PostgreSQL **solo** se guarda el hash SHA-256 (`token_hash`) del token:
    nunca el valor en claro. Un usuario puede tener varios tokens históricos,
    pero solo el más reciente queda activo (los anteriores se invalidan al
    emitir uno nuevo).
    """

    __tablename__ = "password_reset_tokens"
    __table_args__ = (
        UniqueConstraint(
            "token_hash", name="uq_password_reset_tokens_token_hash"
        ),
        Index("ix_password_reset_tokens_user_id", "user_id"),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    # SHA-256 en hexadecimal: exactamente 64 caracteres, único y no nulo.
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    # Se marca al usarse **y** al invalidarse por una solicitud posterior.
    used_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
