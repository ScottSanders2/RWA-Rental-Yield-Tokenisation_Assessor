"""
Marketplace Listing Model

SQLAlchemy model for marketplace listings tracking off-chain listing metadata
for secondary market yield share trading.

Architecture:
- Off-chain listings (PostgreSQL storage) with on-chain settlement
- Supports both ERC-721+ERC-20 and ERC-1155 token standards
- USD-first pricing with wei conversion for blockchain transactions
- Links to yield agreements for validation and metadata

Listing Lifecycle:
1. ACTIVE: Listed and available for purchase
2. SOLD: Fully purchased (shares_for_sale == 0)
3. CANCELLED: Cancelled by seller
4. EXPIRED: Past expiry timestamp

Research Contribution:
- Enables secondary market liquidity (Research Question 7)
- Supports fractional pooling (partial listing purchases)
- Tracks USD pricing for user comprehension
- Provides audit trail for dissertation metrics collection
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, Numeric, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from config.database import Base
import enum


class ListingStatus(enum.Enum):
    """Enumeration of marketplace listing statuses"""
    ACTIVE = "active"
    SOLD = "sold"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


class MarketplaceListing(Base):
    """
    Marketplace listing model for secondary market yield share trading.
    
    Attributes:
        id: Primary key
        agreement_id: Foreign key to yield_agreements table
        seller_address: Ethereum address of seller (42-character hex string)
        shares_for_sale: Number of yield shares listed for sale (wei precision)
        price_per_share_usd: Price per share in USD (2 decimal places)
        price_per_share_wei: Price per share in wei (blockchain precision)
        total_listing_value_usd: Total value of listing in USD (computed)
        listing_status: Current status (ACTIVE, SOLD, CANCELLED, EXPIRED)
        token_standard: Token standard ('ERC721' or 'ERC1155')
        token_contract_address: Address of YieldSharesToken or CombinedPropertyYieldToken
        expires_at: Optional expiry timestamp for listing
        created_at: Timestamp when listing was created
        updated_at: Timestamp when listing was last updated
    
    Relationships:
        yield_agreement: Link to YieldAgreement model
        trades: List of MarketplaceTrade records for this listing
    
    Usage:
        - Frontend displays USD-first pricing with ETH conversion
        - Backend validates seller owns sufficient shares before creation
        - Fractional purchases reduce shares_for_sale, mark SOLD when zero
        - Transfer restrictions validated before listing creation and trade settlement
    """
    
    __tablename__ = 'marketplace_listings'
    
    # Primary key
    id = Column(Integer, primary_key=True, index=True)
    
    # Foreign key to yield agreement
    agreement_id = Column(Integer, ForeignKey('yield_agreements.id'), nullable=False, index=True)
    
    # Seller information
    seller_address = Column(String(42), nullable=False, index=True)  # Ethereum address (0x + 40 hex chars)
    
    # Listing amounts (wei precision for blockchain compatibility)
    shares_for_sale = Column(Numeric(precision=78, scale=0), nullable=False)  # Supports up to 10^78 wei
    
    # Pricing (USD-first for user comprehension)
    price_per_share_usd = Column(Numeric(precision=18, scale=2), nullable=False)  # USD with 2 decimal places
    price_per_share_wei = Column(Numeric(precision=78, scale=0), nullable=False)  # Wei price for blockchain
    total_listing_value_usd = Column(Numeric(precision=18, scale=2), nullable=True)  # Computed: shares * price_usd
    
    # Status and metadata
    listing_status = Column(SQLEnum(ListingStatus), default=ListingStatus.ACTIVE, nullable=False, index=True)
    token_standard = Column(String(10), nullable=False)  # 'ERC721' or 'ERC1155'
    token_contract_address = Column(String(42), nullable=False)  # Contract address
    
    # Expiry (optional)
    expires_at = Column(DateTime, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=func.now(), nullable=False)
    updated_at = Column(DateTime, onupdate=func.now())
    
    # Relationships
    yield_agreement = relationship("YieldAgreement", back_populates="marketplace_listings")
    trades = relationship("MarketplaceTrade", back_populates="listing", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<MarketplaceListing(id={self.id}, agreement_id={self.agreement_id}, seller={self.seller_address}, shares={self.shares_for_sale}, status={self.listing_status.value})>"
    
    def to_dict(self):
        """Convert listing to dictionary for API responses"""
        return {
            'id': self.id,
            'agreement_id': self.agreement_id,
            'seller_address': self.seller_address,
            'shares_for_sale': str(self.shares_for_sale),
            'price_per_share_usd': float(self.price_per_share_usd),
            'price_per_share_wei': str(self.price_per_share_wei),
            'total_listing_value_usd': float(self.total_listing_value_usd) if self.total_listing_value_usd else None,
            'listing_status': self.listing_status.value,
            'token_standard': self.token_standard,
            'token_contract_address': self.token_contract_address,
            'expires_at': self.expires_at.isoformat() if self.expires_at else None,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }

