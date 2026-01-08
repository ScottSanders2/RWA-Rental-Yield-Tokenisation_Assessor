"""
SQLAlchemy model for YieldAgreement entity representing rental yield agreements.

This model captures yield agreement parameters, repayment tracking, and blockchain
integration. It supports both ERC-721+ERC-20 and ERC-1155 approaches through the
token_standard field for comparative analysis.
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, Numeric, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from config.database import Base


class YieldAgreement(Base):
    """
    YieldAgreement model representing rental yield tokenization agreements.

    Tracks agreement parameters, repayment progress, and blockchain integration.
    Supports dual token standard approach (ERC-721+ERC-20 vs ERC-1155).
    """

    __tablename__ = "yield_agreements"

    # Primary key
    id = Column(Integer, primary_key=True)

    # Foreign key to Property
    property_id = Column(
        Integer,
        ForeignKey("properties.id"),
        nullable=False,
        comment="Reference to associated property"
    )

    # Financial parameters - stored as uint256 equivalents
    upfront_capital = Column(
        Numeric(precision=78, scale=0),
        nullable=False,
        comment="Initial capital invested in agreement (wei units)"
    )
    upfront_capital_usd = Column(
        Numeric(precision=18, scale=2),
        nullable=False,
        default=0,
        comment="Initial capital invested in agreement (USD)"
    )
    monthly_payment_usd = Column(
        Numeric(precision=18, scale=2),
        nullable=False,
        default=0,
        comment="Monthly payment amount (USD)"
    )
    repayment_term_months = Column(
        Integer,
        nullable=False,
        comment="Total term of the agreement in months"
    )
    annual_roi_basis_points = Column(
        Integer,
        nullable=False,
        comment="Annual return on investment in basis points (1/100th of 1%)"
    )

    # Repayment tracking
    total_repaid = Column(
        Numeric(precision=78, scale=0),
        default=0,
        comment="Total amount repaid so far (wei units)"
    )
    last_repayment_timestamp = Column(
        DateTime,
        nullable=True,
        comment="Timestamp of last repayment transaction"
    )

    # Agreement status
    is_active = Column(
        Boolean,
        default=True,
        comment="Whether the agreement is currently active"
    )

    # Blockchain integration
    blockchain_agreement_id = Column(
        Integer,
        nullable=True,
        comment="Agreement ID from YieldBase contract"
    )
    token_standard = Column(
        String(10),
        nullable=False,
        comment="Token standard used: 'ERC721' or 'ERC1155'"
    )
    token_contract_address = Column(
        String(42),
        nullable=True,
        comment="Address of YieldSharesToken or CombinedPropertyYieldToken contract"
    )

    # Risk parameters
    grace_period_days = Column(
        Integer,
        nullable=False,
        comment="Grace period in days before default penalties apply"
    )
    default_penalty_rate = Column(
        Integer,
        nullable=False,
        comment="Penalty rate for late payments (basis points)"
    )

    # Agreement flexibility options
    allow_partial_repayments = Column(
        Boolean,
        default=False,
        comment="Whether partial repayments are allowed"
    )
    allow_early_repayment = Column(
        Boolean,
        default=False,
        comment="Whether early repayment is allowed"
    )

    # Timestamps
    created_at = Column(
        DateTime,
        default=func.now(),
        comment="Agreement creation timestamp"
    )
    updated_at = Column(
        DateTime,
        default=func.now(),
        onupdate=func.now(),
        comment="Last update timestamp"
    )

    # Relationships
    property = relationship("Property", back_populates="yield_agreements")
    transactions = relationship(
        "Transaction",
        back_populates="yield_agreement",
        cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        """String representation for debugging."""
        return (
            f"<YieldAgreement(id={self.id}, "
            f"property_id={self.property_id}, "
            f"capital={self.upfront_capital}, "
            f"term={self.repayment_term_months}mo, "
            f"roi={self.annual_roi_basis_points}bp, "
            f"active={self.is_active}, "
            f"standard={self.token_standard})>"
        )
