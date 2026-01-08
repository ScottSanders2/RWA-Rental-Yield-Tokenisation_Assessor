-- User Profile Seeding Script for Production Environment
-- Seeds test user profiles for multi-voter governance testing
-- Date: 2025-11-09
-- Purpose: Enable UserProfileSwitcher functionality in frontend

-- Clear existing profiles (optional - comment out if updating existing)
-- DELETE FROM user_profiles;

-- Insert test user profiles
-- Pattern: Property Owners (2), Investors (8), Admin (1)
INSERT INTO user_profiles (wallet_address, display_name, role, email, is_active) VALUES
-- Property Owners (20% token holdings each)
('0x0000000000000000000000000000000000000001', 'Property Owner #1', 'property_owner', 'owner1@test.com', TRUE),
('0x0000000000000000000000000000000000000002', 'Property Owner #2', 'property_owner', 'owner2@test.com', TRUE),

-- Investors (10% token holdings each)
('0x0000000000000000000000000000000000000101', 'Investor Alice', 'investor', 'alice@test.com', TRUE),
('0x0000000000000000000000000000000000000102', 'Investor Bob', 'investor', 'bob@test.com', TRUE),
('0x0000000000000000000000000000000000000103', 'Investor Charlie', 'investor', 'charlie@test.com', TRUE),
('0x0000000000000000000000000000000000000104', 'Investor Diana', 'investor', 'diana@test.com', TRUE),
('0x0000000000000000000000000000000000000105', 'Investor Eve', 'investor', 'eve@test.com', TRUE),
('0x0000000000000000000000000000000000000106', 'Investor Frank', 'investor', 'frank@test.com', TRUE),
('0x0000000000000000000000000000000000000107', 'Investor Grace', 'investor', 'grace@test.com', TRUE),
('0x0000000000000000000000000000000000000108', 'Investor Henry', 'investor', 'henry@test.com', TRUE),

-- Platform Admin
('0x0000000000000000000000000000000000000999', 'Platform Admin', 'admin', 'admin@test.com', TRUE)

ON CONFLICT (wallet_address) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    role = EXCLUDED.role,
    email = EXCLUDED.email,
    is_active = EXCLUDED.is_active;

-- Verification Query
SELECT 
    role,
    COUNT(*) as count,
    string_agg(display_name, ', ' ORDER BY display_name) as users
FROM user_profiles
WHERE is_active = TRUE
GROUP BY role
ORDER BY role;

-- Expected Results:
-- admin          | 1 | Platform Admin
-- investor       | 8 | Investor Alice, Investor Bob, Investor Charlie, Investor Diana, Investor Eve, Investor Frank, Investor Grace, Investor Henry
-- property_owner | 2 | Property Owner #1, Property Owner #2

-- Total: 11 active user profiles

