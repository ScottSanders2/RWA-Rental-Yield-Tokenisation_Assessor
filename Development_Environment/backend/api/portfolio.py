"""
Portfolio API

Endpoints for querying user share balances and portfolio holdings.

Routes:
- GET /portfolio/{user_address} - Get user's complete portfolio
- GET /portfolio/{user_address}/balance/{agreement_id} - Get specific balance
- GET /portfolio/{user_address}/history - Get balance change history
"""

from fastapi import APIRouter, Depends, HTTPException, Query, Path
from sqlalchemy.orm import Session
from typing import List, Optional
from config.database import get_db
from models.user_share_balance import UserShareBalance
from models.yield_agreement import YieldAgreement
from models.property import Property
from models.marketplace_trade import MarketplaceTrade
from models.marketplace_listing import MarketplaceListing
from schemas.portfolio import (
    UserPortfolioSummary,
    UserShareBalanceResponse,
    UserBalanceHistoryResponse,
    BalanceHistoryItem
)
import logging
import time

router = APIRouter(prefix="/portfolio", tags=["portfolio"])
logger = logging.getLogger(__name__)


@router.get("/{user_address}", response_model=UserPortfolioSummary)
async def get_user_portfolio(
    user_address: str = Path(..., description="User's Ethereum wallet address"),
    db: Session = Depends(get_db)
):
    """
    Get user's complete portfolio of share holdings.
    
    Returns:
        UserPortfolioSummary with all holdings
    """
    start_time = time.time()
    user_address = user_address.lower()
    
    logger.info(f"Fetching portfolio for user: {user_address}")
    
    # Query all balances for user
    balances = db.query(UserShareBalance).filter(
        UserShareBalance.user_address == user_address,
        UserShareBalance.balance_wei > 0  # Only show non-zero balances
    ).all()
    
    holdings = []
    total_value_usd = 0.0
    
    for balance in balances:
        # Get agreement details
        agreement = db.query(YieldAgreement).filter(
            YieldAgreement.id == balance.agreement_id
        ).first()
        
        if not agreement:
            continue
        
        # Get property details
        property_obj = db.query(Property).filter(
            Property.id == agreement.property_id
        ).first()
        
        # Calculate ownership percentage
        ownership_pct = (balance.balance_wei / (agreement.total_token_supply * 10**18)) * 100 if agreement.total_token_supply > 0 else 0
        
        holdings.append(UserShareBalanceResponse(
            agreement_id=balance.agreement_id,
            balance_wei=int(balance.balance_wei),
            balance_shares=float(balance.balance_wei) / 10**18,
            last_updated=balance.last_updated,
            agreement_token_standard=agreement.token_standard,
            agreement_total_supply=agreement.total_token_supply,
            ownership_percentage=float(ownership_pct),
            property_id=property_obj.id if property_obj else None
        ))
        
        # Placeholder value calculation (could be enhanced with actual valuations)
        # total_value_usd += (balance.balance_wei / 10**18) * some_price_per_share
    
    duration_ms = (time.time() - start_time) * 1000
    logger.info(f"Portfolio fetch completed in {duration_ms:.0f}ms: {len(holdings)} holdings")
    
    return UserPortfolioSummary(
        user_address=user_address,
        total_agreements=len(holdings),
        total_shares_value_usd=total_value_usd if total_value_usd > 0 else None,
        holdings=holdings
    )


