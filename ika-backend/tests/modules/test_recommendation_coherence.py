"""Tests unitarios para la coherencia de recomendaciones turísticas y descarte de falsos positivos en alertas."""

from unittest.mock import patch
import pytest
from src.modules.weather import rules
from src.modules.weather.scoring import ResultadoRecomendacion
from src.modules.ai_engine.prompts import generar_prompt_recomendacion_turistica
from src.modules.ai_engine.recommender import generar_recomendacion_enriquecida


def test_hot_sand_no_aplica_a_islas_ballestas():
    """Islas Ballestas está en el mar/islas; una alta temperatura de suelo (57°C) no debe generar alerta hot_sand."""
    alertas = rules.evaluar_alertas(
        temperatura=28.0,
        uv=8.0,
        viento=16.0,
        precipitacion=0.0,
        temperatura_arena=57.0,
        zona="Islas Ballestas",
    )
    codigos = [a.code for a in alertas]
    assert "hot_sand" not in codigos


def test_hot_sand_si_aplica_a_huacachina():
    """En las dunas de Huacachina, temperatura de arena >= 45°C debe generar alerta crítica de hot_sand."""
    alertas = rules.evaluar_alertas(
        temperatura=32.0,
        uv=10.0,
        viento=15.0,
        precipitacion=0.0,
        temperatura_arena=55.0,
        zona="Oasis de Huacachina",
    )
    codigos = [a.code for a in alertas]
    assert "hot_sand" in codigos
    alerta_arena = next(a for a in alertas if a.code == "hot_sand")
    assert alerta_arena.severity == "high"


def test_prompt_no_recomendado_exige_advertencia_y_prohibe_invitacion():
    """Cuando el sistema califica NO_RECOMENDADO, el prompt debe exigir advertencia clara y justificación de riesgo."""
    prompt = generar_prompt_recomendacion_turistica(
        nombre_atractivo="Islas Ballestas",
        categoria_pertur="Naturaleza y Fauna",
        atractivos_alternativos=["Bodega Tacama", "Museo Regional de Ica"],
        temperatura=24.0,
        viento=52.0,
        uv=6.0,
        condicion_cielo="Cielo cubierto con viento fuerte",
        score_calculado=0.25,
        nivel_calculado="no_recomendado",
        afinidad_preferencias=True,
        alertas_activas=["Viento Paracas Peligroso (52 km/h): cierre preventivo de muelles"],
        consejos_base=["Evitar navegación marítima"],
    )

    assert "ATENCIÓN CRÍTICA: El dictamen oficial del sistema para Islas Ballestas es NO_RECOMENDADO" in prompt
    assert "Bajo NINGUNA circunstancia debes elogiar la visita ni invitar a ir hoy" in prompt
    assert "desaconsejando la visita a Islas Ballestas" in prompt
    assert "Bodega Tacama" in prompt


@pytest.mark.anyio
async def test_narrativa_gemini_no_recomendado_es_coherente():
    """Verifica que Gemini elabore una narrativa de advertencia y no una invitación cuando el score es bajo."""
    res = ResultadoRecomendacion(
        score=0.28,
        nivel="no_recomendado",
        texto="No se recomienda la visita.",
        factores={"viento": 0.2},
        consejos=["No navegar"],
        perfil="Naturaleza",
    )
    enriquecida = await generar_recomendacion_enriquecida(
        nombre_atractivo="Islas Ballestas",
        resultado=res,
        temperatura=22.0,
        uv=5.0,
        viento=50.0,
        condicion="Viento Paracas fuerte",
        alertas_activas=["Viento Paracas Peligroso (50 km/h)"],
    )

    assert enriquecida.suitability_score == 0.28
    resumen_lower = enriquecida.summary.lower()
    # Debe ser una advertencia preventiva, nunca un elogio de visita
    assert any(w in resumen_lower for w in ["no es recomendable", "desaconseja", "no se recomienda", "peligro", "advertencia"])
    assert "perfecto para visitar" not in resumen_lower
    assert "excelente momento" not in resumen_lower


@pytest.mark.anyio
async def test_fallback_enriquecido_no_recomendado():
    """En caso de fallback sin conexión con Gemini, el texto determinista debe ser coherente con NO_RECOMENDADO."""
    res = ResultadoRecomendacion(
        score=0.25,
        nivel="no_recomendado",
        texto="No se recomienda la visita.",
        factores={"viento": 0.2},
        consejos=["No navegar"],
        perfil="Naturaleza",
    )
    # Forzar fallback simulando fallo en generar_recomendacion_estructurada
    with patch("src.modules.ai_engine.engine.MotorGeminiClima.generar_recomendacion_estructurada", return_value=None):
        enriquecida = await generar_recomendacion_enriquecida(
            nombre_atractivo="Islas Ballestas",
            resultado=res,
            temperatura=22.0,
            uv=5.0,
            viento=50.0,
            condicion="Viento Paracas fuerte",
            alertas_activas=["Viento Paracas Peligroso (50 km/h)"],
        )

    assert enriquecida.source == "fallback"
    assert enriquecida.suitability_score == 0.25
    assert "No se recomienda visitar Islas Ballestas" in enriquecida.summary
    assert "Condiciones adversas en la zona" in enriquecida.climate_justification
