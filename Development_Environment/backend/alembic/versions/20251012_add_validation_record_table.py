"""add validation_record table

Revision ID: 20251012_add_validation_record_table
Revises:
Create Date: 2025-10-12 15:35:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20251012_add_validation_record_table'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade database schema."""
    # Create validation_records table
    op.create_table('validation_records',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('property_id', sa.Integer(), nullable=False),
        sa.Column('deed_hash', sa.String(length=66), nullable=False),
        sa.Column('rental_agreement_uri', sa.String(length=1000), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['property_id'], ['properties.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    # Create index on property_id for performance
    op.create_index(op.f('ix_validation_records_property_id'), 'validation_records', ['property_id'], unique=False)


def downgrade() -> None:
    """Downgrade database schema."""
    # Drop index
    op.drop_index(op.f('ix_validation_records_property_id'), table_name='validation_records')
    # Drop table
    op.drop_table('validation_records')









