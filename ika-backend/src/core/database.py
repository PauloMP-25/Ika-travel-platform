from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import declarative_base
from src.core.config import settings

# Motor de BD asíncrono
engine = create_async_engine(settings.DATABASE_URL, echo=True)

# Creador de sesiones asíncronas
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)

Base = declarative_base()

# Dependencia para obtener la sesión de BD en FastAPI
async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
