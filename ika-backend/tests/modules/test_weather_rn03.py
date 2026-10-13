"""Tests de RN-03, caché, recomendador, alertas y mapeo HTTP del módulo weather.

Sin red, sin Redis y sin PostgreSQL: el caché, la BD y los proveedores se
sustituyen por dobles de prueba.
"""

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from src.core.exceptions import registrar_manejadores_excepciones
from src.modules.weather import ai_recommender, service
from src.modules.weather.exceptions import (
    AtractivoSinClimaException,
    DatosClimaDesactualizadosException,
    DestinoNoEncontradoException,
    ProveedorClimaNoDisponibleException,
    TodosLosProveedoresFallaronException,
    WeatherProviderUnavailableException,
)
from src.modules.weather.schemas import ClimaActual, ClimaActualResponse

AHORA = datetime.now(tz=timezone.utc)


def _clima(temperatura: float = 25.0) -> ClimaActual:
    return ClimaActual(
        temperatura_actual=temperatura, sensacion_termica=temperatura, probabilidad_precipitacion=0.0,
        humedad=50.0, velocidad_viento=10.0, rafagas_viento=None, indice_uv=5.0,
        descripcion_clima="Despejado", visibilidad=10.0, hora_amanecer=AHORA, hora_atardecer=AHORA,
        fecha_hora_pronostico=AHORA, origen_api="test",
    )


def _db_falsa() -> MagicMock:
    db = MagicMock()
    db.add = MagicMock()
    db.commit = AsyncMock()
    db.refresh = AsyncMock()
    return db


@pytest.fixture
def sin_redis(monkeypatch):
    """Redis vacío: toda lectura es miss y las escrituras se registran."""
    escrituras: list[tuple] = []
    monkeypatch.setattr(service, "cache_obtener_json", AsyncMock(return_value=None))

    async def guardar(clave, valor, ttl):
        escrituras.append((clave, valor, ttl))
        return True

    monkeypatch.setattr(service, "cache_guardar_json", guardar)
    return escrituras


# ----------------------------------------------------------------------
# RN-03 (get_fresh_snapshot)
# ----------------------------------------------------------------------
@pytest.mark.anyio
async def test_sin_cache_ni_snapshot_vigente_refresca_y_persiste(monkeypatch, sin_redis):
    """Un snapshot de 7 h no es 'vigente': la consulta devuelve None y se refresca."""
    monkeypatch.setattr(service, "_ultimo_snapshot_vigente", AsyncMock(return_value=None))
    agregador = MagicMock()
    agregador.obtener_consenso = AsyncMock(return_value=_clima(27.0))
    db = _db_falsa()

    respuesta = await service.get_fresh_snapshot(db, service.ubicacion_region(), agregador=agregador)

    agregador.obtener_consenso.assert_awaited_once()
    db.add.assert_called_once()
    db.commit.assert_awaited_once()
    assert respuesta.temperatura_actual == 27.0
    assert respuesta.is_cached is False
    # Se guardó en Redis con TTL de 6 h (RN-03).
    assert sin_redis[0][2] == 6 * 3600


@pytest.mark.anyio
async def test_cache_redis_evita_llamar_a_proveedores(monkeypatch):
    payload = ClimaActualResponse(destino="Ica", **_clima().model_dump()).model_dump(mode="json")
    monkeypatch.setattr(service, "cache_obtener_json", AsyncMock(return_value=payload))
    agregador = MagicMock()
    agregador.obtener_consenso = AsyncMock()

    respuesta = await service.get_fresh_snapshot(_db_falsa(), service.ubicacion_region(), agregador=agregador)

    agregador.obtener_consenso.assert_not_called()
    assert respuesta.is_cached is True


@pytest.mark.anyio
async def test_todos_los_proveedores_caidos_lanza_503_stale(monkeypatch, sin_redis):
    monkeypatch.setattr(service, "_ultimo_snapshot_vigente", AsyncMock(return_value=None))
    agregador = MagicMock()
    agregador.obtener_consenso = AsyncMock(side_effect=TodosLosProveedoresFallaronException([]))

    with pytest.raises(DatosClimaDesactualizadosException):
        await service.get_fresh_snapshot(_db_falsa(), service.ubicacion_region(), agregador=agregador)


@pytest.mark.anyio
async def test_forzar_refresco_ignora_redis_y_bd(monkeypatch, sin_redis):
    leer = AsyncMock()
    monkeypatch.setattr(service, "cache_obtener_json", leer)
    monkeypatch.setattr(service, "_ultimo_snapshot_vigente", leer)
    agregador = MagicMock()
    agregador.obtener_consenso = AsyncMock(return_value=_clima())

    await service.get_fresh_snapshot(
        _db_falsa(), service.ubicacion_region(), forzar_refresco=True, agregador=agregador
    )

    leer.assert_not_called()
    agregador.obtener_consenso.assert_awaited_once()


