from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base
from src.core.config import configuracion

motor = create_async_engine(configuracion.URL_BASE_DATOS, echo=True)

SesionAsincronaLocal = async_sessionmaker(
    bind=motor,
    class_=AsyncSession,
    expire_on_commit=False
)

Base = declarative_base()

async def obtener_bd():
    async with SesionAsincronaLocal() as sesion:
        yield sesion



from src.modules.users import models as _users_models           
from src.modules.weather import models as _weather_models       
from src.modules.emergency import models as _emergency_models   
from src.modules.catalog import models as _catalog_models       