"""Tests del motor de alertas climáticas de Ica (Sprint 4, P2).

Cubren:
- la función pura `rules.evaluar_alertas` con la tabla de umbrales
  (valores justo debajo, en y por encima de cada umbral);
- la regla de zona: `paracas_wind` solo aplica en la costa de Paracas;
- el upsert de `WeatherAlert` por (atractivo, tipo) con BD real: severidad
  que cambia, condición que cesa (baja lógica) y vencimiento a 6 h.

Los umbrales están **propuestos, pendientes de validación** con
DIRCETUR/SENAMHI (ver `docs/sprint_4.md`).
"""

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from sqlalchemy import select

from src.modules.catalog.models import Attraction
from src.modules.weather import rules
from src.modules.weather.models import SeveridadAlerta, WeatherAlert
from src.modules.weather.service import sincronizar_alertas_atractivo
from tests.conftest import run

AHORA = datetime.now(tz=timezone.utc)


def _clima(**kwargs) -> SimpleNamespace:
    """Snapshot mínimo con los campos que usa el motor de alertas.

    Acepta alias cortos (`temperatura`, `uv`, `viento`) que se mapean a los
    nombres reales del esquema, para que un kwarg mal escrito no quede como
    un atributo ignorado en silencio.
    """
    base = dict(
        temperatura_actual=22.0,
        indice_uv=3.0,
        velocidad_viento=10.0,
        probabilidad_precipitacion=0.0,
        temperatura_suelo_arena=None,
    )
    alias = {
        "temperatura": "temperatura_actual",
        "uv": "indice_uv",
        "viento": "velocidad_viento",
        "precipitacion": "probabilidad_precipitacion",
        "arena": "temperatura_suelo_arena",
    }
    for clave, valor in kwargs.items():
        base[alias.get(clave, clave)] = valor
    return SimpleNamespace(**base)


def _crear_atractivo(db, nombre: str, distrito: str) -> Attraction:
    """Inserta un atractivo real (la FK de `weather_alert` lo exige)."""
    atractivo = Attraction(
        name=nombre,
        description=f"Escenario de prueba en {distrito}.",
        latitude=-14.0873,
        longitude=-75.7637,
        district=distrito,
        is_active=True,
    )
    db.add(atractivo)
    run(db.commit())
    return atractivo


def _tipos(**kwargs) -> set[str]:
    return {a.alert_type for a in rules.evaluar_alertas(**kwargs)}


# ---------------------------------------------------------------------------
# Tabla de umbrales: debajo / en / por encima
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("viento_paracas", "esperado"),
    [
        (24.9, None),   # justo debajo de advisory (25)
        (25.0, "low"),  # en advisory
        (34.9, "low"),
        (35.0, "medium"),  # en warning
        (49.9, "medium"),
        (50.0, "high"),    # en danger
    ],
)
def test_umbral_viento_paracas(viento_paracas: float, esperado: str | None):
    alertas = rules.evaluar_alertas(
        temperatura=22.0, uv=3.0, viento=viento_paracas, zona="Reserva Nacional de Paracas"
    )
    paracas = [a for a in alertas if a.alert_type == "paracas_wind"]
    if esperado is None:
        assert paracas == []
    else:
        assert len(paracas) == 1
        assert paracas[0].severity == esperado


@pytest.mark.parametrize(
    ("uv", "esperado"),
    [
        (7.9, None),
        (8.0, "low"),
        (10.9, "low"),
        (11.0, "medium"),
        (11.9, "medium"),
        (12.0, "high"),
    ],
)
def test_umbral_uv_extremo(uv: float, esperado: str | None):
    alertas = rules.evaluar_alertas(temperatura=22.0, uv=uv, viento=10.0, zona="Ica")
    uv_alertas = [a for a in alertas if a.alert_type in ("extreme_uv", "uv_extremo")]
    if esperado is None:
        assert uv_alertas == []
    else:
        assert len(uv_alertas) == 1
        assert uv_alertas[0].severity == esperado


@pytest.mark.parametrize(
    ("temperatura", "esperado"),
    [
        (32.9, None),
        (33.0, "low"),
        (36.9, "low"),
        (37.0, "medium"),
        (39.9, "medium"),
        (40.0, "high"),
    ],
)
def test_umbral_calor_alto(temperatura: float, esperado: str | None):
    alertas = rules.evaluar_alertas(
        temperatura=temperatura, uv=3.0, viento=10.0, zona="Ica"
    )
    calor = [a for a in alertas if a.alert_type == "high_temperature"]
    if esperado is None:
        assert calor == []
    else:
        assert len(calor) == 1
        assert calor[0].severity == esperado


@pytest.mark.parametrize(
    ("precipitacion_mm", "esperado"),
    [
        (0.9, None),
        (1.0, "low"),
        (3.9, "low"),
        (4.0, "medium"),
        (7.9, "medium"),
        (8.0, "high"),
    ],
)
def test_umbral_lluvia(precipitacion_mm: float, esperado: str | None):
    alertas = rules.evaluar_alertas(
        temperatura=22.0,
        uv=3.0,
        viento=10.0,
        precipitacion=precipitacion_mm,
        zona="Ica",
    )
    lluvia = [a for a in alertas if a.alert_type == "rain_hazard"]
    if esperado is None:
        assert lluvia == []
    else:
        assert len(lluvia) == 1
        assert lluvia[0].severity == esperado


