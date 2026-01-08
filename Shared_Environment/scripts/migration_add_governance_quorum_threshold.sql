-- Migration: Add quorum_required and proposal_threshold columns to governance_proposals
-- Date: 2025-11-09
-- Author: Development Team
-- Purpose: Support dynamic quorum/threshold computation from Comment 4 implementation

-- Add new columns for dynamic governance parameters
ALTER TABLE governance_proposals 
ADD COLUMN IF NOT EXISTS quorum_required NUMERIC(78, 0),
ADD COLUMN IF NOT EXISTS proposal_threshold NUMERIC(78, 0);

-- Add comments to columns (PostgreSQL-specific syntax)
COMMENT ON COLUMN governance_proposals.quorum_required IS 'Minimum votes required for quorum (computed from total supply)';
COMMENT ON COLUMN governance_proposals.proposal_threshold IS 'Minimum tokens required to create proposal (computed from total supply)';

-- Update existing proposals with default values
-- Default: 10% quorum (10000 bp), 1% threshold (1000 bp) on 100,000 token supply
UPDATE governance_proposals 
SET quorum_required = COALESCE(quorum_required, 10000),
    proposal_threshold = COALESCE(proposal_threshold, 1000)
WHERE quorum_required IS NULL OR proposal_threshold IS NULL;

-- Verify migration
SELECT 
    COUNT(*) as total_proposals,
    COUNT(quorum_required) as with_quorum,
    COUNT(proposal_threshold) as with_threshold
FROM governance_proposals;

-- Expected result: All three counts should be equal

