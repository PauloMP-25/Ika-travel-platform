"""Primitivas de seguridad: hasheo de contraseñas y tokens JWT."""

import os
from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

import jwt
from passlib.context import CryptContext

from src.modules.users.exceptions import InvalidCredentialsException

SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-cambiar-antes-de-produccion")
ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str | None) -> bool:
    if not hashed:
        return False
    return pwd_context.verify(plain, hashed)


def create_access_token(user_id: UUID, role: str, expires_minutes: int | None = None) -> str:
    """Firma un JWT con el `sub` (id) y el `role` del usuario."""
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=expires_minutes or ACCESS_TOKEN_EXPIRE_MINUTES)
    payload: dict[str, object] = {
        "sub": str(user_id),
        "role": role,  
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "jti": str(uuid4()),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict:
    """Valida un JWT y devuelve el payload (sub y role)."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if "sub" not in payload or "role" not in payload:
            raise ValueError("Payload incompleto")
        return payload  
    except (jwt.PyJWTError, KeyError, ValueError):
        raise InvalidCredentialsException("Token inválido o expirado")