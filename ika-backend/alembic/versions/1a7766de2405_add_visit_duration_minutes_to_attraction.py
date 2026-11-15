"""add_visit_duration_minutes_to_attraction

Revision ID: 1a7766de2405
Revises: b7c9e1f4a2d6
Create Date: 2026-11-15 09:58:59.389151

Punto N.º 4 de pendientes del backend:
- Columna `visit_duration_minutes` (INTEGER, nullable) en tabla `attraction`
  para el cálculo preciso de tiempos en el planificador de itinerarios.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '1a7766de2405'
down_revision: Union[str, Sequence[str], None] = 'b7c9e1f4a2d6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        'attraction',
        sa.Column('visit_duration_minutes', sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('attraction', 'visit_duration_minutes')
