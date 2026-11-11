"""Dependencias de autenticación y autorización del módulo `users`."""

from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession

from src.core.database import obtener_bd
from src.core.rate_limit import limit_requests
from src.core.config import configuracion
from src.core.security import decode_access_token_payload, segundos_enteros
from src.modules.users.exceptions import InvalidCredentialsException
from src.modules.users.models import User, UserRole

# Requiere que `users_router` se monte con `prefix="/api/v1"` en main.py.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def jwt_valido_para_el_usuario(payload: dict[str, object], user: User) -> bool:
    """RF-03: un JWT solo es válido si su `iat` no es anterior al cambio.

    Tras restablecer la contraseña se fija `users.password_changed_at` y
    **todos** los JWT emitidos antes quedan rechazados. La comparación se
    hace en **segundos enteros** para no rechazar los tokens emitidos
    inmediatamente después del cambio.
    """
    if user.password_changed_at is None:
        return True
    iat = payload.get("iat")
    if iat is None:
        return False
    return int(iat) >= segundos_enteros(user.password_changed_at)


async def get_current_user(
    db: Annotated[AsyncSession, Depends(obtener_bd)],
    token: Annotated[str, Depends(oauth2_scheme)],
) -> User:
    """Resuelve el usuario a partir del JWT de la cabecera `Authorization`.

    Lanza 401 si el token es inválido, el usuario no existe, está
    desactivado o fue emitido antes del último cambio de contraseña.
    """
    payload = decode_access_token_payload(token)
    user_id: UUID = UUID(str(payload["sub"]))
    user = await db.get(User, user_id)
    if user is None or not user.is_active:
        raise InvalidCredentialsException("Usuario no encontrado o desactivado")
    if not jwt_valido_para_el_usuario(payload, user):
        raise InvalidCredentialsException("Token inválido o expirado")
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

# RF-03: máximo 5 solicitudes de recuperación por IP cada 15 minutos.
# La IP solo vive en Redis (clave con TTL); jamás se persiste en PostgreSQL.
limit_password_reset_ip = limit_requests(
    scope="password_reset_ip",
    maximum=configuracion.PASSWORD_RESET_MAX_POR_IP,
    window_seconds=configuracion.PASSWORD_RESET_VENTANA_IP_SEGUNDOS,
)
