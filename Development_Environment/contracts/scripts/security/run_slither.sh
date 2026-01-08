#!/bin/bash
# Slither Static Analysis for RWA Tokenization Platform
# Detects vulnerabilities, code quality issues, and optimization opportunities

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORT_DIR="$REPO_ROOT/docs/security/slither"
mkdir -p "$REPORT_DIR"

echo "==================================="
echo "Slither Static Analyzer"
echo "==================================="
echo "Report directory: $REPORT_DIR"
echo ""

# Check if Slither is installed
if ! command -v slither &> /dev/null; then
    echo "ERROR: Slither not installed"
    echo "Install with: pip3 install slither-analyzer"
    exit 1
fi

echo "Slither version:"
slither --version
echo ""

# Change to repo root for correct imports
cd "$REPO_ROOT"

# Run full project scan
echo "========================================="
echo "Running full project scan..."
echo "========================================="
echo ""

slither . \
    --json "$REPORT_DIR/full_report.json" \
    --checklist \
    --markdown-root "$REPORT_DIR" \
    --filter-paths "node_modules|test|mock" \
    > "$REPORT_DIR/full_report.txt" 2>&1 || {
        echo "WARNING: Slither found issues (this is normal)"
        echo "Check $REPORT_DIR/full_report.txt for details"
    }

echo "Full report saved: $REPORT_DIR/full_report.txt"
echo ""

# Run targeted scans on critical contracts
declare -A CONTRACTS=(
    ["YieldBase"]="src/YieldBase.sol"
    ["YieldSharesToken"]="src/YieldSharesToken.sol"
    ["KYCRegistry"]="src/KYCRegistry.sol"
    ["GovernanceController"]="src/GovernanceController.sol"
    ["CombinedPropertyYieldToken"]="src/CombinedPropertyYieldToken.sol"
)

for name in "${!CONTRACTS[@]}"; do
    file="${CONTRACTS[$name]}"
    echo "========================================="
    echo "Analyzing: $name"
    echo "========================================="
    
    # Run analysis with multiple printers
    slither "$file" \
        --json "$REPORT_DIR/${name}_report.json" \
        --print human-summary,inheritance-graph,call-graph \
        --filter-paths "node_modules|test|mock" \
        > "$REPORT_DIR/${name}_report.txt" 2>&1 || true
    
    echo "Report saved: $REPORT_DIR/${name}_report.txt"
    echo ""
done

# Generate human-readable summary
echo "========================================="
echo "Generating summary..."
echo "========================================="
echo ""

slither . \
    --print human-summary \
    --filter-paths "node_modules|test|mock" \
    > "$REPORT_DIR/human_summary.txt" 2>&1 || true

# Extract and categorize findings
SUMMARY_FILE="$REPORT_DIR/summary.md"

cat > "$SUMMARY_FILE" << EOF
# Slither Static Analysis Summary
**Date:** $(date)
**Platform:** RWA Rental Yield Tokenization
**Analysis Type:** Static Code Analysis

## Overview
This report contains the results of static analysis using Slither, a Solidity static analysis framework.

## Analysis Scope
- Full codebase scan with dependency filtering
- Individual contract analysis for critical contracts
- Vulnerability detection (high/medium/low/informational)
- Code quality assessment
- Optimization opportunities

## Scanned Contracts
EOF

for name in "${!CONTRACTS[@]}"; do
    echo "- **$name** (${CONTRACTS[$name]})" >> "$SUMMARY_FILE"
done

cat >> "$SUMMARY_FILE" << EOF

## Key Findings

### Critical Issues
EOF

# Extract critical findings from full report
grep -A 3 "Impact: High" "$REPORT_DIR/full_report.txt" | head -n 20 >> "$SUMMARY_FILE" 2>/dev/null || echo "None detected" >> "$SUMMARY_FILE"

cat >> "$SUMMARY_FILE" << EOF

### Medium Issues
EOF

grep -A 3 "Impact: Medium" "$REPORT_DIR/full_report.txt" | head -n 20 >> "$SUMMARY_FILE" 2>/dev/null || echo "None detected" >> "$SUMMARY_FILE"

