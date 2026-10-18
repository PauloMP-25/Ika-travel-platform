"""Rutas del módulo translation: solo delegación, sin lógica de negocio."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Request, Response

from src.modules.translation.dependencies import (
    get_phrasebook,
    get_translation_service,
    limit_translations,
)
from src.modules.translation.phrasebook import Phrasebook
from src.modules.translation.schemas import (
    PhraseCategory,
    PhrasebookResponse,
    TranslationRequest,
    TranslationResponse,
)
from src.modules.translation.service import TranslationService, build_phrasebook_response

router = APIRouter(prefix="/translation", tags=["translation"])

_EJEMPLO_ERROR_503 = {
    "detail": "El servicio de traducción no está disponible. Use las frases oficiales descargadas.",
    "codigo": "TRADUCCION_PROVEEDOR_NO_DISPONIBLE",
}

_EJEMPLO_ERROR_502 = {
    "detail": "El proveedor devolvió una traducción inválida. Intente nuevamente.",
    "codigo": "TRADUCCION_RESPUESTA_INVALIDA",
}


@router.post(
    "/translate",
    response_model=TranslationResponse,
    dependencies=[Depends(limit_translations)],
    summary="Traduce texto libre es↔en (frasebook, caché o proveedor)",
    responses={
        422: {"description": "Solicitud inválida: texto vacío, demasiado largo o idiomas iguales/no soportados"},
        429: {"description": "Límite de solicitudes por IP excedido"},
        502: {"description": "El proveedor devolvió una respuesta inválida", "content": {"application/json": {"example": _EJEMPLO_ERROR_502}}},
        503: {"description": "El proveedor de traducción no está disponible", "content": {"application/json": {"example": _EJEMPLO_ERROR_503}}},
    },
)
async def translate(
    body: TranslationRequest,
    service: TranslationService = Depends(get_translation_service),
) -> TranslationResponse:
    """Público sin token (RN-02): frasebook primero, luego caché y proveedor con respaldo."""
    return await service.translate(body)


@router.get(
    "/phrases",
    response_model=PhrasebookResponse,
    summary="Frasebook oficial versionado con ETag (32 frases, 8 categorías)",
    responses={
        304: {"description": "El ETag enviado en If-None-Match sigue vigente (respuesta sin cuerpo)"},
        422: {"description": "Categoría no soportada"},
    },
)
async def list_phrases(
    request: Request,
    response: Response,
    category: PhraseCategory | None = None,
    phrasebook: Phrasebook = Depends(get_phrasebook),
) -> PhrasebookResponse | Response:
    """Listado público de frases oficiales con caché de 1 h y revalidación por ETag."""
    payload = build_phrasebook_response(phrasebook, category)
    etag = f'"{payload.version}-{category.value if category else "all"}"'
    if request.headers.get("if-none-match") == etag:
        return Response(status_code=304, headers={"ETag": etag})
    response.headers["ETag"] = etag
    response.headers["Cache-Control"] = "public, max-age=3600"
    return payload
