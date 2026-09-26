"""Dependencias compartidas de inyección (BD y usuario autenticado).

`get_current_user` es la dependencia que usarán TODOS los módulos protegidos
(SOS, Reviews, Favoritos).
"""

from typing import Annotated, Iterator
from uuid import UUID

from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from src.config import settings
from src.core.security import decode_access_token
from src.database import SessionLocal
from src.modules.users.exceptions import InvalidCredentialsException
from src.modules.users.models import User

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl=f"{settings.API_V1_PREFIX}/auth/login"
)


def get_db() -> Iterator[Session]:
    """Provee una sesión de SQLAlchemy por petición y la cierra al final."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(
    db: Annotated[Session, Depends(get_db)],
    token: Annotated[str, Depends(oauth2_scheme)],
) -> User:
    """Resuelve el usuario a partir del JWT de la cabecera `Authorization`.

    Lanza 401 si el token es inválido, el usuario no existe o está
    desactivado.
    """
    user_id: UUID = decode_access_token(token)
    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise InvalidCredentialsException("Usuario no encontrado o desactivado")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
DbSession = Annotated[Session, Depends(get_db)]
