"""Suite de verificación de la separación del módulo `ai_engine` respecto de `weather` (5 tests críticos)."""

import importlib
import sys
import time

import pytest

from src.modules.ai_engine import recommender as ai_engine
from src.modules.ai_engine.prompts import generar_prompt_recomendacion_turistica
from src.modules.ai_engine.schemas import RecomendacionEnriquecida
from src.modules.weather import scoring


def _resultado_base():
    return scoring.generar_recomendacion(
        nombre_atractivo="Huacachina",
        slugs_categorias=[],
        temperatura=28,
        uv=8,
        viento=12,
        precipitacion=0,
    )


def test_ai_engine_initialization():
    """El módulo carga sus esquemas y el cliente Gemini sin importar la capa de servicio de weather."""
    assert RecomendacionEnriquecida.model_fields["source"].default == "gemini"
    paquete = importlib.import_module("src.modules.ai_engine")
    for nombre in ("MotorGeminiClima", "RecomendacionEnriquecida", "generar_prompt_recomendacion_turistica"):
        assert hasattr(paquete, nombre)
    assert hasattr(ai_engine, "generar_recomendacion_enriquecida")
    assert hasattr(ai_engine, "redactar_con_gemini")


def test_ai_prompt_generation_bilingual():
    """El prompt estructurado contiene el contexto del atractivo y respeta el idioma solicitado."""
    kwargs = dict(
        nombre_atractivo="Huacachina",
        categoria_pertur="aventura",
        temperatura=30,
        viento=15,
        uv=9,
        condicion_cielo="Despejado",
        score_calculado=0.8,
        nivel_calculado="bueno",
        afinidad_preferencias=True,
        alertas_activas=[],
        consejos_base=[],
        intereses_turista=["aventura"],
    )
    prompt_es = generar_prompt_recomendacion_turistica(idioma="es", **kwargs)
    prompt_en = generar_prompt_recomendacion_turistica(idioma="en", **kwargs)
    assert "Huacachina" in prompt_es and "Huacachina" in prompt_en
    assert prompt_es != prompt_en


@pytest.mark.anyio
async def test_ai_recommender_fallback_deterministic(monkeypatch):
    """Sin API key de Gemini se activa el fallback determinista en < 150 ms con source='fallback'."""
    monkeypatch.setattr(ai_engine.configuracion, "GEMINI_API_KEY", "")
    monkeypatch.setattr(ai_engine, "_motor_gemini", None)
    inicio = time.perf_counter()
    rec = await ai_engine.generar_recomendacion_enriquecida(
        nombre_atractivo="Huacachina",
        resultado=_resultado_base(),
        temperatura=28,
        uv=8,
        viento=12,
        condicion="Despejado",
        idioma="es",
    )
    assert (time.perf_counter() - inicio) * 1000 < 150
    assert rec.source == "fallback"
    assert rec.language == "es"
    assert 2 <= len(rec.clothing) <= 4


def test_weather_module_independence():
    """`weather` (reglas y alertas) funciona sin importar ni inicializar `ai_engine`."""
    guardados = {m: sys.modules.pop(m) for m in list(sys.modules) if m.startswith("src.modules.ai_engine")}
    guardados["src.modules.weather.scoring"] = sys.modules.pop("src.modules.weather.scoring", scoring)
    try:
        aislado = importlib.import_module("src.modules.weather.scoring")
        assert not any(m.startswith("src.modules.ai_engine") for m in sys.modules)
        alertas = aislado.detectar_alertas(temperatura=25, uv=12, viento=65, precipitacion=0)
        assert alertas, "El motor de alertas de weather debe operar sin ai_engine"
    finally:
        for m in [k for k in sys.modules if k.startswith("src.modules.ai_engine")]:
            sys.modules.pop(m)
        sys.modules.update(guardados)


def test_ai_engine_endpoint_registered():
    """Router /recommendations de ai_engine registrado y alias /weather/recommendations preservado."""
    from src.main import PREFIJO_API, aplicacion

    rutas = set(aplicacion.openapi()["paths"])
    assert f"{PREFIJO_API}/recommendations" in rutas
    assert f"{PREFIJO_API}/recommendations/of-the-day" in rutas
    assert f"{PREFIJO_API}/weather/recommendations" in rutas
