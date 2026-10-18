"""Estrategia de autenticación con Google (Sprint 4, F1).

Verifica el `id_token` emitido por Google Sign-In con `google-auth`. La
verificación de firma es síncrona (`verify_oauth2_token` hace una petición
de red a los certificados de Google), así que se ejecuta en un hilo del
pool de `anyio` para no bloquear el event loop.

Se almacenan únicamente `sub`, email y nombre (minimización de datos,
Ley N° 29733). El ID token NO se persiste.
"""

from typing import Any

import anyio
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token

from src.modules.users.exceptions import (
    EmailSocialNoVerificadoException,
    TokenSocialInvalidoException,
)
from src.modules.users.auth_strategies.base import IdentidadSocial

# Emisores válidos de un id_token de Google (firma emitida por Google).
_EMISORES_VALIDOS = {"accounts.google.com", "https://accounts.google.com"}


class GoogleAuthStrategy:
    """Verifica tokens de Google y devuelve una `IdentidadSocial`."""

    proveedor = "google"

    def __init__(self, client_ids: list[str]) -> None:
        self._client_ids = set(client_ids)

    async def verificar(self, token: str) -> IdentidadSocial:
        try:
            claims = await anyio.to_thread.run_sync(self._verificar_sync, token)
        except ValueError as exc:  # firma, expiración o formato inválidos
            raise TokenSocialInvalidoException() from exc

        # `aud` se valida contra la lista completa de client IDs (Android,
        # iOS y web), no contra uno solo.
        if claims.get("iss") not in _EMISORES_VALIDOS:
            raise TokenSocialInvalidoException()
        if not self._client_ids or claims.get("aud") not in self._client_ids:
            raise TokenSocialInvalidoException()
        if claims.get("email") is None:
            raise TokenSocialInvalidoException()
        if claims.get("email_verified") is not True:
            raise EmailSocialNoVerificadoException()

        email = str(claims["email"]).lower()
        return IdentidadSocial(
            proveedor=self.proveedor,
            id_proveedor=str(claims["sub"]),
            email=email,
            email_verificado=True,
            nombre_completo=str(claims.get("name") or email),
        )

    @staticmethod
    def _verificar_sync(token: str) -> dict[str, Any]:
        # audience=None: la comprobación de `aud` (varios client IDs) se hace
        # arriba, contra GOOGLE_CLIENT_IDS del entorno.
        return id_token.verify_oauth2_token(token, google_requests.Request(), audience=None)
