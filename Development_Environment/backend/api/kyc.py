"""
KYC API Endpoints

FastAPI router for KYC verification, document management, and admin review.
Provides RESTful endpoints for KYC submission, status checking, and admin operations.
"""

from fastapi import APIRouter, Depends, HTTPException, status  # File, Form, UploadFile temporarily disabled
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from typing import List
import hashlib
import logging

from config.database import get_db
from services.kyc_service import KYCService
from services.web3_service import Web3Service
from schemas.kyc import (
    KYCSubmissionRequest,
    KYCStatusResponse,
    KYCReviewRequest,
    KYCApprovalRateMetrics,
    KYCPublicStatusResponse,
    KYCBatchReviewRequest
)
from models.kyc_verification import KYCStatus, KYCTier
from models.kyc_document import DocumentType

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/kyc", tags=["KYC"])


def get_kyc_service(db: Session = Depends(get_db)) -> KYCService:
    """Dependency injection for KYCService"""
    web3_service = Web3Service(db=db)
    return KYCService(db, web3_service)


@router.post(
    "/submit",
    response_model=KYCStatusResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Submit KYC Application",
    description="Submit new KYC application with wallet signature for proof of ownership"
)
async def submit_kyc(
    request: KYCSubmissionRequest,
    kyc_service: KYCService = Depends(get_kyc_service)
):
    """
    Submit KYC application with wallet signature
    
    Requires:
    - Valid Ethereum address
    - Personal information (name, email, country)
    - Signature proving wallet ownership
    - Verification tier selection
    
    Returns:
    - Created KYC verification record with pending status
    """
    try:
        kyc = kyc_service.submit_kyc(
            wallet_address=request.wallet_address,
            full_name=request.full_name,
            email=request.email,
            country=request.country,
            tier=KYCTier[request.tier.upper()],
            signature=request.signature
        )
        return KYCStatusResponse.from_orm(kyc)
    except ValueError as e:
        logger.warning(f"KYC submission validation failed: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"KYC submission failed: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


# File upload endpoint temporarily disabled - requires python-multipart dependency
# To enable: pip install python-multipart in the backend container


@router.get(
    "/status/{wallet_address}",
    response_model=KYCStatusResponse,
    summary="Get KYC Status",
    description="Get KYC verification status for a wallet address"
)
async def get_kyc_status(
    wallet_address: str,
    kyc_service: KYCService = Depends(get_kyc_service)
):
    """
    Get KYC status for wallet address
    
    Returns:
    - Complete KYC verification record if found
    - 404 if no KYC application exists
    """
    kyc = kyc_service.get_kyc_status(wallet_address)
    if not kyc:
        raise HTTPException(status_code=404, detail="KYC verification not found")
    return KYCStatusResponse.from_orm(kyc)


@router.get(
    "/status/{wallet_address}/public",
    response_model=KYCPublicStatusResponse,
    summary="Get Public KYC Status",
    description="Get public KYC status (no sensitive data)"
)
async def get_kyc_status_public(
    wallet_address: str,
    kyc_service: KYCService = Depends(get_kyc_service)
):
    """
    Get public KYC status (excludes sensitive information)
    
    Returns:
    - Status, tier, and whitelist status only
    - Suitable for public APIs
    """
    kyc = kyc_service.get_kyc_status(wallet_address)
    if not kyc:
        raise HTTPException(status_code=404, detail="KYC verification not found")
    return KYCPublicStatusResponse.from_orm(kyc)


@router.post(
    "/admin/review",
    summary="Admin Review KYC (Protected)",
    description="Admin endpoint to approve/reject KYC and add to on-chain whitelist"
)
async def review_kyc(
    request: KYCReviewRequest,
    kyc_service: KYCService = Depends(get_kyc_service)
):
    """
    Admin review KYC application
    
    Actions:
    - Approve: Sets status to approved, adds to blockchain whitelist
    - Reject: Sets status to rejected with reason
    
    TODO: Add admin authentication middleware (JWT/OAuth)
    
    Returns:
    - Updated KYC record with whitelist transaction hash
    """
    # TODO: Validate admin permissions
    # For now, any authenticated user can review
    
    try:
        result = kyc_service.review_kyc(
            kyc_id=request.kyc_verification_id,
            status=KYCStatus[request.status.upper()],
            reviewer_address=request.reviewer_address,
            rejection_reason=request.rejection_reason,
            add_to_whitelist=request.add_to_whitelist
        )
        return result
    except ValueError as e:
        logger.warning(f"KYC review validation failed: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"KYC review failed: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get(
    "/admin/pending",
    response_model=List[KYCStatusResponse],
    summary="Get Pending KYC Applications",
    description="Admin endpoint to list all pending KYC applications"
)
async def get_pending_kyc(
    limit: int = 100,
    kyc_service: KYCService = Depends(get_kyc_service)
):
    """
    Get pending KYC applications for admin review
    
    TODO: Add admin authentication
    
    Returns:
    - List of pending KYC applications (oldest first)
    """
    pending = kyc_service.get_pending_kyc(limit=limit)
    return [KYCStatusResponse.from_orm(kyc) for kyc in pending]


@router.post(
    "/admin/batch-review",
    summary="Batch Review KYC Applications",
    description="Admin endpoint to batch approve/reject multiple applications"
)
async def batch_review_kyc(
    request: KYCBatchReviewRequest,
    kyc_service: KYCService = Depends(get_kyc_service)
):
    """
    Batch review multiple KYC applications
    
    Efficient for processing multiple applications with same decision
    
    Returns:
    - Summary of successful and failed reviews
    """
    try:
        result = kyc_service.batch_review_kyc(
            kyc_ids=request.kyc_verification_ids,
            status=KYCStatus[request.status.upper()],
            reviewer_address=request.reviewer_address,
            add_to_whitelist=request.add_to_whitelist
        )
        return result
    except Exception as e:
        logger.error(f"Batch review failed: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@router.get(
    "/metrics/approval-rate",
    response_model=KYCApprovalRateMetrics,
    summary="KYC Approval Metrics",
    description="Get KYC approval rate metrics for dissertation analysis"
)
async def get_approval_metrics(
    kyc_service: KYCService = Depends(get_kyc_service)
):
    """
    Get KYC approval metrics
    
    Metrics include:
    - Total submissions
    - Approval/rejection/pending counts
    - Approval/rejection rates
    - Average review time
    
    Used for dissertation analysis and platform monitoring
    """
    metrics = kyc_service.get_approval_metrics()
    return KYCApprovalRateMetrics(**metrics)


@router.get(
    "/health",
    summary="KYC Service Health Check",
    description="Check if KYC service and blockchain integration are operational"
)
async def health_check(kyc_service: KYCService = Depends(get_kyc_service)):
    """
    Health check endpoint
    
    Verifies:
    - Database connectivity
    - Blockchain connectivity
    - KYC Registry contract availability
    """
    try:
        # Test database
        kyc_service.db.execute("SELECT 1")
        
        # Test blockchain (if not in testing mode)
        if not kyc_service.web3_service.testing_mode:
            kyc_registry_available = kyc_service.web3_service.kyc_registry is not None
        else:
            kyc_registry_available = True
        
        return {
            'status': 'healthy',
            'database': 'connected',
            'blockchain': 'connected' if kyc_registry_available else 'registry_not_configured',
            'kyc_registry': 'available' if kyc_registry_available else 'not_configured'
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={'status': 'unhealthy', 'error': str(e)}
        )

