"""Excepciones de aplicación y registro de sus manejadores HTTP.

Regla del equipo: la capa `service` lanza excepciones personalizadas y aquí se
traducen una única vez a códigos HTTP. No se repite `HTTPException` en routers.
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


class AppException(Exception):
    """Base de todas las excepciones de negocio del dominio."""

    status_code: int = 500
    default_detail: str = "Error interno"

    def __init__(self, detail: str | None = None) -> None:
        self.detail = detail if detail is not None else self.default_detail
        super().__init__(self.detail)


def register_exception_handlers(app: FastAPI) -> None:
    """Adjunta los manejadores globales a la app FastAPI.

    Debe llamarse desde `src/main.py` (o desde la app de tests).
    """

    @app.exception_handler(AppException)
    async def handle_app_exception(
        request: Request, exc: AppException
    ) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail},
        )
