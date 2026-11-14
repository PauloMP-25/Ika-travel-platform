"""crear tabla roles y FK users.role_id (Corrección N.º 14)

Revision ID: b7c9e1f4a2d6
Revises: e5c1a7b93f28
Create Date: 2026-11-13 00:00:00.000000

Corrección N.º 14 · Tabla de roles alineada con los actores de negocio:
- `roles` (id, name, description, created_at) con seed de los roles base
  del informe: `tourist` y `dircetur_admin`.
- `users.role_id` FK NOT NULL -> `roles.id`, con backfill desde el enum
  `user_role` existente y `server_default` al rol `tourist`.
- El enum `users.role` se conserva como espejo de compatibilidad para la
  API y el cliente móvil.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b7c9e1f4a2d6'
down_revision: Union[str, Sequence[str], None] = 'e5c1a7b93f28'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# UUIDs fijos: deben coincidir con ROLE_TOURIST_ID / ROLE_DIRCETUR_ADMIN_ID
# de `src/modules/users/models.py`.
ROLE_TOURIST_ID = '11111111-1111-4111-8111-111111111111'
ROLE_DIRCETUR_ADMIN_ID = '22222222-2222-4222-8222-222222222222'


def upgrade() -> None:
    """Upgrade schema: crea `roles`, siembra y vincula `users.role_id`."""
    op.create_table(
        'roles',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('name', sa.String(length=50), nullable=False),
        sa.Column('description', sa.String(length=255), nullable=False),
        sa.Column(
            'created_at',
            sa.DateTime(timezone=True),
            server_default=sa.text('now()'),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('name', name='uq_roles_name'),
    )

    # Seed de los actores de negocio definidos en el informe del proyecto.
    op.execute(
        "INSERT INTO roles (id, name, description) VALUES "
        f"('{ROLE_TOURIST_ID}', 'tourist', "
        "'Turista: usuario final que explora la plataforma, guarda "
        "favoritos, emite reseñas y usa el botón SOS.'), "
        f"('{ROLE_DIRCETUR_ADMIN_ID}', 'dircetur_admin', "
        "'Administrador DIRCETUR Ica: personal autorizado para fiscalizar "
        "reportes de informalidad, gestionar reseñas y consultar "
        "analítica.');"
    )

    # 1) Columna nullable -> 2) backfill desde el enum -> 3) NOT NULL + FK.
    op.add_column('users', sa.Column('role_id', sa.Uuid(), nullable=True))
    op.execute(
        "UPDATE users SET role_id = CASE role::text "
        f"WHEN 'dircetur_admin' THEN '{ROLE_DIRCETUR_ADMIN_ID}'::uuid "
        f"ELSE '{ROLE_TOURIST_ID}'::uuid END"
    )
    op.alter_column(
        'users',
        'role_id',
        existing_type=sa.Uuid(),
        nullable=False,
        server_default=sa.text(f"'{ROLE_TOURIST_ID}'"),
    )
    op.create_foreign_key(
        'fk_users_role_id', 'users', 'roles', ['role_id'], ['id']
    )
    op.create_index('ix_users_role_id', 'users', ['role_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema (reversible: deshace exactamente lo del upgrade)."""
    op.drop_index('ix_users_role_id', table_name='users')
    op.drop_constraint('fk_users_role_id', 'users', type_='foreignkey')
    op.alter_column(
        'users',
        'role_id',
        existing_type=sa.Uuid(),
        nullable=True,
        server_default=None,
    )
    op.drop_column('users', 'role_id')
    op.drop_table('roles')
