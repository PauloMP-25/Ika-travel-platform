"""Esquemas Pydantic v2 para las recomendaciones estructuradas generadas por IA."""

from __future__ import annotations

from typing import Literal
from pydantic import BaseModel, Field


class RecomendacionEnriquecida(BaseModel):
    """Contrato formal devuelto por Gemini Structured Outputs o por el Fallback determinista."""

    summary: str = Field(description="Resumen breve de la recomendación turística (máx 250 caracteres)")
    climate_justification: str = Field(description="Justificación basada en el clima de Ica")
    clothing: list[str] = Field(description="Lista de 2 a 4 prendas sugeridas")
    precautions: list[str] = Field(description="Lista de 1 a 4 precauciones para el clima")
    suitability_score: float = Field(ge=0.0, le=1.0, description="Puntaje de idoneidad calculado por el sistema")
    language: Literal["es", "en"] = Field(default="es", description="Idioma de la narrativa")
    source: Literal["gemini", "fallback"] = Field(default="gemini", description="Origen de la recomendación")