# ---------------------------------------------------------------------------
# Regla de zona: el viento de Paracas no aplica en Huacachina
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "zona", ["Paracas", "Reserva Nacional de Paracas", "Islas Ballestas", "Playa El Chaco"]
)
def test_viento_paracas_si_aplica_en_la_costa(zona: str):
    assert "paracas_wind" in _tipos(temperatura=22.0, uv=3.0, viento=40.0, zona=zona)


@pytest.mark.parametrize("zona", ["Huacachina", "Plaza de Armas de Ica", "Bodega Tacama"])
def test_viento_paracas_no_aplica_en_el_desierto(zona: str):
    tipos = _tipos(temperatura=22.0, uv=3.0, viento=40.0, zona=zona)
    assert "paracas_wind" not in tipos
    # En su lugar aplica la regla general de viento del desierto.
    assert "viento_fuerte" in tipos


def test_clima_tranquilo_no_produce_alertas():
    assert _tipos(temperatura=22.0, uv=3.0, viento=10.0, zona="Huacachina") == set()


# ---------------------------------------------------------------------------
# Upsert persistente por (atractivo, tipo)
# ---------------------------------------------------------------------------


def test_upsert_inserta_luego_actualiza_severidad(db_session):
    """Alta inicial y actualización de severidad sin duplicar filas."""
    atractivo = _crear_atractivo(db_session, "Dunas de Huacachina", "Ica")
    atractivo_id = atractivo.id  # id simple; no tocar atributos tras commit

    activas = run(sincronizar_alertas_atractivo(db_session, atractivo, _clima(temperatura=38.0)))
    assert activas == 1

    run(sincronizar_alertas_atractivo(db_session, atractivo, _clima(temperatura=41.0)))

    filas = run(_alertas_de(db_session, atractivo_id))
    assert len(filas) == 1  # no duplica: upsert por (attraction_id, code)
    assert filas[0].severity == SeveridadAlerta.high
    assert filas[0].is_active is True
    assert filas[0].code == "high_temperature"


def test_condicion_que_cesa_pasa_a_inactiva(db_session):
    """Si el clima normaliza, la alerta se desactiva (no se borra)."""
    atractivo = _crear_atractivo(db_session, "Dunas de Huacachina", "Ica")
    atractivo_id = atractivo.id
    run(sincronizar_alertas_atractivo(db_session, atractivo, _clima(temperatura=41.0)))

    run(sincronizar_alertas_atractivo(db_session, atractivo, _clima(temperatura=25.0)))

    filas = run(_alertas_de(db_session, atractivo_id))
    assert len(filas) == 1
    assert filas[0].is_active is False  # baja lógica, conserva el rastro

    assert run(sincronizar_alertas_atractivo(db_session, atractivo, _clima(temperatura=25.0))) == 0


def test_alertas_de_dos_atractivos_no_se_mezclan(db_session):
    huacachina = _crear_atractivo(db_session, "Dunas de Huacachina", "Ica")
    paracas = _crear_atractivo(db_session, "Playa El Chaco", "Paracas")
    id_huacachina, id_paracas = huacachina.id, paracas.id

    run(sincronizar_alertas_atractivo(db_session, huacachina, _clima(viento=60.0)))
    run(sincronizar_alertas_atractivo(db_session, paracas, _clima(viento=60.0)))

    tipos_paracas = {a.code for a in run(_alertas_de(db_session, id_paracas))}
    tipos_huacachina = {a.code for a in run(_alertas_de(db_session, id_huacachina))}

    assert "paracas_wind" in tipos_paracas
    assert "paracas_wind" not in tipos_huacachina
    assert "viento_fuerte" in tipos_huacachina


def test_vencimiento_es_capturado_mas_6_horas(db_session):
    """RN-03: la alerta vence a las 6 h, igual que el snapshot."""
    atractivo = _crear_atractivo(db_session, "Dunas de Huacachina", "Ica")
    atractivo_id = atractivo.id
    antes = datetime.now(tz=timezone.utc)
    run(sincronizar_alertas_atractivo(db_session, atractivo, _clima(temperatura=41.0)))
    despues = datetime.now(tz=timezone.utc)

    fila = run(_alertas_de(db_session, atractivo_id))[0]

    assert antes + timedelta(hours=6) <= fila.ends_at <= despues + timedelta(hours=6)


def test_zona_del_atractivo_determina_las_reglas(db_session):
    """Un atractivo en Paracas con viento fuerte genera `paracas_wind`."""
    paracas = _crear_atractivo(db_session, "Playa El Chaco", "Paracas")
    atractivo_id = paracas.id
    run(sincronizar_alertas_atractivo(db_session, paracas, _clima(viento=36.0)))

    filas = run(_alertas_de(db_session, atractivo_id))
    assert [f.code for f in filas] == ["paracas_wind"]
    assert filas[0].severity == SeveridadAlerta.medium


async def _alertas_de(db, atractivo_id):
    resultado = await db.execute(
        select(WeatherAlert).where(WeatherAlert.attraction_id == atractivo_id)
    )
    return list(resultado.scalars().all())
