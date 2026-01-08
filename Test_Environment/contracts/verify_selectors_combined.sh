#!/bin/bash

# verify_selectors_combined.sh
# Verify CombinedToken facets for selector collisions

echo "=== CombinedPropertyYieldToken Diamond Selector Verification ==="
echo ""

# Define Combined facets
COMBINED_FACETS=(
    "CombinedTokenCoreFacet"
    "MintingFacet"
    "DistributionFacet"
    "RestrictionsFacet"
    "CombinedViewsFacet"
)

# Temporary file
ALL_SELECTORS_FILE=$(mktemp)

extract_selectors() {
    local facet_name=$1
    local abi_file="./out/${facet_name}.sol/${facet_name}.json"
    
    if [ ! -f "$abi_file" ]; then
        echo "Error: ABI file not found for ${facet_name}"
        return 1
    fi
    
    local count=$(jq -r '[.abi[] | select(.type == "function")] | length' "$abi_file")
    echo "${facet_name}: ${count} functions"
    
    # Store function signatures (exclude inherited OpenZeppelin and ERC-1155 functions)
    jq -r '.abi[] | select(.type == "function") | "\(.name)(\(.inputs | map(.type) | join(",")))"' "$abi_file" | \
    grep -v "^owner()" | \
    grep -v "^renounceOwnership()" | \
    grep -v "^transferOwnership(" | \
    grep -v "^UPGRADE_INTERFACE_VERSION()" | \
    grep -v "^proxiableUUID()" | \
    grep -v "^upgradeToAndCall(" | \
    grep -v "^balanceOf(" | \
    grep -v "^balanceOfBatch(" | \
    grep -v "^setApprovalForAll(" | \
    grep -v "^isApprovedForAll(" | \
    grep -v "^safeTransferFrom(" | \
    grep -v "^safeBatchTransferFrom(" | \
    grep -v "^supportsInterface(" | \
    grep -v "^uri(" >> "$ALL_SELECTORS_FILE"
    
    return 0
}

echo "Extracting selectors from each facet..."
echo ""

TOTAL_FUNCTIONS=0

for facet in "${COMBINED_FACETS[@]}"; do
    extract_selectors "$facet"
    count=$(jq -r '[.abi[] | select(.type == "function")] | length' "./out/${facet}.sol/${facet}.json" 2>/dev/null || echo 0)
    TOTAL_FUNCTIONS=$((TOTAL_FUNCTIONS + count))
done

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

