from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.core.config import configuracion
from src.core.database import motor
from src.core.exceptions import registrar_manejadores_excepciones
from src.modules.catalog.router import admin as catalog_admin_router
from src.modules.catalog.router import router as catalog_router
from src.modules.emergency.router import emergency_router
from src.modules.geo.router import router as geo_router
from src.modules.reviews.router import reviews_router
from src.modules.analytics.router import router as analytics_router
from src.modules.translation.router import router as translation_router
from src.modules.weather.router import router as weather_router
from src.modules.users.router import users_router
from src.modules.users.exceptions import register_users_exception_handlers
from src.redis_client import cerrar_redis


@asynccontextmanager
async def ciclo_de_vida(_: FastAPI):
    yield
    await cerrar_redis()
    await motor.dispose()


aplicacion = FastAPI(
    title="API de Ika Travel",
    description="Backend para la aplicación de turismo en Ica",
    version="1.0.0",
    lifespan=ciclo_de_vida,
)

aplicacion.add_middleware(
    CORSMiddleware,
    allow_origins=configuracion.origenes_cors_lista,
    allow_methods=["*"],
    allow_headers=["*"],
    # Sprint 4, F3/F4: el cliente web necesita leer estas cabeceras de origen.
    expose_headers=["ETag", "Idempotent-Replayed"],
)
registrar_manejadores_excepciones(aplicacion)
register_users_exception_handlers(aplicacion)

PREFIJO_API = "/api/v1"
aplicacion.include_router(users_router, prefix=PREFIJO_API)
aplicacion.include_router(catalog_router, prefix=PREFIJO_API)
aplicacion.include_router(catalog_admin_router, prefix=PREFIJO_API)
aplicacion.include_router(weather_router, prefix=PREFIJO_API)
aplicacion.include_router(geo_router, prefix=PREFIJO_API)
aplicacion.include_router(emergency_router, prefix=PREFIJO_API)
aplicacion.include_router(reviews_router, prefix=PREFIJO_API)
aplicacion.include_router(analytics_router, prefix=PREFIJO_API)
aplicacion.include_router(translation_router, prefix=PREFIJO_API)


@aplicacion.get("/")
async def raiz():
    return {"mensaje": "Bienvenido a la API de Ika Travel"}
