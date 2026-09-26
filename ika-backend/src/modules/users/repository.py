"""Capa de repositorio del módulo `users`: consultas SQLAlchemy puras.

Aquí solo viven las queries; toda la lógica de negocio está en `service.py`.
"""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.modules.users.models import User


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    """Busca un usuario por su email."""
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def get_user_by_id(db: AsyncSession, user_id: UUID) -> User | None:
    """Busca un usuario por su id."""
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


def add_user(db: AsyncSession, user: User) -> None:
    """Encola un usuario nuevo en la sesión actual."""
    db.add(user)
