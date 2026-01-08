-- Migration: Create token_balances table
-- Date: 2025-11-06
-- Purpose: Track token ownership for each wallet per agreement (simulates blockchain state)

BEGIN;

-- Create token_balances table
CREATE TABLE token_balances (
    id SERIAL PRIMARY KEY,
    agreement_id INTEGER NOT NULL REFERENCES yield_agreements(id) ON DELETE CASCADE,
    wallet_address VARCHAR(42) NOT NULL,
    balance BIGINT NOT NULL DEFAULT 0,
    token_standard VARCHAR(10) NOT NULL,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT uq_agreement_wallet UNIQUE (agreement_id, wallet_address),
    CONSTRAINT chk_balance_positive CHECK (balance >= 0),
    CONSTRAINT chk_token_standard CHECK (token_standard IN ('ERC721', 'ERC1155'))
);

-- Create indexes for performance
CREATE INDEX idx_token_balances_agreement ON token_balances(agreement_id);
CREATE INDEX idx_token_balances_wallet ON token_balances(wallet_address);
CREATE INDEX idx_token_balances_updated ON token_balances(last_updated DESC);

-- Add comments for documentation
COMMENT ON TABLE token_balances IS 
'Tracks token ownership per wallet for governance voting power calculations. Simulates blockchain token balances for Development/Test environments. In Production, this would be queried from the blockchain.';

COMMENT ON COLUMN token_balances.id IS 'Unique identifier for the balance record';
COMMENT ON COLUMN token_balances.agreement_id IS 'Reference to the yield agreement';
COMMENT ON COLUMN token_balances.wallet_address IS 'Ethereum address of the token holder (0x... format)';
COMMENT ON COLUMN token_balances.balance IS 'Number of tokens held by this wallet for this agreement';
COMMENT ON COLUMN token_balances.token_standard IS 'Token standard: ERC721 (NFT) or ERC1155 (fungible within agreement)';
COMMENT ON COLUMN token_balances.last_updated IS 'Timestamp of last balance update';

COMMIT;

-- Verification query
SELECT 
    'Migration 002 completed' as status,
    COUNT(*) as table_exists
FROM information_schema.tables 
WHERE table_name = 'token_balances';
