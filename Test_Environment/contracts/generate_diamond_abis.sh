#!/bin/bash
# Generate Unified ABIs for Diamond Contracts
# This script merges all facet ABIs into a single unified ABI per Diamond
# following EIP-2535 best practices for external integrations

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/out"

echo "═══════════════════════════════════════════════════════════"
echo "  Generating Unified Diamond ABIs"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required but not installed."
    echo "   Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Check if out directory exists
if [ ! -d "$OUT_DIR" ]; then
    echo "❌ Error: $OUT_DIR directory not found."
    echo "   Please run 'forge build' first."
    exit 1
fi

# ============================================================================
# YieldBase Diamond - Merge all YieldBase facet ABIs
# ============================================================================
echo "📦 Generating YieldBase Diamond unified ABI..."

YIELD_FACETS=(
    "DiamondCutFacet"
    "DiamondLoupeFacet"
    "OwnershipFacet"
    "YieldBaseFacet"
    "RepaymentFacet"
    "GovernanceFacet"
    "DefaultManagementFacet"
    "ViewsFacet"
)

# Build paths to facet ABI files
# All facets are compiled to out/ directory directly
YIELD_PATHS=()
for facet in "${YIELD_FACETS[@]}"; do
    YIELD_PATHS+=("$OUT_DIR/$facet.sol/$facet.json")
done

# Verify all facet files exist
for path in "${YIELD_PATHS[@]}"; do
    if [ ! -f "$path" ]; then
        echo "❌ Error: Facet ABI not found: $path"
        exit 1
    fi
done

# Merge YieldBase facet ABIs using jq
# Extract .abi from each JSON, combine, and remove duplicates by (name + type)
jq -s '
    [.[] | .abi] | 
    add | 
    unique_by(.name + (.type // ""))
' "${YIELD_PATHS[@]}" > "$OUT_DIR/DiamondYieldBase_ABI.json"

echo "   ✅ YieldBase Diamond ABI: $OUT_DIR/DiamondYieldBase_ABI.json"
echo "      Functions: $(jq '[.[] | select(.type == "function")] | length' "$OUT_DIR/DiamondYieldBase_ABI.json")"
echo "      Events: $(jq '[.[] | select(.type == "event")] | length' "$OUT_DIR/DiamondYieldBase_ABI.json")"
echo ""

# ============================================================================
# CombinedPropertyYieldToken Diamond - Merge all CombinedToken facet ABIs
# ============================================================================
echo "📦 Generating CombinedPropertyYieldToken Diamond unified ABI..."

COMBINED_FACETS=(
    "DiamondCutFacet"
    "DiamondLoupeFacet"
    "OwnershipFacet"
    "CombinedTokenCoreFacet"
    "MintingFacet"
    "DistributionFacet"
    "RestrictionsFacet"
    "CombinedViewsFacet"
)

# Build paths to facet ABI files
# All facets are compiled to out/ directory directly
COMBINED_PATHS=()
for facet in "${COMBINED_FACETS[@]}"; do
    COMBINED_PATHS+=("$OUT_DIR/$facet.sol/$facet.json")
done

# Verify all facet files exist
for path in "${COMBINED_PATHS[@]}"; do
    if [ ! -f "$path" ]; then
        echo "❌ Error: Facet ABI not found: $path"
        exit 1
    fi
done

# Merge CombinedToken facet ABIs using jq
jq -s '
    [.[] | .abi] | 
    add | 
    unique_by(.name + (.type // ""))
' "${COMBINED_PATHS[@]}" > "$OUT_DIR/DiamondCombinedToken_ABI.json"

echo "   ✅ CombinedToken Diamond ABI: $OUT_DIR/DiamondCombinedToken_ABI.json"
echo "      Functions: $(jq '[.[] | select(.type == "function")] | length' "$OUT_DIR/DiamondCombinedToken_ABI.json")"
echo "      Events: $(jq '[.[] | select(.type == "event")] | length' "$OUT_DIR/DiamondCombinedToken_ABI.json")"
echo ""

# ============================================================================
# Verification
# ============================================================================
echo "🔍 Verifying unified ABIs..."

# Check YieldBase Diamond ABI
YIELD_FUNCTIONS=$(jq '[.[] | select(.type == "function")] | length' "$OUT_DIR/DiamondYieldBase_ABI.json")
if [ "$YIELD_FUNCTIONS" -lt 30 ]; then
    echo "⚠️  Warning: YieldBase Diamond has only $YIELD_FUNCTIONS functions (expected ~35+)"
fi

# Check CombinedToken Diamond ABI
COMBINED_FUNCTIONS=$(jq '[.[] | select(.type == "function")] | length' "$OUT_DIR/DiamondCombinedToken_ABI.json")
if [ "$COMBINED_FUNCTIONS" -lt 29 ]; then
    echo "⚠️  Warning: CombinedToken Diamond has only $COMBINED_FUNCTIONS functions (expected ~34+)"
fi

# Check for critical functions
echo ""
echo "🔍 Checking for critical functions..."

# YieldBase critical functions
YIELD_CRITICAL=(
    "createYieldAgreement"
    "makeRepayment"
    "adjustAgreementROI"
    "getAgreementStatus"
)

for func in "${YIELD_CRITICAL[@]}"; do
    if jq -e --arg fname "$func" '[.[] | select(.type == "function" and .name == $fname)] | length > 0' "$OUT_DIR/DiamondYieldBase_ABI.json" > /dev/null; then
        echo "   ✅ YieldBase: $func"
    else
        echo "   ❌ YieldBase: $func NOT FOUND"
    fi
done

# CombinedToken critical functions
COMBINED_CRITICAL=(
    "mintPropertyToken"
    "mintYieldTokens"
    "distributeYieldRepayment"
    "setYieldTokenRestrictions"
)

for func in "${COMBINED_CRITICAL[@]}"; do
    if jq -e --arg fname "$func" '[.[] | select(.type == "function" and .name == $fname)] | length > 0' "$OUT_DIR/DiamondCombinedToken_ABI.json" > /dev/null; then
        echo "   ✅ CombinedToken: $func"
    else
        echo "   ❌ CombinedToken: $func NOT FOUND"
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Unified Diamond ABIs Generated Successfully!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📄 Output Files:"
echo "   - $OUT_DIR/DiamondYieldBase_ABI.json"
echo "   - $OUT_DIR/DiamondCombinedToken_ABI.json"
echo ""
echo "💡 Next Steps:"
echo "   1. Restart backend to load new unified ABIs"
echo "   2. Test contract interactions via backend API"
echo "   3. Verify events are emitted correctly"
echo ""

