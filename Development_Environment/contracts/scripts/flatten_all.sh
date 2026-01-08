#!/bin/bash

###############################################################################
# flatten_all.sh
# 
# Purpose: Flatten all smart contracts using Hardhat for Remix IDE deployment
#          to Polygon Amoy testnet
#
# Usage: bash scripts/flatten_all.sh
#
# Requirements:
#   - Hardhat installed (npm install --save-dev hardhat)
#   - All contracts compiled successfully
#
# Output: Flattened contracts in ./flattened/ directory
###############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Set directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"  # scripts is in contracts/scripts, so .. = contracts
FLATTENED_DIR="$CONTRACTS_DIR/flattened"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Contract Flattening Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Change to contracts directory
cd "$CONTRACTS_DIR"

# Check Hardhat installation
echo -e "${YELLOW}Checking Hardhat installation...${NC}"
if ! command -v npx &> /dev/null; then
    echo -e "${RED}Error: npx not found. Please install Node.js and npm.${NC}"
    exit 1
fi

if ! npx hardhat --version &> /dev/null; then
    echo -e "${RED}Error: Hardhat not found. Installing...${NC}"
    npm install --save-dev hardhat
fi

HARDHAT_VERSION=$(npx hardhat --version)
echo -e "${GREEN}✓ Hardhat version: $HARDHAT_VERSION${NC}"
echo ""

# Create output directory
echo -e "${YELLOW}Creating output directory...${NC}"
rm -rf "$FLATTENED_DIR"
mkdir -p "$FLATTENED_DIR"
echo -e "${GREEN}✓ Output directory created: $FLATTENED_DIR${NC}"
echo ""

# Flatten core contracts
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Flattening Core Contracts${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}[1/6] Flattening PropertyNFT.sol...${NC}"
npx hardhat flatten src/PropertyNFT.sol > "$FLATTENED_DIR/PropertyNFT.flat.sol"
echo -e "${GREEN}✓ PropertyNFT.flat.sol created${NC}"

echo -e "${YELLOW}[2/6] Flattening YieldBase.sol...${NC}"
npx hardhat flatten src/YieldBase.sol > "$FLATTENED_DIR/YieldBase.flat.sol"
echo -e "${GREEN}✓ YieldBase.flat.sol created${NC}"

echo -e "${YELLOW}[3/6] Flattening YieldSharesToken.sol...${NC}"
npx hardhat flatten src/YieldSharesToken.sol > "$FLATTENED_DIR/YieldSharesToken.flat.sol"
echo -e "${GREEN}✓ YieldSharesToken.flat.sol created${NC}"

echo -e "${YELLOW}[4/6] Flattening CombinedPropertyYieldToken.sol...${NC}"
npx hardhat flatten src/CombinedPropertyYieldToken.sol > "$FLATTENED_DIR/CombinedPropertyYieldToken.flat.sol"
echo -e "${GREEN}✓ CombinedPropertyYieldToken.flat.sol created${NC}"

echo -e "${YELLOW}[5/6] Flattening GovernanceController.sol...${NC}"
npx hardhat flatten src/GovernanceController.sol > "$FLATTENED_DIR/GovernanceController.flat.sol"
echo -e "${GREEN}✓ GovernanceController.flat.sol created${NC}"

echo -e "${YELLOW}[6/6] Flattening KYCRegistry.sol...${NC}"
npx hardhat flatten src/KYCRegistry.sol > "$FLATTENED_DIR/KYCRegistry.flat.sol"
echo -e "${GREEN}✓ KYCRegistry.flat.sol created${NC}"

echo ""

# Flatten storage libraries (for reference, not deployed separately)
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Flattening Storage Libraries${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}[1/7] Flattening PropertyStorage.sol...${NC}"
npx hardhat flatten src/storage/PropertyStorage.sol > "$FLATTENED_DIR/PropertyStorage.flat.sol"
echo -e "${GREEN}✓ PropertyStorage.flat.sol created${NC}"

echo -e "${YELLOW}[2/7] Flattening YieldStorage.sol...${NC}"
npx hardhat flatten src/storage/YieldStorage.sol > "$FLATTENED_DIR/YieldStorage.flat.sol"
echo -e "${GREEN}✓ YieldStorage.flat.sol created${NC}"

echo -e "${YELLOW}[3/7] Flattening YieldSharesStorage.sol...${NC}"
npx hardhat flatten src/storage/YieldSharesStorage.sol > "$FLATTENED_DIR/YieldSharesStorage.flat.sol"
echo -e "${GREEN}✓ YieldSharesStorage.flat.sol created${NC}"

