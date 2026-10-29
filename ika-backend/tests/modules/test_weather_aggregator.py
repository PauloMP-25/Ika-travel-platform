"""Tests del agregador climático robustecido (Sprint 4, P1).

Cubren los puntos del plan: cada proveedor caído por separado, los tres
caídos, un proveedor lento (timeout) y un proveedor con datos absurdos
(outliers). Todo con dobles locales: ningún test toca la red.
"""

import asyncio
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

from src.core.config import configuracion
from src.modules.weather.exceptions import (
    ProveedorClimaNoDisponibleException,
    ProveedorClimaTimeoutException,
    TodosLosProveedoresFallaronException,
)
from src.modules.weather.schemas import ClimaActual
from src.modules.weather.service import (
    AgregadorClima,
    RANGOS_FISICOS_CLIMA,
    _mediana_con_outliers,
)

AHORA = datetime.now(tz=timezone.utc)


def make_clima(
    temperatura: float = 25.0,
    uv: float = 5.0,
    viento: float = 15.0,
    origen: str = "proveedor_test",
) -> ClimaActual:
    return ClimaActual(
        temperatura_actual=temperatura,
        sensacion_termica=temperatura - 2,
        probabilidad_precipitacion=10.0,
        humedad=60.0,
        velocidad_viento=viento,
        rafagas_viento=viento + 5.0,
        indice_uv=uv,
        descripcion_clima="Despejado",
        visibilidad=10.0,
        hora_amanecer=AHORA,
        hora_atardecer=AHORA,
        fecha_hora_pronostico=AHORA,
        origen_api=origen,
    )


def _adaptador(nombre: str, **kwargs) -> MagicMock:
    adaptador = MagicMock()
    adaptador.nombre_proveedor = nombre
    adaptador.obtener_clima_actual = AsyncMock(return_value=make_clima(**kwargs))
    return adaptador


def _adaptador_que_falla(nombre: str) -> MagicMock:
    adaptador = MagicMock()
    adaptador.nombre_proveedor = nombre
    adaptador.obtener_clima_actual = AsyncMock(
        side_effect=ProveedorClimaNoDisponibleException(nombre, "503 desde la API")
    )
    return adaptador


# ---------------------------------------------------------------------------
# Quórum: cada proveedor caído por separado, y los tres caídos
# ---------------------------------------------------------------------------


@pytest.mark.anyio
@pytest.mark.parametrize("caido", ["api_a", "api_b", "api_c"])
async def test_un_proveedor_caido_por_separado_no_detiene_el_consenso(caido: str):
    """Quórum ≥ 1: con dos proveedores sanos el consenso sigue vivo."""
    nombres = ["api_a", "api_b", "api_c"]
    adaptadores = [
        _adaptador_que_falla(n) if n == caido else _adaptador(n, temperatura=20.0)
        for n in nombres
    ]

    resultado = await AgregadorClima(adaptadores=adaptadores).obtener_consenso(
        -14.0873, -75.7637
    )

    assert resultado.temperatura_actual == 20.0
    assert resultado.origen_api.count("+") == 1  # solo dos nombres unidos
    assert caido not in resultado.origen_api


@pytest.mark.anyio
async def test_los_tres_proveedores_caidos_lanzan_excepcion_con_detalle():
    """Si fallan los tres, el 502 conserva qué proveedor falló y por qué."""
    adaptadores = [_adaptador_que_falla(n) for n in ("api_a", "api_b", "api_c")]

    with pytest.raises(TodosLosProveedoresFallaronException) as excinfo:
        await AgregadorClima(adaptadores=adaptadores).obtener_consenso(
            -14.0873, -75.7637
        )

    errores = excinfo.value.errores
    assert len(errores) == 3
    assert all(isinstance(e, ProveedorClimaNoDisponibleException) for e in errores)
    assert {e.proveedor for e in errores} == {"api_a", "api_b", "api_c"}


# ---------------------------------------------------------------------------
# Proveedor lento: timeout individual
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_proveedor_lento_no_bloquea_el_consenso(monkeypatch):
    """Un proveedor que tarda más que el techo se descarta con timeout."""
    monkeypatch.setattr(configuracion, "TIMEOUT_PROVEEDOR_CLIMA_SEGUNDOS", 0.05)

    lento = MagicMock()
    lento.nombre_proveedor = "api_lenta"

    async def _tardar_demasiado(*_args, **_kwargs):
        await asyncio.sleep(2)
        return make_clima(temperatura=99.0)

    lento.obtener_clima_actual = AsyncMock(side_effect=_tardar_demasiado)
    rapido = _adaptador("api_rapida", temperatura=21.0)

    resultado = await AgregadorClima(adaptadores=[lento, rapido]).obtener_consenso(
        -14.0873, -75.7637
    )

    assert resultado.temperatura_actual == 21.0
    assert resultado.origen_api == "api_rapida"


