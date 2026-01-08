-- Migration: Add total_token_supply to yield_agreements
-- Date: 2025-11-06
-- Purpose: Track total token supply for each agreement to calculate quorum correctly

BEGIN;

-- Add total_token_supply column
ALTER TABLE yield_agreements 
ADD COLUMN total_token_supply BIGINT NOT NULL DEFAULT 100000;

-- Add column comment
COMMENT ON COLUMN yield_agreements.total_token_supply IS 
'Total number of tokens issued for this agreement. Used for governance quorum calculations. Formula: quorum_required = (total_token_supply × quorum_percentage) / 10000';

-- Create index for performance (used in governance queries)
CREATE INDEX idx_yield_agreements_total_supply ON yield_agreements(total_token_supply);

COMMIT;

-- Verification query
SELECT 
    'Migration 001 completed' as status,
    COUNT(*) as agreements_updated,
    MIN(total_token_supply) as min_supply,
    MAX(total_token_supply) as max_supply
FROM yield_agreements;
