"""
Marketplace API Router

FastAPI router for secondary market marketplace endpoints.

Endpoints:
- POST /marketplace/listings: Create new marketplace listing
- GET /marketplace/listings: Get all active listings with filters
- GET /marketplace/listings/{listing_id}: Get single listing details
- POST /marketplace/listings/{listing_id}/buy: Purchase shares from listing
- DELETE /marketplace/listings/{listing_id}: Cancel listing

Architecture:
- Uses MarketplaceService for business logic
- Injects Web3Service for transfer restriction checks and on-chain settlement
- Tracks time metrics for dissertation performance analysis
- Validates requests with Pydantic schemas
- Returns detailed error messages for debugging

Web3 Integration:
- All handlers inject Web3Service via get_web3_service dependency
- Transfer restrictions checked via web3_service.is_transfer_allowed()
- On-chain settlement via web3_service.execute_transfer()
- Controlled via USE_WEB3_FOR_MARKETPLACE environment variable (default: true)
- When USE_WEB3_FOR_MARKETPLACE=false, marketplace operates in simulation mode

Research Contribution:
- Enables secondary market liquidity (Research Question 7)
- Tracks API response times for performance analysis (Research Question 3)
- Supports fractional pooling with USD-first pricing
- Validates transfer restrictions before trades
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
import logging
import time
import os

from config.database import get_db
from config.web3_config import get_web3_service
from schemas.marketplace import (
    CreateListingRequest,
    BuySharesRequest,
    CreateListingResponse,
    BuySharesResponse,
    ListingDetailResponse
)
from services.marketplace_service import MarketplaceService

logger = logging.getLogger(__name__)

# Environment flag to enable Web3 integration for marketplace (default: true in Production)
USE_WEB3_FOR_MARKETPLACE = os.getenv('USE_WEB3_FOR_MARKETPLACE', 'true').lower() == 'true'

router = APIRouter(
    prefix="/marketplace",
    tags=["marketplace"],
    responses={404: {"description": "Not found"}}
)


@router.post("/listings", response_model=CreateListingResponse, status_code=status.HTTP_201_CREATED)
async def create_listing(
    request: CreateListingRequest,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Create new marketplace listing.
    
    Args:
        request: CreateListingRequest with listing details
        db: Database session
        web3_service: Web3 service for transfer restriction checks
    
    Returns:
        CreateListingResponse with listing details
    
    Raises:
        HTTPException 400: Validation errors (insufficient shares, transfer restrictions violated)
        HTTPException 500: Database or blockchain errors
    
    Metrics:
        - API response time (total)
        - Validation time
        - Database insert time
    
    Web3 Integration:
        - Checks isTransferAllowed before creating listing
        - Controlled via USE_WEB3_FOR_MARKETPLACE environment variable
    """
    start_time = time.time()
    
    try:
        logger.info(f"Creating listing for agreement {request.agreement_id} by {request.seller_address}")
        
        # Create MarketplaceService instance with Web3 service for transfer restriction checks
        # Pass web3_service only if USE_WEB3_FOR_MARKETPLACE is enabled
        effective_web3_service = web3_service if USE_WEB3_FOR_MARKETPLACE else None
        marketplace_service = MarketplaceService(db, web3_service=effective_web3_service)
        
        # Create listing
        validation_start = time.time()
        response = marketplace_service.create_listing(request)
        validation_time = time.time() - validation_start
        
        total_time = time.time() - start_time
        
        logger.info(
            f"Created listing {response.listing_id} in {total_time:.3f}s "
            f"(validation: {validation_time:.3f}s)"
        )
        
        return response
    
    except ValueError as e:
        logger.error(f"Validation error creating listing: {str(e)}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    
    except Exception as e:
        logger.error(f"Error creating listing: {str(e)}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("/listings", response_model=List[ListingDetailResponse])
async def get_listings(
    agreement_id: Optional[int] = Query(None, description="Filter by agreement ID"),
    token_standard: Optional[str] = Query(None, description="Filter by token standard (ERC721 or ERC1155)"),
    min_price_usd: Optional[float] = Query(None, description="Filter by minimum price per share (USD)"),
    max_price_usd: Optional[float] = Query(None, description="Filter by maximum price per share (USD)"),
    listing_status: Optional[str] = Query(None, description="Filter by status (active, sold, cancelled, expired)"),
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Get marketplace listings with optional filters.
    
    Args:
        agreement_id: Filter by agreement ID
        token_standard: Filter by token standard
        min_price_usd: Filter by minimum price
        max_price_usd: Filter by maximum price
        listing_status: Filter by listing status
        db: Database session
        web3_service: Web3 service for blockchain queries
    
    Returns:
        List of ListingDetailResponse objects
    
    Raises:
        HTTPException 500: Database errors
    
    Metrics:
        - API response time
        - Number of listings returned
    """
    start_time = time.time()
    
    try:
        logger.info(f"Fetching listings with filters: agreement_id={agreement_id}, token_standard={token_standard}, listing_status={listing_status}")
        
        # Create MarketplaceService instance with Web3 service
        effective_web3_service = web3_service if USE_WEB3_FOR_MARKETPLACE else None
        marketplace_service = MarketplaceService(db, web3_service=effective_web3_service)
        
        # Get listings
        listings = marketplace_service.get_listings(
            agreement_id=agreement_id,
            token_standard=token_standard,
            min_price_usd=min_price_usd,
            max_price_usd=max_price_usd,
            status=listing_status
        )
        
        total_time = time.time() - start_time
        
        logger.info(f"Fetched {len(listings)} listings in {total_time:.3f}s")
        
        return listings
    
    except Exception as e:
        logger.error(f"Error fetching listings: {str(e)}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("/listings/{listing_id}", response_model=ListingDetailResponse)
async def get_listing(
    listing_id: int,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Get single listing details by ID.
    
    Args:
        listing_id: Listing ID to fetch
        db: Database session
        web3_service: Web3 service for blockchain queries
    
    Returns:
        ListingDetailResponse with listing details
    
    Raises:
        HTTPException 404: Listing not found
        HTTPException 500: Database errors
    """
    start_time = time.time()
    
    try:
        logger.info(f"Fetching listing {listing_id}")
        
        # Create MarketplaceService instance with Web3 service
        effective_web3_service = web3_service if USE_WEB3_FOR_MARKETPLACE else None
        marketplace_service = MarketplaceService(db, web3_service=effective_web3_service)
        
        # Get listing
        listing = marketplace_service.get_listing_by_id(listing_id)
        
        if not listing:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Listing {listing_id} not found")
        
        total_time = time.time() - start_time
        
        logger.info(f"Fetched listing {listing_id} in {total_time:.3f}s")
        
        return listing
    
    except HTTPException:
        raise
    
    except Exception as e:
        logger.error(f"Error fetching listing {listing_id}: {str(e)}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/listings/{listing_id}/buy", response_model=BuySharesResponse)
async def buy_shares(
    listing_id: int,
    request: BuySharesRequest,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Purchase shares from marketplace listing.
    
    Args:
        listing_id: Listing ID to purchase from
        request: BuySharesRequest with purchase details
        db: Database session
        web3_service: Web3 service for on-chain settlement and transfer restrictions
    
    Returns:
        BuySharesResponse with trade details
    
    Raises:
        HTTPException 400: Validation errors (insufficient shares, restrictions violated, price slippage)
        HTTPException 404: Listing not found
        HTTPException 500: Database or blockchain errors
    
    Metrics:
        - API response time (total)
        - Validation time
        - Blockchain settlement time
        - Gas used
    
    Web3 Integration:
        - Checks isTransferAllowed before purchase
        - Executes on-chain transfer via execute_transfer
        - Controlled via USE_WEB3_FOR_MARKETPLACE environment variable
    """
    start_time = time.time()
    
    try:
        logger.info(f"Buying shares from listing {listing_id} by {request.buyer_address}")
        
        # Validate listing_id matches request
        if request.listing_id != listing_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Listing ID mismatch: URL has {listing_id}, request has {request.listing_id}"
            )
        
        # Create MarketplaceService instance with Web3 service for on-chain settlement
        effective_web3_service = web3_service if USE_WEB3_FOR_MARKETPLACE else None
        marketplace_service = MarketplaceService(db, web3_service=effective_web3_service)
        
        # Execute purchase
        validation_start = time.time()
        response = marketplace_service.buy_shares(request)
        validation_time = time.time() - validation_start
        
        total_time = time.time() - start_time
        
        logger.info(
            f"Created trade {response.trade_id} in {total_time:.3f}s "
            f"(validation: {validation_time:.3f}s, gas: {response.gas_used})"
        )
        
        return response
    
    except ValueError as e:
        logger.error(f"Validation error buying shares: {str(e)}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    
    except Exception as e:
        logger.error(f"Error buying shares: {str(e)}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.delete("/listings/{listing_id}")
async def cancel_listing(
    listing_id: int,
    seller_address: str = Query(..., description="Seller Ethereum address"),
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Cancel active marketplace listing.
    
    Args:
        listing_id: Listing ID to cancel
        seller_address: Seller Ethereum address (must match listing seller)
        db: Database session
        web3_service: Web3 service for blockchain queries
    
    Returns:
        Dict with cancellation confirmation
    
    Raises:
        HTTPException 400: Validation errors (seller mismatch, not active)
        HTTPException 404: Listing not found
        HTTPException 500: Database errors
    """
    start_time = time.time()
    
    try:
        logger.info(f"Cancelling listing {listing_id} by {seller_address}")
        
        # Create MarketplaceService instance with Web3 service
        effective_web3_service = web3_service if USE_WEB3_FOR_MARKETPLACE else None
        marketplace_service = MarketplaceService(db, web3_service=effective_web3_service)
        
        # Cancel listing
        result = marketplace_service.cancel_listing(listing_id, seller_address)
        
        total_time = time.time() - start_time
        
        logger.info(f"Cancelled listing {listing_id} in {total_time:.3f}s")
        
        return result
    
    except ValueError as e:
        logger.error(f"Validation error cancelling listing: {str(e)}")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    
    except Exception as e:
        logger.error(f"Error cancelling listing: {str(e)}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))

