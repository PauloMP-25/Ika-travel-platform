"""Excepciones personalizadas del módulo `users` y su manejador HTTP.

El módulo es autocontenido: no depende de `src/core/exceptions.py`. Basta
con llamar a `register_users_exception_handlers(app)` desde `main.py`.
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class UsersException(Exception):
    """Base de las excepciones de negocio del módulo `users`."""

    status_code: int = 500
    default_detail: str = "Error en el módulo de usuarios"

    def __init__(self, detail: str | None = None) -> None:
        self.detail = detail if detail is not None else self.default_detail
        super().__init__(self.detail)


class UserAlreadyExistsException(UsersException):
    """Ya existe un usuario registrado con ese email (HTTP 409)."""

    status_code = 409
    default_detail = "Ya existe una cuenta con ese email"

    def __init__(self, email: str) -> None:
        super().__init__(detail=f"Ya existe una cuenta con el email {email}")


class InvalidCredentialsException(UsersException):
    """Email o contraseña incorrectos, o token inválido/expirado (HTTP 401)."""

    status_code = 401
    default_detail = "Credenciales incorrectas"


class InactiveUserException(UsersException):
    """La cuenta existe pero está desactivada (HTTP 403)."""

    status_code = 403
    default_detail = "La cuenta está desactivada"


def register_users_exception_handlers(app: FastAPI) -> None:
    """Adjunta el manejador de las excepciones de `users` a la app.

    Llamar desde `src/main.py` (una línea) para que las excepciones del
    servicio se traduzcan a su código HTTP en lugar de dar 500.
    """

    @app.exception_handler(UsersException)
    async def handle_users_exception(
        request: Request, exc: UsersException
    ) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail},
        )
