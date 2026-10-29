"""alertas de clima por atractivo (P2, sprint 4)

Anade ``weather_alert.attraction_id`` e ``is_active`` para el upsert por
(atractivo, tipo): si la severidad cambia se actualiza la fila; si la
condicion cesa, la alerta pasa a ``is_active=False`` en vez de borrarse.

Revision ID: c7d8e9f0a1b2
Revises: 8db9ab3bcce4
Create Date: 2026-10-28 14:05:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c7d8e9f0a1b2'
down_revision: Union[str, Sequence[str], None] = '8db9ab3bcce4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'weather_alert',
        sa.Column('attraction_id', sa.Uuid(), nullable=True),
    )
    op.add_column(
        'weather_alert',
        sa.Column('is_active', sa.Boolean(), server_default=sa.text('true'), nullable=False),
    )
    op.create_foreign_key(
        'fk_weather_alert_attraction',
        'weather_alert',
        'attraction',
        ['attraction_id'],
        ['id'],
        ondelete='CASCADE',
    )
    # Una sola alerta activa por (atractivo, tipo); el filtro `is_active`
    # permite guardar histórico inactivo sin chocar con la activa.
    op.create_index(
        'uq_weather_alert_active_attraction_code',
        'weather_alert',
        ['attraction_id', 'code'],
        unique=True,
        postgresql_where=sa.text('is_active AND attraction_id IS NOT NULL'),
    )
    op.create_index(
        'ix_weather_alert_attraction_active',
        'weather_alert',
        ['attraction_id', 'is_active'],
    )


def downgrade() -> None:
    op.drop_index('ix_weather_alert_attraction_active', table_name='weather_alert')
    op.drop_index('uq_weather_alert_active_attraction_code', table_name='weather_alert')
    op.drop_constraint('fk_weather_alert_attraction', 'weather_alert', type_='foreignkey')
    op.drop_column('weather_alert', 'is_active')
    op.drop_column('weather_alert', 'attraction_id')
