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
- Tracks time metrics for dissertation performance analysis
- Validates requests with Pydantic schemas
- Returns detailed error messages for debugging

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

from config.database import get_db
from schemas.marketplace import (
    CreateListingRequest,
    BuySharesRequest,
    CreateListingResponse,
    BuySharesResponse,
    ListingDetailResponse
)
from services.marketplace_service import MarketplaceService

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/marketplace",
    tags=["marketplace"],
    responses={404: {"description": "Not found"}}
)


@router.post("/listings", response_model=CreateListingResponse, status_code=status.HTTP_201_CREATED)
async def create_listing(
    request: CreateListingRequest,
    db: Session = Depends(get_db)
):
    """
    Create new marketplace listing.
    
    Args:
        request: CreateListingRequest with listing details
        db: Database session
    
    Returns:
        CreateListingResponse with listing details
    
    Raises:
        HTTPException 400: Validation errors (insufficient shares, transfer restrictions violated)
        HTTPException 500: Database or blockchain errors
    
    Metrics:
        - API response time (total)
        - Validation time
        - Database insert time
    """
    start_time = time.time()
    
    try:
        logger.info(f"Creating listing for agreement {request.agreement_id} by {request.seller_address}")
        
        # Create MarketplaceService instance
        marketplace_service = MarketplaceService(db)
        
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
    db: Session = Depends(get_db)
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
        
        # Create MarketplaceService instance
        marketplace_service = MarketplaceService(db)
        
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
    db: Session = Depends(get_db)
):
    """
    Get single listing details by ID.
    
    Args:
        listing_id: Listing ID to fetch
        db: Database session
    
    Returns:
        ListingDetailResponse with listing details
    
    Raises:
        HTTPException 404: Listing not found
        HTTPException 500: Database errors
    """
    start_time = time.time()
    
    try:
        logger.info(f"Fetching listing {listing_id}")
        
        # Create MarketplaceService instance
        marketplace_service = MarketplaceService(db)
        
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
    db: Session = Depends(get_db)
):
    """
    Purchase shares from marketplace listing.
    
    Args:
        listing_id: Listing ID to purchase from
        request: BuySharesRequest with purchase details
        db: Database session
    
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
        
        # Create MarketplaceService instance
        marketplace_service = MarketplaceService(db)
        
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
    db: Session = Depends(get_db)
):
    """
    Cancel active marketplace listing.
    
    Args:
        listing_id: Listing ID to cancel
        seller_address: Seller Ethereum address (must match listing seller)
        db: Database session
    
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
        
        # Create MarketplaceService instance
        marketplace_service = MarketplaceService(db)
        
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

