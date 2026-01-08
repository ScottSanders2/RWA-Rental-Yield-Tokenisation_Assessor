#!/bin/bash
# Mythril Security Scan for RWA Tokenization Platform
# Scans yield-related contracts for vulnerabilities using symbolic execution

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$REPO_ROOT/docs/security/mythril"
mkdir -p "$REPORT_DIR"

echo "==================================="
echo "Mythril Security Scanner"
echo "==================================="
echo "Report directory: $REPORT_DIR"
echo ""

# Check if Mythril is installed
if ! command -v myth &> /dev/null; then
    echo "ERROR: Mythril not installed"
    echo "Install with: pip3 install mythril"
    exit 1
fi

echo "Mythril version:"
myth version
echo ""

# Contracts to scan (Diamond architecture - Iteration 15)
# Note: Scanning Diamond contracts + key facets + standalone contracts
declare -A CONTRACTS=(
    ["DiamondYieldBase"]="src/diamond/DiamondYieldBase.sol"
    ["YieldBaseFacet"]="src/diamond/facets/YieldBaseFacet.sol"
    ["RepaymentFacet"]="src/diamond/facets/RepaymentFacet.sol"
    ["ViewsFacet"]="src/diamond/facets/ViewsFacet.sol"
    ["DiamondCombinedToken"]="src/diamond/DiamondCombinedToken.sol"
    ["YieldSharesToken"]="src/YieldSharesToken.sol"
    ["KYCRegistry"]="src/KYCRegistry.sol"
    ["GovernanceController"]="src/GovernanceController.sol"
)

# Scan configuration
MAX_DEPTH=22
EXECUTION_TIMEOUT=300  # 5 minutes per contract
SOLVER_TIMEOUT=60000   # 60 seconds

echo "Scan Configuration:"
echo "  Max Depth: $MAX_DEPTH"
echo "  Execution Timeout: ${EXECUTION_TIMEOUT}s"
echo "  Solver Timeout: ${SOLVER_TIMEOUT}ms"
echo ""

# Initialize summary counters
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0
TOTAL_INFO=0

# Scan each contract
for name in "${!CONTRACTS[@]}"; do
    file="${CONTRACTS[$name]}"
    echo "========================================="
    echo "Scanning: $name"
    echo "File: $file"
    echo "========================================="
    
    REPORT_FILE="$REPORT_DIR/${name}_report.md"
    JSON_FILE="$REPORT_DIR/${name}_report.json"
    
    # Run Mythril with symbolic execution
    # Note: Using --solc-json for better Solidity version handling
    myth analyze "$REPO_ROOT/$file" \
        --solv 0.8.24 \
        --max-depth $MAX_DEPTH \
        --execution-timeout $EXECUTION_TIMEOUT \
        --solver-timeout $SOLVER_TIMEOUT \
        --output markdown \
        > "$REPORT_FILE" 2>&1 || {
            echo "WARNING: Mythril encountered issues scanning $name"
            echo "Check $REPORT_FILE for details"
        }
    
    # Also generate JSON output for programmatic analysis
    myth analyze "$REPO_ROOT/$file" \
        --solv 0.8.24 \
        --max-depth $MAX_DEPTH \
        --execution-timeout $EXECUTION_TIMEOUT \
        --solver-timeout $SOLVER_TIMEOUT \
        --output json \
        > "$JSON_FILE" 2>&1 || true
    
    echo "Report saved: $REPORT_FILE"
    echo ""
    
    # Count issues by severity
    HIGH=$(grep -c "Severity: High" "$REPORT_FILE" 2>/dev/null || echo "0")
    MEDIUM=$(grep -c "Severity: Medium" "$REPORT_FILE" 2>/dev/null || echo "0")
    LOW=$(grep -c "Severity: Low" "$REPORT_FILE" 2>/dev/null || echo "0")
    
    echo "  High: $HIGH"
    echo "  Medium: $MEDIUM"
    echo "  Low: $LOW"
    echo ""
    
    TOTAL_HIGH=$((TOTAL_HIGH + HIGH))
    TOTAL_MEDIUM=$((TOTAL_MEDIUM + MEDIUM))
    TOTAL_LOW=$((TOTAL_LOW + LOW))
