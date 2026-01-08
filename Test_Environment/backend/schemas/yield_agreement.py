"""
Pydantic schemas for yield agreement creation API requests and responses.

These schemas define the contract for yield agreement operations, ensuring
parameter validation matches smart contract requirements and provides clear
API documentation.
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime
from decimal import Decimal
from utils.validators import validate_ethereum_address


class YieldAgreementCreateRequest(BaseModel):
    """
    Request schema for yield agreement creation endpoint.

    Validates all agreement parameters against smart contract constraints
    and business rules before blockchain transaction execution.
    """

    property_token_id: int = Field(
        ...,
        gt=0,
        description="Token ID of the property to create agreement for"
    )
    upfront_capital: int = Field(
        ...,
        gt=0,
        description="Initial capital investment in wei (uint256)"
    )
    upfront_capital_usd: float = Field(
        ...,
        gt=0,
        description="Initial capital investment in USD"
    )
    term_months: int = Field(
        ...,
        ge=1,
        le=360,
        description="Agreement term in months (1-360)"
    )
    annual_roi_basis_points: int = Field(
        ...,
        ge=1,
        le=5000,
        description="Annual ROI in basis points (1-5000, i.e., 0.01%-50%)"
    )
    property_payer: Optional[str] = Field(
        default=None,
        description="Ethereum address of property payer (optional)"
    )
    grace_period_days: int = Field(
        default=30,
        ge=1,
        le=365,
        description="Grace period in days before penalties (1-365)"
    )
    default_penalty_rate: int = Field(
        default=200,
        ge=0,
        le=1000,
        description="Default penalty rate in basis points (0-1000, i.e., 0%-10%)"
    )
    default_threshold: int = Field(
        default=3,
        ge=1,
        le=12,
        description="Default threshold in months (1-12)"
    )
    allow_partial_repayments: bool = Field(
        default=True,
        description="Whether partial repayments are allowed"
    )
    allow_early_repayment: bool = Field(
        default=True,
        description="Whether early repayment is allowed"
    )
    token_standard: str = Field(
        default="ERC721",
        pattern="^(ERC721|ERC1155)$",
        description="Token standard to use: 'ERC721' or 'ERC1155'"
    )

    @field_validator("property_payer")
    @classmethod
    def validate_property_payer(cls, v):
        """Validate Ethereum address format if provided."""
        if v is not None:
            if not validate_ethereum_address(v):
                raise ValueError("Property payer must be valid Ethereum address")
        return v

    model_config = {
        "json_schema_extra": {
            "example": {
                "property_token_id": 1,
                "upfront_capital": 1000000000000000000,  # 1 ETH in wei
                "term_months": 24,
                "annual_roi_basis_points": 1200,  # 12%
                "property_payer": "0x742d35Cc6634C0532925a3b84cF055f8b6F5f2f8",
                "grace_period_days": 30,
                "default_penalty_rate": 200,  # 2%
                "default_threshold": 3,
                "allow_partial_repayments": True,
                "allow_early_repayment": True,
                "token_standard": "ERC721"
            }
        }
    }


class YieldAgreementCreateResponse(BaseModel):
    """
    Response schema for successful yield agreement creation.

    Returns agreement details and calculated financial projections.
    """

    agreement_id: int = Field(..., description="Internal database agreement ID")
    blockchain_agreement_id: int = Field(..., description="Agreement ID from blockchain")
    token_contract_address: str = Field(..., description="Yield token contract address")
    tx_hash: str = Field(..., description="Blockchain transaction hash")
    monthly_payment: int = Field(..., description="Calculated monthly payment in wei")
    total_expected_repayment: int = Field(..., description="Total expected repayment in wei")
    status: str = Field(..., description="Creation status")
    message: str = Field(..., description="Status message")

    model_config = {
        "json_schema_extra": {
            "example": {
                "agreement_id": 1,
                "blockchain_agreement_id": 1,
                "token_contract_address": "0x1234567890123456789012345678901234567890",
                "tx_hash": "0xabcdef1234567890...",
                "monthly_payment": 45833333333333333,  # ~0.0458 ETH
                "total_expected_repayment": 1100000000000000000,  # 1.1 ETH
                "status": "success",
                "message": "Yield agreement created successfully"
            }
        }
    }


class YieldAgreementDetailResponse(BaseModel):
    """
    Response schema for yield agreement detail queries.

    Returns complete agreement information including repayment progress.
    """

    id: int
    property_id: int
    upfront_capital: int
    upfront_capital_usd: float
    repayment_term_months: int
    annual_roi_basis_points: int
    total_repaid: int
    last_repayment_timestamp: Optional[datetime]
    is_active: bool
    blockchain_agreement_id: Optional[int]
    token_standard: str
    token_contract_address: Optional[str]
    total_token_supply: int
    grace_period_days: int
    default_penalty_rate: int
    allow_partial_repayments: bool
    allow_early_repayment: bool
    created_at: datetime
    updated_at: datetime
    
    # Computed fields (set by API endpoint, not from database)
    governance_enabled: bool = Field(
        default=True,
        description="Whether governance is enabled (always true - governance is available for all agreements)"
    )
    quorum_percentage: Optional[int] = Field(
        default=10,
        description="Quorum percentage required for governance votes (10%)"
    )
    voting_period_days: Optional[int] = Field(
        default=7,
        description="Voting period duration in days"
    )
    reserve_pool_balance: int = Field(
        default=0,
        description="Reserve pool balance in wei"
    )

    @field_validator("upfront_capital", "total_repaid", mode="before")
    @classmethod
    def coerce_decimal_to_int(cls, v):
        """Coerce Decimal fields from SQLAlchemy Numeric to int for JSON serialization."""
        if isinstance(v, Decimal):
            return int(v)
        return v

    model_config = {
        "from_attributes": True
    }
