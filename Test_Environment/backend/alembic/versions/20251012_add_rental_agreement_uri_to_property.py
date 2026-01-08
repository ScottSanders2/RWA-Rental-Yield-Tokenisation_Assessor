"""add rental_agreement_uri to property

Revision ID: 20251012_add_rental_agreement_uri_to_property
Revises: 20251012_add_validation_record_table
Create Date: 2025-10-12 16:06:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20251012_add_rental_agreement_uri_to_property'
down_revision: Union[str, None] = '20251012_add_validation_record_table'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade database schema."""
    # Add rental_agreement_uri column to properties table
    op.add_column('properties', sa.Column('rental_agreement_uri', sa.String(), nullable=True))

    # Backfill: Copy current metadata_uri values to rental_agreement_uri for existing records
    # and set metadata_uri to NULL
    op.execute("""
        UPDATE properties
        SET rental_agreement_uri = metadata_uri,
            metadata_uri = NULL
        WHERE rental_agreement_uri IS NULL AND metadata_uri IS NOT NULL
    """)


def downgrade() -> None:
    """Downgrade database schema."""
    # Restore: Copy rental_agreement_uri back to metadata_uri for existing records
    op.execute("""
        UPDATE properties
        SET metadata_uri = rental_agreement_uri
        WHERE metadata_uri IS NULL AND rental_agreement_uri IS NOT NULL
    """)

    # Drop rental_agreement_uri column
    op.drop_column('properties', 'rental_agreement_uri')
