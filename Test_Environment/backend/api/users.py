"""
User Management API endpoints for testing with multiple profiles.

This module provides endpoints to manage test user profiles and query
token balances for governance testing in Development/Test environments.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from config.database import get_db
from models.user_profile import UserProfile
from models.token_balance import TokenBalance
from models.yield_agreement import YieldAgreement
import logging

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/users",
    tags=["Users"],
    responses={404: {"description": "Not found"}}
)


@router.get(
    "/profiles",
    response_model=List[Dict[str, Any]],
    summary="Get All User Profiles",
    description="Retrieve all active user profiles for testing governance with multiple voters"
)
async def get_user_profiles(db: Session = Depends(get_db)):
    """
    Get all active user profiles for testing.
    
    Returns a list of user profiles with their wallet addresses, display names,
    and roles. Used by frontend to populate the user profile switcher.
    
    **Response:**
    - List of user profiles with wallet addresses and metadata
    
    **Use Case:**
    Frontend calls this on load to populate a dropdown/picker with available test users.
    """
    try:
        profiles = db.query(UserProfile).filter(
            UserProfile.is_active == True
        ).order_by(UserProfile.role, UserProfile.display_name).all()
        
        return [profile.to_dict() for profile in profiles]
        
    except Exception as e:
        logger.error(f"Error retrieving user profiles: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve user profiles: {str(e)}"
        )


@router.get(
    "/profiles/{wallet_address}",
    response_model=Dict[str, Any],
    summary="Get User Profile by Wallet",
    description="Retrieve a specific user profile by wallet address"
)
async def get_user_profile(
    wallet_address: str,
    db: Session = Depends(get_db)
):
    """
    Get a specific user profile by wallet address.
    
    **Parameters:**
    - `wallet_address`: Ethereum address (0x... format)
    
    **Returns:**
    - User profile with all details
    
    **Use Case:**
    Look up user details when switching profiles in the frontend.
    """
    try:
        profile = db.query(UserProfile).filter(
            UserProfile.wallet_address == wallet_address,
            UserProfile.is_active == True
        ).first()
        
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"User profile not found for wallet {wallet_address}"
            )
        
        return profile.to_dict()
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error retrieving profile for {wallet_address}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve user profile: {str(e)}"
        )


@router.get(
    "/profiles/{wallet_address}/voting-power/{agreement_id}",
    response_model=Dict[str, Any],
    summary="Get User Voting Power",
    description="Get voting power (token balance) for a specific user on an agreement"
)
async def get_user_voting_power(
    wallet_address: str,
    agreement_id: int,
    db: Session = Depends(get_db)
):
    """
    Get voting power for a specific user on an agreement.
    
    **Parameters:**
    - `wallet_address`: Ethereum address of the voter
    - `agreement_id`: ID of the yield agreement
    
    **Returns:**
    - `wallet_address`: User's wallet address
    - `agreement_id`: Agreement ID
    - `voting_power`: Number of tokens held (0 if user has no tokens)
    - `total_supply`: Total token supply for the agreement
    - `percentage`: User's ownership percentage
    - `can_reach_quorum`: Whether user can reach quorum alone
    
    **Use Case:**
    Frontend calls this when user switches profiles to show their voting power
    for the current proposal's agreement.
    """
    try:
        # Get token balance
        balance = db.query(TokenBalance).filter(
            TokenBalance.agreement_id == agreement_id,
            TokenBalance.wallet_address == wallet_address
        ).first()
        
        # Get agreement for total supply
        agreement = db.query(YieldAgreement).filter(
            YieldAgreement.id == agreement_id
        ).first()
        
        if not agreement:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Agreement {agreement_id} not found"
            )
        
        voting_power = balance.balance if balance else 0
        total_supply = agreement.total_token_supply
        percentage = (voting_power / total_supply * 100) if total_supply > 0 else 0
        
        # Calculate if user can reach quorum alone (10% of total supply)
        quorum_required = (total_supply * 1000) // 10000  # 10%
        can_reach_quorum = voting_power >= quorum_required
        
        return {
            "wallet_address": wallet_address,
            "agreement_id": agreement_id,
            "voting_power": voting_power,
            "total_supply": total_supply,
            "percentage": round(percentage, 2),
            "quorum_required": quorum_required,
            "can_reach_quorum": can_reach_quorum
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting voting power for {wallet_address} on agreement {agreement_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get voting power: {str(e)}"
        )


@router.get(
    "/profiles/{wallet_address}/balances",
    response_model=List[Dict[str, Any]],
    summary="Get All Token Balances for User",
    description="Get all token balances across all agreements for a user"
)
async def get_user_balances(
    wallet_address: str,
    db: Session = Depends(get_db)
):
    """
    Get all token balances for a user across all agreements.
    
    **Parameters:**
    - `wallet_address`: Ethereum address of the user
    
    **Returns:**
    - List of token balances with agreement details
    
    **Use Case:**
    Show user's portfolio of governance tokens across all agreements.
    """
    try:
        balances = db.query(TokenBalance).filter(
            TokenBalance.wallet_address == wallet_address
        ).all()
        
        result = []
        for balance in balances:
            agreement = db.query(YieldAgreement).filter(
                YieldAgreement.id == balance.agreement_id
            ).first()
            
            if agreement:
                result.append({
                    "agreement_id": balance.agreement_id,
                    "balance": balance.balance,
                    "token_standard": balance.token_standard,
                    "total_supply": agreement.total_token_supply,
                    "percentage": round(balance.balance / agreement.total_token_supply * 100, 2) if agreement.total_token_supply > 0 else 0
                })
        
        return result
        
    except Exception as e:
        logger.error(f"Error getting balances for {wallet_address}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get user balances: {str(e)}"
        )

