"""
SQLAlchemy model for TokenBalance entity representing token ownership per wallet.

This model tracks token balances for each wallet address per yield agreement,
simulating blockchain token state in Development/Test environments.
"""

from sqlalchemy import Column, Integer, String, BigInteger, DateTime, ForeignKey, Index, UniqueConstraint, CheckConstraint
from sqlalchemy.sql import func
from config.database import Base


class TokenBalance(Base):
    """
    TokenBalance model representing token ownership for governance voting.

    Tracks how many tokens each wallet holds for each agreement. This simulates
    blockchain token balances in Dev/Test environments. In Production, token
    balances would be queried directly from the blockchain.
    """

    __tablename__ = "token_balances"

    # Primary key
    id = Column(Integer, primary_key=True, index=True)

    # Foreign key to YieldAgreement
    agreement_id = Column(
        Integer,
        ForeignKey('yield_agreements.id', ondelete='CASCADE'),
        nullable=False,
        comment="Reference to the yield agreement"
    )

    # Wallet address (Ethereum address format)
    wallet_address = Column(
        String(42),
        nullable=False,
        index=True,
        comment="Ethereum address of the token holder (0x... format)"
    )

    # Token balance
    balance = Column(
        BigInteger,
        nullable=False,
        default=0,
        comment="Number of tokens held by this wallet for this agreement"
    )

    # Token standard
    token_standard = Column(
        String(10),
        nullable=False,
        comment="Token standard: ERC721 (NFT) or ERC1155 (fungible)"
    )

    # Last updated timestamp
    last_updated = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        comment="Timestamp of last balance update"
    )

    # Table-level constraints
    __table_args__ = (
        UniqueConstraint('agreement_id', 'wallet_address', name='uq_agreement_wallet'),
        CheckConstraint('balance >= 0', name='chk_balance_positive'),
        CheckConstraint(
            "token_standard IN ('ERC721', 'ERC1155')",
            name='chk_token_standard'
        ),
        Index('idx_token_balances_agreement', 'agreement_id'),
        Index('idx_token_balances_wallet', 'wallet_address'),
        Index('idx_token_balances_updated', 'last_updated'),
    )

    def __repr__(self):
        return (
            f"<TokenBalance(id={self.id}, "
            f"agreement={self.agreement_id}, "
            f"wallet={self.wallet_address[:10]}..., "
            f"balance={self.balance}, "
            f"standard={self.token_standard})>"
        )

