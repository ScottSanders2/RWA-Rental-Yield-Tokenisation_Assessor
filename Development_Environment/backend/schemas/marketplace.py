"""
Marketplace API Schemas

Pydantic schemas for marketplace API request validation and response serialization.

Architecture:
- CreateListingRequest: Validates listing creation with fractional share support
- BuySharesRequest: Validates purchase with fractional purchase support
- Response schemas: Serialize listing and trade data for API responses
- USD-first pricing with automatic wei conversion
- Transfer restriction validation integration

Fractional Pooling:
- shares_for_sale_fraction: 0.01-1.0 (sell 1%-100% of holdings)
- shares_to_buy_fraction: 0.01-1.0 (buy 1%-100% of listing)
- Backend computes actual share amounts from fractions

Research Contribution:
- Enables fractional pooling for liquidity (Research Question 7)
- USD-first pricing for user comprehension
- Supports both ERC-721+ERC-20 and ERC-1155 token standards
- Validates transfer restrictions before listing/purchase
"""

from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime
from enum import Enum


class ListingStatus(str, Enum):
    """Listing status enumeration"""
    ACTIVE = "active"
    SOLD = "sold"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


class TokenStandard(str, Enum):
    """Token standard enumeration"""
    ERC721 = "ERC721"
    ERC1155 = "ERC1155"


class CreateListingRequest(BaseModel):
    """
    Request schema for creating marketplace listing.
    
    Attributes:
        agreement_id: Yield agreement ID to list shares for
        shares_for_sale: Absolute share amount in wei (optional, computed from fraction)
        shares_for_sale_fraction: Fractional amount to sell (0.01-1.0, e.g., 0.5 = 50% of holdings)
        price_per_share_usd: Price per share in USD (must be > 0)
        expires_in_days: Optional listing expiry in days (1-365)
        token_standard: Token standard ('ERC721' or 'ERC1155')
        seller_address: Ethereum address of seller (42-character hex string)
    
    Validation:
        - At least one of shares_for_sale or shares_for_sale_fraction must be provided
        - shares_for_sale_fraction must be between 0.01 and 1.0 (1%-100%)
        - price_per_share_usd must be positive
        - expires_in_days must be between 1 and 365 if provided
        - seller_address must be valid Ethereum address format
    """
    
    agreement_id: int = Field(..., gt=0, description="Yield agreement ID")
    shares_for_sale: Optional[int] = Field(None, gt=0, description="Absolute share amount in wei")
    shares_for_sale_fraction: Optional[float] = Field(None, ge=0.01, le=1.0, description="Fractional amount to sell (0.01-1.0)")
    price_per_share_usd: float = Field(..., gt=0, description="Price per share in USD")
    expires_in_days: Optional[int] = Field(None, ge=1, le=365, description="Listing expiry in days")
    token_standard: TokenStandard = Field(TokenStandard.ERC721, description="Token standard")
    seller_address: str = Field(..., min_length=42, max_length=42, description="Seller Ethereum address")
    
    @validator('seller_address')
    def validate_ethereum_address(cls, v):
        """Validate Ethereum address format (0x followed by 40 hex characters)"""
        if not v.startswith('0x'):
            raise ValueError('Address must start with 0x')
        if len(v) != 42:
            raise ValueError('Address must be 42 characters (0x + 40 hex)')
        try:
            int(v, 16)
        except ValueError:
            raise ValueError('Address must contain valid hexadecimal characters')
        return v.lower()
    
    @validator('shares_for_sale_fraction')
    def validate_fraction_provided(cls, v, values):
        """Ensure at least one of shares_for_sale or shares_for_sale_fraction is provided"""
        if v is None and values.get('shares_for_sale') is None:
            raise ValueError('Either shares_for_sale or shares_for_sale_fraction must be provided')
        return v
    
    class Config:
        schema_extra = {
            "example": {
                "agreement_id": 1,
                "shares_for_sale_fraction": 0.5,
                "price_per_share_usd": 5000.00,
                "expires_in_days": 30,
                "token_standard": "ERC721",
                "seller_address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
            }
        }


class CreateListingResponse(BaseModel):
    """
    Response schema for successful listing creation.
    
    Attributes:
        listing_id: Created listing ID
        agreement_id: Yield agreement ID
        shares_for_sale: Absolute share amount in wei
        price_per_share_usd: Price per share in USD
        price_per_share_wei: Price per share in wei
        total_listing_value_usd: Total listing value in USD
        expires_at: Expiry timestamp (if set)
        status: Listing status (typically 'active')
        message: Success message
    """
    
    listing_id: int
    agreement_id: int
    shares_for_sale: int
    price_per_share_usd: float
    price_per_share_wei: int
    total_listing_value_usd: float
    expires_at: Optional[datetime]
    status: str
    message: str
    
    class Config:
        schema_extra = {
            "example": {
                "listing_id": 1,
                "agreement_id": 1,
                "shares_for_sale": 500000000000000000000,
                "price_per_share_usd": 5000.00,
                "price_per_share_wei": 2500000000000000000,
                "total_listing_value_usd": 2500000.00,
                "expires_at": "2025-12-09T00:00:00",
                "status": "active",
                "message": "Listing created successfully"
            }
        }


