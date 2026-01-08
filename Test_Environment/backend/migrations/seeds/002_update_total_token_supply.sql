-- Seed Data: Update total_token_supply with realistic values
-- Date: 2025-11-06
-- Purpose: Set diverse token supply values to test different quorum scenarios

BEGIN;

-- Agreement #1: 100,000 tokens (10% quorum = 10,000 tokens)
-- Scenario: Single large investor CAN reach quorum alone
UPDATE yield_agreements SET total_token_supply = 100000 WHERE id = 1;

-- Agreement #2: 500,000 tokens (10% quorum = 50,000 tokens)
-- Scenario: Need 5 investors with 10,000 tokens each
UPDATE yield_agreements SET total_token_supply = 500000 WHERE id = 2;

-- Agreement #3: 1,000,000 tokens (10% quorum = 100,000 tokens)
-- Scenario: Need 10 investors with 10,000 tokens each
UPDATE yield_agreements SET total_token_supply = 1000000 WHERE id = 3;

-- Agreements #4-10: Varying supplies for diversity
UPDATE yield_agreements SET total_token_supply = 250000 WHERE id >= 4 AND id <= 10;

-- Remaining agreements: Keep default 100,000
-- (Already set by migration default)

COMMIT;

-- Verification
SELECT 
    'Token supply updated' as status,
    total_token_supply,
    COUNT(*) as agreement_count,
    (total_token_supply * 1000 / 10000) as quorum_10_percent
FROM yield_agreements
GROUP BY total_token_supply
ORDER BY total_token_supply;
