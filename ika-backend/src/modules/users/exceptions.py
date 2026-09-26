"""Excepciones personalizadas del módulo `users`."""

from src.core.exceptions import AppException


class UserAlreadyExistsException(AppException):
    """Ya existe un usuario registrado con ese email (HTTP 409)."""

    status_code = 409
    default_detail = "Ya existe una cuenta con ese email"

    def __init__(self, email: str) -> None:
        super().__init__(detail=f"Ya existe una cuenta con el email {email}")


class InvalidCredentialsException(AppException):
    """Email o contraseña incorrectos, o token inválido/expirado (HTTP 401)."""

    status_code = 401
    default_detail = "Credenciales incorrectas"


class InactiveUserException(AppException):
    """La cuenta existe pero está desactivada (HTTP 403)."""

    status_code = 403
    default_detail = "La cuenta está desactivada"
