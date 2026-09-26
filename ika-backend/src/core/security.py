"""Primitivas de seguridad: hasheo de contraseñas y tokens JWT."""

from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import jwt
from passlib.context import CryptContext

from src.config import settings
from src.modules.users.exceptions import InvalidCredentialsException

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """Devuelve el hash bcrypt de la contraseña en texto plano."""
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str | None) -> bool:
    """Compara una contraseña en texto plano contra su hash."""
    if not hashed:
        return False
    return pwd_context.verify(plain, hashed)


def create_access_token(
    user_id: UUID,
    expires_minutes: int | None = None,
) -> str:
    """Firma un JWT con el `sub` igual al id del usuario."""
    now = datetime.now(timezone.utc)
    expire = now + timedelta(
        minutes=expires_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload: dict[str, object] = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "jti": str(uuid4()),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> UUID:
    """Valida un JWT y devuelve el id del usuario.

    Lanza `InvalidCredentialsException` si el token es inválido, está
    manipulado o ya expiró (PyJWT valida `exp` automáticamente).
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        return UUID(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise InvalidCredentialsException("Token inválido o expirado")
