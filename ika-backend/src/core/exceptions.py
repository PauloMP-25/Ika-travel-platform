"""Manejadores globales de excepciones.

Se registran una sola vez en `main.py`. Cada módulo de dominio define sus
propias excepciones; aquí solo se mapean a códigos HTTP, siguiendo el
estándar del equipo de no repetir `HTTPException` en cada router.
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from src.modules.clima.exceptions import (
    DestinoNoEncontradoException,
    TodosLosProveedoresFallaronException,
)


def registrar_manejadores_excepciones(aplicacion: FastAPI) -> None:
    @aplicacion.exception_handler(DestinoNoEncontradoException)
    async def manejar_destino_no_encontrado(request: Request, exc: DestinoNoEncontradoException):
        return JSONResponse(status_code=404, content={"detalle": str(exc)})

    @aplicacion.exception_handler(TodosLosProveedoresFallaronException)
    async def manejar_todos_proveedores_fallaron(request: Request, exc: TodosLosProveedoresFallaronException):
        return JSONResponse(
            status_code=503,
            content={
                "detalle": "Ningún proveedor de clima respondió. Intente más tarde.",
                "proveedores_intentados": [error.proveedor for error in exc.errores],
            },
        )

    # A medida que se sumen excepciones de otros módulos (users, catalog,
    # emergency, reviews), registrar sus handlers aquí siguiendo el mismo patrón.
