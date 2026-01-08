#!/bin/bash

echo "=== Testing Diamond Contract Integration ==="
echo ""

# Diamond addresses from deployment
YIELD_BASE="0x1613beB3B2C4f22Ee086B2b38C1476A3cE7f78E8"
COMBINED_TOKEN="0x4c5859f0F772848b2D91F1D83E2Fe57935348029"

echo "1. Testing YieldBase Diamond - Query facets via DiamondLoupe"
cast call $YIELD_BASE "facetAddresses()(address[])" --rpc-url http://localhost:8545

echo ""
echo "2. Testing YieldBase Diamond - Get agreement count"
cast call $YIELD_BASE "getAgreementCount()(uint256)" --rpc-url http://localhost:8545

echo ""
echo "3. Testing CombinedToken Diamond - Query facets"
cast call $COMBINED_TOKEN "facetAddresses()(address[])" --rpc-url http://localhost:8545

echo ""
echo "4. Testing CombinedToken Diamond - Get property token counter"
cast call $COMBINED_TOKEN "getPropertyTokenIdCounter()(uint256)" --rpc-url http://localhost:8545

echo ""
echo "=== Integration Tests Complete ==="
