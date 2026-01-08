"""
SQLAlchemy model for GovernanceProposal entity representing on-chain governance proposals.

This model captures governance proposal data, voting tracking, and execution status.
"""

from sqlalchemy import Column, Integer, String, DateTime, Numeric, Boolean, Text, Enum as SQLEnum
from sqlalchemy.sql import func
from config.database import Base
import enum


class ProposalType(str, enum.Enum):
    """Enum for governance proposal types"""
    ROI_ADJUSTMENT = "ROI_ADJUSTMENT"
    RESERVE_ALLOCATION = "RESERVE_ALLOCATION"
    RESERVE_WITHDRAWAL = "RESERVE_WITHDRAWAL"
    GOVERNANCE_PARAMETER_UPDATE = "GOVERNANCE_PARAMETER_UPDATE"
    AGREEMENT_PARAMETER_UPDATE = "AGREEMENT_PARAMETER_UPDATE"


class ProposalStatus(str, enum.Enum):
    """Enum for proposal status"""
    PENDING = "PENDING"  # Created, voting not started
    ACTIVE = "ACTIVE"    # Voting in progress
    SUCCEEDED = "SUCCEEDED"  # Passed (for > against, quorum met)
    DEFEATED = "DEFEATED"    # Failed (for <= against or quorum not met)
    EXECUTED = "EXECUTED"    # Successfully executed
    CANCELLED = "CANCELLED"  # Cancelled by creator or admin


class GovernanceProposal(Base):
    """
    GovernanceProposal model representing on-chain governance proposals.

    Tracks proposal parameters, voting progress, and execution status.
    """

    __tablename__ = "governance_proposals"

    # Primary key
    id = Column(Integer, primary_key=True)

    # Blockchain reference
    blockchain_proposal_id = Column(
        Integer,
        nullable=False,
        unique=True,
        comment="On-chain proposal ID from GovernanceController contract"
    )

    # Agreement reference
    agreement_id = Column(
        Integer,
        nullable=False,
        comment="Yield agreement being governed"
    )

    # Proposer
    proposer = Column(
        String(42),
        nullable=False,
        default="0x0000000000000000000000000000000000000000",
        comment="Address that created the proposal"
    )

    # Proposal details
    proposal_type = Column(
        SQLEnum(ProposalType),
        nullable=False,
        comment="Type of governance action"
    )

    target_value = Column(
        Numeric(precision=78, scale=0),
        nullable=False,
        comment="Target value for proposal (ROI bp, reserve wei, parameter value)"
    )

    parameter_name = Column(
        String(100),
        nullable=True,
        comment="Parameter name for PARAMETER_UPDATE proposals"
    )

    description = Column(
        Text,
        nullable=False,
        comment="Human-readable proposal description"
    )

    # Voting periods
    voting_start = Column(
        DateTime,
        nullable=False,
        comment="When voting opens (1 day after creation)"
    )

    voting_end = Column(
        DateTime,
        nullable=False,
        comment="When voting closes (7 days after start)"
    )

    # Vote counts
    for_votes = Column(
        Numeric(precision=78, scale=0),
        default=0,
        comment="Total FOR votes (token-weighted)"
    )

    against_votes = Column(
        Numeric(precision=78, scale=0),
        default=0,
        comment="Total AGAINST votes (token-weighted)"
    )

    abstain_votes = Column(
        Numeric(precision=78, scale=0),
        default=0,
        comment="Total ABSTAIN votes (token-weighted)"
    )

    # Status and execution
    status = Column(
        SQLEnum(ProposalStatus),
        default=ProposalStatus.PENDING,
        comment="Current proposal status"
    )

    executed = Column(
        Boolean,
        default=False,
        comment="Whether proposal has been executed"
    )

    defeated = Column(
        Boolean,
        default=False,
        comment="Whether proposal was defeated"
    )

    quorum_reached = Column(
        Boolean,
        default=False,
        comment="Whether quorum requirement was met"
    )

    quorum_required = Column(
        Numeric(precision=78, scale=0),
        nullable=True,
        comment="Minimum votes required for quorum (computed from total supply)"
    )

    proposal_threshold = Column(
        Numeric(precision=78, scale=0),
        nullable=True,
        comment="Minimum tokens required to create proposal (computed from total supply)"
    )

    # Blockchain transaction
    tx_hash = Column(
        String(66),
        nullable=False,
        comment="Transaction hash of proposal creation"
    )

    execution_tx_hash = Column(
        String(66),
        nullable=True,
        comment="Transaction hash of proposal execution"
    )

    # Timestamps
    created_at = Column(
        DateTime,
        server_default=func.now(),
        comment="Timestamp of proposal creation"
    )

    updated_at = Column(
        DateTime,
        server_default=func.now(),
        onupdate=func.now(),
        comment="Timestamp of last update"
    )

    def __repr__(self):
        return f"<GovernanceProposal(id={self.id}, blockchain_id={self.blockchain_proposal_id}, type={self.proposal_type}, status={self.status})>"

