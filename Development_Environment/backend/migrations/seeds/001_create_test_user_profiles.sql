-- Seed Data: Create test user profiles
-- Date: 2025-11-06
-- Purpose: Create diverse user profiles for testing governance with multiple voters

BEGIN;

-- Clear existing data (Development environment only!)
TRUNCATE user_profiles CASCADE;

-- Insert test user profiles
INSERT INTO user_profiles (wallet_address, display_name, role, email) VALUES
-- Property Owners (2 users)
('0x0000000000000000000000000000000000000001', 'Property Owner #1', 'property_owner', 'owner1@test.com'),
('0x0000000000000000000000000000000000000002', 'Property Owner #2', 'property_owner', 'owner2@test.com'),

-- Investors (8 users - majority token holders)
('0x0000000000000000000000000000000000000101', 'Investor Alice', 'investor', 'alice@test.com'),
('0x0000000000000000000000000000000000000102', 'Investor Bob', 'investor', 'bob@test.com'),
('0x0000000000000000000000000000000000000103', 'Investor Charlie', 'investor', 'charlie@test.com'),
('0x0000000000000000000000000000000000000104', 'Investor Diana', 'investor', 'diana@test.com'),
('0x0000000000000000000000000000000000000105', 'Investor Eve', 'investor', 'eve@test.com'),
('0x0000000000000000000000000000000000000106', 'Investor Frank', 'investor', 'frank@test.com'),
('0x0000000000000000000000000000000000000107', 'Investor Grace', 'investor', 'grace@test.com'),
('0x0000000000000000000000000000000000000108', 'Investor Henry', 'investor', 'henry@test.com'),

-- Platform Admin (1 user)
('0x0000000000000000000000000000000000000999', 'Platform Admin', 'admin', 'admin@test.com');

COMMIT;

-- Verification
SELECT 
    'User profiles created' as status,
    role,
    COUNT(*) as user_count
FROM user_profiles
GROUP BY role
ORDER BY role;
