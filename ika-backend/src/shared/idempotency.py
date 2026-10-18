"""Idempotencia de peticiones de creación (Sprint 4, F4).

Cabecera **opcional** `Idempotency-Key` (los clientes actuales no se rompen).
Su ámbito es el usuario autenticado: dos usuarios pueden usar la misma clave
sin pisarse. El formato esperado es el de un UUID v4 generado por la app.
"""

import hashlib
import json
import re

from fastapi import Header
from pydantic import BaseModel

from src.shared.exceptions import IdempotencyKeyInvalidaError

_PATRON = re.compile(r"^[A-Za-z0-9_-]{8,64}$")


def obtener_clave_idempotencia(
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> str | None:
    """Dependencia FastAPI: valida el formato de la cabecera (opcional)."""
    if idempotency_key is not None and not _PATRON.fullmatch(idempotency_key):
        raise IdempotencyKeyInvalidaError()
    return idempotency_key


def calcular_hash_solicitud(payload: BaseModel) -> str:
    """Huella del cuerpo canónico: detecta la misma clave con payload distinto."""
    canonico = json.dumps(payload.model_dump(mode="json"), sort_keys=True, default=str)
    return hashlib.sha256(canonico.encode("utf-8")).hexdigest()
