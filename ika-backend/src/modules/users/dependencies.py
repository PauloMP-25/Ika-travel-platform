"""Dependencias de autenticación y autorización del módulo `users`."""

from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.database import obtener_bd
from src.core.security import decode_access_token
from src.modules.users.exceptions import InvalidCredentialsException
from src.modules.users.models import User, UserRole

# Requiere que `users_router` se monte con `prefix="/api/v1"` en main.py.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(
    db: Annotated[AsyncSession, Depends(obtener_bd)],
    token: Annotated[str, Depends(oauth2_scheme)],
) -> User:
    """Resuelve el usuario a partir del JWT de la cabecera `Authorization`.

    Lanza 401 si el token es inválido, el usuario no existe o está
    desactivado.
    """
    user_id: UUID = decode_access_token(token)
    user = await db.get(User, user_id)
    if user is None or not user.is_active:
        raise InvalidCredentialsException("Usuario no encontrado o desactivado")
    return user


async def require_dircetur_admin(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    """Verifica que el usuario autenticado tenga rol de administrador DIRCETUR."""
    if current_user.role != UserRole.DIRCETUR_ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Operación restringida al personal autorizado de DIRCETUR Ica.",
        )
    return current_user


CurrentUser = Annotated[User, Depends(get_current_user)]
CurrentDirceturAdmin = Annotated[User, Depends(require_dircetur_admin)]
DbSession = Annotated[AsyncSession, Depends(obtener_bd)]
