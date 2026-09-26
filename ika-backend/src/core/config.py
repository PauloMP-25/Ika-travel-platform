from pydantic_settings import BaseSettings, SettingsConfigDict

class Configuracion(BaseSettings):
    URL_BASE_DATOS: str

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

configuracion = Configuracion()
