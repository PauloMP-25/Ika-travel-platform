"""Excepciones de negocio y su mapeo global a respuestas HTTP.

Cada módulo define sus excepciones heredando de `ErrorDeNegocio` (con su
`codigo_http` y `codigo`). Aquí se registran, una sola vez, los manejadores
que las convierten en un JSON con formato único para toda la API:

    {"detail": "<mensaje legible>", "codigo": "<identificador_estable>"}

El frontend puede mostrar `detail` al usuario y usar `codigo` para lógica
(p. ej. redirigir al login si `codigo == "credenciales_invalidas"`).

Importante: este archivo NO importa nada de los módulos de negocio para
evitar imports circulares (los módulos importan `ErrorDeNegocio` desde aquí).
"""

import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)


class ErrorDeNegocio(Exception):
    """Base de todas las excepciones controladas de la aplicación."""

    codigo_http: int = 400
    codigo: str = "error_de_negocio"
    mensaje_por_defecto: str = "Se produjo un error de negocio."

    def __init__(self, mensaje: str | None = None, *, extra: dict[str, Any] | None = None) -> None:
        self.mensaje = mensaje or self.mensaje_por_defecto
        # Datos adicionales opcionales que se añaden al cuerpo JSON de la respuesta.
        self.extra = extra or {}
        super().__init__(self.mensaje)


class AccesoAdminDenegadoException(ErrorDeNegocio):
    codigo_http = 403
    codigo = "acceso_admin_denegado"
    mensaje_por_defecto = "Clave de administración inválida o ausente."


class RateLimitExceededException(ErrorDeNegocio):
    codigo_http = 429
    codigo = "LIMITE_SOLICITUDES_EXCEDIDO"
    mensaje_por_defecto = "Demasiadas solicitudes. Intente nuevamente más tarde."

    def __init__(self, window_seconds: int) -> None:
        super().__init__(
            f"Demasiadas solicitudes. Intente nuevamente en {window_seconds} segundos.",
            extra={"retry_after": window_seconds},
        )


class AdminNoConfiguradoException(ErrorDeNegocio):
    codigo_http = 503
    codigo = "admin_no_configurado"
    mensaje_por_defecto = (
        "Los endpoints administrativos están deshabilitados: falta CLAVE_ADMIN en el entorno."
    )


def construir_cuerpo_error(detail: str, codigo: str, **extra: Any) -> dict[str, Any]:
    """Formato único del cuerpo de error (reutilizable por cualquier módulo)."""
    return {"detail": detail, "codigo": codigo, **extra}


# ----------------------------------------------------------------------
# Manejadores
# ----------------------------------------------------------------------
async def _manejar_error_de_negocio(request: Request, exc: ErrorDeNegocio) -> JSONResponse:
    if exc.codigo_http >= 500:
        logger.error("%s: %s", exc.codigo, exc.mensaje, exc_info=exc.__cause__)
    return JSONResponse(
        status_code=exc.codigo_http,
        content=jsonable_encoder(construir_cuerpo_error(exc.mensaje, exc.codigo, **exc.extra)),
    )


async def _manejar_validacion(request: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content=jsonable_encoder(
            construir_cuerpo_error(
                "Los datos enviados no son válidos.",
                "validacion_fallida",
                errores=exc.errors(),
            )
        ),
    )


async def _manejar_http(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    codigos = {401: "no_autenticado", 403: "prohibido", 404: "no_encontrado", 405: "metodo_no_permitido"}
    detail = exc.detail if isinstance(exc.detail, str) else "Error HTTP."
    return JSONResponse(
        status_code=exc.status_code,
        content=construir_cuerpo_error(detail, codigos.get(exc.status_code, "error_http")),
        headers=getattr(exc, "headers", None),
    )


async def _manejar_inesperado(request: Request, exc: Exception) -> JSONResponse:
    # Nunca se expone la traza al cliente; queda solo en el log del servidor.
    logger.exception("Error no controlado en %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content=construir_cuerpo_error("Error interno del servidor.", "error_interno"),
    )


def registrar_manejadores_excepciones(aplicacion: FastAPI) -> None:
    """Registra todos los manejadores globales. Se invoca una sola vez desde main.py."""
    aplicacion.add_exception_handler(ErrorDeNegocio, _manejar_error_de_negocio)
    aplicacion.add_exception_handler(RequestValidationError, _manejar_validacion)
    aplicacion.add_exception_handler(StarletteHTTPException, _manejar_http)
    aplicacion.add_exception_handler(Exception, _manejar_inesperado)
