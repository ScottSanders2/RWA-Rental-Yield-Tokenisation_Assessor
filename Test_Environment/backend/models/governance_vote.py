"""
Database model for governance votes.

Tracks individual votes cast by users on governance proposals,
ensuring vote uniqueness and enabling vote history retrieval.
"""

from sqlalchemy import Column, Integer, String, BigInteger, DateTime, Index, UniqueConstraint
from sqlalchemy.sql import func
from config.database import Base


class GovernanceVote(Base):
    """
    Model for individual governance votes.
    
    Stores vote records with voter address, proposal, and voting power.
    Enforces one-vote-per-address-per-proposal constraint.
    """
    __tablename__ = "governance_votes"
    
    # Primary key
    id = Column(Integer, primary_key=True, index=True)
    
    # Foreign key to proposal (database ID, not blockchain ID)
    proposal_id = Column(Integer, nullable=False, index=True)
    
    # Voter wallet address (42 characters for Ethereum address with 0x prefix)
    voter_address = Column(String(42), nullable=False, index=True)
    
    # Vote choice: 0 = Against, 1 = For, 2 = Abstain
    support = Column(Integer, nullable=False)
    
    # Voting power at time of vote (token balance)
    voting_power = Column(BigInteger, nullable=False, default=0)
    
    # Timestamp when vote was cast
    voted_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    
    # Unique constraint: one vote per address per proposal
    __table_args__ = (
        UniqueConstraint('proposal_id', 'voter_address', name='uq_proposal_voter'),
        Index('idx_proposal_voter', 'proposal_id', 'voter_address'),
        Index('idx_voter_address', 'voter_address'),
        Index('idx_voted_at', 'voted_at'),
    )
    
    def __repr__(self):
        support_labels = {0: "Against", 1: "For", 2: "Abstain"}
        return (
            f"<GovernanceVote(id={self.id}, "
            f"proposal_id={self.proposal_id}, "
            f"voter={self.voter_address[:8]}..., "
            f"vote={support_labels.get(self.support, 'Unknown')}, "
            f"power={self.voting_power})>"
        )

