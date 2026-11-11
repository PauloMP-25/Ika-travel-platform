"""Capa de repositorio del módulo `users`: consultas SQLAlchemy puras.

Aquí solo viven las queries; toda la lógica de negocio está en `service.py`.
"""

from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.users.models import PasswordResetToken, User


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    """Busca un usuario por su email."""
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def get_user_by_id(db: AsyncSession, user_id: UUID) -> User | None:
    """Busca un usuario por su id."""
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def get_user_by_provider_id(db: AsyncSession, provider_id: str) -> User | None:
    """Busca un usuario por el identificador del proveedor social (`sub`)."""
    result = await db.execute(select(User).where(User.provider_id == provider_id))
    return result.scalar_one_or_none()


def add_user(db: AsyncSession, user: User) -> None:
    """Encola un usuario nuevo en la sesión actual."""
    db.add(user)


# ----------------------------------------------------------------------
# Tokens de recuperación (RF-03)
# ----------------------------------------------------------------------
def add_password_reset_token(db: AsyncSession, token: PasswordResetToken) -> None:
    """Encola un token nuevo en la sesión actual (la sesión lo hashea antes)."""
    db.add(token)


async def get_password_reset_token_by_hash(
    db: AsyncSession, token_hash: str
) -> PasswordResetToken | None:
    """Busca un token por su hash SHA-256 (nunca por el valor en claro)."""
    result = await db.execute(
        select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
    )
    return result.scalar_one_or_none()


async def invalidate_active_tokens(db: AsyncSession, user_id: UUID) -> int:
    """Invalida todos los tokens activos del usuario. Devuelve los afectados.

    Se ejecuta como un único `UPDATE` dentro de la misma transacción que
    inserta el token nuevo: una solicitud válida siempre deja **un solo**
    token activo.
    """
    result = await db.execute(
        update(PasswordResetToken)
        .where(
            PasswordResetToken.user_id == user_id,
            PasswordResetToken.used_at.is_(None),
        )
        .values(used_at=datetime.now(timezone.utc))
    )
    return int(result.rowcount or 0)


async def mark_token_used(db: AsyncSession, token_id: UUID) -> bool:
    """Marca el token como usado de forma **atómica**.

    El `UPDATE ... WHERE used_at IS NULL` es un compare-and-set: ante dos
    peticiones simultáneas con el mismo token, solo una obtiene `rowcount == 1`
    y por tanto solo una restablece la contraseña.
    """
    result = await db.execute(
        update(PasswordResetToken)
        .where(
            PasswordResetToken.id == token_id,
            PasswordResetToken.used_at.is_(None),
        )
        .values(used_at=datetime.now(timezone.utc))
    )
    return int(result.rowcount or 0) == 1
