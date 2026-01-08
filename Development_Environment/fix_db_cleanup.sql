-- Clean up out-of-sync Property 3
DELETE FROM properties WHERE id = 3;

-- Show remaining properties
SELECT id, blockchain_token_id, token_standard, owner_address, is_verified 
FROM properties 
ORDER BY id;

