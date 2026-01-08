-- Migration: Create governance_votes table
-- Purpose: Store individual vote records for governance proposals
-- Date: 2025-11-05
-- Author: System

-- Create governance_votes table
CREATE TABLE IF NOT EXISTS governance_votes (
    id SERIAL PRIMARY KEY,
    proposal_id INTEGER NOT NULL,
    voter_address VARCHAR(42) NOT NULL,
    support INTEGER NOT NULL CHECK (support IN (0, 1, 2)),
    voting_power BIGINT NOT NULL DEFAULT 0,
    voted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Constraints
    CONSTRAINT uq_proposal_voter UNIQUE (proposal_id, voter_address)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_proposal_voter ON governance_votes(proposal_id, voter_address);
CREATE INDEX IF NOT EXISTS idx_voter_address ON governance_votes(voter_address);
CREATE INDEX IF NOT EXISTS idx_voted_at ON governance_votes(voted_at);
CREATE INDEX IF NOT EXISTS idx_proposal_id ON governance_votes(proposal_id);

-- Add comments for documentation
COMMENT ON TABLE governance_votes IS 'Individual vote records for governance proposals';
COMMENT ON COLUMN governance_votes.proposal_id IS 'Database ID of the proposal (not blockchain ID)';
COMMENT ON COLUMN governance_votes.voter_address IS 'Ethereum address of the voter (with 0x prefix)';
COMMENT ON COLUMN governance_votes.support IS 'Vote choice: 0=Against, 1=For, 2=Abstain';
COMMENT ON COLUMN governance_votes.voting_power IS 'Token balance (voting power) at time of vote';
COMMENT ON COLUMN governance_votes.voted_at IS 'Timestamp when vote was cast';
COMMENT ON CONSTRAINT uq_proposal_voter ON governance_votes IS 'Ensures one vote per address per proposal';

