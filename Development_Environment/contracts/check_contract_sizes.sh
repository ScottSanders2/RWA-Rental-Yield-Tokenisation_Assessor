#!/bin/bash
# Contract Bytecode Size Checker
# Usage: ./check_contract_sizes.sh
# Returns: 0 if all contracts under limit, 1 if any exceed limit

set -e

MAX_SIZE=24576
WARN_SIZE=20000
EXIT_CODE=0

echo "=== Contract Bytecode Size Check ==="
echo "EVM Limit: $MAX_SIZE bytes (24KB)"
echo "Warning Threshold: $WARN_SIZE bytes (81.4%)"
echo ""

# Build contracts
echo "Building contracts..."
docker exec rwa-dev-foundry forge build --force > /dev/null 2>&1 || {
    echo "❌ Contract compilation failed"
    exit 1
}

echo "Checking contract sizes..."
echo ""

CONTRACTS=("YieldBase" "CombinedPropertyYieldToken" "PropertyNFT" "YieldSharesToken" "GovernanceController")

for contract in "${CONTRACTS[@]}"; do
    if docker exec rwa-dev-foundry forge inspect $contract deployedBytecode > /tmp/${contract}_bytecode.txt 2>&1; then
        HEX_SIZE=$(cat /tmp/${contract}_bytecode.txt | wc -c)
        SIZE=$(( ($HEX_SIZE - 2) / 2 ))
        PERCENT=$(awk "BEGIN {printf \"%.1f\", ($SIZE / $MAX_SIZE) * 100}")
        DIFF=$(( $MAX_SIZE - $SIZE ))
        
        if [ $SIZE -gt $MAX_SIZE ]; then
            echo "❌ FAILED: $contract"
            echo "   Size: $SIZE bytes (${PERCENT}% of limit)"
            echo "   Exceeds limit by $(( $SIZE - $MAX_SIZE )) bytes"
            EXIT_CODE=1
        elif [ $SIZE -gt $WARN_SIZE ]; then
            echo "⚠️  WARNING: $contract"
            echo "   Size: $SIZE bytes (${PERCENT}% of limit)"
            echo "   Remaining: $DIFF bytes"
        else
            echo "✅ PASSED: $contract"
            echo "   Size: $SIZE bytes (${PERCENT}% of limit)"
            echo "   Remaining: $DIFF bytes"
        fi
        echo ""
        
        # Cleanup
        rm -f /tmp/${contract}_bytecode.txt
    else
        echo "⚠️  SKIP: $contract (not found or compilation failed)"
        echo ""
    fi
done

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All contracts within size limits"
else
    echo "❌ One or more contracts exceed the 24KB limit"
    echo ""
    echo "RECOMMENDED ACTIONS:"
    echo "1. Extract view functions to libraries"
    echo "2. Consolidate duplicate validation logic"
    echo "3. Optimize storage reads (cache in memory)"
    echo "4. Use unchecked{} for overflow-safe operations"
    echo "5. See CONTRACT_REFACTORING_PLAN.md for detailed optimization strategies"
fi

exit $EXIT_CODE

