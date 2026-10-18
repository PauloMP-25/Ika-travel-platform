"""Cliente y ejecutor de Google Gemini AI para el módulo meteorológico de Ica."""

from __future__ import annotations

import asyncio
import logging
from typing import Optional

from google import genai
from google.genai import types

from src.core.config import configuracion
from src.modules.weather.ai.schemas import RecomendacionEnriquecida

logger = logging.getLogger(__name__)


class MotorGeminiClima:
    """Ejecutor de llamadas a Gemini utilizando Structured Outputs."""

    def __init__(self, api_key: str, modelo: str = "gemini-flash-latest", timeout_segundos: float = 8.0) -> None:
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

            if not resp.text:
                logger.warning("[GEMINI-CLIMA] Gemini devolvió respuesta vacía.")
                return None

            rec = RecomendacionEnriquecida.model_validate_json(resp.text)
            rec.language = "en" if idioma == "en" else "es"
            rec.source = "gemini"
            return rec

        except Exception as exc:
            logger.warning("[GEMINI-CLIMA] Excepción al llamar a Gemini (%s): %s", type(exc).__name__, exc)
            return None
