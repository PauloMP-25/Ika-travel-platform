"""add_address_and_business_hours_to_agency

Revision ID: 4c8877ef9901
Revises: 3b9988fe5517
Create Date: 2026-11-15 13:16:00.000000

Información oficial de prestadores de servicios turísticos (DIRCETUR Ica):
- `address`: Dirección legal o de atención en Ica / Paracas.
- `business_hours`: Horario oficial de atención al turista.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4c8877ef9901'
down_revision: Union[str, Sequence[str], None] = '3b9988fe5517'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema (idempotente)."""
    op.execute(
        "ALTER TABLE agency ADD COLUMN IF NOT EXISTS address VARCHAR(250) DEFAULT 'Ica, Perú';"
    )
    op.execute(
        "ALTER TABLE agency ADD COLUMN IF NOT EXISTS business_hours VARCHAR(100) DEFAULT 'Lunes a Domingo: 08:00 - 18:00';"
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute("ALTER TABLE agency DROP COLUMN IF EXISTS business_hours;")
    op.execute("ALTER TABLE agency DROP COLUMN IF EXISTS address;")
