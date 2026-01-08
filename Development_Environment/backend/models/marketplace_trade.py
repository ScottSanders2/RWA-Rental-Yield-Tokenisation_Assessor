"""
Marketplace Trade Model

SQLAlchemy model for marketplace trades tracking executed secondary market transactions.

Architecture:
- Records completed trades with blockchain settlement details
- Links to marketplace listings for audit trail
- Supports fractional purchases (shares_purchased <= listing.shares_for_sale)
- Captures gas costs for dissertation performance metrics

Trade Flow:
1. Buyer initiates purchase via POST /marketplace/listings/{id}/buy
2. Backend validates buyer, shares available, transfer restrictions
3. Smart contract transfer() or safeTransferFrom() executes on-chain settlement
4. Trade record created with tx_hash and gas_used
5. Listing updated (reduce shares_for_sale or mark SOLD)

Research Contribution:
- Provides audit trail for secondary market activity
- Tracks gas costs for performance analysis (Research Question 3)
- Supports fractional pooling metrics collection
- Links on-chain settlement to off-chain listing metadata
"""

from sqlalchemy import Column, Integer, String, DateTime, Numeric, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from config.database import Base


class MarketplaceTrade(Base):
    """
    Marketplace trade model for executed secondary market transactions.
    
    Attributes:
        id: Primary key
        listing_id: Foreign key to marketplace_listings table
        buyer_address: Ethereum address of buyer (42-character hex string)
        shares_purchased: Number of yield shares purchased (wei precision)
        total_price_usd: Total purchase price in USD (2 decimal places)
        total_price_wei: Total purchase price in wei (blockchain precision)
        tx_hash: Blockchain transaction hash (66-character hex string with 0x prefix)
        gas_used: Gas consumed by transaction (optional, for metrics)
        executed_at: Timestamp when trade was executed
        created_at: Timestamp when trade record was created
    
    Relationships:
        listing: Link to MarketplaceListing model
    
    Usage:
        - Created after successful on-chain transfer settlement
        - tx_hash links off-chain record to blockchain transaction
        - gas_used captured for dissertation gas cost analysis
        - Supports fractional purchases (shares_purchased < listing.shares_for_sale)
        - Multiple trades can link to same listing (partial purchases)
    """
    
    __tablename__ = 'marketplace_trades'
    
    # Primary key
    id = Column(Integer, primary_key=True, index=True)
    
    # Foreign key to marketplace listing
    listing_id = Column(Integer, ForeignKey('marketplace_listings.id'), nullable=False, index=True)
    
    # Buyer information
    buyer_address = Column(String(42), nullable=False, index=True)  # Ethereum address (0x + 40 hex chars)
    
    # Purchase amounts (wei precision for blockchain compatibility)
    shares_purchased = Column(Numeric(precision=78, scale=0), nullable=False)  # Supports up to 10^78 wei
    
    # Pricing (USD-first for user comprehension)
    total_price_usd = Column(Numeric(precision=18, scale=2), nullable=False)  # USD with 2 decimal places
    total_price_wei = Column(Numeric(precision=78, scale=0), nullable=False)  # Wei price for blockchain
    
    # Blockchain settlement details
    tx_hash = Column(String(66), unique=True, nullable=False, index=True)  # Transaction hash (0x + 64 hex chars)
    gas_used = Column(Integer, nullable=True)  # Gas consumed (for performance metrics)
    
    # Timestamps
    executed_at = Column(DateTime, default=func.now(), nullable=False)  # Trade execution time
    created_at = Column(DateTime, default=func.now(), nullable=False)  # Record creation time
    
    # Relationships
    listing = relationship("MarketplaceListing", back_populates="trades")
    
    def __repr__(self):
        return f"<MarketplaceTrade(id={self.id}, listing_id={self.listing_id}, buyer={self.buyer_address}, shares={self.shares_purchased}, tx={self.tx_hash})>"
    
    def to_dict(self):
        """Convert trade to dictionary for API responses"""
        return {
            'id': self.id,
            'listing_id': self.listing_id,
            'buyer_address': self.buyer_address,
            'shares_purchased': str(self.shares_purchased),
            'total_price_usd': float(self.total_price_usd),
            'total_price_wei': str(self.total_price_wei),
            'tx_hash': self.tx_hash,
            'gas_used': self.gas_used,
            'executed_at': self.executed_at.isoformat(),
            'created_at': self.created_at.isoformat()
        }

