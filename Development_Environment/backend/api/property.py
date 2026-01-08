"""
FastAPI router for property-related endpoints.

This router provides REST API endpoints for property registration,
verification, and querying operations with comprehensive error handling
and time metric tracking for dissertation analysis.
"""

import time
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from config.database import get_db
from schemas.property import (
    PropertyRegistrationRequest,
    PropertyRegistrationResponse,
    PropertyDetailResponse
)
from typing import List, Optional
from services.property_service import PropertyService
from config.web3_config import get_web3_service
from utils.metrics import track_time, metrics_logger

# Configure logger for this module
logger = logging.getLogger(__name__)

# Create router with prefix and tags
router = APIRouter(
    prefix="/properties",
    tags=["properties"],
    responses={
        404: {"description": "Property not found"},
        400: {"description": "Validation error"},
        500: {"description": "Blockchain or database error"}
    }
)

# Create alias router without prefix for root-level routes
alias_router = APIRouter(
    tags=["properties"],
    responses={
        404: {"description": "Property not found"},
        400: {"description": "Validation error"},
        500: {"description": "Blockchain or database error"}
    }
)


@router.post(
    "/register-property",
    response_model=PropertyRegistrationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new property (alias route)",
    description="""
    Register a new property in the RWA tokenization platform.

    This is an alias route for /properties/register to maintain API contract compatibility.
    """
)
@router.post(
    "/register",
    response_model=PropertyRegistrationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new property",
    description="""
    Register a new property in the RWA tokenization platform.

    This endpoint:
    - Validates property details and deed hash format
    - Creates property record in database
    - Mints NFT on blockchain (ERC-721 or ERC-1155)
    - Returns property ID and blockchain transaction details

    **Time Metrics Tracked**: API response time, blockchain transaction time
    """
)
@track_time("api_property_register", lambda req, db, web3_service: {"token_standard": req.token_standard})
async def register_property(
    request: PropertyRegistrationRequest,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
) -> PropertyRegistrationResponse:
    """
    Register a new property and mint associated NFT.

    Tracks API response time and blockchain transaction time for dissertation metrics.
    """
    start_time = time.time()

    try:
        # Initialize services
        property_service = PropertyService(db, web3_service)

        # Register property
        response = property_service.register_property(request)

        # Calculate elapsed time
        elapsed_time = time.time() - start_time

        # Log metrics for dissertation analysis
        metrics_logger.info(f"Property registration - API time: {elapsed_time:.3f}s, "
                           f"TX hash: {response.tx_hash[:10]}..., Gas used: N/A")

        return response

    except ValueError as e:
        # Validation errors - log details but return generic message
        logger.warning(f"Property registration validation error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid request data provided"
        )
    except Exception as e:
        # Blockchain or database errors - log details but return generic message
        logger.error(f"Property registration failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal error occurred during property registration"
        )


@router.post(
    "/{property_id}/verify",
    summary="Verify a property",
    description="""
    Verify a registered property by calling blockchain verification.

    This endpoint:
    - Retrieves property by ID
    - Calls PropertyNFT.verifyProperty() on blockchain
    - Updates verification status in database
    - Returns verification confirmation

    Property must exist and not already be verified.
    """
)
@track_time("api_property_verify")
async def verify_property(
    property_id: int,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
):
    """
    Verify a property by calling blockchain verification function.
    """
    try:
        # Initialize services
        property_service = PropertyService(db, web3_service)

        # Verify property
        result = property_service.verify_property(property_id)

        return {
            "message": "Property verified successfully",
            "property_id": property_id,
            "verified": True,
            "transaction_hash": result["tx_hash"],
            "verification_timestamp": result["timestamp"]
        }

    except ValueError as e:
        logger.warning(f"Property verification validation error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid request or property state for verification"
        )
    except Exception as e:
        logger.error(f"Property verification failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal error occurred during property verification"
        )