done

# Generate summary report
SUMMARY_FILE="$REPORT_DIR/summary.md"
echo "Generating summary report..."

cat > "$SUMMARY_FILE" << EOF
# Mythril Security Scan Summary
**Date:** $(date)
**Platform:** RWA Rental Yield Tokenization
**Scan Type:** Symbolic Execution Analysis

## Overview
This report contains the results of automated security scans using Mythril, a security analysis tool for Ethereum smart contracts.

## Scan Configuration
- **Max Depth:** $MAX_DEPTH
- **Execution Timeout:** ${EXECUTION_TIMEOUT}s per contract
- **Solver Timeout:** ${SOLVER_TIMEOUT}ms
- **Solidity Version:** 0.8.24

## Scanned Contracts
EOF

for name in "${!CONTRACTS[@]}"; do
    echo "- **$name** (${CONTRACTS[$name]})" >> "$SUMMARY_FILE"
done

cat >> "$SUMMARY_FILE" << EOF

## Results Summary

| Severity | Count |
|----------|-------|
| High     | $TOTAL_HIGH |
| Medium   | $TOTAL_MEDIUM |
| Low      | $TOTAL_LOW |

## Detailed Results by Contract

EOF

for name in "${!CONTRACTS[@]}"; do
    REPORT_FILE="$REPORT_DIR/${name}_report.md"
    HIGH=$(grep -c "Severity: High" "$REPORT_FILE" 2>/dev/null || echo "0")
    MEDIUM=$(grep -c "Severity: Medium" "$REPORT_FILE" 2>/dev/null || echo "0")
    LOW=$(grep -c "Severity: Low" "$REPORT_FILE" 2>/dev/null || echo "0")
    
    cat >> "$SUMMARY_FILE" << EOF
### $name
- High: $HIGH
- Medium: $MEDIUM
- Low: $LOW
- Report: [${name}_report.md](./${name}_report.md)

EOF
done

cat >> "$SUMMARY_FILE" << EOF
## Known False Positives

### Reentrancy in nonReentrant Functions
Many contracts use OpenZeppelin's \`ReentrancyGuard\` which Mythril may not recognize.
These are false positives if the function has the \`nonReentrant\` modifier.

### Assembly Usage in ERC-7201 Storage
ERC-7201 namespaced storage uses assembly for storage slot calculations.
This is intentional and follows the ERC-7201 standard for collision-free storage.

### Unchecked External Calls
Some external calls are intentionally unchecked where failure is acceptable
(e.g., ETH transfers to shareholders where individual failure shouldn't revert the entire distribution).

## Recommendations

1. **Review High Severity Issues:** Immediately investigate all high-severity findings
2. **Validate Medium Severity:** Assess medium-severity issues for actual risk in context
3. **Document False Positives:** Clearly document any findings that are false positives
4. **Regular Scanning:** Run Mythril scans after any significant contract changes

## Next Steps

- Review detailed reports for each contract
- Cross-reference with Slither static analysis results
- Conduct manual security audit for critical functions
- Consider professional security audit before mainnet deployment

---
*Generated by Mythril v$(myth version | head -n1 | awk '{print $2}')*
EOF

echo "========================================="
echo "Scan Complete!"
echo "========================================="
echo ""
echo "Total Issues Found:"
echo "  High: $TOTAL_HIGH"
echo "  Medium: $TOTAL_MEDIUM"
echo "  Low: $TOTAL_LOW"
echo ""
echo "Summary: $SUMMARY_FILE"
echo "Individual reports: $REPORT_DIR/*_report.md"
echo ""

# Exit with error code if high-severity issues found
if [ $TOTAL_HIGH -gt 0 ]; then
    echo "WARNING: $TOTAL_HIGH high-severity issues detected!"
    echo "Review reports before deployment."
    exit 1
fi

echo "Scan completed successfully."
exit 0

