-- Migration: Alter governance_votes.voting_power from BIGINT to NUMERIC
-- Purpose: Fix "bigint out of range" error for Wei values (18 decimals)
-- Date: 2025-11-30
-- Issue: voting_power=10000000000000000000000 exceeds BIGINT max (9,223,372,036,854,775,807)
-- Solution: Change to NUMERIC(78,0) to match governance_proposals vote count columns

-- Alter voting_power column type
ALTER TABLE governance_votes
ALTER COLUMN voting_power TYPE NUMERIC(78,0);

-- Update comment for documentation
COMMENT ON COLUMN governance_votes.voting_power IS 'Token balance (voting power) at time of vote in Wei (up to 78 digits)';

-- Verify the change
SELECT column_name, data_type, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_name = 'governance_votes' AND column_name = 'voting_power';

