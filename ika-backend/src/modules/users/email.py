"""Envío de correo del módulo `users` (RF-03: recuperación de cuenta).

- `EmailSender`: abstracción que usan los servicios de negocio.
- `SMTPEmailSender`: implementación SMTP real (Gmail, STARTTLS).
- El envío es bloqueante (`smtplib`), así que se ejecuta en el pool de
  hilos de `anyio` para no congelar el event loop.

Seguridad: las credenciales se leen únicamente de variables de entorno y
este módulo nunca registra tokens, enlaces, contraseñas, credenciales SMTP
ni cuerpos de correo en los logs.
"""

from __future__ import annotations

import logging
import smtplib
import ssl
from abc import ABC, abstractmethod
from dataclasses import dataclass
from email.message import EmailMessage

import anyio

from src.core.config import Configuracion, configuracion

logger = logging.getLogger(__name__)

# Idiomas aceptados en `User.preferred_language`; cualquier otro usa `es`.
_IDIOMA_POR_DEFECTO = "es"


class ConfiguracionEmailInvalida(RuntimeError):
    """Falta o es inválida una variable de entorno de correo.

    El mensaje incluye solo **nombres** de variables, jamás sus valores.
    """


@dataclass(frozen=True)
class Correo:
    """Mensaje en claro listo para enviar (nunca se registra en logs)."""

    destino: str
    asunto: str
    cuerpo: str


class EmailSender(ABC):
    """Abstracción del envío de correo: los servicios no conocen `smtplib`."""

    @abstractmethod
    async def enviar(self, correo: Correo) -> None:
        """Envía el correo de forma asíncrona (implementación no bloqueante)."""


# ----------------------------------------------------------------------
# Validación de la configuración (al iniciar el sender)
# ----------------------------------------------------------------------
def validar_configuracion_email(cfg: Configuracion) -> None:
    """Valida la configuración SMTP y la plantilla del enlace.

    Lanza `ConfiguracionEmailInvalida` con los **nombres** de las variables
    que falten o sean inválidas (nunca sus valores).
    """
    faltantes: list[str] = []

    if not str(cfg.SMTP_HOST).strip():
        faltantes.append("SMTP_HOST")
    if not 1 <= int(cfg.SMTP_PORT) <= 65535:
        faltantes.append("SMTP_PORT")
    if not str(cfg.SMTP_USER).strip():
        faltantes.append("SMTP_USER")
    if not str(cfg.SMTP_PASSWORD).strip():
        faltantes.append("SMTP_PASSWORD")
    if not str(cfg.SMTP_FROM or cfg.SMTP_USER).strip():
        faltantes.append("SMTP_FROM")
    if not cfg.SMTP_STARTTLS:
        faltantes.append("SMTP_STARTTLS")
    if "{token}" not in str(cfg.PASSWORD_RESET_URL_TEMPLATE):
        faltantes.append("PASSWORD_RESET_URL_TEMPLATE({token})")

    if faltantes:
        raise ConfiguracionEmailInvalida(
            "Configuración de correo incompleta o inválida: "
            + ", ".join(faltantes)
        )


# ----------------------------------------------------------------------
# Plantillas (es / en) según `preferred_language`
# ----------------------------------------------------------------------
_PLANTILLAS: dict[str, dict[str, tuple[str, str]]] = {
    "es": {
        "reset": (
            "Recupera tu contraseña de Ika Travel",
            (
                "Hola,\n"
                "\n"
                "Recibimos una solicitud para restablecer tu contraseña de "
                "Ika Travel.\n"
                "Abre este enlace en la aplicación para elegir una nueva:\n"
                "\n"
                "{enlace}\n"
                "\n"
                "El enlace caduca en 30 minutos y solo puede usarse una vez.\n"
                "Si no fuiste tú, ignora este mensaje: tu contraseña no cambiará.\n"
                "\n"
                "El equipo de Ika Travel\n"
            ),
        ),
        "google": (
            "Inicia sesión con Google para continuar",
            (
                "Hola,\n"
                "\n"
                "Tu cuenta de Ika Travel se creó con Google, por lo que no "
                "tiene una contraseña local que podamos restablecer.\n"
                "Para entrar, usa el botón «Continuar con Google».\n"
                "\n"
                "El equipo de Ika Travel\n"
            ),
        ),
    },
    "en": {
        "reset": (
            "Reset your Ika Travel password",
            (
                "Hello,\n"
                "\n"
                "We received a request to reset your Ika Travel password.\n"
                "Open this link in the app to choose a new one:\n"
                "\n"
                "{enlace}\n"
                "\n"
                "The link expires in 30 minutes and can only be used once.\n"
                "If this wasn't you, ignore this message: your password won't "
                "change.\n"
                "\n"
                "The Ika Travel team\n"
            ),
        ),
        "google": (
            "Sign in with Google to continue",
            (
                "Hello,\n"
                "\n"
                "Your Ika Travel account was created with Google, so it has no "
                "local password we can reset.\n"
                "Use the «Continue with Google» button to sign in.\n"
                "\n"
                "The Ika Travel team\n"
            ),
        ),
    },
}