# ----------------------------------------------------------------------
# Recomendador y alertas (funciones puras)
# ----------------------------------------------------------------------
def test_viento_alto_baja_el_score_de_sandboarding():
    calmado = ai_recommender.generar_recomendacion(
        nombre_atractivo="Sandboarding en Huacachina", slugs_categorias=["sandboarding"],
        temperatura=25, uv=6, viento=10, precipitacion=0,
    )
    ventoso = ai_recommender.generar_recomendacion(
        nombre_atractivo="Sandboarding en Huacachina", slugs_categorias=["sandboarding"],
        temperatura=25, uv=6, viento=50, precipitacion=0,
    )
    assert ventoso.score < calmado.score
    assert ventoso.nivel in {"regular", "no_recomendado"}


def test_actividad_cultural_penaliza_menos_el_viento_que_sandboarding():
    kwargs = dict(temperatura=25, uv=6, viento=35, precipitacion=0)
    cultural = ai_recommender.generar_recomendacion(
        nombre_atractivo="Museo Regional", slugs_categorias=["cultural"], **kwargs
    )
    aventura = ai_recommender.generar_recomendacion(
        nombre_atractivo="Sandboarding", slugs_categorias=["sandboarding"], **kwargs
    )
    assert cultural.score > aventura.score


def test_detectar_alertas_por_viento_y_uv():
    alertas = ai_recommender.detectar_alertas(temperatura=25, uv=12, viento=65, precipitacion=0)
    codigos = {(a.code, a.severity) for a in alertas}
    assert ("viento_fuerte", "high") in codigos
    assert ("uv_extremo", "high") in codigos


def test_sin_condiciones_extremas_no_hay_alertas():
    assert ai_recommender.detectar_alertas(temperatura=25, uv=5, viento=10, precipitacion=0) == []


@pytest.mark.anyio
async def test_gemini_caido_devuelve_none_y_no_rompe(monkeypatch):
    """Si Gemini falla, la recomendación sigue funcionando con el texto por reglas."""
    monkeypatch.setattr(ai_recommender.configuracion, "GEMINI_API_KEY", "clave-falsa")

    class ClienteRoto:
        def __init__(self, *a, **k): ...
        async def __aenter__(self): return self
        async def __aexit__(self, *a): return False
        async def post(self, *a, **k): raise httpx.ConnectTimeout("caído")

    monkeypatch.setattr(ai_recommender.httpx, "AsyncClient", ClienteRoto)
    resultado = ai_recommender.generar_recomendacion(
        nombre_atractivo="Huacachina", slugs_categorias=[], temperatura=25, uv=5, viento=10, precipitacion=0
    )
    texto = await ai_recommender.redactar_con_gemini(
        nombre_atractivo="Huacachina", resultado=resultado, temperatura=25, uv=5, viento=10,
        condicion="Despejado",
    )
    assert texto is None
    assert resultado.texto  # el texto por reglas siempre existe


@pytest.mark.anyio
async def test_gemini_sin_api_key_no_hace_llamadas(monkeypatch):
    monkeypatch.setattr(ai_recommender.configuracion, "GEMINI_API_KEY", "")
    resultado = ai_recommender.generar_recomendacion(
        nombre_atractivo="X", slugs_categorias=[], temperatura=25, uv=5, viento=10, precipitacion=0
    )
    assert await ai_recommender.redactar_con_gemini(
        nombre_atractivo="X", resultado=resultado, temperatura=25, uv=5, viento=10, condicion="-"
    ) is None


# ----------------------------------------------------------------------
# Handlers globales: cada excepción -> su código HTTP
# ----------------------------------------------------------------------
@pytest.mark.parametrize(
    ("excepcion", "estado", "codigo"),
    [
        (DatosClimaDesactualizadosException(), 503, "datos_clima_desactualizados"),
        (WeatherProviderUnavailableException(), 502, "proveedor_pronostico_no_disponible"),
        (TodosLosProveedoresFallaronException([ProveedorClimaNoDisponibleException("x", "e")]), 502, "todos_los_proveedores_fallaron"),
        (DestinoNoEncontradoException("Marte"), 404, "destino_no_encontrado"),
        (AtractivoSinClimaException(), 404, "atractivo_no_encontrado"),
    ],
)
def test_excepciones_de_clima_se_mapean_a_http(excepcion, estado, codigo):
    app = FastAPI()
    registrar_manejadores_excepciones(app)

    @app.get("/falla")
    async def falla():
        raise excepcion

    respuesta = TestClient(app).get("/falla")
    assert respuesta.status_code == estado
    assert respuesta.json()["codigo"] == codigo
