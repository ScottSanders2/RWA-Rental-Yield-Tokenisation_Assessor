"""
SQLAlchemy model for Transaction entity tracking blockchain transactions.

This model records all blockchain interactions for audit trail and performance
metrics analysis. It supports dissertation requirements for time metric tracking
and provides comprehensive transaction history for compliance and debugging.
"""

from sqlalchemy import Column, Integer, String, DateTime, Numeric, ForeignKey, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from config.database import Base


class TransactionStatus(enum.Enum):
    """Enumeration of possible transaction statuses."""
    PENDING = "pending"
    CONFIRMED = "confirmed"
    FAILED = "failed"


class Transaction(Base):
    """
    Transaction model recording blockchain interactions.

    Provides audit trail for all smart contract interactions, supporting
    dissertation time metrics analysis and compliance requirements.
    """

    __tablename__ = "transactions"

    # Primary key
    id = Column(Integer, primary_key=True, autoincrement=True)

    # Transaction identification
    tx_hash = Column(
        String(66),
        unique=True,
        nullable=False,
        comment="Ethereum transaction hash (0x-prefixed, 66 characters)"
    )
    block_number = Column(
        Integer,
        nullable=True,
        comment="Block number where transaction was mined"
    )

    # Timing information
    timestamp = Column(
        DateTime,
        nullable=True,
        comment="Timestamp when transaction was processed"
    )

    # Transaction status and metrics
    status = Column(
        Enum(TransactionStatus),
        default=TransactionStatus.PENDING,
        comment="Current status of the transaction"
    )
    gas_used = Column(
        Integer,
        nullable=True,
        comment="Gas units consumed by transaction"
    )

    # Contract information
    contract_address = Column(
        String(42),
        nullable=False,
        comment="Target contract address (0x-prefixed)"
    )
    function_name = Column(
        String(100),
        nullable=False,
        comment="Smart contract function called"
    )

    # Optional relationship to yield agreement
    yield_agreement_id = Column(
        Integer,
        ForeignKey("yield_agreements.id"),
        nullable=True,
        comment="Associated yield agreement if applicable"
    )

    # Timestamps
    created_at = Column(
        DateTime,
        default=func.now(),
        comment="Record creation timestamp"
    )
    updated_at = Column(
        DateTime,
        default=func.now(),
        onupdate=func.now(),
        comment="Last update timestamp"
    )

    # Relationships
    yield_agreement = relationship("YieldAgreement", back_populates="transactions")

    def __repr__(self) -> str:
        """String representation for debugging."""
        return (
            f"<Transaction(id={self.id}, "
            f"tx_hash={self.tx_hash[:10]}..., "
            f"status={self.status.value}, "
            f"function={self.function_name}, "
            f"gas={self.gas_used})>"
        )
