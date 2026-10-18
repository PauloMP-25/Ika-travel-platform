"""Excepciones compartidas entre módulos (Sprint 4).

Heredan de `ErrorDeNegocio`, así que el manejador global las devuelve con su
código HTTP y su `codigo` estable.
"""

from src.core.exceptions import ErrorDeNegocio


class IdempotencyKeyInvalidaError(ErrorDeNegocio):
    """La cabecera `Idempotency-Key` no cumple el formato permitido (HTTP 400)."""

    codigo_http = 400
    codigo = "IDEMPOTENCY_KEY_INVALIDA"
    mensaje_por_defecto = (
        "Idempotency-Key inválida: usa entre 8 y 64 caracteres de [A-Za-z0-9_-]."
    )


class IdempotencyKeyReutilizadaError(ErrorDeNegocio):
    """Se reutilizó la misma clave con un payload distinto (HTTP 422)."""

    codigo_http = 422
    codigo = "IDEMPOTENCY_KEY_REUTILIZADA"
    mensaje_por_defecto = (
        "La Idempotency-Key ya se usó con una solicitud diferente."
    )