cat >> "$SUMMARY_FILE" << EOF

### Optimization Opportunities
EOF

grep -A 3 "Optimization" "$REPORT_DIR/full_report.txt" | head -n 20 >> "$SUMMARY_FILE" 2>/dev/null || echo "None detected" >> "$SUMMARY_FILE"

cat >> "$SUMMARY_FILE" << EOF

## Code Quality Metrics

### Inheritance Complexity
EOF

# Extract inheritance info if available
grep -A 5 "Inheritance" "$REPORT_DIR/human_summary.txt" >> "$SUMMARY_FILE" 2>/dev/null || echo "See individual contract reports" >> "$SUMMARY_FILE"

cat >> "$SUMMARY_FILE" << EOF

### Function Complexity
EOF

grep -A 5 "Complexity" "$REPORT_DIR/human_summary.txt" >> "$SUMMARY_FILE" 2>/dev/null || echo "See individual contract reports" >> "$SUMMARY_FILE"

cat >> "$SUMMARY_FILE" << EOF

## Detailed Reports

- [Full Project Report](./full_report.txt)
- [Human-Readable Summary](./human_summary.txt)

### Individual Contract Reports
EOF

for name in "${!CONTRACTS[@]}"; do
    echo "- [$name Report](./${name}_report.txt)" >> "$SUMMARY_FILE"
done

cat >> "$SUMMARY_FILE" << EOF

## Known Expected Warnings

### Assembly Usage in Storage Libraries
ERC-7201 namespaced storage uses assembly for storage slot calculations.
This is intentional and follows the standard for collision-free upgradeable storage.

\`\`\`solidity
assembly {
    $.slot := STORAGE_LOCATION
}
\`\`\`

### Unchecked Math Operations
Some operations use \`unchecked\` blocks for gas optimization where overflow/underflow
is mathematically impossible or explicitly validated beforehand.

### External Calls in Loops
Some distribution functions make external calls in loops (e.g., distributing yield to shareholders).
This is necessary for pro-rata distribution but includes safeguards:
- Gas limits enforced
- Individual failure doesn't revert entire transaction
- Maximum shareholder limits enforced

### Solidity Version Pragma
Platform uses Solidity 0.8.24 with specific version constraints for consistency.
This is intentional to ensure deployment compatibility.

## Recommendations

1. **Review Critical Issues:** Immediately address any high-impact findings
2. **Assess Medium Issues:** Evaluate medium-impact findings in context
3. **Consider Optimizations:** Implement gas optimizations where beneficial
4. **Document Decisions:** Clearly document any warnings that are false positives or accepted risks

## Cross-Reference with Mythril

Compare these static analysis results with Mythril's symbolic execution findings
for comprehensive security coverage:
- Slither: Fast, broad detection of common patterns
- Mythril: Deep, execution-based vulnerability detection

## Next Steps

1. Review all high and medium severity findings
2. Implement fixes or document why findings are false positives
3. Run tests to ensure fixes don't break functionality
4. Consider professional security audit before mainnet deployment
5. Establish continuous security scanning in CI/CD pipeline

---
*Generated by Slither v$(slither --version | head -n1 | awk '{print $2}')*
EOF

echo "========================================="
echo "Analysis Complete!"
echo "========================================="
echo ""
echo "Reports generated:"
echo "  - Summary: $SUMMARY_FILE"
echo "  - Full report: $REPORT_DIR/full_report.txt"
echo "  - Human summary: $REPORT_DIR/human_summary.txt"
echo "  - Individual contracts: $REPORT_DIR/*_report.txt"
echo ""

# Check for critical issues
if grep -q "Impact: High" "$REPORT_DIR/full_report.txt" 2>/dev/null; then
    CRITICAL_COUNT=$(grep -c "Impact: High" "$REPORT_DIR/full_report.txt" || echo "0")
    echo "WARNING: $CRITICAL_COUNT high-impact issues detected!"
    echo "Review reports before deployment."
    exit 1
fi

echo "Analysis completed successfully."
echo "Review the reports and address any findings before deployment."
exit 0

