"""Excepciones de negocio y su mapeo global a respuestas HTTP.

Cada módulo define sus excepciones heredando de ``ErrorDeNegocio`` e indicando
``codigo_http`` y ``codigo``. Un único manejador global las convierte en JSON,
así los routers nunca repiten ``HTTPException``.
"""
import logging

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)


class ErrorDeNegocio(Exception):
    """Base de todas las excepciones controladas de la aplicación."""

    codigo_http: int = 400
    codigo: str = "error_de_negocio"
    mensaje_por_defecto: str = "Se produjo un error de negocio."

    def __init__(self, mensaje: str | None = None) -> None:
        self.mensaje = mensaje or self.mensaje_por_defecto
        super().__init__(self.mensaje)


class AccesoAdminDenegadoException(ErrorDeNegocio):
    codigo_http = 403
    codigo = "acceso_admin_denegado"
    mensaje_por_defecto = "Clave de administración inválida o ausente."


class AdminNoConfiguradoException(ErrorDeNegocio):
    codigo_http = 503
    codigo = "admin_no_configurado"
    mensaje_por_defecto = (
        "Los endpoints administrativos están deshabilitados: falta CLAVE_ADMIN en el entorno."
    )


async def _manejar_error_de_negocio(request: Request, exc: ErrorDeNegocio) -> JSONResponse:
    if exc.codigo_http >= 500:
        logger.error("%s: %s", exc.codigo, exc.mensaje, exc_info=exc.__cause__)
    return JSONResponse(
        status_code=exc.codigo_http,
        content={"detail": exc.mensaje, "codigo": exc.codigo},
    )


def registrar_manejadores_excepciones(aplicacion: FastAPI) -> None:
    """Registra el manejador global. Se invoca una sola vez desde main.py."""
    aplicacion.add_exception_handler(ErrorDeNegocio, _manejar_error_de_negocio)
