"""Tests unitarios del módulo weather.

Se prueban las capas de lógica pura (schemas, constants, service/Aggregator)
sin hacer llamadas reales a APIs externas — todo se mockea con `monkeypatch`
o instancias falsas, siguiendo el mismo patrón del módulo users.
"""

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

from src.modules.weather.constants import DESTINOS_ICA, normalizar_nombre_destino
from src.modules.weather.exceptions import (
    DestinoNoEncontradoException,
    ProveedorClimaNoDisponibleException,
    TodosLosProveedoresFallaronException,
)
from src.modules.weather.schemas import ClimaActual, ClimaActualResponse
from src.modules.weather.service import AgregadorClima, resolver_coordenadas_destino

# ---------------------------------------------------------------------------
# Fixture de un ClimaActual válido para reutilizar en los tests
# ---------------------------------------------------------------------------

AHORA = datetime.now(tz=timezone.utc)


def make_clima(
    temperatura: float = 25.0,
    uv: float = 5.0,
    origen: str = "proveedor_test",
    rafagas: float | None = 20.0,
) -> ClimaActual:
    return ClimaActual(
        temperatura_actual=temperatura,
        sensacion_termica=temperatura - 2,
        probabilidad_precipitacion=10.0,
        humedad=60.0,
        velocidad_viento=15.0,
        rafagas_viento=rafagas,
        indice_uv=uv,
        descripcion_clima="Despejado",
        visibilidad=10.0,
        hora_amanecer=AHORA,
        hora_atardecer=AHORA,
        fecha_hora_pronostico=AHORA,
        origen_api=origen,
    )


# ---------------------------------------------------------------------------
# Tests de constants
# ---------------------------------------------------------------------------


def test_destinos_ica_contiene_huacachina():
    assert "huacachina" in DESTINOS_ICA


def test_normalizar_nombre_destino_elimina_espacios_y_lowercase():
    assert normalizar_nombre_destino("  Huacachina  ") == "huacachina"
    assert normalizar_nombre_destino("ISLAS BALLESTAS") == "islas ballestas"


def test_resolver_coordenadas_huacachina():
    lat, lon = resolver_coordenadas_destino("Huacachina")
    assert lat == pytest.approx(-14.0873)
    assert lon == pytest.approx(-75.7637)


def test_resolver_coordenadas_destino_desconocido_lanza_excepcion():
    with pytest.raises(DestinoNoEncontradoException) as exc_info:
        resolver_coordenadas_destino("Marte")
    assert exc_info.value.destino == "Marte"


# ---------------------------------------------------------------------------
# Tests de schemas
# ---------------------------------------------------------------------------


def test_clima_actual_schema_valida_campos_correctos():
    clima = make_clima()
    assert clima.temperatura_actual == 25.0
    assert clima.origen_api == "proveedor_test"


def test_clima_actual_response_incluye_campo_destino():
    clima = make_clima()
    response = ClimaActualResponse(destino="Huacachina", **clima.model_dump())
    assert response.destino == "Huacachina"
    assert response.temperatura_actual == 25.0


def test_clima_actual_rafagas_puede_ser_none():
    clima = make_clima(rafagas=None)
    assert clima.rafagas_viento is None


# ---------------------------------------------------------------------------
# Tests del AgregadorClima (service)
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_agregador_retorna_promedio_de_dos_proveedores():
    """Si dos proveedores responden, el promedio se calcula correctamente."""
    adaptador_a = MagicMock()
    adaptador_a.nombre_proveedor = "api_a"
    adaptador_a.obtener_clima_actual = AsyncMock(return_value=make_clima(temperatura=20.0, uv=4.0))

    adaptador_b = MagicMock()
    adaptador_b.nombre_proveedor = "api_b"
    adaptador_b.obtener_clima_actual = AsyncMock(return_value=make_clima(temperatura=30.0, uv=6.0))

    agregador = AgregadorClima(adaptadores=[adaptador_a, adaptador_b])
    resultado = await agregador.obtener_consenso(-14.0873, -75.7637)

    assert resultado.temperatura_actual == 25.0  # promedio de 20 y 30
    assert resultado.indice_uv == 5.0            # promedio de 4 y 6
    assert "api_a" in resultado.origen_api
    assert "api_b" in resultado.origen_api


@pytest.mark.anyio
async def test_agregador_tolera_fallo_de_un_proveedor():
    """Si un proveedor falla pero otro responde, el resultado es válido."""
    adaptador_ok = MagicMock()
    adaptador_ok.nombre_proveedor = "api_ok"
    adaptador_ok.obtener_clima_actual = AsyncMock(return_value=make_clima(temperatura=22.0))

    adaptador_falla = MagicMock()
    adaptador_falla.nombre_proveedor = "api_falla"
    adaptador_falla.obtener_clima_actual = AsyncMock(
        side_effect=ProveedorClimaNoDisponibleException("api_falla", "timeout")
    )

    agregador = AgregadorClima(adaptadores=[adaptador_ok, adaptador_falla])
    resultado = await agregador.obtener_consenso(-14.0873, -75.7637)

    assert resultado.temperatura_actual == 22.0
    assert "api_ok" in resultado.origen_api


@pytest.mark.anyio
async def test_agregador_lanza_excepcion_si_todos_fallan():
    """Si todos los proveedores fallan, debe lanzar TodosLosProveedoresFallaronException."""
    adaptador = MagicMock()
    adaptador.nombre_proveedor = "api_caida"
    adaptador.obtener_clima_actual = AsyncMock(
        side_effect=ProveedorClimaNoDisponibleException("api_caida", "error")
    )

    agregador = AgregadorClima(adaptadores=[adaptador])
    with pytest.raises(TodosLosProveedoresFallaronException):
        await agregador.obtener_consenso(-14.0873, -75.7637)


@pytest.mark.anyio
async def test_agregador_filtra_uv_cero_de_openweathermap():
    """El UV de 0.0 de OWM (que no tiene el dato) no debe contaminar el promedio."""
    adaptador_owm = MagicMock()
    adaptador_owm.nombre_proveedor = "openweathermap"
    adaptador_owm.obtener_clima_actual = AsyncMock(return_value=make_clima(uv=0.0))

    adaptador_openmeteo = MagicMock()
    adaptador_openmeteo.nombre_proveedor = "open-meteo"
    adaptador_openmeteo.obtener_clima_actual = AsyncMock(return_value=make_clima(uv=8.0))

    agregador = AgregadorClima(adaptadores=[adaptador_owm, adaptador_openmeteo])
    resultado = await agregador.obtener_consenso(-14.0873, -75.7637)

    # Solo open-meteo aportó UV válido (>0), así que el promedio debe ser 8.0
    assert resultado.indice_uv == 8.0


@pytest.mark.anyio
async def test_agregador_maneja_rafagas_none_correctamente():
    """Si algún proveedor no tiene datos de ráfagas, el promedio ignora los None."""
    adaptador_a = MagicMock()
    adaptador_a.nombre_proveedor = "api_a"
    adaptador_a.obtener_clima_actual = AsyncMock(return_value=make_clima(rafagas=30.0))

    adaptador_b = MagicMock()
    adaptador_b.nombre_proveedor = "api_b"
    adaptador_b.obtener_clima_actual = AsyncMock(return_value=make_clima(rafagas=None))

    agregador = AgregadorClima(adaptadores=[adaptador_a, adaptador_b])
    resultado = await agregador.obtener_consenso(-14.0873, -75.7637)

    # Solo adaptador_a aportó ráfagas, así que el promedio es 30.0
    assert resultado.rafagas_viento == 30.0
