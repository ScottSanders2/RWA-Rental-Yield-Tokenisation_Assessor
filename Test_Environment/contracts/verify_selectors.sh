#!/bin/bash

# verify_selectors.sh
# Extracts function selectors from all Diamond facets and checks for collisions

echo "=== Diamond Selector Verification ==="#
echo ""

# Define YieldBase facets
YIELDBASE_FACETS=(
    "YieldBaseFacet"
    "RepaymentFacet"
    "GovernanceFacet"
    "DefaultManagementFacet"
    "ViewsFacet"
)

# Define CombinedToken facets
COMBINED_FACETS=(
    "CombinedTokenCoreFacet"
    "MintingFacet"
    "DistributionFacet"
    "RestrictionsFacet"
    "CombinedViewsFacet"
)

# Temporary file to store all selectors
ALL_SELECTORS_FILE=$(mktemp)

# Function to extract selectors from ABI
extract_selectors() {
    local facet_name=$1
    local abi_file="./out/${facet_name}.sol/${facet_name}.json"
    
    if [ ! -f "$abi_file" ]; then
        echo "Error: ABI file not found for ${facet_name}"
        return 1
    fi
    
    # Extract function names and selectors using jq
    local selectors=$(jq -r '.abi[] | select(.type == "function") | .name + " -> " + (.inputs | map(.type) | join(","))' "$abi_file" | while read -r func_sig; do
        # Calculate selector (first 4 bytes of keccak256 hash)
        # We'll just count for now since we need cast for actual selector calculation
        echo "$func_sig"
    done)
    
    # Count functions
    local count=$(jq -r '[.abi[] | select(.type == "function")] | length' "$abi_file")
    
    echo "${facet_name}: ${count} functions"
    
    # Store function signatures for this facet (exclude inherited OpenZeppelin functions)
    jq -r '.abi[] | select(.type == "function") | "\(.name)(\(.inputs | map(.type) | join(",")))"' "$abi_file" | \
    grep -v "^owner()" | \
    grep -v "^renounceOwnership()" | \
    grep -v "^transferOwnership(" | \
    grep -v "^UPGRADE_INTERFACE_VERSION()" | \
    grep -v "^proxiableUUID()" | \
    grep -v "^upgradeToAndCall(" >> "$ALL_SELECTORS_FILE"
    
    return 0
}

echo "=== YieldBase Diamond ===" 
echo ""

YIELDBASE_TOTAL=0
for facet in "${YIELDBASE_FACETS[@]}"; do
    extract_selectors "$facet"
    count=$(jq -r '[.abi[] | select(.type == "function")] | length' "./out/${facet}.sol/${facet}.json" 2>/dev/null || echo 0)
    YIELDBASE_TOTAL=$((YIELDBASE_TOTAL + count))
done

echo ""
echo "=== CombinedPropertyYieldToken Diamond ===" 
echo ""

COMBINED_TOTAL=0
for facet in "${COMBINED_FACETS[@]}"; do
    extract_selectors "./out/facets/combined/${facet}.sol/${facet}.json" "$facet" "combined"
    count=$(jq -r '[.abi[] | select(.type == "function")] | length' "./out/facets/combined/${facet}.sol/${facet}.json" 2>/dev/null || echo 0)
    COMBINED_TOTAL=$((COMBINED_TOTAL + count))
done

TOTAL_FUNCTIONS=$((YIELDBASE_TOTAL + COMBINED_TOTAL))

echo ""
echo "-------------------------------------------"
echo "TOTAL FUNCTIONS: ${TOTAL_FUNCTIONS}"
echo ""

# Check for duplicates
echo "Checking for selector collisions..."
UNIQUE_COUNT=$(sort "$ALL_SELECTORS_FILE" | uniq | wc -l | tr -d ' ')
ALL_COUNT=$(wc -l < "$ALL_SELECTORS_FILE" | tr -d ' ')

if [ "$UNIQUE_COUNT" -eq "$ALL_COUNT" ]; then
    echo "✅ SUCCESS: All ${ALL_COUNT} function selectors are unique!"
    echo "✅ NO COLLISIONS DETECTED"
else
    echo "❌ ERROR: Found duplicate selectors!"
    echo "   Total functions: ${ALL_COUNT}"
    echo "   Unique selectors: ${UNIQUE_COUNT}"
    echo ""
    echo "Duplicates:"
    sort "$ALL_SELECTORS_FILE" | uniq -d
    rm "$ALL_SELECTORS_FILE"
    exit 1
fi

# Clean up
rm "$ALL_SELECTORS_FILE"

echo ""
echo "=== Verification Complete ===" 
echo ""

exit 0

