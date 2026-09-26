from fastapi import FastAPI

aplicacion = FastAPI(
    title="API de Ika Travel",
    description="Backend para la aplicación de turismo en Ica",
    version="1.0.0"
)

@aplicacion.get("/")
async def raiz():
    return {"mensaje": "Bienvenido a la API de Ika Travel"}
