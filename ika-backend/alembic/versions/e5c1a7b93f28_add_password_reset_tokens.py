"""add password_reset_tokens y users.password_changed_at (RF-03)

Revision ID: e5c1a7b93f28
Revises: d4af4f66c370
Create Date: 2026-11-11 00:00:00.000000

RF-03 · Recuperación de cuenta por correo:
- `password_reset_tokens` guarda **solo** el hash SHA-256 del token (nunca el
  valor en claro), con expiración (30 min) y marca de uso.
- `users.password_changed_at` permite rechazar los JWT emitidos antes del
  cambio de contraseña (`iat` anterior a esa marca).
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e5c1a7b93f28'
down_revision: Union[str, Sequence[str], None] = 'd4af4f66c370'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        'users',
        sa.Column('password_changed_at', sa.DateTime(timezone=True), nullable=True),
    )

    op.create_table(
        'password_reset_tokens',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('token_hash', sa.String(length=64), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('used_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint(
            'token_hash', name='uq_password_reset_tokens_token_hash'
        ),
    )
    op.create_index(
        'ix_password_reset_tokens_user_id',
        'password_reset_tokens',
        ['user_id'],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema (reversible: deshace exactamente lo del upgrade)."""
    op.drop_index(
        'ix_password_reset_tokens_user_id', table_name='password_reset_tokens'
    )
    op.drop_table('password_reset_tokens')
    op.drop_column('users', 'password_changed_at')
