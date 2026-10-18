"""Contratos offline-first: caché HTTP con ETag (Sprint 4, F3).

El ETag se calcula sobre el **cuerpo ya filtrado y paginado**, así que cada
combinación de query params tiene su propio valor. Efecto colateral útil
(RN-01): si una agencia deja de estar validada, el listado cambia y su ETag
también, sin tener que rastrear `updated_at`.

El cliente siempre revalida (`Cache-Control: no-cache`): ahorra ancho de
banda sin servir datos obsoletos.
"""

import hashlib
import json
from typing import Any

from fastapi import Request, Response
from pydantic import BaseModel


def serializar_canonico(payload: Any) -> str:
    """JSON determinista: claves ordenadas y sin espacios sobrantes."""
    if isinstance(payload, BaseModel):
        payload = payload.model_dump(mode="json")
    elif isinstance(payload, list):
        payload = [
            item.model_dump(mode="json") if isinstance(item, BaseModel) else item
            for item in payload
        ]
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str)


def calcular_etag(payload: Any) -> str:
    """ETag débil `W/"<sha256[:32]>"` sobre la serialización canónica."""
    huella = hashlib.sha256(serializar_canonico(payload).encode("utf-8")).hexdigest()
    return f'W/"{huella[:32]}"'


def coincide_if_none_match(if_none_match: str | None, etag: str) -> bool:
    """Compara `If-None-Match` con el ETag (acepta `*` y varias comas)."""
    if not if_none_match:
        return False
    candidatos = {valor.strip() for valor in if_none_match.split(",")}
    return "*" in candidatos or etag in candidatos


def responder_con_etag(request: Request, payload: Any) -> Response:
    """200 con el cuerpo y su ETag, o **304 sin cuerpo** si ya está vigente."""
    etag = calcular_etag(payload)
    cabeceras = {"ETag": etag, "Cache-Control": "no-cache"}
    if coincide_if_none_match(request.headers.get("if-none-match"), etag):
        return Response(status_code=304, headers=cabeceras)
    if isinstance(payload, BaseModel):
        cuerpo = payload.model_dump_json()
    else:
        cuerpo = json.dumps(
            [
                item.model_dump(mode="json") if isinstance(item, BaseModel) else item
                for item in payload
            ],
            default=str,
        )
    return Response(content=cuerpo, media_type="application/json", headers=cabeceras)
