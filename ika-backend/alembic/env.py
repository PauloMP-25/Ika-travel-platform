import asyncio
import os
import sys
from logging.config import fileConfig

# Inyectamos la ruta principal para poder importar src.*
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context
from src.core.config import configuracion
from src.core.database import Base

# Este es el objeto de configuración de Alembic, que provee
# acceso a los valores dentro del archivo .ini en uso.
config = context.config
config.set_main_option("sqlalchemy.url", configuracion.URL_BASE_DATOS)

# Interpretar el archivo de configuración para el registro (logging) de Python.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Añade el objeto MetaData de tus modelos aquí
# para soporte de 'autogenerate'
objetivo_metadatos = Base.metadata

def run_migrations_offline() -> None:
    """Ejecutar migraciones en modo 'offline'."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=objetivo_metadatos,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()

def do_run_migrations(connection: Connection) -> None:
    """Ejecutar migraciones en modo 'online' (conexión sincrónica interna)."""
    context.configure(connection=connection, target_metadata=objetivo_metadatos)

    with context.begin_transaction():
        context.run_migrations()

async def run_async_migrations() -> None:
    """En este escenario necesitamos crear un Motor y asociar
    una conexión con el contexto.
    """
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()

def run_migrations_online() -> None:
    """Ejecutar migraciones en modo 'online'."""
    asyncio.run(run_async_migrations())

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
