"""Configuración central de la aplicación.

Todas las variables pueden sobreescribirse desde el entorno o desde un archivo
`.env`. Nunca se debe hardcodear un secreto en el código fuente.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Ajustes de la aplicación cargados desde variables de entorno."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    PROJECT_NAME: str = "Ika Travel & Experience API"
    API_V1_PREFIX: str = "/api/v1"
    DEBUG: bool = False

    # Base de datos
    DATABASE_URL: str = "postgresql+psycopg2://postgres:admin@localhost:5432/ika_travel"
    TEST_DATABASE_URL: str = (
        "postgresql+psycopg2://postgres:admin@localhost:5432/ika_travel_test"
    )
    DATABASE_ECHO: bool = False

    # Seguridad / JWT
    SECRET_KEY: str = "cambiar-en-produccion-clave-secreta-super-larga"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 horas

    # Celery / Redis (notificaciones SOS, refresco de clima, etc.)
    CELERY_BROKER_URL: str = "redis://localhost:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/1"
    # True solo en tests: ejecuta las tareas en síncrono, sin broker
    CELERY_TASK_ALWAYS_EAGER: bool = False


@lru_cache
def get_settings() -> Settings:
    """Instancia cacheada de los ajustes (una sola lectura por proceso)."""
    return Settings()


settings = get_settings()
