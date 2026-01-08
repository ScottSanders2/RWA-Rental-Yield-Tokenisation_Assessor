"""add usd fields to yield_agreements

Revision ID: 20251014_add_upfront_capital_usd_to_yield_agreements
Revises: 20251012_add_metadata_json_to_property
Create Date: 2025-10-14 18:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20251014_add_upfront_capital_usd_to_yield_agreements'
down_revision: Union[str, None] = '20251012_add_metadata_json_to_property'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade database schema."""
    # Add upfront_capital_usd column to yield_agreements table
    op.add_column('yield_agreements', sa.Column('upfront_capital_usd', sa.Numeric(precision=18, scale=2), nullable=False, default=0))
    # Add monthly_payment_usd column to yield_agreements table
    op.add_column('yield_agreements', sa.Column('monthly_payment_usd', sa.Numeric(precision=18, scale=2), nullable=False, default=0))


def downgrade() -> None:
    """Downgrade database schema."""
    # Remove upfront_capital_usd column from yield_agreements table
    op.drop_column('yield_agreements', 'upfront_capital_usd')
    # Remove monthly_payment_usd column from yield_agreements table
    op.drop_column('yield_agreements', 'monthly_payment_usd')


