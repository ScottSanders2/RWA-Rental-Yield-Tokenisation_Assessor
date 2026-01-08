"""
KYC Pydantic Schemas

Request/response validation schemas for KYC API endpoints.
Ensures data integrity and provides automatic API documentation.
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum


class KYCStatusEnum(str, Enum):
    """KYC verification status"""
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    EXPIRED = "expired"


class KYCTierEnum(str, Enum):
    """KYC verification tiers"""
    BASIC = "basic"
    ACCREDITED = "accredited"
    INSTITUTIONAL = "institutional"


class DocumentTypeEnum(str, Enum):
    """Supported document types"""
    PASSPORT = "passport"
    DRIVERS_LICENSE = "drivers_license"
    NATIONAL_ID = "national_id"
    PROOF_OF_ADDRESS = "proof_of_address"
    ACCREDITATION_LETTER = "accreditation_letter"
    BANK_STATEMENT = "bank_statement"
    UTILITY_BILL = "utility_bill"


class KYCSubmissionRequest(BaseModel):
    """Request schema for KYC submission"""
    wallet_address: str = Field(
        ...,
        pattern=r'^0x[a-fA-F0-9]{40}$',
        description="Ethereum wallet address (checksummed)"
    )
    full_name: str = Field(..., min_length=2, max_length=255)
    email: str = Field(..., pattern=r'^[\w\.-]+@[\w\.-]+\.\w+$', description="Email for notifications")
    country: str = Field(..., min_length=2, max_length=100, description="Country code or name")
    tier: KYCTierEnum = Field(default=KYCTierEnum.BASIC)
    signature: str = Field(
        ...,
        description="Signed message proving wallet ownership (0x-prefixed hex)"
    )
    
    @validator('wallet_address')
    def validate_address(cls, v):
        """Convert address to lowercase for consistent storage"""
        return v.lower()
    
    class Config:
        schema_extra = {
            "example": {
                "wallet_address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1",
                "full_name": "John Doe",
                "email": "john.doe@example.com",
                "country": "United States",
                "tier": "basic",
                "signature": "0x..."
            }
        }


class DocumentUploadRequest(BaseModel):
    """Request schema for document upload"""
    kyc_verification_id: int = Field(..., description="KYC verification ID")
    document_type: DocumentTypeEnum
    file_name: str = Field(..., max_length=255)
    file_hash: str = Field(
        ...,
        pattern=r'^[a-fA-F0-9]{64}$',
        description="SHA-256 hash of file contents"
    )
    file_size: int = Field(..., gt=0, lt=10485760, description="File size in bytes (max 10MB)")
    mime_type: str = Field(..., max_length=100, description="MIME type (e.g., image/jpeg)")
    ipfs_uri: Optional[str] = Field(None, description="IPFS URI if uploaded to IPFS")
    
    class Config:
        schema_extra = {
            "example": {
                "kyc_verification_id": 1,
                "document_type": "passport",
                "file_name": "passport.pdf",
                "file_hash": "a3b2c1...",
                "file_size": 1024000,
                "mime_type": "application/pdf",
                "ipfs_uri": "ipfs://QmXyz..."
            }
        }


class KYCReviewRequest(BaseModel):
    """Request schema for admin KYC review"""
    kyc_verification_id: int
    status: KYCStatusEnum = Field(..., description="New status (approved/rejected)")
    rejection_reason: Optional[str] = Field(None, max_length=1000)
    reviewer_address: str = Field(
        ...,
        pattern=r'^0x[a-fA-F0-9]{40}$',
        description="Admin wallet address"
    )
    add_to_whitelist: bool = Field(default=True, description="Add to blockchain whitelist if approved")
    
    @validator('rejection_reason')
    def validate_rejection_reason(cls, v, values):
        """Require rejection reason if status is REJECTED"""
        if values.get('status') == KYCStatusEnum.REJECTED and not v:
            raise ValueError('rejection_reason required when status is REJECTED')
        return v
    
    class Config:
        schema_extra = {
            "example": {
                "kyc_verification_id": 1,
                "status": "approved",
                "reviewer_address": "0x...",
                "add_to_whitelist": True
            }
        }


class KYCDocumentResponse(BaseModel):
    """Response schema for document info"""
    id: int
    document_type: str
    file_name: str
    file_size: int
    uploaded_at: datetime
    verified_at: Optional[datetime]
    
    class Config:
        orm_mode = True


class KYCStatusResponse(BaseModel):
    """Response schema for KYC status"""
    id: int
    wallet_address: str
    status: KYCStatusEnum
    tier: KYCTierEnum
    full_name: str
    email: str
    country: str
    submission_date: datetime
    review_date: Optional[datetime]
    expiry_date: Optional[datetime]
    reviewer_address: Optional[str]
    whitelisted_on_chain: bool
    whitelist_tx_hash: Optional[str]
    documents: List[KYCDocumentResponse] = []
    
    class Config:
        from_attributes = True  # Pydantic v2 (was orm_mode in v1)
        schema_extra = {
            "example": {
                "id": 1,
                "wallet_address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1",
                "status": "approved",
                "tier": "basic",
                "full_name": "John Doe",
                "email": "john.doe@example.com",
                "country": "United States",
                "submission_date": "2025-01-01T00:00:00Z",
                "review_date": "2025-01-02T00:00:00Z",
                "expiry_date": "2026-01-02T00:00:00Z",
                "whitelisted_on_chain": True,
                "whitelist_tx_hash": "0x...",
                "documents": []
            }
        }


class KYCPublicStatusResponse(BaseModel):
    """Public response schema (no sensitive data)"""
    wallet_address: str
    status: KYCStatusEnum
    tier: KYCTierEnum
    submission_date: datetime
    whitelisted_on_chain: bool
    
    class Config:
        orm_mode = True


class KYCApprovalRateMetrics(BaseModel):
    """Metrics schema for dissertation analysis"""
    total_submissions: int
    approved: int
    rejected: int
    pending: int
    approval_rate: float = Field(..., description="Percentage of approved submissions")
    rejection_rate: float = Field(..., description="Percentage of rejected submissions")
    avg_review_time_hours: float = Field(..., description="Average review time in hours")
    
    class Config:
        schema_extra = {
            "example": {
                "total_submissions": 100,
                "approved": 60,
                "rejected": 30,
                "pending": 10,
                "approval_rate": 60.0,
                "rejection_rate": 30.0,
                "avg_review_time_hours": 24.5
            }
        }


class KYCBatchReviewRequest(BaseModel):
    """Request schema for batch review"""
    kyc_verification_ids: List[int] = Field(..., min_items=1, max_items=100)
    status: KYCStatusEnum
    reviewer_address: str = Field(..., pattern=r'^0x[a-fA-F0-9]{40}$')
    add_to_whitelist: bool = Field(default=True)
    
    class Config:
        schema_extra = {
            "example": {
                "kyc_verification_ids": [1, 2, 3],
                "status": "approved",
                "reviewer_address": "0x...",
                "add_to_whitelist": True
            }
        }

