"""add metadata_json to property

Revision ID: 20251012_add_metadata_json_to_property
Revises: 20251012_add_token_standard_to_property
Create Date: 2025-10-12 15:45:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20251012_add_metadata_json_to_property'
down_revision: Union[str, None] = '20251012_add_token_standard_to_property'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade database schema."""
    # Make metadata_uri nullable (it was previously not nullable)
    op.alter_column('properties', 'metadata_uri', existing_type=sa.String(), nullable=True)

    # Add metadata_json column
    op.add_column('properties', sa.Column('metadata_json', sa.String(), nullable=True))


def downgrade() -> None:
    """Downgrade database schema."""
    # Remove metadata_json column
    op.drop_column('properties', 'metadata_json')

    # Make metadata_uri not nullable again (this might fail if there are NULL values)
    op.alter_column('properties', 'metadata_uri', existing_type=sa.String(), nullable=False)














