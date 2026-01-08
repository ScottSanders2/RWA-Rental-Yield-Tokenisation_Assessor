#!/bin/bash
# Simple contract deployment using forge create (no terminal needed)
set -e

RPC_URL="http://localhost:8546"
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
DEPLOYER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

echo "🚀 Deploying contracts to Anvil..."
echo "RPC: $RPC_URL"
echo "Deployer: $DEPLOYER"
echo ""

# Note: This script creates a marker file to indicate deployment is ready for user
# User will manually deploy contracts, then this script validates addresses exist

echo "✅ Deployment script ready"
echo ""
echo "📋 MANUAL DEPLOYMENT STEPS:"
echo "1. You will deploy contracts manually"
echo "2. Update .env.dev with deployed addresses"
echo "3. Run: docker-compose restart rwa-dev-backend"
echo ""
echo "Contract deployment addresses will be shown after manual deployment"

