from pydantic_settings import BaseSettings, SettingsConfigDict

class Configuracion(BaseSettings):
    URL_BASE_DATOS: str                       # <- tuyo, no cambia

    # --- Dev 2 (pega todo este bloque) ---
    URL_REDIS: str = "redis://localhost:6379/0"
    ORIGENES_CORS: str = "*"
    CLAVE_ADMIN: str = ""
    CLIMA_URL_BASE: str = "https://api.open-meteo.com/v1/forecast"
    CLIMA_ZONA_HORARIA: str = "America/Lima"
    CLIMA_TIMEOUT_SEGUNDOS: float = 10.0
    CLIMA_VIGENCIA_HORAS: int = 6
    CLIMA_LATITUD_REGION: float = -14.0678
    CLIMA_LONGITUD_REGION: float = -75.7286
    GEMINI_API_KEY: str = ""
    GEMINI_MODELO: str = "gemini-2.5-flash"
    GEMINI_TIMEOUT_SEGUNDOS: float = 8.0
    RUTAS_URL_BASE: str = "https://routing.openstreetmap.de"
    RUTAS_TIMEOUT_SEGUNDOS: float = 10.0
    DIRCETUR_URL_PADRON: str = ""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")  # <- único cambio: extra="ignore"

    @property
    def origenes_cors_lista(self) -> list[str]:
        return [o.strip() for o in self.ORIGENES_CORS.split(",") if o.strip()]

configuracion = Configuracion()               # <- tuyo, no cambia