def contenido_plantilla(clave: str, idioma: str | None) -> tuple[str, str]:
    """Devuelve `(asunto, cuerpo)` de una plantilla; usa `es` si el idioma no aplica."""
    catalogo = _PLANTILLAS.get(idioma or _IDIOMA_POR_DEFECTO, _PLANTILLAS[_IDIOMA_POR_DEFECTO])
    return catalogo[clave]


def construir_enlace_reset(token: str, cfg: Configuracion | None = None) -> str:
    """Construye el enlace **únicamente** desde `PASSWORD_RESET_URL_TEMPLATE`.

    No recibe ni usa la cabecera `Host` de la petición.
    """
    cfg = cfg if cfg is not None else configuracion
    plantilla = str(cfg.PASSWORD_RESET_URL_TEMPLATE)
    if "{token}" not in plantilla:
        raise ConfiguracionEmailInvalida("PASSWORD_RESET_URL_TEMPLATE({token})")
    return plantilla.format(token=token)


# ----------------------------------------------------------------------
# Implementación SMTP
# ----------------------------------------------------------------------
def _enmascarar(email: str) -> str:
    """`viajera@ika.pe` → `v***@ika.pe` (para logs: sin datos personales)."""
    local, _, dominio = email.partition("@")
    if not local:
        return "***"
    return f"{local[0]}***@{dominio}" if dominio else "***"


class SMTPEmailSender(EmailSender):
    """Envío real vía `smtplib` + `ssl` con STARTTLS.

    Valida toda la configuración **al iniciar** (en `__init__`), antes de
    que exista posibilidad de enviar algo con datos incompletos.
    """

    def __init__(self, cfg: Configuracion | None = None) -> None:
        cfg = cfg if cfg is not None else configuracion
        validar_configuracion_email(cfg)
        self._host = str(cfg.SMTP_HOST).strip()
        self._puerto = int(cfg.SMTP_PORT)
        self._usuario = str(cfg.SMTP_USER).strip()
        self._clave = str(cfg.SMTP_PASSWORD)
        self._remitente = str(cfg.SMTP_FROM or cfg.SMTP_USER).strip()
        self._starttls = bool(cfg.SMTP_STARTTLS)
        self._timeout = float(cfg.SMTP_TIMEOUT_SEGUNDOS)

    async def enviar(self, correo: Correo) -> None:
        """Delega el bloqueo de red al pool de hilos de `anyio`."""
        await anyio.to_thread.run_sync(self._enviar_bloqueante, correo)

    def _enviar_bloqueante(self, correo: Correo) -> None:
        """Corre en un hilo aparte: `smtplib` es síncrono y bloqueante."""
        mensaje = EmailMessage()
        mensaje["From"] = self._remitente
        mensaje["To"] = correo.destino
        mensaje["Subject"] = correo.asunto
        mensaje.set_content(correo.cuerpo)

        contexto = ssl.create_default_context()
        with smtplib.SMTP(self._host, self._puerto, timeout=self._timeout) as servidor:
            if self._starttls:
                servidor.starttls(context=contexto)
            servidor.login(self._usuario, self._clave)
            servidor.send_message(mensaje)

        # Solo metadatos: nunca el cuerpo, el enlace ni las credenciales.
        logger.info("Correo enviado (destino=%s)", _enmascarar(correo.destino))


# ----------------------------------------------------------------------
# Fábrica (para inyectar en los endpoints)
# ----------------------------------------------------------------------
_sender_cache: EmailSender | None = None


def obtener_email_sender() -> EmailSender:
    """Devuelve el `EmailSender` real (se valida la configuración al crearlo)."""
    global _sender_cache
    if _sender_cache is None:
        _sender_cache = SMTPEmailSender()
    return _sender_cache


def inyectar_email_sender(sender: EmailSender | None) -> None:
    """Sustituye el sender (uso exclusivo de tests para no tocar Gmail)."""
    global _sender_cache
    _sender_cache = sender
