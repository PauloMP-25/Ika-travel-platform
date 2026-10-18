"""Verificación de los índices de PostgreSQL (Sprint 4, F2).

Comprueba en `pg_indexes` que existen los índices creados por la migración
`f1a2b3c4d5e6` y que el índice redundante de la tabla puente ya no está.

Los `EXPLAIN (ANALYZE, BUFFERS)` antes/después quedan documentados en
`docs/optimizacion_bd.md` (con el script `scripts/explicar_optimizacion.py`):
afirmar sobre el plan de ejecución en CI sería frágil (depende del volumen
y del planificador), así que aquí solo se valida la existencia.
"""

import re

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from tests.conftest import run
# (nombre, tabla) de los índices que debe crear la migración del sprint.
INDICES_SPRINT4 = [
    ("idx_attraction_category_category", "attraction_category"),
    ("idx_reviews_attraction_rating", "reviews"),
    ("idx_attractions_active_district", "attraction"),
    ("idx_agencies_validated", "agency"),
    ("idx_sos_reports_user_created", "sos_reports"),
    ("idx_incident_reports_status_created", "tourist_incident_reports"),
]

# Índices que ya existían y siguen cubriendo los objetivos de F2.
INDICES_PREVIOS = [
    ("ix_attraction_lat_lon", "attraction"),
    ("ix_usage_events_type_created_at", "usage_events"),
]


async def _indices_existentes(db: AsyncSession) -> dict[str, str]:
    resultado = await db.execute(
        text("SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = current_schema()")
    )
    return {fila[0]: fila[1] for fila in resultado.all()}


def test_indices_del_sprint_4_existen_en_el_esquema(db_session: AsyncSession) -> None:
    indices = run(_indices_existentes(db_session))

    for nombre, tabla in INDICES_SPRINT4 + INDICES_PREVIOS:
        assert nombre in indices, f"Falta el índice {nombre} sobre {tabla}"
        # La definición incluye el esquema: "ON public.attraction ..."
        assert re.search(rf"ON (\w+\.)?{tabla}\b", indices[nombre]), (
            f"El índice {nombre} no apunta a {tabla}"
        )


def test_indice_de_categoria_es_compuesto(db_session: AsyncSession) -> None:
    """El índice de categoría debe cubrir (category_id, attraction_id)."""
    definicion = run(_indices_existentes(db_session))["idx_attraction_category_category"]

    assert "category_id, attraction_id" in definicion


def test_indice_de_agencias_es_parcial_solo_validadas(db_session: AsyncSession) -> None:
    """RN-01: el índice parcial cubre únicamente las agencias validadas."""
    definicion = run(_indices_existentes(db_session))["idx_agencies_validated"]

    assert "WHERE is_validated" in definicion


def test_indice_de_historial_sos_ordena_por_fecha_desc(db_session: AsyncSession) -> None:
    definicion = run(_indices_existentes(db_session))["idx_sos_reports_user_created"]

    assert "created_at DESC" in definicion


def test_el_indice_redundante_de_categoria_fue_reemplazado(db_session: AsyncSession) -> None:
    indices = run(_indices_existentes(db_session))

    assert "ix_attraction_category_category_id" not in indices
