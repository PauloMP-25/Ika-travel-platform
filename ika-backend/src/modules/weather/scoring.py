"""Puntuación determinista de recomendaciones turísticas según clima (reglas puras, sin IA)."""

from __future__ import annotations

import logging
from dataclasses import dataclass

from src.modules.weather.rules import (
    PERFILES,
    PerfilActividad,
    detectar_alertas,
    evaluar_factores,
    nivel_desde_puntaje,
    seleccionar_perfil,
)

logger = logging.getLogger(__name__)

__all__ = [
    "PERFILES",
    "PerfilActividad",
    "ResultadoRecomendacion",
    "seleccionar_perfil",
    "nivel_desde_puntaje",
    "generar_recomendacion",
    "detectar_alertas",
]


@dataclass(frozen=True)
class ResultadoRecomendacion:
    score: float
    nivel: str
    texto: str
    factores: dict[str, float]
    consejos: list[str]
    perfil: str
    afinidad_preferencia: float = 0.0


_ENCABEZADOS = {
    "excelente": "Condiciones excelentes para visitar",
    "bueno": "Buen momento para disfrutar de",
    "regular": "Condiciones moderadas en",
    "no_recomendado": "No se recomienda realizar visitas en este momento a",
}


def _describir_viento(kmh: float) -> str:
    if kmh < 15:
        return "viento suave"
    if kmh < 30:
        return "viento moderado"
    if kmh < 45:
        return "viento fuerte"
    return "viento muy fuerte"


def _describir_uv(indice: float) -> str:
    if indice < 3:
        return "UV bajo"
    if indice < 6:
        return "UV moderado"
    if indice < 8:
        return "UV alto"
    if indice < 11:
        return "UV muy alto"
    return "UV extremo"


def generar_recomendacion(
    *,
    nombre_atractivo: str,
    slugs_categorias: list[str],
    temperatura: float,
    uv: float,
    viento: float,
    precipitacion: float = 0.0,
    preferencias_usuario: list[str] | None = None,
) -> ResultadoRecomendacion:
    """Calcula y devuelve la recomendación basada en reglas deterministas (Fallback rápido)."""
    perfil = seleccionar_perfil(slugs_categorias, nombre_atractivo)
    score, factores, consejos, afinidad = evaluar_factores(
        temperatura=temperatura,
        uv=uv,
        viento=viento,
        precipitacion=precipitacion,
        perfil=perfil,
        preferencias_usuario=preferencias_usuario,
    )
    nivel = nivel_desde_puntaje(score)
    encabezado = _ENCABEZADOS[nivel]
    sujeto = f"{encabezado} {nombre_atractivo}" if nivel != "no_recomendado" else f"{encabezado}: {nombre_atractivo}"
    detalle = f"{temperatura:.0f} °C, {_describir_viento(viento)} ({viento:.0f} km/h), {_describir_uv(uv)} ({uv:.0f})"
    texto = f"{sujeto}. Condiciones actuales: {detalle}."
    if afinidad > 0:
        texto += " (Recomendado según tus preferencias de viaje en Ica)."
    if consejos:
        texto += " " + " ".join(consejos)

    return ResultadoRecomendacion(
        score=score,
        nivel=nivel,
        texto=texto[:900],
        factores=factores,
        consejos=consejos,
        perfil=perfil.nombre,
        afinidad_preferencia=afinidad,
    )
