"""Cliente y ejecutor de Google Gemini AI para el módulo meteorológico de Ica."""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Optional

from google import genai
from google.genai import types

from src.core.config import configuracion
from src.modules.weather.ai.schemas import RecomendacionEnriquecida
from src.shared.ai_logging import registrar_consumo_tokens

logger = logging.getLogger(__name__)


class MotorGeminiClima:
    """Ejecutor de llamadas a Gemini utilizando Structured Outputs."""

    def __init__(self, api_key: str, modelo: str = "gemini-3.1-flash-lite", timeout_segundos: float = 8.0) -> None:
        self._api_key = api_key
        self._modelo = modelo
        self._timeout_segundos = timeout_segundos
        self._client: genai.Client | None = None

    def _obtener_cliente(self) -> genai.Client:
        if self._client is None:
            self._client = genai.Client(api_key=self._api_key)
        return self._client

    async def generar_recomendacion_estructurada(
        self, prompt_xml: str, idioma: str = "es"
    ) -> Optional[RecomendacionEnriquecida]:
        """Invoca a Gemini con Structured Outputs en base al prompt XML estructurado."""
        if not self._api_key:
            logger.info("[GEMINI-CLIMA] No hay GEMINI_API_KEY configurada; se usará fallback.")
            return None

        t0 = time.time()
        try:
            client = self._obtener_cliente()
            resp = await asyncio.wait_for(
                client.aio.models.generate_content(
                    model=self._modelo,
                    contents=prompt_xml,
                    config=types.GenerateContentConfig(
                        temperature=0.2,
                        response_mime_type="application/json",
                        response_schema=RecomendacionEnriquecida,
                    ),
                ),
                timeout=self._timeout_segundos,
            )

            duracion = time.time() - t0

            if not resp.text:
                logger.warning("[GEMINI-CLIMA] Gemini devolvió respuesta vacía.")
                return None

            # Registro visual de consumo de tokens
            registrar_consumo_tokens(
                operacion="Recomendación Meteorológica Inteligente",
                modelo=self._modelo,
                tiempo_segundos=duracion,
                usage_metadata=getattr(resp, "usage_metadata", None),
                detalles_extra=f"Idioma: {idioma} | Salida: JSON estructurado",
            )

            rec = RecomendacionEnriquecida.model_validate_json(resp.text)
            rec.language = "en" if idioma == "en" else "es"
            rec.source = "gemini"
            return rec

        except Exception as exc:
            duracion = time.time() - t0
            logger.warning("[GEMINI-CLIMA] Excepción al llamar a Gemini (%s): %s", type(exc).__name__, exc)
            return None