echo -e "${YELLOW}[4/7] Flattening CombinedTokenStorage.sol...${NC}"
npx hardhat flatten src/storage/CombinedTokenStorage.sol > "$FLATTENED_DIR/CombinedTokenStorage.flat.sol"
echo -e "${GREEN}✓ CombinedTokenStorage.flat.sol created${NC}"

echo -e "${YELLOW}[5/7] Flattening GovernanceStorage.sol...${NC}"
npx hardhat flatten src/storage/GovernanceStorage.sol > "$FLATTENED_DIR/GovernanceStorage.flat.sol"
echo -e "${GREEN}✓ GovernanceStorage.flat.sol created${NC}"

echo -e "${YELLOW}[6/7] Flattening KYCStorage.sol...${NC}"
npx hardhat flatten src/storage/KYCStorage.sol > "$FLATTENED_DIR/KYCStorage.flat.sol"
echo -e "${GREEN}✓ KYCStorage.flat.sol created${NC}"

echo -e "${YELLOW}[7/7] Flattening TransferRestrictionsStorage.sol...${NC}"
npx hardhat flatten src/storage/TransferRestrictionsStorage.sol > "$FLATTENED_DIR/TransferRestrictionsStorage.flat.sol"
echo -e "${GREEN}✓ TransferRestrictionsStorage.flat.sol created${NC}"

echo ""

# Verification
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Verification${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Flattened files:${NC}"
ls -lh "$FLATTENED_DIR"

echo ""
echo -e "${YELLOW}Checking for import statements (should be none)...${NC}"
if grep -rn "^import" "$FLATTENED_DIR"/*.flat.sol; then
    echo -e "${RED}⚠ Warning: Import statements found in flattened files${NC}"
    echo -e "${RED}  This should not happen. Please review the output.${NC}"
else
    echo -e "${GREEN}✓ No import statements found (expected)${NC}"
fi

echo ""
echo -e "${YELLOW}Counting SPDX license identifiers (multiple expected)...${NC}"
for file in "$FLATTENED_DIR"/*.flat.sol; do
    filename=$(basename "$file")
    count=$(grep -c "SPDX-License-Identifier" "$file" || echo "0")
    echo -e "  ${filename}: ${count} SPDX licenses"
done

echo ""
echo -e "${YELLOW}Checking pragma versions...${NC}"
for file in "$FLATTENED_DIR"/*.flat.sol; do
    filename=$(basename "$file")
    pragma=$(grep "pragma solidity" "$file" | head -n 1 | awk '{print $3}')
    echo -e "  ${filename}: ${pragma}"
    if [[ "$pragma" != "^0.8.24;" ]]; then
        echo -e "${RED}    ⚠ Warning: Unexpected pragma version${NC}"
    fi
done

echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

CORE_COUNT=$(ls -1 "$FLATTENED_DIR"/*.flat.sol 2>/dev/null | grep -E "(PropertyNFT|YieldBase|YieldSharesToken|CombinedPropertyYieldToken|GovernanceController|KYCRegistry)" | wc -l | tr -d ' ')
STORAGE_COUNT=$(ls -1 "$FLATTENED_DIR"/*.flat.sol 2>/dev/null | grep -E "(PropertyStorage|YieldStorage|YieldSharesStorage|CombinedTokenStorage|GovernanceStorage|KYCStorage|TransferRestrictionsStorage)" | wc -l | tr -d ' ')
TOTAL_COUNT=$(ls -1 "$FLATTENED_DIR"/*.flat.sol 2>/dev/null | wc -l | tr -d ' ')

echo -e "${GREEN}✓ Flattening completed successfully${NC}"
echo -e "${GREEN}  Core contracts: ${CORE_COUNT}${NC}"
echo -e "${GREEN}  Storage libraries: ${STORAGE_COUNT}${NC}"
echo -e "${GREEN}  Total flattened files: ${TOTAL_COUNT}${NC}"
echo ""

# Calculate total size
TOTAL_SIZE=$(du -sh "$FLATTENED_DIR" | awk '{print $1}')
echo -e "${GREEN}  Total size: ${TOTAL_SIZE}${NC}"

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Review flattened files in: ${FLATTENED_DIR}"
echo -e "  2. Verify pragma versions are ^0.8.24"
echo -e "  3. Check file sizes (each should be <24KB when compiled)"
echo -e "  4. Upload to Remix IDE for Polygon Amoy deployment"
echo -e "  5. Follow deployment guide: Shared_Environment/docs/polygon-amoy-deployment-guide.md"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Ready for Remix Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