@router.get("/{user_address}/agreements")
async def get_user_agreements(
    user_address: str = Path(..., description="User's Ethereum wallet address"),
    db: Session = Depends(get_db)
):
    """
    Get list of yield agreements where user has shares (balance > 0).
    
    Returns list of agreements with balance info for dropdown filtering.
    """
    user_address = user_address.lower()
    
    logger.info(f"Fetching agreements for user {user_address}")
    
    # Query balances where user has shares
    balances = db.query(UserShareBalance).filter(
        UserShareBalance.user_address == user_address,
        UserShareBalance.balance_wei > 0
    ).all()
    
    agreements_list = []
    for balance in balances:
        agreement = db.query(YieldAgreement).filter(
            YieldAgreement.id == balance.agreement_id
        ).first()
        
        if agreement:
            # Generate agreement name with agreement ID first for better readability
            # Truncate property ID for mobile picker rendering
            if agreement.property:
                # Format: "Agr #69 - Prop #146" (shortened for mobile)
                agreement_name = f"Agr #{agreement.id} - Prop #{agreement.property.id}"
            else:
                # Fallback if no property linked
                agreement_name = f"Agr #{agreement.id}"
            
            agreements_list.append({
                "id": agreement.id,
                "agreement_name": agreement_name,
                "token_standard": agreement.token_standard,
                "total_token_supply": agreement.total_token_supply,
                "user_balance_wei": int(balance.balance_wei),
                "user_balance_shares": float(balance.balance_wei) / 10**18,
                "ownership_percentage": (float(balance.balance_wei) / (agreement.total_token_supply * 10**18) * 100) if agreement.total_token_supply > 0 else 0
            })
    
    # Sort agreements by ID descending (newest first)
    agreements_list.sort(key=lambda x: x['id'], reverse=True)
    
    return {
        "user_address": user_address,
        "agreements": agreements_list,
        "total_agreements": len(agreements_list)
    }


@router.get("/{user_address}/available-balance/{agreement_id}")
async def get_user_available_balance(
    user_address: str = Path(..., description="User's Ethereum wallet address"),
    agreement_id: int = Path(..., description="Yield agreement ID"),
    db: Session = Depends(get_db)
):
    """
    Get user's AVAILABLE share balance for listing (total balance minus already listed shares).
    
    Returns:
        {
            "total_balance_wei": int,
            "listed_balance_wei": int,
            "available_balance_wei": int,
            "total_balance_shares": float,
            "listed_balance_shares": float,
            "available_balance_shares": float
        }
    """
    from models.marketplace_listing import MarketplaceListing
    from sqlalchemy import func
    
    user_address = user_address.lower()
    
    logger.info(f"Fetching available balance for user {user_address}, agreement {agreement_id}")
    
    # Get total balance
    balance = db.query(UserShareBalance).filter(
        UserShareBalance.user_address == user_address,
        UserShareBalance.agreement_id == agreement_id
    ).first()
    
    total_balance_wei = int(balance.balance_wei) if balance else 0
    
    # Get sum of shares in active listings
    listed_balance_wei = db.query(func.sum(MarketplaceListing.shares_for_sale)).filter(
        MarketplaceListing.seller_address == user_address,
        MarketplaceListing.agreement_id == agreement_id,
        MarketplaceListing.listing_status == 'ACTIVE'
    ).scalar() or 0
    
    available_balance_wei = total_balance_wei - int(listed_balance_wei)
    
    return {
        "total_balance_wei": total_balance_wei,
        "listed_balance_wei": int(listed_balance_wei),
        "available_balance_wei": available_balance_wei,
        "total_balance_shares": float(total_balance_wei) / 10**18,
        "listed_balance_shares": float(listed_balance_wei) / 10**18,
        "available_balance_shares": float(available_balance_wei) / 10**18
    }


