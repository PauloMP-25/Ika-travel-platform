"""crear tabla usage_events

Revision ID: a50e921e5758
Revises: 86f8f1fc5a16
Create Date: 2026-10-15 10:38:23.724655

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = 'a50e921e5758'
down_revision: Union[str, Sequence[str], None] = '86f8f1fc5a16'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    usage_event_type = postgresql.ENUM(
        'translation', 'attraction_search', 'attraction_view',
        name='usage_event_type',
        create_type=False,
    )
    usage_event_type.create(op.get_bind(), checkfirst=True)

    op.create_table('usage_events',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('event_type', usage_event_type, nullable=False),
    sa.Column('ui_language', sa.String(length=5), nullable=True),
    sa.Column('source_lang', sa.String(length=5), nullable=True),
    sa.Column('target_lang', sa.String(length=5), nullable=True),
    sa.Column('translation_origin', sa.String(length=20), nullable=True),
    sa.Column('category_slug', sa.String(length=80), nullable=True),
    sa.Column('district', sa.String(length=80), nullable=True),
    sa.Column('attraction_id', sa.Uuid(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
    sa.ForeignKeyConstraint(['attraction_id'], ['attraction.id'], ondelete='SET NULL'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_usage_events_attraction_id', 'usage_events', ['attraction_id'], unique=False)
    op.create_index('ix_usage_events_type_created_at', 'usage_events', ['event_type', 'created_at'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_usage_events_type_created_at', table_name='usage_events')
    op.drop_index('ix_usage_events_attraction_id', table_name='usage_events')
    op.drop_table('usage_events')

    usage_event_type = postgresql.ENUM(
        'translation', 'attraction_search', 'attraction_view',
        name='usage_event_type',
        create_type=False,
    )
    usage_event_type.drop(op.get_bind(), checkfirst=True)
