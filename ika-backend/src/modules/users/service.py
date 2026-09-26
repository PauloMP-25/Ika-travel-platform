"""Lógica de negocio del módulo `users` (registro, login y perfil)."""

from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from src.config import settings
from src.core import security
from src.modules.users.exceptions import (
    InactiveUserException,
    InvalidCredentialsException,
    UserAlreadyExistsException,
)
from src.modules.users.models import AuthProvider, User
from src.modules.users.schemas import TokenResponse, UserCreate, UserLogin, UserUpdate


def get_user_by_email(db: Session, email: str) -> User | None:
    """Busca un usuario por su email (sin lógica adicional)."""
    return db.query(User).filter(User.email == email).first()


def get_user_by_id(db: Session, user_id: UUID) -> User | None:
    """Busca un usuario por su id."""
    return db.query(User).filter(User.id == user_id).first()


def register_user(db: Session, data: UserCreate) -> User:
    """Crea una cuenta nueva con contraseña (valida email único)."""
    if get_user_by_email(db, data.email) is not None:
        raise UserAlreadyExistsException(data.email)

    user = User(
        email=data.email,
        password_hash=security.hash_password(data.password),
        full_name=data.full_name,
        auth_provider=AuthProvider.EMAIL,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        # Carrera entre dos registros simultáneos: la restricción unique
        # de la BD es la última línea de defensa.
        db.rollback()
        raise UserAlreadyExistsException(data.email)
    db.refresh(user)
    return user


def authenticate_user(db: Session, email: str, password: str) -> User:
    """Valida credenciales por email/contraseña y devuelve el usuario.

    El mensaje de error es idéntico exista o no el email para no revelar
    qué cuentas están registradas.
    """
    user = get_user_by_email(db, email)
    if user is None:
        raise InvalidCredentialsException()

    if not user.is_active:
        raise InactiveUserException()

    if not security.verify_password(password, user.password_hash):
        raise InvalidCredentialsException()

    return user


def login_user(db: Session, data: UserLogin) -> TokenResponse:
    """Orquesta la autenticación y la emisión del token JWT."""
    user = authenticate_user(db, data.email, data.password)
    token = security.create_access_token(user.id)
    return TokenResponse(
        access_token=token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


def update_user_profile(
    db: Session, user: User, data: UserUpdate
) -> User:
    """Actualiza únicamente los campos enviados (no-`None`)."""
    updates = data.model_dump(exclude_unset=True)
    for field, value in updates.items():
        if value is not None:
            setattr(user, field, value)

    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# TODO(Dev 1 - fuera del sprint): `authenticate_oauth` para login social
# con Google/Facebook (find-or-create por provider_id y email).