@router.get(
    "",
    response_model=List[PropertyDetailResponse],
    summary="Get all properties",
    description="""
    Retrieve a list of all registered properties.

    Returns summary information for all properties.
    Optionally filter by owner_address.
    """
)
async def get_properties(
    owner_address: Optional[str] = None,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
) -> List[PropertyDetailResponse]:
    """
    Get all properties.
    """
    try:
        # Initialize services
        property_service = PropertyService(db, web3_service)

        # Get all properties (optionally filtered by owner)
        properties = property_service.get_properties(owner_address=owner_address.lower() if owner_address else None)

        # Convert to response format
        response_data = []
        for prop in properties:
            # Check if property has an active yield agreement
            from models.yield_agreement import YieldAgreement
            has_active_agreement = db.query(YieldAgreement).filter(
                YieldAgreement.property_id == prop.id,
                YieldAgreement.is_active == True
            ).first() is not None

            prop_dict = {
                "id": prop.id,
                "property_address_hash": prop.property_address_hash.hex() if prop.property_address_hash else None,
                "metadata_uri": prop.metadata_uri,
                "metadata_json": getattr(prop, 'metadata_json', None),  # Handle missing column
                "rental_agreement_uri": getattr(prop, 'rental_agreement_uri', None),  # Handle missing column
                "token_standard": getattr(prop, 'token_standard', 'ERC721'),  # Handle missing column
                "verification_timestamp": prop.verification_timestamp,
                "is_verified": prop.is_verified,
                "verifier_address": prop.verifier_address,
                "owner_address": getattr(prop, 'owner_address', None),  # Handle missing column
                "blockchain_token_id": prop.blockchain_token_id,
                "has_active_yield_agreement": has_active_agreement,
                "created_at": prop.created_at,
                "updated_at": prop.updated_at,
            }
            response_data.append(PropertyDetailResponse(**prop_dict))

        return response_data

    except Exception as e:
        logger.error(f"Error getting properties: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal error occurred while retrieving properties"
        )


@router.get(
    "/{property_id}",
    response_model=PropertyDetailResponse,
    summary="Get property details",
    description="""
    Retrieve detailed information about a registered property.

    Returns property metadata, verification status, and blockchain information.
    """
)
async def get_property(
    property_id: int,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
) -> PropertyDetailResponse:
    """
    Get property details by ID.
    """
    try:
        # Initialize services
        property_service = PropertyService(db, web3_service)

        # Get property
        property_obj = property_service.get_property(property_id)

        if not property_obj:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Property not found: {property_id}"
            )

        # Construct response data without modifying the model object
        # Check if property has any active yield agreements
        from models.yield_agreement import YieldAgreement
        has_active_agreement = db.query(YieldAgreement).filter(
            YieldAgreement.property_id == property_obj.id,
            YieldAgreement.is_active == True
        ).first() is not None
        
        data = {
            "id": property_obj.id,
            "property_address_hash": property_obj.property_address_hash.hex() if property_obj.property_address_hash else None,
            "metadata_uri": property_obj.metadata_uri,
            "metadata_json": getattr(property_obj, 'metadata_json', None),  # Handle missing column
            "rental_agreement_uri": getattr(property_obj, 'rental_agreement_uri', None),  # Handle missing column
            "token_standard": getattr(property_obj, 'token_standard', 'ERC721'),  # Handle missing column
            "verification_timestamp": property_obj.verification_timestamp,
            "is_verified": property_obj.is_verified,
            "verifier_address": property_obj.verifier_address,
            "owner_address": getattr(property_obj, 'owner_address', None),  # Added missing field
            "blockchain_token_id": property_obj.blockchain_token_id,
            "has_active_yield_agreement": has_active_agreement,  # Added missing field
            "created_at": property_obj.created_at,
            "updated_at": property_obj.updated_at
        }

        return PropertyDetailResponse(**data)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to retrieve property: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal error occurred while retrieving property details"
        )


# Alias routes for backward compatibility
@alias_router.post(
    "/register-property",
    response_model=PropertyRegistrationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new property (root-level alias)",
    description="""
    Register a new property in the RWA tokenization platform.

    This is a root-level alias route for /properties/register to maintain API contract compatibility.
    """
)
@track_time("api_property_register_alias", lambda req, db, web3_service: {"token_standard": req.token_standard})
async def register_property_alias(
    request: PropertyRegistrationRequest,
    db: Session = Depends(get_db),
    web3_service = Depends(get_web3_service)
) -> PropertyRegistrationResponse:
    """
    Register a new property and mint associated NFT (alias route).

    Delegates to the same logic as /properties/register.
    Tracks API response time and blockchain transaction time for dissertation metrics.
    """
    start_time = time.time()

    try:
        # Initialize services
        property_service = PropertyService(db, web3_service)

        # Register property
        response = property_service.register_property(request)

        # Calculate elapsed time
        elapsed_time = time.time() - start_time

        # Log metrics for dissertation analysis
        metrics_logger.info(f"Property registration (alias) - API time: {elapsed_time:.3f}s, "
                           f"TX hash: {response.tx_hash[:10]}..., Gas used: N/A")

        return response

    except ValueError as e:
        # Validation errors - log details but return generic message
        logger.warning(f"Property registration (alias) validation error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid request data provided"
        )
    except Exception as e:
        # Blockchain or database errors - log details but return generic message
        logger.error(f"Property registration (alias) failed: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An internal error occurred during property registration"
        )
