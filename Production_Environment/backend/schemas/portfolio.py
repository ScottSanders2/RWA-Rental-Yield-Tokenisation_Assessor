"""
Portfolio Schemas

Pydantic schemas for user portfolio and share balance endpoints.
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class UserShareBalanceResponse(BaseModel):
    """
    Response schema for user share balance.
    
    Attributes:
        agreement_id: Yield agreement ID
        balance_wei: Share balance in wei
        balance_shares: Share balance as decimal (for display)
        last_updated: Timestamp of last balance change
        
        # Agreement details
        agreement_token_standard: Token standard (ERC721/ERC1155)
        agreement_total_supply: Total token supply
        ownership_percentage: User's ownership percentage
        
        # Property details
        property_id: Property ID
    """
    
    agreement_id: int
    balance_wei: int
    balance_shares: float
    last_updated: Optional[datetime]
    
    # Agreement details
    agreement_token_standard: Optional[str]
    agreement_total_supply: Optional[int]
    ownership_percentage: Optional[float]
    
    # Property details
    property_id: Optional[int]
    
    class Config:
        orm_mode = True


class UserPortfolioSummary(BaseModel):
    """
    Summary of user's complete portfolio.
    
    Attributes:
        user_address: Ethereum wallet address
        total_agreements: Number of agreements user has shares in
        total_shares_value_usd: Estimated total value (placeholder)
        holdings: List of individual holdings
    """
    
    user_address: str
    total_agreements: int
    total_shares_value_usd: Optional[float] = None
    holdings: List[UserShareBalanceResponse]
    
    class Config:
        schema_extra = {
            "example": {
                "user_address": "0x0000000000000000000000000000000000000101",
                "total_agreements": 3,
                "total_shares_value_usd": 150000.00,
                "holdings": [
                    {
                        "agreement_id": 1,
                        "balance_wei": 50000000000000000000000,
                        "balance_shares": 50000.0,
                        "ownership_percentage": 50.0,
                        "agreement_token_standard": "ERC721",
                        "agreement_total_supply": 100000,
                        "property_id": 1
                    }
                ]
            }
        }


class BalanceHistoryItem(BaseModel):
    """
    Single balance change event.
    
    Attributes:
        timestamp: When the change occurred
        event_type: Type of event (TRADE, MINT, BURN)
        agreement_id: Yield agreement ID
        amount_wei: Amount changed (positive for credit, negative for debit)
        balance_after_wei: Balance after change
        counterparty_address: Other party in transaction (if applicable)
        transaction_hash: Blockchain tx hash (if available)
    """
    
    timestamp: datetime
    event_type: str = Field(..., description="TRADE | MINT | BURN")
    agreement_id: int
    amount_wei: int
    balance_after_wei: int
    counterparty_address: Optional[str] = None
    transaction_hash: Optional[str] = None
    
    class Config:
        schema_extra = {
            "example": {
                "timestamp": "2025-11-10T06:00:00",
                "event_type": "TRADE",
                "agreement_id": 1,
                "amount_wei": 50000000000000000000000,
                "balance_after_wei": 50000000000000000000000,
                "counterparty_address": "0x0000000000000000000000000000000000000002",
                "transaction_hash": "0xabc123..."
            }
        }


class UserBalanceHistoryResponse(BaseModel):
    """
    User's complete balance history.
    
    Attributes:
        user_address: Ethereum wallet address
        agreement_id: Filter by agreement (if specified)
        events: List of balance change events
    """
    
    user_address: str
    agreement_id: Optional[int] = None
    events: List[BalanceHistoryItem]
    
    class Config:
        schema_extra = {
            "example": {
                "user_address": "0x0000000000000000000000000000000000000101",
                "agreement_id": 1,
                "events": []
            }
        }

