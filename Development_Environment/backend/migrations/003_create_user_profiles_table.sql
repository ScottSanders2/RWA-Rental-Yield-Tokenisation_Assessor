-- Migration: Create user_profiles table
-- Date: 2025-11-06
-- Purpose: User profiles for testing governance with multiple voters (simulates wallet management)

BEGIN;

-- Create user_profiles table
CREATE TABLE user_profiles (
    id SERIAL PRIMARY KEY,
    wallet_address VARCHAR(42) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT chk_role CHECK (role IN ('property_owner', 'investor', 'admin')),
    CONSTRAINT chk_wallet_format CHECK (wallet_address ~* '^0x[a-fA-F0-9]{40}$')
);

-- Create indexes for performance
CREATE INDEX idx_user_profiles_wallet ON user_profiles(wallet_address);
CREATE INDEX idx_user_profiles_role ON user_profiles(role);
CREATE INDEX idx_user_profiles_active ON user_profiles(is_active) WHERE is_active = TRUE;

-- Add comments for documentation
COMMENT ON TABLE user_profiles IS 
'User profiles for testing governance with multiple voters. Simulates different wallet connections in Development/Test environments. In Production, user data would come from actual wallet connections.';

COMMENT ON COLUMN user_profiles.id IS 'Unique identifier for the user profile';
COMMENT ON COLUMN user_profiles.wallet_address IS 'Ethereum address (0x... format, 42 characters)';
COMMENT ON COLUMN user_profiles.display_name IS 'Human-readable name for UI display';
COMMENT ON COLUMN user_profiles.role IS 'User role: property_owner, investor, or admin';
COMMENT ON COLUMN user_profiles.email IS 'Email address (optional, for notifications in testing)';
COMMENT ON COLUMN user_profiles.is_active IS 'Whether this profile is active and available for selection';
COMMENT ON COLUMN user_profiles.created_at IS 'Timestamp when profile was created';

COMMIT;

-- Verification query
SELECT 
    'Migration 003 completed' as status,
    COUNT(*) as table_exists
FROM information_schema.tables 
WHERE table_name = 'user_profiles';
