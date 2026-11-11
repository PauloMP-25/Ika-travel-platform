from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

_ENV_FILE = str(Path(__file__).resolve().parent.parent.parent / ".env")

class Configuracion(BaseSettings):
    URL_BASE_DATOS: str

    # --- Redis y CORS ---
    URL_REDIS: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"
    ORIGENES_CORS: str = "*"

    # --- Archivos (Reviews) ---
    UPLOADS_DIR: str = "./uploads"
    MAX_UPLOAD_MB: int = 5

    # --- Emergencias (SOS) ---
    SOS_NOTIFY_EMAILS: str = ""

    # --- Admin ---
    CLAVE_ADMIN: str = ""

    # --- Proveedores de clima externos (RF-06) ---
    OPENWEATHERMAP_API_KEY: str = ""
    WEATHERAPI_API_KEY: str = ""
    TIMEOUT_CLIMA_SEGUNDOS: float = 10.0

    # --- Clima (configuración regional) ---
    CLIMA_URL_BASE: str = "https://api.open-meteo.com/v1/forecast"
    CLIMA_ZONA_HORARIA: str = "America/Lima"
    CLIMA_VIGENCIA_HORAS: int = 6
    CLIMA_LATITUD_REGION: float = -14.0678
    CLIMA_LONGITUD_REGION: float = -75.7286

    # --- IA (Gemini) ---
    GEMINI_API_KEY: str = ""
    GEMINI_MODELO: str = "gemini-3.1-flash-lite"
    GEMINI_TIMEOUT_SEGUNDOS: float = 15.0
    # Presupuesto de tiempo del recomendador estructurado (Sprint 4, P4).
    GEMINI_TIMEOUT_RECOMENDACION_SEGUNDOS: float = 2.5

    # --- Login social (Sprint 4, F1) ---
    # Lista separada por comas de los `client_id` OAuth aceptados (Android, iOS y web).
    GOOGLE_CLIENT_IDS: str = ""

    # --- Proveedores de clima: tope por proveedor (Sprint 4, P1) ---
    TIMEOUT_PROVEEDOR_CLIMA_SEGUNDOS: float = 3.0

    # --- Traducción (Sprint 3, RNF-04) ---
    TRANSLATION_MODEL: str | None = None  # si es None se usa GEMINI_MODELO
    TRANSLATION_TIMEOUT_SECONDS: float = 8.0
    TRANSLATION_MAX_CHARS: int = 500
    TRANSLATION_CACHE_TTL_SECONDS: int = 604_800  # 7 días
    TRANSLATION_FALLBACK_TTL_SECONDS: int = 2_592_000  # 30 días
    TRANSLATION_RATE_LIMIT_PER_MINUTE: int = 30

    # --- Rutas ---
    RUTAS_URL_BASE: str = "https://routing.openstreetmap.de"
    RUTAS_TIMEOUT_SEGUNDOS: float = 10.0

    # --- DIRCETUR ---
    DIRCETUR_URL_PADRON: str = ""

    # --- Correo transaccional (RF-03: recuperación de cuenta) ---
    # Credenciales SOLO desde variables de entorno (nunca valores por defecto
    # reales). Con Gmail se usa una contraseña de aplicación de Google.
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_STARTTLS: bool = True
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM: str = ""  # si se omite se usa SMTP_USER
    SMTP_TIMEOUT_SEGUNDOS: float = 15.0

    # Única fuente del enlace enviado por correo: nunca se usa la cabecera Host.
    PASSWORD_RESET_URL_TEMPLATE: str = "ikatravel://reset-password?token={token}"
    # Duración del token de recuperación (RF-03: 30 minutos).
    PASSWORD_RESET_TOKEN_TTL_MINUTES: int = 30

    # --- RF-03: límites de solicitud de recuperación ---
    # 5 solicitudes por IP cada 15 minutos.
    PASSWORD_RESET_MAX_POR_IP: int = 5
    PASSWORD_RESET_VENTANA_IP_SEGUNDOS: int = 900
    # 3 solicitudes por correo cada hora.
    PASSWORD_RESET_MAX_POR_CORREO: int = 3
    PASSWORD_RESET_VENTANA_CORREO_SEGUNDOS: int = 3600

    model_config = SettingsConfigDict(env_file=_ENV_FILE, env_file_encoding="utf-8", extra="ignore")

    @property
    def origenes_cors_lista(self) -> list[str]:
        return [o.strip() for o in self.ORIGENES_CORS.split(",") if o.strip()]

    @property
    def google_client_ids_lista(self) -> list[str]:
        """`GOOGLE_CLIENT_IDS` como lista limpia (para `GoogleAuthStrategy`)."""
        return [i.strip() for i in self.GOOGLE_CLIENT_IDS.split(",") if i.strip()]


configuracion = Configuracion()
