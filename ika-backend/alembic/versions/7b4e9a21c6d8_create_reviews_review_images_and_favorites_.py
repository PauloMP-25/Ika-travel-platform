"""create reviews, review_images and favorites tables

Revision ID: 7b4e9a21c6d8
Revises: c12ff0cd8dcb
Create Date: 2026-10-17 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7b4e9a21c6d8'
down_revision: Union[str, None] = 'c12ff0cd8dcb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'reviews',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('attraction_id', sa.Uuid(), nullable=False),
        sa.Column('rating', sa.Integer(), nullable=False),
        sa.Column('comment', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.CheckConstraint('rating BETWEEN 1 AND 5', name='ck_reviews_rating_range'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['attraction_id'], ['attraction.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'attraction_id', name='uq_reviews_user_attraction'),
    )
    op.create_index(op.f('ix_reviews_user_id'), 'reviews', ['user_id'], unique=False)
    op.create_index(op.f('ix_reviews_attraction_id'), 'reviews', ['attraction_id'], unique=False)

    op.create_table(
        'review_images',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('review_id', sa.Uuid(), nullable=False),
        sa.Column('url', sa.String(length=500), nullable=False),
        sa.ForeignKeyConstraint(['review_id'], ['reviews.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_review_images_review_id'), 'review_images', ['review_id'], unique=False)

    op.create_table(
        'favorites',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('user_id', sa.Uuid(), nullable=False),
        sa.Column('attraction_id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['attraction_id'], ['attraction.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'attraction_id', name='uq_favorites_user_attraction'),
    )
    op.create_index(op.f('ix_favorites_user_id'), 'favorites', ['user_id'], unique=False)
    op.create_index(op.f('ix_favorites_attraction_id'), 'favorites', ['attraction_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index(op.f('ix_favorites_attraction_id'), table_name='favorites')
    op.drop_index(op.f('ix_favorites_user_id'), table_name='favorites')
    op.drop_table('favorites')
    op.drop_index(op.f('ix_review_images_review_id'), table_name='review_images')
    op.drop_table('review_images')
    op.drop_index(op.f('ix_reviews_attraction_id'), table_name='reviews')
    op.drop_index(op.f('ix_reviews_user_id'), table_name='reviews')
    op.drop_table('reviews')
