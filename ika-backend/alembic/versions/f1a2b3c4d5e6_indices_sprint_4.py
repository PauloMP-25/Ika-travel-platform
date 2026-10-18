"""índices sprint 4 (optimización de catálogo, analítica y emergencias)

Revision ID: f1a2b3c4d5e6
Revises: a50e921e5758
Create Date: 2026-10-18 10:00:00.000000

Índices del apartado F2 del Sprint 4. Se crean sin `CONCURRENTLY`: para el
volumen del MVP el bloqueo breve de escritura es aceptable y evita el
`autocommit_block` de Alembic. Si la tabla crece en producción, migrar a
`CREATE INDEX CONCURRENTLY` (ver `docs/optimizacion_bd.md`).

Los índices `ix_attraction_lat_lon` (attraction) y
`ix_usage_events_type_created_at` (usage_events) ya existían y cubren los
objetivos de bounding box y de analítica: no se tocan.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f1a2b3c4d5e6'
down_revision: Union[str, Sequence[str], None] = 'a50e921e5758'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Crea los índices de F2 (y elimina el que queda redundante)."""
    # Filtro por categoría del catálogo: el índice compuesto reemplaza al
    # antiguo `ix_attraction_category_category_id` (que era su prefijo).
    op.drop_index('ix_attraction_category_category_id', table_name='attraction_category')
    op.create_index(
        'idx_attraction_category_category',
        'attraction_category',
        ['category_id', 'attraction_id'],
    )

    # `avg(rating)` y distribución de calificaciones por atractivo.
    op.create_index(
        'idx_reviews_attraction_rating', 'reviews', ['attraction_id', 'rating']
    )

    # Listado público de atractivos por distrito solo entre activos.
    op.create_index(
        'idx_attractions_active_district', 'attraction', ['is_active', 'district']
    )

    # RN-01: catálogo de agencias validadas por DIRCETUR (índice parcial).
    op.create_index(
        'idx_agencies_validated',
        'agency',
        ['name'],
        postgresql_where=sa.text('is_validated'),
    )

    # Historial de incidentes SOS del usuario, del más reciente al antiguo.
    op.create_index(
        'idx_sos_reports_user_created',
        'sos_reports',
        ['user_id', 'created_at'],
        postgresql_ops={'created_at': 'DESC'},
    )

    # Panel de fiscalización DIRCETUR: filtro por estado, más recientes primero.
    op.create_index(
        'idx_incident_reports_status_created',
        'tourist_incident_reports',
        ['status', 'created_at'],
        postgresql_ops={'created_at': 'DESC'},
    )


def downgrade() -> None:
    """Elimina los índices y restaura el índice simple de la tabla puente."""
    op.drop_index('idx_incident_reports_status_created', table_name='tourist_incident_reports')
    op.drop_index('idx_sos_reports_user_created', table_name='sos_reports')
    op.drop_index('idx_agencies_validated', table_name='agency')
    op.drop_index('idx_attractions_active_district', table_name='attraction')
    op.drop_index('idx_reviews_attraction_rating', table_name='reviews')

    op.drop_index('idx_attraction_category_category', table_name='attraction_category')
    op.create_index(
        'ix_attraction_category_category_id', 'attraction_category', ['category_id']
    )
