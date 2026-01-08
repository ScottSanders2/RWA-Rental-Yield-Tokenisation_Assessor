-- ============================================================================
-- DATABASE SYNC FIX
-- Purpose: Align database property ownership with blockchain reality
-- ============================================================================

-- 1. Delete out-of-sync Property 3 (ERC-1155 not minted on blockchain)
DELETE FROM properties WHERE id = 3;

-- 2. Update property owner addresses to match blockchain
-- Properties 1 & 2 (ERC-721) are actually owned by deployer on-chain
UPDATE properties 
SET owner_address = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
WHERE id IN (1, 2);

-- 3. Show updated state
SELECT id, blockchain_token_id, token_standard, owner_address, is_verified 
FROM properties 
ORDER BY id;

