from fastapi import FastAPI

from src.modules.users.router import users_router
from src.modules.users.exceptions import register_users_exception_handlers

app = FastAPI(
    title="Ika Travel API",
    description="Backend para la aplicación de turismo en Ica",
    version="1.0.0"
)

register_users_exception_handlers(app)
app.include_router(users_router, prefix="/api/v1", tags=["users"])

@app.get("/")
async def root():
    return {"message": "Bienvenido a la API de Ika Travel"}
