"""
KYC Verification Model

Tracks KYC verification status for platform participants, ensuring regulatory
compliance for security token offerings.

Supports tiered verification:
- Basic: Individual investors
- Accredited: Accredited investors (SEC Regulation D)
- Institutional: Institutional investors

Integrates with KYCRegistry smart contract for on-chain whitelist enforcement.
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum as SQLEnum, Text, Index
from sqlalchemy.sql import func
from config.database import Base
import enum


class KYCStatus(enum.Enum):
    """KYC verification status states"""
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    EXPIRED = "expired"


class KYCTier(enum.Enum):
    """KYC verification tiers for graduated access control"""
    BASIC = "basic"  # Individual investor (standard KYC)
    ACCREDITED = "accredited"  # Accredited investor (SEC Regulation D requirements)
    INSTITUTIONAL = "institutional"  # Institutional investor (enhanced due diligence)


class KYCVerification(Base):
    """
    KYC Verification tracking table
    
    Stores verification status, personal information (encrypted in production),
    and blockchain integration details for regulatory compliance.
    
    Attributes:
        id: Primary key
        wallet_address: Ethereum address (unique, indexed)
        status: Verification status (pending/approved/rejected/expired)
        tier: Verification tier (basic/accredited/institutional)
        full_name: Full legal name (encrypted in production)
        email: Email address for notifications
        country: Country of residence for compliance checks
        submission_date: When KYC application was submitted
        review_date: When admin reviewed the application
        expiry_date: When verification expires (typically 1 year)
        reviewer_address: Admin wallet address who reviewed
        rejection_reason: Reason for rejection (if applicable)
        whitelisted_on_chain: Whether address is on KYCRegistry whitelist
        whitelist_tx_hash: Transaction hash of whitelist addition
        created_at: Record creation timestamp
        updated_at: Record last update timestamp
    """
    __tablename__ = "kyc_verifications"
    
    # Primary key
    id = Column(Integer, primary_key=True, index=True)
    
    # Wallet identification
    wallet_address = Column(
        String(42),
        nullable=False,
        unique=True,
        index=True,
        comment="Ethereum wallet address (checksummed)"
    )
    
    # Verification status
    status = Column(
        SQLEnum(KYCStatus),
        nullable=False,
        default=KYCStatus.PENDING,
        index=True,
        comment="Current verification status"
    )
    
    tier = Column(
        SQLEnum(KYCTier),
        nullable=False,
        default=KYCTier.BASIC,
        comment="Verification tier for graduated access"
    )
    
    # Personal information (should be encrypted in production using SQLAlchemy-Utils encrypted types)
    full_name = Column(
        String(255),
        nullable=False,
        comment="Full legal name (encrypt in production)"
    )
    
    email = Column(
        String(255),
        nullable=False,
        index=True,
        comment="Email for notifications"
    )
    
    country = Column(
        String(100),
        nullable=False,
        comment="Country of residence for compliance"
    )
    
    # Verification timeline
    submission_date = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="When application was submitted"
    )
    
    review_date = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="When admin reviewed the application"
    )
    
    expiry_date = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="When verification expires (typically 1 year from approval)"
    )
    
    # Review information
    reviewer_address = Column(
        String(42),
        nullable=True,
        comment="Admin wallet address who reviewed"
    )
    
    rejection_reason = Column(
        Text,
        nullable=True,
        comment="Reason for rejection (if status is REJECTED)"
    )
    
    # Blockchain integration
    whitelisted_on_chain = Column(
        Boolean,
        default=False,
        nullable=False,
        comment="Whether address is on KYCRegistry whitelist"
    )
    
    whitelist_tx_hash = Column(
        String(66),
        nullable=True,
        comment="Transaction hash of whitelist addition"
    )
    
    # Audit trail
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="Record creation timestamp"
    )
    
    updated_at = Column(
        DateTime(timezone=True),
        onupdate=func.now(),
        comment="Record last update timestamp"
    )
    
    # Composite indexes for common queries
    __table_args__ = (
        Index('idx_kyc_status_date', 'status', 'submission_date'),
        Index('idx_kyc_wallet', 'wallet_address'),
        Index('idx_kyc_status', 'status'),
    )
    
    def to_dict(self):
        """
        Convert model to dictionary for API responses
        
        Returns:
            dict: Dictionary representation of KYC verification
        """
        return {
            'id': self.id,
            'wallet_address': self.wallet_address,
            'status': self.status.value,
            'tier': self.tier.value,
            'full_name': self.full_name,
            'email': self.email,
            'country': self.country,
            'submission_date': self.submission_date.isoformat() if self.submission_date else None,
            'review_date': self.review_date.isoformat() if self.review_date else None,
            'expiry_date': self.expiry_date.isoformat() if self.expiry_date else None,
            'reviewer_address': self.reviewer_address,
            'whitelisted_on_chain': self.whitelisted_on_chain,
            'whitelist_tx_hash': self.whitelist_tx_hash,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
    
    def to_dict_public(self):
        """
        Convert model to dictionary for public API responses (excludes sensitive fields)
        
        Returns:
            dict: Public dictionary representation
        """
        return {
            'wallet_address': self.wallet_address,
            'status': self.status.value,
            'tier': self.tier.value,
            'submission_date': self.submission_date.isoformat() if self.submission_date else None,
            'whitelisted_on_chain': self.whitelisted_on_chain
        }
    
    def __repr__(self):
        return f"<KYCVerification(id={self.id}, wallet={self.wallet_address}, status={self.status.value})>"

