"""Entorno de Alembic: conecta con la BD y expone `target_metadata`.

Importa dinámicamente el `models.py` de cada módulo para que cualquier
desarrollador que agregue modelos nuevos no tenga que editar este archivo.
"""

import importlib
import pkgutil
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool

from alembic import context

from src.config import settings
from src.database import Base
import src.modules  # noqa: F401

config = context.config

# URL de conexión tomada de los Settings de la app (nunca en claro en el .ini)
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

for module in pkgutil.iter_modules(src.modules.__path__):
    try:
        importlib.import_module(f"src.modules.{module.name}.models")
    except ModuleNotFoundError:  # pragma: no cover - módulo sin models.py
        continue

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Ejecuta las migraciones en modo offline (genera SQL sin conexión)."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Ejecuta las migraciones contra la base de datos conectada."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
