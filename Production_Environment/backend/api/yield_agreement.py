"""
FastAPI router for yield agreement endpoints.

This router provides REST API endpoints for yield agreement creation
and querying with financial calculations and time metric tracking.
"""

import time
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from config.database import get_db
from schemas.yield_agreement import (
    YieldAgreementCreateRequest,
    YieldAgreementCreateResponse,
    YieldAgreementDetailResponse
)
from typing import List
from services.yield_service import YieldService
from config.web3_config import get_web3_service
from utils.metrics import track_time, metrics_logger

# Configure logger for this module
logger = logging.getLogger(__name__)

# Create router with prefix and tags
router = APIRouter(
    prefix="/yield-agreements",
    tags=["yield-agreements"],
    responses={
        404: {"description": "Agreement not found"},
        400: {"description": "Validation error"},
        500: {"description": "Blockchain or database error"}
    }
)


@router.post(
    "/create",
    response_model=YieldAgreementCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a yield agreement",
    description="""
    Create a new yield agreement for tokenized rental income.

    **Prerequisites**:
    - Property MUST be registered first via POST /properties/register
    - Property MUST be verified via POST /properties/{id}/verify
    - No automatic property creation in Production environment

    This endpoint:
    - Validates property exists and is verified (returns 400 if not)
    - Creates yield agreement on blockchain (ERC-721+ERC-20 or ERC-1155)
    - Calculates monthly payments and total expected repayment
    - Returns agreement details and financial projections

    **Error Responses**:
    - 400: Property not found or not verified
    - 400: Property already has an active yield agreement
    - 500: Blockchain or database error

    **Time Metrics Tracked**: API response time, blockchain transaction time, database query time
    """
)
@track_time("api_yield_agreement_create", lambda req, db: {"term_months": req.term_months, "annual_roi": req.annual_roi_basis_points})
async def create_yield_agreement(
    request: YieldAgreementCreateRequest,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
) -> YieldAgreementCreateResponse:
    """
    Create a new yield agreement with financial calculations.

    Tracks comprehensive timing metrics for dissertation analysis.
    """
    start_time = time.time()

    try:
        # Initialize services
        yield_service = YieldService(db, web3_service)

        # Track blockchain start time
        blockchain_start = time.time()

        # Create yield agreement
        response = yield_service.create_yield_agreement(request)

        # Calculate timing metrics
        blockchain_time = time.time() - blockchain_start
        total_time = time.time() - start_time

        # Log metrics for dissertation analysis with actual gas usage
        gas_used_str = str(response.gas_used) if response.gas_used else "N/A"
        metrics_logger.info(f"Yield agreement creation - "
                           f"Total API time: {total_time:.3f}s, "
                           f"Blockchain time: {blockchain_time:.3f}s, "
                           f"TX hash: {response.tx_hash[:10]}..., "
                           f"Gas used: {gas_used_str}")
        
        # Log gas metric separately for dissertation_metrics.json aggregation
        # This ensures gas data is captured alongside timing metrics
        from utils.metrics import metrics_tracker
        metrics_tracker.log_metric(
            "api_yield_agreement_create_gas",
            blockchain_time,
            {
                "term_months": request.term_months,
                "annual_roi": request.annual_roi_basis_points,
                "token_standard": request.token_standard,
                "gas_used": response.gas_used,
                "tx_hash": response.tx_hash[:20] + "..." if response.tx_hash else None
            }
        )

        return response

    except ValueError as e:
        # Validation errors (property not found, not verified, invalid parameters)
        # Surface the specific error message to help clients understand what went wrong
        logger.warning(f"Yield agreement creation validation error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)  # Return specific validation error message to client
        )
    except Exception as e:
        # Blockchain or database errors
        logger.error(f"Yield agreement creation failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal error occurred during yield agreement creation"
        )


@router.get(
    "",
    response_model=List[YieldAgreementDetailResponse],
    summary="Get all yield agreements",
    description="""
    Retrieve a list of all yield agreements.

    Returns summary information for all agreements.
    """
)
async def get_yield_agreements(
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
) -> List[YieldAgreementDetailResponse]:
    """
    Get all yield agreements.
    """
    try:
        # Initialize services
        yield_service = YieldService(db, web3_service)

        # Get all agreements
        agreements = yield_service.get_yield_agreements()

        # Convert to response format
        return [
            YieldAgreementDetailResponse.model_validate(agreement)
            for agreement in agreements
        ]

    except Exception as e:
        logger.error(f"Error getting yield agreements: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal error occurred while retrieving yield agreements"
        )


@router.get(
    "/{agreement_id}",
    response_model=YieldAgreementDetailResponse,
    summary="Get yield agreement details",
    description="""
    Retrieve detailed information about a yield agreement.

    Returns agreement parameters, repayment progress, and blockchain information.
    """
)
async def get_yield_agreement(
    agreement_id: int,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
) -> YieldAgreementDetailResponse:
    """
    Get yield agreement details by ID.
    """
    try:
        # Initialize services
        yield_service = YieldService(db, web3_service)

        # Get agreement
        agreement = yield_service.get_yield_agreement(agreement_id)

        if not agreement:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Yield agreement not found: {agreement_id}"
            )

        return agreement

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to retrieve yield agreement: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal error occurred while retrieving yield agreement details"
        )
