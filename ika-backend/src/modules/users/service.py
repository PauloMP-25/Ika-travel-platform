"""Lógica de negocio del módulo `users` (registro, login y perfil)."""

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from src.core import security
from src.modules.users import repository
from src.modules.users.exceptions import (
    InactiveUserException,
    InvalidCredentialsException,
    UserAlreadyExistsException,
)
from src.modules.users.models import AuthProvider, User, UserRole
from src.modules.users.schemas import TokenResponse, UserCreate, UserLogin, UserUpdate


async def register_user(db: AsyncSession, data: UserCreate) -> User:
    """Crea una cuenta nueva con contraseña (valida email único)."""
    existing = await repository.get_user_by_email(db, data.email)
    if existing is not None:
        raise UserAlreadyExistsException(data.email)

    user = User(
        email=data.email,
        password_hash=security.hash_password(data.password),
        full_name=data.full_name,
        phone=data.phone,
        preferred_language=data.preferred_language,
        preferences=[p.value if hasattr(p, "value") else str(p) for p in data.preferences],
        role=UserRole.TOURIST,
        auth_provider=AuthProvider.EMAIL,
    )
    repository.add_user(db, user)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raise UserAlreadyExistsException(data.email)
    await db.refresh(user)
    return user


async def authenticate_user(
    db: AsyncSession, email: str, password: str
) -> User:
    """Valida credenciales por email/contraseña y devuelve el usuario."""
    user = await repository.get_user_by_email(db, email)
    if user is None:
        raise InvalidCredentialsException()

    if not user.is_active:
        raise InactiveUserException()

    if not security.verify_password(password, user.password_hash):
        raise InvalidCredentialsException()

    return user


async def login_user(db: AsyncSession, data: UserLogin) -> TokenResponse:
    """Orquesta la autenticación y la emisión del token JWT."""
    user = await authenticate_user(db, data.email, data.password)
    token = security.create_access_token(user.id)
    return TokenResponse(
        access_token=token,
        expires_in=security.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


async def update_user_profile(
    db: AsyncSession, user: User, data: UserUpdate
) -> User:
    """Actualiza únicamente los campos enviados (no-`None`)."""
    updates = data.model_dump(exclude_unset=True)
    for field, value in updates.items():
        if value is not None:
            if field == "preferences" and isinstance(value, list):
                value = [p.value if hasattr(p, "value") else str(p) for p in value]
            setattr(user, field, value)

    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user