class BuySharesRequest(BaseModel):
    """
    Request schema for purchasing yield shares from marketplace listing.
    
    Attributes:
        listing_id: Listing ID to purchase from
        shares_to_buy: Absolute share amount in wei (optional, computed from fraction)
        shares_to_buy_fraction: Fractional amount to buy (0.01-1.0, e.g., 0.3 = 30% of listing)
        buyer_address: Ethereum address of buyer (42-character hex string)
        max_price_per_share_usd: Optional slippage protection (reject if price exceeds this)
    
    Validation:
        - At least one of shares_to_buy or shares_to_buy_fraction must be provided
        - shares_to_buy_fraction must be between 0.01 and 1.0 (1%-100%)
        - buyer_address must be valid Ethereum address format
        - max_price_per_share_usd must be positive if provided
    """
    
    listing_id: int = Field(..., gt=0, description="Listing ID to purchase from")
    shares_to_buy: Optional[int] = Field(None, gt=0, description="Absolute share amount in wei")
    shares_to_buy_fraction: Optional[float] = Field(None, ge=0.01, le=1.0, description="Fractional amount to buy (0.01-1.0)")
    buyer_address: str = Field(..., min_length=42, max_length=42, description="Buyer Ethereum address")
    max_price_per_share_usd: Optional[float] = Field(None, gt=0, description="Slippage protection price limit")
    
    @validator('buyer_address')
    def validate_ethereum_address(cls, v):
        """Validate Ethereum address format (0x followed by 40 hex characters)"""
        if not v.startswith('0x'):
            raise ValueError('Address must start with 0x')
        if len(v) != 42:
            raise ValueError('Address must be 42 characters (0x + 40 hex)')
        try:
            int(v, 16)
        except ValueError:
            raise ValueError('Address must contain valid hexadecimal characters')
        return v.lower()
    
    @validator('shares_to_buy_fraction')
    def validate_fraction_provided(cls, v, values):
        """Ensure at least one of shares_to_buy or shares_to_buy_fraction is provided"""
        if v is None and values.get('shares_to_buy') is None:
            raise ValueError('Either shares_to_buy or shares_to_buy_fraction must be provided')
        return v
    
    class Config:
        schema_extra = {
            "example": {
                "listing_id": 1,
                "shares_to_buy_fraction": 0.3,
                "buyer_address": "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199",
                "max_price_per_share_usd": 5500.00
            }
        }


class BuySharesResponse(BaseModel):
    """
    Response schema for successful share purchase.
    
    Attributes:
        trade_id: Created trade ID
        listing_id: Listing ID purchased from
        shares_purchased: Absolute share amount purchased in wei
        total_price_usd: Total purchase price in USD
        total_price_wei: Total purchase price in wei
        tx_hash: Blockchain transaction hash
        gas_used: Gas consumed by transaction
        status: Trade status (typically 'executed')
        message: Success message
    """
    
    trade_id: int
    listing_id: int
    shares_purchased: int
    total_price_usd: float
    total_price_wei: int
    tx_hash: str
    gas_used: Optional[int]
    status: str
    message: str
    
    class Config:
        schema_extra = {
            "example": {
                "trade_id": 1,
                "listing_id": 1,
                "shares_purchased": 150000000000000000000,
                "total_price_usd": 750000.00,
                "total_price_wei": 375000000000000000,
                "tx_hash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
                "gas_used": 85000,
                "status": "executed",
                "message": "Shares purchased successfully"
            }
        }


class ListingDetailResponse(BaseModel):
    """
    Response schema for detailed listing information.
    
    Attributes:
        All MarketplaceListing model fields plus computed fields:
        - seller_balance: Current shares owned by seller
        - listing_age_hours: Time since listing creation
        - fractional_availability: Fraction of listing still available (0.0-1.0)
    """
    
    id: int
    agreement_id: int
    seller_address: str
    shares_for_sale: int
    price_per_share_usd: float
    price_per_share_wei: int
    total_listing_value_usd: Optional[float]
    listing_status: str
    token_standard: str
    token_contract_address: str
    expires_at: Optional[datetime]
    created_at: datetime
    updated_at: Optional[datetime]
    
    # Computed fields
    seller_balance: Optional[int] = Field(None, description="Current shares owned by seller")
    listing_age_hours: Optional[float] = Field(None, description="Hours since listing creation")
    fractional_availability: Optional[float] = Field(None, description="Fraction of listing available (0.0-1.0)")
    
    # Seller profile information
    seller_display_name: Optional[str] = Field(None, description="Seller's display name from user profile")
    seller_role: Optional[str] = Field(None, description="Seller's role (property_owner, investor, admin)")
    
    class Config:
        orm_mode = True
        schema_extra = {
            "example": {
                "id": 1,
                "agreement_id": 1,
                "seller_address": "0x742d35cc6634c0532925a3b844bc9e7595f0beb",
                "shares_for_sale": 500000000000000000000,
                "price_per_share_usd": 5000.00,
                "price_per_share_wei": 2500000000000000000,
                "total_listing_value_usd": 2500000.00,
                "listing_status": "active",
                "token_standard": "ERC721",
                "token_contract_address": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
                "expires_at": "2025-12-09T00:00:00",
                "created_at": "2025-11-09T00:00:00",
                "updated_at": "2025-11-09T00:00:00",
                "seller_balance": 1000000000000000000000,
                "listing_age_hours": 24.5,
                "fractional_availability": 1.0
            }
        }

