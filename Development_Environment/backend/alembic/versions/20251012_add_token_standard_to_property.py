"""add token_standard to property

Revision ID: 20251012_add_token_standard_to_property
Revises: 20251012_add_validation_record_table
Create Date: 2025-10-12 15:40:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20251012_add_token_standard_to_property'
down_revision: Union[str, None] = '20251012_add_validation_record_table'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade database schema."""
    # Add token_standard column to properties table
    op.add_column('properties', sa.Column('token_standard', sa.String(length=10), server_default='ERC721', nullable=False))

    # Backfill existing records with default value
    op.execute("UPDATE properties SET token_standard = 'ERC721' WHERE token_standard IS NULL")


def downgrade() -> None:
    """Downgrade database schema."""
    # Remove token_standard column from properties table
    op.drop_column('properties', 'token_standard')














