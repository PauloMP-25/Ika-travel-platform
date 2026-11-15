"""Tests unitarios para el módulo de seguridad temporal y planificación para mañana (safety.py)."""

from datetime import datetime, time, timezone
from zoneinfo import ZoneInfo

import pytest

from src.modules.weather.safety import (
    SeguridadMarinaYPlayas,
    SeguridadDesiertoYAventura,
    SeguridadEnoturismoYBodegas,
    SeguridadArqueologia,
    SeguridadCulturaYCiudad,
    evaluar_seguridad_temporal,
)
from src.modules.weather.schemas import PronosticoHoraResponse


def _crear_horas_pronostico_manana():
    """Crea una lista simulada de horas de pronóstico para el día de mañana."""
    base_date = datetime(2026, 11, 16, 0, 0, tzinfo=timezone.utc)
    horas = []
    # Simular 24 horas
    for h in range(24):
        # Viento sube en la tarde (Paracas típico)
        viento = 12.0 + (h * 2.5 if h >= 12 else 0.5 * h)
        # UV pico al mediodía
        uv = max(0.0, 11.0 - abs(h - 12) * 1.8)
        # Temperatura sube de 16°C a 26°C
        temp = 16.0 + (h * 1.0 if h <= 14 else 26.0 - (h - 14) * 0.8)
        horas.append(
            PronosticoHoraResponse(
                time=datetime(2026, 11, 16, h, 0, tzinfo=timezone.utc),
                temperature=round(temp, 1),
                uv_index=round(uv, 1),
                wind_speed=round(viento, 1),
                precipitation_probability=0.0,
                condition="Despejado con sol",
            )
        )
    return horas


def test_seguridad_playas_de_noche_recomienda_manana():
    horas = _crear_horas_pronostico_manana()
    # Petición a las 11:00 PM (23:00) en Lima
    hora_noche = time(23, 0)

    evaluacion = evaluar_seguridad_temporal(
        slugs_categorias=["naturaleza", "marina"],
        nombre_atractivo="Reserva Nacional de Paracas",
        horas_pronostico=horas,
        hora_referencia_lima=hora_noche,
    )

    assert evaluacion.es_horario_seguro is False
    assert evaluacion.es_planificacion_manana is True
    assert evaluacion.hora_sugerida is not None
    assert "SERNANP" in evaluacion.normativa_oficial or "DICAPI" in evaluacion.normativa_oficial
    assert "marea" in evaluacion.justificacion_seguridad.lower() or "visibilidad" in evaluacion.justificacion_seguridad.lower()
    # Verifica que la hora sugerida se encuentre en la mañana
    assert "AM" in evaluacion.hora_sugerida


def test_seguridad_bodegas_fuera_de_horario_recomienda_apertura():
    horas = _crear_horas_pronostico_manana()
    # Petición a las 8:00 PM (20:00) en Lima
    hora_noche = time(20, 0)

    evaluacion = evaluar_seguridad_temporal(
        slugs_categorias=["gastronomia", "cultural"],
        nombre_atractivo="Viña Tacama",
        horas_pronostico=horas,
        hora_referencia_lima=hora_noche,
    )

    assert evaluacion.es_horario_seguro is False
    assert evaluacion.es_planificacion_manana is True
    assert evaluacion.hora_sugerida is not None
    assert "MINCETUR" in evaluacion.normativa_oficial or "Tacama" in evaluacion.normativa_oficial
    assert "AM" in evaluacion.hora_sugerida


def test_seguridad_huacachina_tubulares_de_noche():
    horas = _crear_horas_pronostico_manana()
    # Petición a las 9:30 PM (21:30) en Lima
    hora_noche = time(21, 30)

    evaluacion = evaluar_seguridad_temporal(
        slugs_categorias=["sandboarding", "aventura"],
        nombre_atractivo="Oasis de Huacachina",
        horas_pronostico=horas,
        hora_referencia_lima=hora_noche,
    )

    assert evaluacion.es_horario_seguro is False
    assert evaluacion.es_planificacion_manana is True
    assert "Ordenanza Regional N° 007-2017" in evaluacion.normativa_oficial
    assert "AM" in evaluacion.hora_sugerida


def test_seguridad_horario_diurno_es_seguro():
    # Petición a las 10:30 AM en Lima (horario seguro)
    hora_dia = time(10, 30)

    evaluacion = evaluar_seguridad_temporal(
        slugs_categorias=["aventura"],
        nombre_atractivo="Oasis de Huacachina",
        horas_pronostico=[],
        hora_referencia_lima=hora_dia,
    )

    assert evaluacion.es_horario_seguro is True
    assert evaluacion.es_planificacion_manana is False
    assert evaluacion.hora_sugerida is None
