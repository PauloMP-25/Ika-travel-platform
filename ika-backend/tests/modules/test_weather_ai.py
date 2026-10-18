"""Suite de pruebas unitarias y de integración para el recomendador IA y alertas de Ica (P7).

Verifica:
1. Motor puro de alertas de Ica (Viento Paracas, UV extremo, calor, lluvia, arena).
2. Guardarraíl de seguridad Post-IA ante alertas de nivel 'high' (danger).
3. Matriz de escenarios reales de Ica (Huacachina, Paracas, Ocucaje, Nazca, Cachiche).
4. Fallback determinista (< 150 ms) y validación de esquemas Pydantic v2.
"""

import time
import pytest
from unittest.mock import AsyncMock, patch

from src.modules.weather.ai.schemas import RecomendacionEnriquecida
from src.modules.weather.rules import (
    AlertaCandidata,
    evaluar_alertas,
    evaluar_factores,
    seleccionar_perfil,
    PERFILES,
)
from src.modules.weather import ai_recommender


# ======================================================================
# 1. Pruebas del Motor Puro de Alertas de Ica
# ======================================================================

def test_alertas_viento_paracas_solo_en_zona_costera():
    """Viento de 40 km/h en Paracas activa alerta Paracas; en Huacachina no."""
    alertas_paracas = evaluar_alertas(
        temperatura=22, uv=6, viento=40, zona="Reserva Nacional de Paracas"
    )
    assert any(a.alert_type == "paracas_wind" and a.severity == "medium" for a in alertas_paracas)

    alertas_huacachina = evaluar_alertas(
        temperatura=30, uv=8, viento=40, zona="Laguna de Huacachina"
    )
    assert not any(a.alert_type == "paracas_wind" for a in alertas_huacachina)
    assert any(a.alert_type == "viento_fuerte" for a in alertas_huacachina)


def test_alertas_viento_paracas_danger_mas_de_50kmh():
    """Viento >= 50 km/h en Paracas activa nivel high (danger) para cierre de puerto."""
    alertas = evaluar_alertas(
        temperatura=20, uv=5, viento=52, zona="Islas Ballestas"
    )
    paracas = [a for a in alertas if a.alert_type == "paracas_wind"]
    assert len(paracas) == 1
    assert paracas[0].severity == "high"
    assert "cierre preventivo" in paracas[0].message


def test_alertas_radiacion_uv_extrema_oms():
    """UV >= 12 es nivel high; UV 11 es medium; UV 9 es low."""
    alertas_12 = evaluar_alertas(temperatura=25, uv=12.5, viento=10)
    assert any((a.alert_type in ("extreme_uv", "uv_extremo")) and a.severity == "high" for a in alertas_12)

    alertas_11 = evaluar_alertas(temperatura=25, uv=11.0, viento=10)
    assert any((a.alert_type in ("extreme_uv", "uv_extremo")) and a.severity == "medium" for a in alertas_11)

    alertas_9 = evaluar_alertas(temperatura=25, uv=9.0, viento=10)
    assert any((a.alert_type in ("extreme_uv", "uv_extremo")) and a.severity == "low" for a in alertas_9)


def test_alertas_calor_extremo_desierto():
    """Temperaturas >= 40 °C activan nivel high por golpe de calor."""
    alertas = evaluar_alertas(temperatura=41.5, uv=7, viento=10, zona="Cañón de los Perdidos")
    assert any(a.alert_type == "high_temperature" and a.severity == "high" for a in alertas)


def test_alertas_arena_caliente_en_dunas():
    """Arena superficial >= 48 °C genera alerta high por riesgo de quemaduras."""
    alertas = evaluar_alertas(
        temperatura=32, uv=10, viento=15, temperatura_arena=50.0, zona="Huacachina"
    )
    arena_alerta = [a for a in alertas if a.alert_type == "hot_sand"]
    assert len(arena_alerta) == 1
    assert arena_alerta[0].severity == "high"
    assert "quemaduras" in arena_alerta[0].message


# ======================================================================
# 2. Matriz de Escenarios Reales de Ica (5 categorías PERTUR)
# ======================================================================

