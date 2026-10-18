"""Registro de estrategias de autenticación social (Sprint 4, F1).

Para añadir Facebook basta con crear la estrategia e incluirla en
`ESTRATEGIAS_SOCIALES`: ni el servicio ni el router cambian.
"""

from src.core.config import configuracion
from src.modules.users.auth_strategies.base import (
    EstrategiaAutenticacionSocial,
    IdentidadSocial,
)
from src.modules.users.auth_strategies.google import GoogleAuthStrategy

ESTRATEGIAS_SOCIALES: dict[str, EstrategiaAutenticacionSocial] = {
    GoogleAuthStrategy.proveedor: GoogleAuthStrategy(configuracion.google_client_ids_lista),
}


def obtener_estrategia(proveedor: str) -> EstrategiaAutenticacionSocial | None:
    """Devuelve la estrategia registrada o `None` si el proveedor no existe."""
    return ESTRATEGIAS_SOCIALES.get(proveedor)


__all__ = [
    "ESTRATEGIAS_SOCIALES",
    "EstrategiaAutenticacionSocial",
    "GoogleAuthStrategy",
    "IdentidadSocial",
    "obtener_estrategia",
]
