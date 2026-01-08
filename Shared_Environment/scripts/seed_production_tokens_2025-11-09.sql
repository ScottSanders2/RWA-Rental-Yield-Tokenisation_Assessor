-- Production Token Seeding Script
-- Seeds token balances for 10 existing agreements in Production
-- Pattern: Property Owner #1 (20%) + 8 Investors (10% each) = 100%
-- Date: 2025-11-09
-- Purpose: Enable governance functionality for Production agreements

-- Standard wallet addresses (shared across all agreements)
-- Property Owner #1: 0x0000000000000000000000000000000000000001
-- Investor Alice:     0x0000000000000000000000000000000000000101
-- Investor Bob:       0x0000000000000000000000000000000000000102
-- Investor Charlie:   0x0000000000000000000000000000000000000103
-- Investor Diana:     0x0000000000000000000000000000000000000104
-- Investor Eve:       0x0000000000000000000000000000000000000105
-- Investor Frank:     0x0000000000000000000000000000000000000106
-- Investor Grace:     0x0000000000000000000000000000000000000107
-- Investor Henry:     0x0000000000000000000000000000000000000108

BEGIN;

-- Agreements 1-10 (100,000 tokens each - ERC721 standard)
-- 20% to property owner, 10% to each of 8 investors
INSERT INTO token_balances (agreement_id, wallet_address, balance, token_standard) 
SELECT agreement_id, wallet_address, 20000, 'ERC721' 
FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10)) AS t(agreement_id), 
     (VALUES ('0x0000000000000000000000000000000000000001')) AS w(wallet_address)
UNION ALL
SELECT agreement_id, wallet_address, 10000, 'ERC721' 
FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10)) AS t(agreement_id), 
     (VALUES 
       ('0x0000000000000000000000000000000000000101'),
       ('0x0000000000000000000000000000000000000102'),
       ('0x0000000000000000000000000000000000000103'),
       ('0x0000000000000000000000000000000000000104'),
       ('0x0000000000000000000000000000000000000105'),
       ('0x0000000000000000000000000000000000000106'),
       ('0x0000000000000000000000000000000000000107'),
       ('0x0000000000000000000000000000000000000108')
     ) AS w(wallet_address);

COMMIT;

-- Verification Query
SELECT 
  COUNT(DISTINCT agreement_id) as agreements_seeded,
  COUNT(*) as total_token_holders,
  SUM(balance) as total_tokens_distributed
FROM token_balances
WHERE agreement_id IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);

-- Show token distribution per agreement
SELECT 
  agreement_id,
  COUNT(*) as holders,
  SUM(balance) as total_tokens,
  token_standard
FROM token_balances
WHERE agreement_id IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
GROUP BY agreement_id, token_standard
ORDER BY agreement_id;

