"""
Governance API Schemas for On-Chain Governance

Pydantic schemas for governance proposal creation, voting, and execution.
Includes validation for ROI bounds, reserve limits, and governance parameter constraints.
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional
from enum import Enum
from datetime import datetime


class ProposalType(str, Enum):
    """Governance proposal types"""
    ROI_ADJUSTMENT = "ROI_ADJUSTMENT"
    RESERVE_ALLOCATION = "RESERVE_ALLOCATION"
    RESERVE_WITHDRAWAL = "RESERVE_WITHDRAWAL"
    GOVERNANCE_PARAMETER_UPDATE = "GOVERNANCE_PARAMETER_UPDATE"
    AGREEMENT_PARAMETER_UPDATE = "AGREEMENT_PARAMETER_UPDATE"


class ParameterType(str, Enum):
    """Parameter update types"""
    GOVERNANCE = "GOVERNANCE"  # Governance params: votingDelay, votingPeriod, quorum, threshold
    AGREEMENT = "AGREEMENT"     # Agreement params: gracePeriod, penalty, defaultThreshold, etc.


class GovernanceProposalCreateRequest(BaseModel):
    """Request schema for creating a governance proposal"""
    agreement_id: int = Field(..., gt=0, description="Target yield agreement ID (or parameterId for governance params)")
    proposal_type: ProposalType = Field(..., description="Type of governance action")
    target_value: int = Field(..., gt=0, description="New ROI (basis points) or reserve amount (wei) or parameter value")
    target_value_usd: Optional[float] = Field(None, gt=0, description="Reserve amount in USD for display")
    description: str = Field(..., min_length=10, max_length=500, description="Rationale for proposal")
    token_standard: str = Field(default="ERC721", description="Token standard (ERC721 or ERC1155)")
    parameter_type: Optional[ParameterType] = Field(None, description="For parameter updates: GOVERNANCE or AGREEMENT")
    param_id: Optional[int] = Field(None, ge=0, le=4, description="Parameter ID (0-3 governance, 0-4 agreement)")

    @field_validator('target_value')
    @classmethod
    def validate_roi_bounds(cls, v, info):
        """Validate ROI is within acceptable range (1-50% = 100-5000 basis points)"""
        if info.data.get('proposal_type') == ProposalType.ROI_ADJUSTMENT:
            if v < 100 or v > 5000:
                raise ValueError("ROI must be between 1% and 50% (100-5000 basis points)")
        return v

    @field_validator('token_standard')
    @classmethod
    def validate_token_standard(cls, v):
        """Validate token standard is ERC721 or ERC1155"""
        if v not in ["ERC721", "ERC1155"]:
            raise ValueError("Token standard must be ERC721 or ERC1155")
        return v

    @field_validator('param_id')
    @classmethod
    def validate_param_id(cls, v, info):
        """Validate parameter ID based on parameter type"""
        if v is None:
            return v
        proposal_type = info.data.get('proposal_type')
        parameter_type = info.data.get('parameter_type')
        
        if proposal_type in [ProposalType.GOVERNANCE_PARAMETER_UPDATE, ProposalType.AGREEMENT_PARAMETER_UPDATE]:
            if parameter_type == ParameterType.GOVERNANCE:
                if v > 3:
                    raise ValueError("Governance parameter ID must be 0-3")
            elif parameter_type == ParameterType.AGREEMENT:
                if v > 4:
                    raise ValueError("Agreement parameter ID must be 0-4")
            else:
                raise ValueError("parameter_type required for parameter update proposals")
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "agreement_id": 1,
                "proposal_type": "ROI_ADJUSTMENT",
                "target_value": 1260,
                "description": "Increase ROI from 12% to 12.6% to account for market changes",
                "token_standard": "ERC721"
            }
        }


class GovernanceProposalCreateResponse(BaseModel):
    """Response schema for governance proposal creation"""
    proposal_id: int = Field(..., description="Database proposal ID")
    blockchain_proposal_id: int = Field(..., description="On-chain proposal ID")
    tx_hash: str = Field(..., description="Transaction hash of proposal creation")
    voting_start: datetime = Field(..., description="Timestamp when voting begins")
    voting_end: datetime = Field(..., description="Timestamp when voting ends")
    quorum_required: int = Field(..., description="Minimum votes required for quorum")
    proposal_threshold: int = Field(..., description="Minimum tokens to create proposal")
    status: str = Field(..., description="Current proposal status")
    message: str = Field(..., description="Success message")

    class Config:
        orm_mode = True
        json_encoders = {
            # Ensure datetime is serialized as UTC with Z suffix
            datetime: lambda v: v.isoformat() + 'Z' if v.tzinfo is None else v.isoformat()
        }


class VoteCastRequest(BaseModel):
    """Request schema for casting a vote"""
    proposal_id: int = Field(..., gt=0, description="Proposal ID to vote on")
    support: int = Field(..., ge=0, le=2, description="Vote direction (0=Against, 1=For, 2=Abstain)")
    token_standard: str = Field(default="ERC721", description="Token standard")

    @field_validator('token_standard')
    @classmethod
    def validate_token_standard(cls, v):
        """Validate token standard"""
        if v not in ["ERC721", "ERC1155"]:
            raise ValueError("Token standard must be ERC721 or ERC1155")
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "proposal_id": 1,
                "support": 1,
                "token_standard": "ERC721"
            }
        }


class VoteCastResponse(BaseModel):
    """Response schema for vote casting"""
    proposal_id: int = Field(..., description="Proposal ID voted on")
    voter_address: str = Field(..., description="Voter wallet address")
    support: str = Field(..., description="Vote direction (For/Against/Abstain)")
    voting_power: int = Field(..., description="Number of votes cast (token balance)")
    tx_hash: str = Field(..., description="Transaction hash of vote casting")
    status: str = Field(..., description="Vote status")

    class Config:
        orm_mode = True


class ProposalDetailResponse(BaseModel):
    """Response schema for proposal details"""
    proposal_id: int
    blockchain_proposal_id: Optional[int] = Field(None, description="On-chain proposal ID")
    proposer: str = Field(..., description="Address that created proposal")
    agreement_id: int
    proposal_type: str
    target_value: int
    description: str
    voting_start: datetime
    voting_end: datetime
    for_votes: int
    against_votes: int
    abstain_votes: int
    executed: bool
    defeated: bool
    quorum_reached: bool
    status: Optional[str] = Field(None, description="Current proposal status (PENDING/ACTIVE/EXECUTED/DEFEATED)")
    quorum_required: Optional[int] = Field(None, description="Minimum votes required for quorum")

    class Config:
        orm_mode = True
        json_encoders = {
            # Ensure datetime is serialized as UTC with Z suffix
            datetime: lambda v: v.isoformat() + 'Z' if v.tzinfo is None else v.isoformat()
        }


class ProposalExecuteRequest(BaseModel):
    """Request schema for executing a proposal"""
    proposal_id: int = Field(..., gt=0, description="Proposal ID to execute")


class ProposalExecuteResponse(BaseModel):
    """Response schema for proposal execution"""
    proposal_id: int
    executed: bool
    tx_hash: Optional[str] = None
    message: str

    class Config:
        orm_mode = True


class VotingPowerResponse(BaseModel):
    """Response schema for voting power query"""
    voter_address: str
    agreement_id: int
    voting_power: int = Field(..., description="Number of votes (token balance)")
    token_standard: str

    class Config:
        json_schema_extra = {
            "example": {
                "voter_address": "0x1234...",
                "agreement_id": 1,
                "voting_power": 100000,
                "token_standard": "ERC721"
            }
        }


class VoteCheckResponse(BaseModel):
    """Response schema for checking if user has voted"""
    has_voted: bool = Field(..., description="Whether the user has voted on this proposal")
    support: Optional[int] = Field(None, description="Vote choice if voted: 0=Against, 1=For, 2=Abstain")
    voting_power: Optional[int] = Field(None, description="Voting power used if voted")
    voted_at: Optional[datetime] = Field(None, description="Timestamp when vote was cast")
    
    class Config:
        json_schema_extra = {
            "example": {
                "has_voted": True,
                "support": 1,
                "voting_power": 50000,
                "voted_at": "2025-11-05T12:30:00Z"
            }
        }

