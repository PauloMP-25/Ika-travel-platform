from fastapi import FastAPI

from src.core.exceptions import registrar_manejadores_excepciones
from src.modules.clima.router import router as router_clima

aplicacion = FastAPI(
    title="API de Ika Travel",
    description="Backend para la aplicación de turismo en Ica",
    version="1.0.0",
)

registrar_manejadores_excepciones(aplicacion)
aplicacion.include_router(router_clima, prefix="/api/v1")


@aplicacion.get("/")
async def raiz():
    return {"mensaje": "Bienvenido a la API de Ika Travel"}