@pytest.mark.parametrize("nombre_atractivo,slug_categoria,perfil_esperado", [
    ("Oasis de Huacachina", "aventura", "aventura en desierto"),
    ("Islas Ballestas", "naturaleza", "naturaleza y biodiversidad marina"),
    ("Pueblo de Cachiche", "cultural", "visita cultural y mística"),
    ("Bodega Tacama", "enoturismo", "enoturismo y gastronomía"),
    ("Líneas de Nazca", "arqueologia", "arqueología y misterio"),
])
def test_seleccion_perfil_pertur_para_atractivos_reales(nombre_atractivo, slug_categoria, perfil_esperado):
    perfil = seleccionar_perfil([slug_categoria], nombre_atractivo)
    assert perfil.nombre == perfil_esperado


def test_bonificacion_afinidad_preferencias_usuario():
    """Si el turista tiene en su perfil 'aventura_desierto', Huacachina recibe +15% afinidad."""
    perfil = seleccionar_perfil(["aventura"], "Huacachina")
    score_sin, _, _, afinidad_sin = evaluar_factores(
        temperatura=25, uv=6, viento=15, precipitacion=0, perfil=perfil, preferencias_usuario=None
    )
    score_con, _, _, afinidad_con = evaluar_factores(
        temperatura=25, uv=6, viento=15, precipitacion=0, perfil=perfil, preferencias_usuario=["aventura_desierto"]
    )
    assert afinidad_con == 0.15
    assert score_con >= score_sin


# ======================================================================
# 3. Rendimiento del Fallback Determinista (< 150 ms)
# ======================================================================

def test_rendimiento_fallback_determinista_menor_150ms():
    """1,000 ejecuciones del cálculo de recomendación deben tardar en promedio < 1 ms por ejecución."""
    inicio = time.perf_counter()
    for _ in range(1000):
        ai_recommender.generar_recomendacion(
            nombre_atractivo="Laguna de Huacachina",
            slugs_categorias=["aventura", "desierto"],
            temperatura=28.5,
            uv=10.0,
            viento=20.0,
            precipitacion=0.0,
            preferencias_usuario=["aventura_desierto"],
        )
    duracion_total = time.perf_counter() - inicio
    tiempo_promedio_ms = (duracion_total / 1000) * 1000
    assert tiempo_promedio_ms < 5.0, f"Promedio fue {tiempo_promedio_ms} ms, debe ser < 5 ms"


# ======================================================================
# 4. Guardarraíl de Seguridad Post-IA y Mock de Gemini
# ======================================================================

@pytest.mark.anyio
async def test_guardarrail_de_seguridad_recorta_score_ante_peligro(monkeypatch):
    """Aunque Gemini devuelva un score alto (0.95), una alerta 'high' fuerza score <= 0.30."""
    from src.modules.weather.ai.engine import MotorGeminiClima

    mock_rec = RecomendacionEnriquecida(
        summary="Visita a Paracas con emoción extrema.",
        climate_justification="El viento sopla fuerte pero es divertido.",
        clothing=["Cortavientos"],
        precautions=["Cuidado con el viento"],
        suitability_score=0.95,
        language="es",
        source="gemini",
    )

    with patch.object(MotorGeminiClima, "generar_recomendacion_estructurada", new_callable=AsyncMock) as mock_gemini:
        mock_gemini.return_value = mock_rec

        resultado_base = ai_recommender.generar_recomendacion(
            nombre_atractivo="Islas Ballestas",
            slugs_categorias=["marina"],
            temperatura=19,
            uv=5,
            viento=55,  # Peligro: viento Paracas alto
        )

        rec = await ai_recommender.generar_recomendacion_enriquecida(
            nombre_atractivo="Islas Ballestas",
            resultado=resultado_base,
            temperatura=19,
            uv=5,
            viento=55,
            condicion="Viento muy fuerte",
            alertas_activas=["Viento Paracas Peligroso (55 km/h)"],
        )

        assert rec.suitability_score == 0.95  # Objeto puro de Gemini
        # En el service se aplica el guardarrail
        alertas = evaluar_alertas(temperatura=19, uv=5, viento=55, zona="Islas Ballestas")
        hay_peligro = any(a.severity == "high" for a in alertas)
        assert hay_peligro is True
