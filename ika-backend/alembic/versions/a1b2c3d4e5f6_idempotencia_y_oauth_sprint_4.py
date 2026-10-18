"""idempotencia y oauth (sprint 4)

Revision ID: a1b2c3d4e5f6
Revises: f1a2b3c4d5e6
Create Date: 2026-10-18 11:00:00.000000

- `idempotency_key` / `request_hash` en `sos_reports` y
  `tourist_incident_reports`, con unicidad de la clave **dentro del ámbito
  del usuario** (PostgreSQL admite varios NULL, así que la cabecera sigue
  siendo opcional).
- Índice único parcial sobre `users.provider_id` (`sub` del proveedor
  social) para que un `sub` no se vincule a dos cuentas.

Se revisó a mano `upgrade` y `downgrade` sobre BD limpia y con datos
(BD aislada `ika_travel_mig`).
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = 'f1a2b3c4d5e6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Añade las columnas de idempotencia y los índices únicos."""
    op.add_column(
        'sos_reports',
        sa.Column('idempotency_key', sa.String(length=64), nullable=True),
    )
    op.add_column(
        'sos_reports',
        sa.Column('request_hash', sa.String(length=64), nullable=True),
    )
    op.create_unique_constraint(
        'uq_sos_reports_user_idempotency',
        'sos_reports',
        ['user_id', 'idempotency_key'],
    )

    op.add_column(
        'tourist_incident_reports',
        sa.Column('idempotency_key', sa.String(length=64), nullable=True),
    )
    op.add_column(
        'tourist_incident_reports',
        sa.Column('request_hash', sa.String(length=64), nullable=True),
    )
    op.create_unique_constraint(
        'uq_incident_reports_user_idempotency',
        'tourist_incident_reports',
        ['user_id', 'idempotency_key'],
    )

    op.create_index(
        'uq_users_provider_id',
        'users',
        ['provider_id'],
        unique=True,
        postgresql_where=sa.text('provider_id IS NOT NULL'),
    )


def downgrade() -> None:
    """Elimina las columnas y los índices creados."""
    op.drop_index('uq_users_provider_id', table_name='users')

    op.drop_constraint(
        'uq_incident_reports_user_idempotency',
        'tourist_incident_reports',
        type_='unique',
    )
    op.drop_column('tourist_incident_reports', 'request_hash')
    op.drop_column('tourist_incident_reports', 'idempotency_key')

    op.drop_constraint('uq_sos_reports_user_idempotency', 'sos_reports', type_='unique')
    op.drop_column('sos_reports', 'request_hash')
    op.drop_column('sos_reports', 'idempotency_key')
