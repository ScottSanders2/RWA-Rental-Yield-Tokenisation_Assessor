"""
User Share Balance Model

Tracks per-user ownership of yield agreement shares for secondary market operations.

Architecture:
- Each record represents a user's balance for a specific yield agreement
- Balances stored in wei (1 share = 10^18 wei) for precision
- Updated on: agreement creation, marketplace trades, distributions
- Prevents phantom shares and enables accurate marketplace listings

Database Schema:
- user_address: Ethereum wallet address (indexed)
- agreement_id: Foreign key to yield_agreements (indexed)
- balance_wei: Share balance in wei (BigInteger for precision)
- last_updated: Timestamp of last balance change
- Composite unique constraint on (user_address, agreement_id)

Research Contribution:
- Enables accurate secondary market liquidity tracking (Research Question 7)
- Provides data for investor behavior analysis
- Supports fractional ownership transparency
"""

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index, UniqueConstraint, Numeric
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from config.database import Base


class UserShareBalance(Base):
    """
    Model for tracking user share balances per yield agreement.
    
    Attributes:
        id: Primary key
        user_address: Ethereum wallet address of user
        agreement_id: Reference to yield agreement
        balance_wei: Current share balance in wei
        last_updated: Timestamp of last balance change
        created_at: Record creation timestamp
    
    Relationships:
        agreement: Reference to YieldAgreement
    
    Usage:
        # Query user's balance for agreement
        balance = db.query(UserShareBalance).filter(
            UserShareBalance.user_address == '0x123...',
            UserShareBalance.agreement_id == 1
        ).first()
        
        # Update balance after trade
        balance.balance_wei += shares_purchased_wei
        balance.last_updated = datetime.utcnow()
    """
    
    __tablename__ = "user_share_balances"
    
    # Primary key
    id = Column(Integer, primary_key=True, index=True)
    
    # User identification
    user_address = Column(
        String(100),  # Increased to accommodate various address formats
        nullable=False,
        index=True,
        comment="Ethereum wallet address (lowercase, with 0x prefix)"
    )
    
    # Agreement reference
    agreement_id = Column(
        Integer,
        ForeignKey("yield_agreements.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="Foreign key to yield_agreements table"
    )
    
    # Balance in wei (1 share = 10^18 wei)
    balance_wei = Column(
        Numeric(precision=78, scale=0),  # Supports up to 78 digits (more than enough for 10^60)
        nullable=False,
        default=0,
        comment="Share balance in wei (use Numeric for unlimited precision)"
    )
    
    # Timestamps
    last_updated = Column(
        DateTime,
        nullable=False,
        default=func.now(),
        onupdate=func.now(),
        comment="Timestamp of last balance change"
    )
    
    created_at = Column(
        DateTime,
        nullable=False,
        default=func.now(),
        comment="Record creation timestamp"
    )
    
    # Relationships
    agreement = relationship(
        "YieldAgreement",
        back_populates="user_balances"
    )
    
    # Constraints
    __table_args__ = (
        # Ensure one record per user per agreement
        UniqueConstraint('user_address', 'agreement_id', name='uq_user_agreement'),
        
        # Composite index for efficient queries
        Index('idx_user_agreement_balance', 'user_address', 'agreement_id', 'balance_wei'),
        
        # Check constraint to ensure non-negative balances
        # Note: SQLite doesn't enforce CHECK constraints by default, but PostgreSQL does
        # CheckConstraint('balance_wei >= 0', name='chk_balance_non_negative')
    )
    
    def __repr__(self):
        """String representation for debugging."""
        balance_shares = self.balance_wei / 10**18 if self.balance_wei else 0
        return (
            f"<UserShareBalance("
            f"id={self.id}, "
            f"user={self.user_address[:10]}..., "
            f"agreement={self.agreement_id}, "
            f"balance={balance_shares:.2f} shares"
            f")>"
        )
    
    def to_dict(self):
        """Convert to dictionary for API responses."""
        return {
            "id": self.id,
            "user_address": self.user_address,
            "agreement_id": self.agreement_id,
            "balance_wei": int(self.balance_wei),
            "balance_shares": float(self.balance_wei) / 10**18,
            "last_updated": self.last_updated.isoformat() if self.last_updated else None,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }

