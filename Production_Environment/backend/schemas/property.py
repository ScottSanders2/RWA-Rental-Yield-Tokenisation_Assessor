"""
Pydantic schemas for property registration API requests and responses.

These schemas define the contract between API endpoints and clients,
providing validation, serialization, and documentation for property-related operations.
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional, Dict, Any, List
from datetime import datetime


class PropertyRegistrationRequest(BaseModel):
    """
    Request schema for property registration endpoint.

    Validates property details, deed hash format, and rental agreement URI
    accessibility before processing registration.
    """

    property_address: str = Field(
        ...,
        min_length=1,
        description="Human-readable property address"
    )
    deed_hash: str = Field(
        ...,
        description="SHA-256 hash of property deed document (0x-prefixed hex)"
    )
    rental_agreement_uri: str = Field(
        ...,
        description="URI to rental agreement document (IPFS or HTTP URL)"
    )
    metadata: Optional[Dict[str, Any]] = Field(
        default_factory=dict,
        description="Additional property metadata (optional)"
    )
    token_standard: str = Field(
        default="ERC721",
        pattern="^(ERC721|ERC1155)$",
        description="Token standard to use: 'ERC721' or 'ERC1155'"
    )
    owner_address: Optional[str] = Field(
        None,
        description="Ethereum address of the property owner (0x-prefixed)"
    )

    @field_validator("deed_hash")
    @classmethod
    def validate_deed_hash(cls, v):
        """Validate deed hash format (0x-prefixed, 66-character hex)."""
        if not v.startswith("0x") or len(v) != 66:
            raise ValueError("Deed hash must be 0x-prefixed 66-character hex string")

        try:
            int(v, 16)  # Validate hex format
        except ValueError:
            raise ValueError("Deed hash must contain valid hexadecimal characters")

        return v

    @field_validator("rental_agreement_uri")
    @classmethod
    def validate_rental_agreement_uri(cls, v):
        """Validate rental agreement URI format (basic URL validation)."""
        if not (v.startswith("http://") or v.startswith("https://") or v.startswith("ipfs://")):
            raise ValueError("Rental agreement URI must be valid HTTP, HTTPS, or IPFS URL")

        # Basic length check
        if len(v) > 1000:
            raise ValueError("Rental agreement URI is too long (max 1000 characters)")

        return v

    model_config = {
        "json_schema_extra": {
            "example": {
                "property_address": "123 Main Street, London, UK",
                "deed_hash": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
                "rental_agreement_uri": "ipfs://QmXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxX",
                "metadata": {
                    "property_type": "residential",
                    "square_footage": 1200,
                    "year_built": 1995
                },
                "token_standard": "ERC721"
            }
        }
    }


class PropertyRegistrationResponse(BaseModel):
    """
    Response schema for successful property registration.

    Returns registration confirmation with blockchain transaction details.
    """

    property_id: int = Field(..., description="Internal database property ID")
    blockchain_token_id: int = Field(..., description="Token ID from blockchain contract")
    tx_hash: str = Field(..., description="Blockchain transaction hash")
    metadata_uri: Optional[str] = Field(None, description="IPFS metadata URI")
    status: str = Field(..., description="Registration status")
    message: str = Field(..., description="Status message")

    model_config = {
        "json_schema_extra": {
            "example": {
                "property_id": 1,
                "blockchain_token_id": 1,
                "tx_hash": "0x1234567890abcdef...",
                "metadata_uri": "ipfs://QmXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxX",
                "status": "success",
                "message": "Property registered successfully"
            }
        }
    }


class PropertyDetailResponse(BaseModel):
    """
    Response schema for property detail queries.

    Returns complete property information including verification status.
    """

    id: int
    property_address_hash: str  # Will be hex-encoded
    metadata_uri: Optional[str]
    metadata_json: Optional[str]
    rental_agreement_uri: Optional[str]
    token_standard: str
    verification_timestamp: Optional[datetime]
    is_verified: bool
    verifier_address: Optional[str]
    owner_address: Optional[str]
    blockchain_token_id: Optional[int]
    has_active_yield_agreement: bool
    created_at: datetime
    updated_at: datetime

    model_config = {
        "from_attributes": True
    }


