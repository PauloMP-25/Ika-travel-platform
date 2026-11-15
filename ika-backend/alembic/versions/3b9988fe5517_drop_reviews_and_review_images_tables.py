"""drop reviews and review_images tables

Revision ID: 3b9988fe5517
Revises: 1a7766de2405
Create Date: 2026-11-15 10:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '3b9988fe5517'
down_revision: Union[str, Sequence[str], None] = '1a7766de2405'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Elimina las tablas review_images y reviews."""
    op.drop_table('review_images')
    op.drop_table('reviews')


def downgrade() -> None:
    """Restaura las tablas reviews y review_images."""
    op.create_table(
        'reviews',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('attraction_id', sa.Uuid(), nullable=False),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('comment', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint('rating >= 1 AND rating <= 5', name='ck_review_rating_range'),
        sa.ForeignKeyConstraint(['attraction_id'], ['attraction.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'attraction_id', name='uq_user_attraction_review')
    )
    op.create_index('ix_reviews_attraction_id', 'reviews', ['attraction_id'], unique=False)
    op.create_index('ix_reviews_user_id', 'reviews', ['user_id'], unique=False)
    op.create_index('idx_reviews_attraction_rating', 'reviews', ['attraction_id', 'rating'], unique=False)

    op.create_table(
        'review_images',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('review_id', sa.Uuid(), nullable=False),
        sa.Column('image_url', sa.String(length=500), nullable=False),
        sa.Column('storage_provider', sa.String(length=50), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['review_id'], ['reviews.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_review_images_review_id', 'review_images', ['review_id'], unique=False)