@router.get("/{user_address}/balance/{agreement_id}", response_model=UserShareBalanceResponse)
async def get_user_balance_for_agreement(
    user_address: str = Path(..., description="User's Ethereum wallet address"),
    agreement_id: int = Path(..., description="Yield agreement ID"),
    db: Session = Depends(get_db)
):
    """
    Get user's share balance for a specific yield agreement.
    
    Returns:
        UserShareBalanceResponse with balance details
    """
    user_address = user_address.lower()
    
    logger.info(f"Fetching balance for user {user_address}, agreement {agreement_id}")
    
    # Query balance
    balance = db.query(UserShareBalance).filter(
        UserShareBalance.user_address == user_address,
        UserShareBalance.agreement_id == agreement_id
    ).first()
    
    if not balance:
        # Return zero balance if no record exists
        agreement = db.query(YieldAgreement).filter(
            YieldAgreement.id == agreement_id
        ).first()
        
        if not agreement:
            raise HTTPException(status_code=404, detail=f"Yield agreement {agreement_id} not found")
        
        return UserShareBalanceResponse(
            agreement_id=agreement_id,
            balance_wei=0,
            balance_shares=0.0,
            last_updated=None,
            agreement_token_standard=agreement.token_standard,
            agreement_total_supply=agreement.total_token_supply,
            ownership_percentage=0.0,
            property_id=agreement.property_id,
        )
    
    # Get agreement and property details
    agreement = db.query(YieldAgreement).filter(
        YieldAgreement.id == balance.agreement_id
    ).first()
    
    property_obj = None
    if agreement:
        property_obj = db.query(Property).filter(
            Property.id == agreement.property_id
        ).first()
    
    ownership_pct = (balance.balance_wei / (agreement.total_token_supply * 10**18)) * 100 if agreement and agreement.total_token_supply > 0 else 0
    
    return UserShareBalanceResponse(
        agreement_id=balance.agreement_id,
        balance_wei=int(balance.balance_wei),
        balance_shares=float(balance.balance_wei) / 10**18,
        last_updated=balance.last_updated,
        agreement_token_standard=agreement.token_standard if agreement else None,
        agreement_total_supply=agreement.total_token_supply if agreement else None,
        ownership_percentage=float(ownership_pct),
        property_id=property_obj.id if property_obj else None
    )


@router.get("/{user_address}/history", response_model=UserBalanceHistoryResponse)
async def get_user_balance_history(
    user_address: str = Path(..., description="User's Ethereum wallet address"),
    agreement_id: Optional[int] = Query(None, description="Filter by agreement ID"),
    db: Session = Depends(get_db)
):
    """
    Get user's balance change history (marketplace trades).
    
    Note: Currently only tracks marketplace trades. Future: minting, burning, distributions.
    
    Returns:
        UserBalanceHistoryResponse with event history
    """
    user_address = user_address.lower()
    
    logger.info(f"Fetching balance history for user {user_address}")
    
    events = []
    
    # Query marketplace trades where user was buyer
    buyer_trades = db.query(MarketplaceTrade).join(
        MarketplaceListing,
        MarketplaceTrade.listing_id == MarketplaceListing.id
    ).filter(
        MarketplaceTrade.buyer_address == user_address
    )
    
    if agreement_id:
        buyer_trades = buyer_trades.filter(MarketplaceListing.agreement_id == agreement_id)
    
    buyer_trades = buyer_trades.all()
    
    for trade in buyer_trades:
        listing = db.query(MarketplaceListing).filter(
            MarketplaceListing.id == trade.listing_id
        ).first()
        
        if listing:
            events.append(BalanceHistoryItem(
                timestamp=trade.executed_at,
                event_type="TRADE",
                agreement_id=listing.agreement_id,
                amount_wei=int(trade.shares_purchased),  # Positive = credit
                balance_after_wei=0,  # Would need to calculate
                counterparty_address=listing.seller_address,
                transaction_hash=trade.tx_hash
            ))
    
    # Query marketplace trades where user was seller
    seller_listings = db.query(MarketplaceListing).filter(
        MarketplaceListing.seller_address == user_address
    )
    
    if agreement_id:
        seller_listings = seller_listings.filter(MarketplaceListing.agreement_id == agreement_id)
    
    seller_listings = seller_listings.all()
    
    for listing in seller_listings:
        trades = db.query(MarketplaceTrade).filter(
            MarketplaceTrade.listing_id == listing.id
        ).all()
        
        for trade in trades:
            events.append(BalanceHistoryItem(
                timestamp=trade.executed_at,
                event_type="TRADE",
                agreement_id=listing.agreement_id,
                amount_wei=-int(trade.shares_purchased),  # Negative = debit
                balance_after_wei=0,  # Would need to calculate
                counterparty_address=trade.buyer_address,
                transaction_hash=trade.tx_hash
            ))
    
    # Sort events by timestamp descending (newest first)
    events.sort(key=lambda x: x.timestamp, reverse=True)
    
    return UserBalanceHistoryResponse(
        user_address=user_address,
        agreement_id=agreement_id,
        events=events
    )

