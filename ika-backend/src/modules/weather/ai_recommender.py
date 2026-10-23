"""Motor de recomendación turística: orquestación de reglas puras, fallback y Gemini IA."""

from __future__ import annotations

import httpx
import logging
from dataclasses import dataclass

from src.core.config import configuracion
from src.modules.weather.ai.engine import MotorGeminiClima
from src.modules.weather.ai.prompts import generar_prompt_recomendacion_turistica
from src.modules.weather.ai.schemas import RecomendacionEnriquecida
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
    "redactar_con_gemini",
    "generar_recomendacion_enriquecida",
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


# Motor Gemini singleton / perezoso
_motor_gemini: MotorGeminiClima | None = None


def _obtener_motor_gemini() -> MotorGeminiClima:
    global _motor_gemini
    if _motor_gemini is None:
        _motor_gemini = MotorGeminiClima(
            api_key=configuracion.GEMINI_API_KEY,
            modelo=configuracion.GEMINI_MODELO,
            timeout_segundos=configuracion.GEMINI_TIMEOUT_SEGUNDOS,
        )
    return _motor_gemini


async def generar_recomendacion_enriquecida(
    *,
    nombre_atractivo: str,
    resultado: ResultadoRecomendacion,
    temperatura: float,
    uv: float,
    viento: float,
    condicion: str,
    alertas_activas: list[str] | None = None,
    preferencias_usuario: list[str] | None = None,
    idioma: str = "es",
    # Variables ampliadas
    presion_hpa: float | None = None,
    precipitacion_mm: float | None = None,
    temperatura_arena: float | None = None,
    pm10: float | None = None,
    ventana_pico_uv: str | None = None,
    horas_sol: float | None = None,
    altura_ola: float | None = None,
    narrativa_previa: str | None = None,
    atractivos_alternativos: list[str] | None = None,
) -> RecomendacionEnriquecida:
    """Genera la recomendación enriquecida utilizando Gemini (XML estructurado) o Fallback determinista."""
    motor = _obtener_motor_gemini()
    prompt_xml = generar_prompt_recomendacion_turistica(
        nombre_atractivo=nombre_atractivo,
        categoria_pertur=resultado.perfil,
        temperatura=temperatura,
        viento=viento,
        uv=uv,
        condicion_cielo=condicion,
        score_calculado=resultado.score,
        nivel_calculado=resultado.nivel,
        afinidad_preferencias=resultado.afinidad_preferencia > 0,
        alertas_activas=alertas_activas or [],
        consejos_base=resultado.consejos,
        intereses_turista=preferencias_usuario,
        idioma=idioma,
        presion_hpa=presion_hpa,
        precipitacion_mm=precipitacion_mm,
        temperatura_arena=temperatura_arena,
        pm10=pm10,
        ventana_pico_uv=ventana_pico_uv,
        horas_sol=horas_sol,
        altura_ola=altura_ola,
        narrativa_previa=narrativa_previa,
        atractivos_alternativos=atractivos_alternativos,
    )

    respuesta_gemini = await motor.generar_recomendacion_estructurada(prompt_xml, idioma=idioma)
    if respuesta_gemini is not None:
        return respuesta_gemini

    # Fallback determinista estructurado (< 150 ms, sin I/O)
    prendas = ["Ropa ligera y fresca", "Lentes de sol", "Sombrero o gorro"]
    if viento >= 30:
        prendas.append("Cortavientos")
    if temperatura_arena and temperatura_arena >= 38:
        prendas.append("Calzado deportivo cerrado para arena")

    precauciones = list(resultado.consejos) or ["Mantener hidratación constante"]
    if ventana_pico_uv:
        precauciones.append(f"Evitar exposición solar directa entre {ventana_pico_uv}")

    resumen = (
        f"Condiciones óptimas en {nombre_atractivo} para disfrutar al máximo."
        if resultado.score >= 0.7
        else f"Visita moderada en {nombre_atractivo}; toma en cuenta las condiciones del clima."
    )

    return RecomendacionEnriquecida(
        summary=resumen,
        climate_justification=f"Clima en Ica: {temperatura:.0f} °C con viento de {viento:.0f} km/h y UV {uv:.0f}.",
        clothing=prendas[:4],
        precautions=precauciones[:4],
        suitability_score=resultado.score,
        language="en" if idioma == "en" else "es",
        source="fallback",
    )


async def redactar_con_gemini(
    *,
    nombre_atractivo: str,
    resultado: ResultadoRecomendacion,
    temperatura: float,
    uv: float,
    viento: float,
    condicion: str,
    preferencias_usuario: list[str] | None = None,
    idioma: str = "es",
    # Nuevos kwargs opcionales para máxima flexibilidad
    presion_hpa: float | None = None,
    precipitacion_mm: float | None = None,
    temperatura_arena: float | None = None,
    pm10: float | None = None,
    ventana_pico_uv: str | None = None,
    horas_sol: float | None = None,
    altura_ola: float | None = None,
    narrativa_previa: str | None = None,
    atractivos_alternativos: list[str] | None = None,
) -> tuple[str | None, list[str]]:
    """Devuelve texto narrativo y lista de consejos/precauciones estructurados por Gemini."""
    enriquecida = await generar_recomendacion_enriquecida(
        nombre_atractivo=nombre_atractivo,
        resultado=resultado,
        temperatura=temperatura,
        uv=uv,
        viento=viento,
        condicion=condicion,
        preferencias_usuario=preferencias_usuario,
        idioma=idioma,
        presion_hpa=presion_hpa,
        precipitacion_mm=precipitacion_mm,
        temperatura_arena=temperatura_arena,
        pm10=pm10,
        ventana_pico_uv=ventana_pico_uv,
        horas_sol=horas_sol,
        altura_ola=altura_ola,
        narrativa_previa=narrativa_previa,
        atractivos_alternativos=atractivos_alternativos,
    )
    if enriquecida.source == "gemini":
        texto = f"{enriquecida.summary} {enriquecida.climate_justification}"
        return texto, enriquecida.precautions
    return None, []
