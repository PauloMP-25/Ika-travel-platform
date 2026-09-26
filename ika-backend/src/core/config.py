from pydantic_settings import BaseSettings, SettingsConfigDict


class Configuracion(BaseSettings):
    URL_BASE_DATOS: str

    # --- Proveedores de clima externos (PoC RF-06) ---
    OPENWEATHERMAP_API_KEY: str = ""
    WEATHERAPI_API_KEY: str = ""
    TIMEOUT_CLIMA_SEGUNDOS: float = 10.0

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


configuracion = Configuracion()
