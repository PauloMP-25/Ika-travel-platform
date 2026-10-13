from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base
from src.core.config import configuracion

# Motor de base de datos asíncrono
motor = create_async_engine(configuracion.URL_BASE_DATOS, echo=True)

# Creador de sesiones asíncronas
SesionAsincronaLocal = async_sessionmaker(
    bind=motor,
    class_=AsyncSession,
    expire_on_commit=False
)

Base = declarative_base()

# Dependencia para obtener la sesión de base de datos en FastAPI
async def obtener_bd():
    async with SesionAsincronaLocal() as sesion:
        yield sesion
