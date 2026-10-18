"""Contratos comunes de las autenticaciones sociales (Sprint 4, F1).

`IdentidadSocial` es lo único que el servicio de usuarios necesita saber de
un proveedor: quién es la persona y si su correo está verificado. Las
estrategias concretas (Google, y en el futuro Facebook) traducen su token
propio a este dataclass.
"""

from dataclasses import dataclass
from typing import Protocol, runtime_checkable


@dataclass(frozen=True, slots=True)
class IdentidadSocial:
    """Identidad verificada extraída del token del proveedor social."""

    proveedor: str
    id_proveedor: str  # 'sub' de Google
    email: str
    email_verificado: bool
    nombre_completo: str


@runtime_checkable
class EstrategiaAutenticacionSocial(Protocol):
    """Contrato que toda estrategia social debe cumplir (patrón Strategy)."""

    proveedor: str

    async def verificar(self, token: str) -> IdentidadSocial:
        """Valida el token y devuelve la identidad o lanza `UsersException`."""
        ...
