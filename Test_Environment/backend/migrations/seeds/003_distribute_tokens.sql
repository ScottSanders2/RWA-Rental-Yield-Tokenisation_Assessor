-- Seed Data: Distribute tokens among test users
-- Date: 2025-11-06
-- Purpose: Simulate token ownership distribution for realistic governance testing

BEGIN;

-- Clear existing data (Development environment only!)
TRUNCATE token_balances CASCADE;

-- ============================================================================
-- AGREEMENT #1: 100,000 total tokens (10% quorum = 10,000 tokens)
-- Distribution: Property owner 20%, 8 investors @ 10% each
-- Test Scenario: Single investor CAN reach quorum (10,000 tokens = 10%)
-- ============================================================================
INSERT INTO token_balances (agreement_id, wallet_address, balance, token_standard) VALUES
-- Property Owner #1: 20,000 tokens (20%)
(1, '0x0000000000000000000000000000000000000001', 20000, 'ERC721'),

-- Investors: Each holds 10,000 tokens (10% each)
(1, '0x0000000000000000000000000000000000000101', 10000, 'ERC721'),  -- Alice
(1, '0x0000000000000000000000000000000000000102', 10000, 'ERC721'),  -- Bob
(1, '0x0000000000000000000000000000000000000103', 10000, 'ERC721'),  -- Charlie
(1, '0x0000000000000000000000000000000000000104', 10000, 'ERC721'),  -- Diana
(1, '0x0000000000000000000000000000000000000105', 10000, 'ERC721'),  -- Eve
(1, '0x0000000000000000000000000000000000000106', 10000, 'ERC721'),  -- Frank
(1, '0x0000000000000000000000000000000000000107', 10000, 'ERC721'),  -- Grace
(1, '0x0000000000000000000000000000000000000108', 10000, 'ERC721'); -- Henry

-- ============================================================================
-- AGREEMENT #2: 500,000 total tokens (10% quorum = 50,000 tokens)
-- Distribution: Property owner 20%, investors get varying amounts
-- Test Scenario: Need 5 investors to reach quorum
-- ============================================================================
INSERT INTO token_balances (agreement_id, wallet_address, balance, token_standard) VALUES
-- Property Owner #2: 100,000 tokens (20%)
(2, '0x0000000000000000000000000000000000000002', 100000, 'ERC721'),

-- Large investors (can reach quorum together)
(2, '0x0000000000000000000000000000000000000101', 80000, 'ERC721'),   -- Alice (16%)
(2, '0x0000000000000000000000000000000000000102', 80000, 'ERC721'),   -- Bob (16%)
(2, '0x0000000000000000000000000000000000000103', 60000, 'ERC721'),   -- Charlie (12%)

-- Medium investors
(2, '0x0000000000000000000000000000000000000104', 50000, 'ERC721'),   -- Diana (10%)
(2, '0x0000000000000000000000000000000000000105', 50000, 'ERC721'),   -- Eve (10%)

-- Small investors
(2, '0x0000000000000000000000000000000000000106', 40000, 'ERC721'),   -- Frank (8%)
(2, '0x0000000000000000000000000000000000000107', 30000, 'ERC721'),   -- Grace (6%)
(2, '0x0000000000000000000000000000000000000108', 10000, 'ERC721');   -- Henry (2%)

-- ============================================================================
-- AGREEMENT #3: 1,000,000 total tokens (10% quorum = 100,000 tokens)
-- Distribution: More distributed ownership
-- Test Scenario: Need ALL 8 investors to reach quorum (challenging scenario)
-- ============================================================================
INSERT INTO token_balances (agreement_id, wallet_address, balance, token_standard) VALUES
-- Property Owner #1: 200,000 tokens (20%)
(3, '0x0000000000000000000000000000000000000001', 200000, 'ERC1155'),

-- Investors: More evenly distributed (each ~10-12.5%)
(3, '0x0000000000000000000000000000000000000101', 125000, 'ERC1155'),  -- Alice (12.5%)
(3, '0x0000000000000000000000000000000000000102', 125000, 'ERC1155'),  -- Bob (12.5%)
(3, '0x0000000000000000000000000000000000000103', 100000, 'ERC1155'),  -- Charlie (10%)
(3, '0x0000000000000000000000000000000000000104', 100000, 'ERC1155'),  -- Diana (10%)
(3, '0x0000000000000000000000000000000000000105', 100000, 'ERC1155'),  -- Eve (10%)
(3, '0x0000000000000000000000000000000000000106', 100000, 'ERC1155'),  -- Frank (10%)
(3, '0x0000000000000000000000000000000000000107', 100000, 'ERC1155'),  -- Grace (10%)
(3, '0x0000000000000000000000000000000000000108', 50000, 'ERC1155');   -- Henry (5%)

COMMIT;

-- Verification: Check token distribution
SELECT 
    'Token distribution summary' as status,
    agreement_id,
    COUNT(*) as holder_count,
    SUM(balance) as total_distributed,
    (SELECT total_token_supply FROM yield_agreements WHERE id = token_balances.agreement_id) as expected_supply,
    CASE 
        WHEN SUM(balance) = (SELECT total_token_supply FROM yield_agreements WHERE id = token_balances.agreement_id) 
        THEN '✓ Matches'
        ELSE '✗ Mismatch'
    END as verification
FROM token_balances
GROUP BY agreement_id
ORDER BY agreement_id;

-- Show top holders per agreement
SELECT 
    agreement_id,
    wallet_address,
    (SELECT display_name FROM user_profiles WHERE wallet_address = token_balances.wallet_address) as holder_name,
    balance as tokens,
    ROUND(balance * 100.0 / (SELECT total_token_supply FROM yield_agreements WHERE id = token_balances.agreement_id), 2) as percentage
FROM token_balances
WHERE agreement_id IN (1, 2, 3)
ORDER BY agreement_id, balance DESC;
