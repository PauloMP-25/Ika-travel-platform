"""Primitivas de seguridad: hasheo de contraseñas y tokens JWT."""

import os
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import jwt
from passlib.context import CryptContext

from src.modules.users.exceptions import InvalidCredentialsException

# TODO(Paulo): migrar estas tres variables a `src.core.config.Settings` en
# cuanto se amplíe. Hoy se leen del entorno para no tocar `config.py`.
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-cambiar-antes-de-produccion")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))

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
        minutes=expires_minutes or ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload: dict[str, object] = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "jti": str(uuid4()),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> UUID:
    """Valida un JWT y devuelve el id del usuario.

    Lanza `InvalidCredentialsException` si el token es inválido, está
    manipulado o ya expiró (PyJWT valida `exp` automáticamente).
    """
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
        )
        return UUID(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        raise InvalidCredentialsException("Token inválido o expirado")