@pytest.mark.anyio
async def test_proveedores_todos_lentos_lanzan_timeout(monkeypatch):
    """Si los tres superan el techo, el fallo reporta `proveedor_clima_timeout`."""
    monkeypatch.setattr(configuracion, "TIMEOUT_PROVEEDOR_CLIMA_SEGUNDOS", 0.05)

    def _lento(nombre: str) -> MagicMock:
        adaptador = MagicMock()
        adaptador.nombre_proveedor = nombre

        async def _esperar(*_args, **_kwargs):
            await asyncio.sleep(2)
            return make_clima()

        adaptador.obtener_clima_actual = AsyncMock(side_effect=_esperar)
        return adaptador

    with pytest.raises(TodosLosProveedoresFallaronException) as excinfo:
        await AgregadorClima(
            adaptadores=[_lento("api_a"), _lento("api_b")]
        ).obtener_consenso(-14.0873, -75.7637)

    assert all(
        isinstance(e, ProveedorClimaTimeoutException) for e in excinfo.value.errores
    )


# ---------------------------------------------------------------------------
# Datos absurdos: rangos físicos y outliers estadísticos
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_valor_fuera_de_rango_fisico_se_descarta():
    """-999 °C es físicamente imposible: se filtra antes de la mediana."""
    adaptadores = [
        _adaptador("api_a", temperatura=22.0),
        _adaptador("api_b", temperatura=24.0),
        _adaptador("api_rota", temperatura=-999.0),
    ]

    resultado = await AgregadorClima(adaptadores=adaptadores).obtener_consenso(
        -14.0873, -75.7637
    )

    assert resultado.temperatura_actual == 23.0  # mediana de 22 y 24


@pytest.mark.anyio
async def test_uv_imposible_no_contamina_el_maximo():
    """Un UV fuera del rango OMS (0-25) se ignora; el resto decide."""
    adaptadores = [
        _adaptador("api_a", uv=8.0),
        _adaptador("api_b", uv=7.0),
        _adaptador("api_rota", uv=420.0),
    ]

    resultado = await AgregadorClima(adaptadores=adaptadores).obtener_consenso(
        -14.0873, -75.7637
    )

    assert resultado.indice_uv == 8.0


@pytest.mark.anyio
async def test_valor_absurdo_no_contamina_el_consenso():
    """200 °C es físicamente imposible en Ica: se filtra por rango antes de la mediana."""
    valores = [20.0, 21.0, 19.5, 20.5, 200.0]
    adaptadores = [
        _adaptador(f"api_{i}", temperatura=t) for i, t in enumerate(valores)
    ]

    resultado = await AgregadorClima(adaptadores=adaptadores).obtener_consenso(
        -14.0873, -75.7637
    )

    # Mediana de los cuatro valores sanos (200 queda fuera por rango físico).
    assert resultado.temperatura_actual == 20.2


# ---------------------------------------------------------------------------
# Helper puro _mediana_con_outliers
# ---------------------------------------------------------------------------


def test_mediana_con_outliers_filtra_mas_alla_de_3_sigma():
    """Un valor dentro de rango físico pero a > 3 σ se descarta (con ≥ 3 muestras)."""
    valores = [24.0] * 20 + [33.0]  # 33 °C cabe en el rango, pero rompe la distribución

    assert _mediana_con_outliers("temperatura_actual", valores) == 24.0


def test_mediana_con_outliers_con_valores_pocos_no_aplica_sigma():
    """Con menos de 3 muestras la σ no dice nada: solo manda el rango físico."""
    assert _mediana_con_outliers("temperatura_actual", [24.0, 33.0]) == 28.5


def test_mediana_con_outliers_conserva_valores_si_todos_son_absurdos():
    """Si todos los valores están fuera de rango, se conservan (no excepción)."""
    resultado = _mediana_con_outliers("temperatura_actual", [-999.0, -998.0])
    assert resultado == -998.5


def test_mediana_con_outliers_sin_valores_da_cero():
    assert _mediana_con_outliers("temperatura_actual", []) == 0.0


def test_rangos_fisicos_cubren_las_magnitudes_core():
    for campo in (
        "temperatura_actual",
        "velocidad_viento",
        "indice_uv",
        "humedad",
        "visibilidad",
    ):
        assert campo in RANGOS_FISICOS_CLIMA
        minimo, maximo = RANGOS_FISICOS_CLIMA[campo]
        assert minimo < maximo
