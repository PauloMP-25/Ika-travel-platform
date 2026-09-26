"""Dependencias de autenticación del módulo `users`.

`get_current_user` es la dependencia que usarán TODOS los módulos
protegidos (SOS, Reviews, Favoritos) — ver `users/README.md`.
"""

from typing import Annotated
from uuid import UUID

from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.database import get_db
from src.core.security import decode_access_token
from src.modules.users.exceptions import InvalidCredentialsException
from src.modules.users.models import User

# Requiere que `users_router` se monte con `prefix="/api/v1"` en main.py.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_current_user(
    db: Annotated[AsyncSession, Depends(get_db)],
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


CurrentUser = Annotated[User, Depends(get_current_user)]
DbSession = Annotated[AsyncSession, Depends(get_db)]
