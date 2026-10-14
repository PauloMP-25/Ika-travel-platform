"""add_role_language_and_preferences_to_users

Revision ID: 27a9b3325c1b
Revises: da969b9d0ccb
Create Date: 2026-10-14 00:38:18.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '27a9b3325c1b'
down_revision: Union[str, None] = 'da969b9d0ccb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Crear el tipo enum en postgresql antes de usarlo en la columna
    user_role = postgresql.ENUM('tourist', 'dircetur_admin', name='user_role')
    user_role.create(op.get_bind(), checkfirst=True)

    # 2. Agregar columnas
    op.add_column('users', sa.Column('role', sa.Enum('tourist', 'dircetur_admin', name='user_role'), server_default='tourist', nullable=False))
    op.add_column('users', sa.Column('preferred_language', sa.String(length=5), server_default='es', nullable=False))
    op.add_column('users', sa.Column('preferences', sa.JSON(), server_default='[]', nullable=False))


def downgrade() -> None:
    op.drop_column('users', 'preferences')
    op.drop_column('users', 'preferred_language')
    op.drop_column('users', 'role')

    user_role = postgresql.ENUM('tourist', 'dircetur_admin', name='user_role')
    user_role.drop(op.get_bind(), checkfirst=True)
