#!/usr/bin/env python3
"""
Script to populate [TBD] placeholders in DissertationProgress.md with actual benchmark data.

Usage:
    python3 fill_dissertation_tbds.py

Prerequisites:
    1. Run benchmark suite: forge test --match-path "test/benchmarks/**/*.sol" --gas-report --json > benchmarks/comprehensive-summary.json
    2. Deploy to Amoy and record transactions: <create amoy transaction log> > benchmarks/amoy-transactions.json
    3. Run volatile market simulations: forge test --match-path "test/simulations/**/*.sol" -vv > benchmarks/volatile-simulations.log

The script will:
    - Parse benchmark JSON files
    - Extract gas costs, recovery percentages, variance figures
    - Replace [TBD] markers in DissertationProgress.md with concrete values
    - Create backup of original file before modification
"""

import json
import re
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, Any

# Paths
REPO_ROOT = Path(__file__).parent.parent.parent.parent
DISSERTATION_FILE = REPO_ROOT / "DissertationProgress.md"
BENCHMARKS_DIR = REPO_ROOT / "Development_Environment" / "contracts" / "benchmarks"
COMPREHENSIVE_SUMMARY = BENCHMARKS_DIR / "comprehensive-summary.json"
AMOY_TRANSACTIONS = BENCHMARKS_DIR / "amoy-transactions.json"
VOLATILE_SIMULATIONS_LOG = BENCHMARKS_DIR / "volatile-simulations.log"

def load_benchmark_data() -> Dict[str, Any]:
    """Load and parse all benchmark data files."""
    data = {
        "local_gas": {},
        "amoy_gas": {},
        "volatile_metrics": {},
        "variance": {}
    }
    
    # Load comprehensive summary (Anvil/local benchmarks)
    if COMPREHENSIVE_SUMMARY.exists():
        with open(COMPREHENSIVE_SUMMARY, 'r') as f:
            local_data = json.load(f)
            # Extract gas costs from forge test output
            # Format: parse "test_name": {"gasUsed": XXX, ...}
            data["local_gas"] = parse_forge_gas_report(local_data)
    else:
        print(f"Warning: {COMPREHENSIVE_SUMMARY} not found. Run benchmark suite first.")
    
    # Load Amoy transactions
    if AMOY_TRANSACTIONS.exists():
        with open(AMOY_TRANSACTIONS, 'r') as f:
            amoy_data = json.load(f)
            data["amoy_gas"] = parse_amoy_transactions(amoy_data)
    else:
        print(f"Warning: {AMOY_TRANSACTIONS} not found. Deploy to Amoy and record transactions first.")
    
    # Load volatile market simulations
    if VOLATILE_SIMULATIONS_LOG.exists():
        with open(VOLATILE_SIMULATIONS_LOG, 'r') as f:
            volatile_log = f.read()
            data["volatile_metrics"] = parse_volatile_simulations(volatile_log)
    else:
        print(f"Warning: {VOLATILE_SIMULATIONS_LOG} not found. Run volatile market tests first.")
    
    # Calculate variance
    if data["local_gas"] and data["amoy_gas"]:
        data["variance"] = calculate_variance(data["local_gas"], data["amoy_gas"])
    
    return data

def parse_forge_gas_report(json_data: Dict) -> Dict[str, int]:
    """Parse Forge gas report JSON and extract operation costs."""
    gas_costs = {}
    
    # Example extraction logic (adjust based on actual forge JSON structure)
    # This is a simplified version - actual parsing depends on forge output format
    try:
        for test_result in json_data.get("tests", []):
            test_name = test_result.get("test", "")
            gas_used = test_result.get("gasUsed", 0)
            
            # Map test names to operation types
            if "PropertyMint" in test_name:
                gas_costs["property_mint"] = gas_used
            elif "CreateAgreementERC721" in test_name:
                gas_costs["erc721_agreement"] = gas_used
            elif "CreateAgreementERC1155" in test_name:
                gas_costs["erc1155_agreement"] = gas_used
            elif "Repayment" in test_name and "10" in test_name:
                gas_costs["repayment_10_shareholders"] = gas_used
            elif "BatchTransfer" in test_name and "50" in test_name:
                gas_costs["batch_transfer_50"] = gas_used
    except Exception as e:
        print(f"Error parsing forge gas report: {e}")
    
    return gas_costs

def parse_amoy_transactions(json_data: Dict) -> Dict[str, int]:
    """Parse Amoy transaction log and extract gas costs."""
    gas_costs = {}
    
    # Example: {"transactions": [{"operation": "property_mint", "gasUsed": 123456}, ...]}
    try:
        for tx in json_data.get("transactions", []):
            operation = tx.get("operation", "")
            gas_used = tx.get("gasUsed", 0)
            gas_costs[operation] = gas_used
    except Exception as e:
        print(f"Error parsing Amoy transactions: {e}")
    
    return gas_costs

def parse_volatile_simulations(log_content: str) -> Dict[str, Dict[str, Any]]:
    """Parse volatile market simulation logs and extract metrics."""
    metrics = {}
    
    # Parse console.log output from tests
    # Example patterns:
    # "Recovery Percentage: 85 %"
    # "System Status: OPERATIONAL"
    # "Gas Used: 1234567"
    
    scenario_pattern = r"=== Test \d+: (.+?) ==="
    recovery_pattern = r"Recovery Percentage: (\d+) %"
    gas_pattern = r"Gas Used: (\d+)"
    status_pattern = r"System Status: (\w+)"
    
    current_scenario = None
    for line in log_content.split('\n'):
        scenario_match = re.search(scenario_pattern, line)
        if scenario_match:
            current_scenario = scenario_match.group(1)
            metrics[current_scenario] = {}
        
        if current_scenario:
            recovery_match = re.search(recovery_pattern, line)
            if recovery_match:
                metrics[current_scenario]["recovery_percentage"] = int(recovery_match.group(1))
            
            gas_match = re.search(gas_pattern, line)
            if gas_match:
                metrics[current_scenario]["gas_used"] = int(gas_match.group(1))
            
            status_match = re.search(status_pattern, line)
            if status_match:
                metrics[current_scenario]["system_status"] = status_match.group(1)
    
    return metrics

def calculate_variance(local: Dict[str, int], amoy: Dict[str, int]) -> Dict[str, float]:
    """Calculate percentage variance between local and Amoy gas costs."""
    variance = {}
    
    for operation in local.keys():
        if operation in amoy:
            local_gas = local[operation]
            amoy_gas = amoy[operation]
            
            if local_gas > 0:
                var_pct = abs((amoy_gas - local_gas) / local_gas * 100)
                variance[operation] = round(var_pct, 1)
    
    return variance

def format_gas(gas: int) -> str:
    """Format gas value as 'XXXK' for readability."""
    return f"{gas // 1000}K" if gas >= 1000 else str(gas)

def replace_tbds_in_dissertation(data: Dict[str, Any]) -> None:
    """Replace [TBD] markers in DissertationProgress.md with actual values."""
    
    if not DISSERTATION_FILE.exists():
        print(f"Error: {DISSERTATION_FILE} not found.")
        return
    
    # Create backup
    backup_file = DISSERTATION_FILE.with_suffix(f".md.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}")
    with open(DISSERTATION_FILE, 'r') as f:
        original_content = f.read()
    
    with open(backup_file, 'w') as f:
        f.write(original_content)
    print(f"Created backup: {backup_file}")
    
    # Replacement mappings
    replacements = {}
    
    # Example replacements (expand based on actual TBD locations)
    local_gas = data.get("local_gas", {})
    amoy_gas = data.get("amoy_gas", {})
    variance = data.get("variance", {})
    volatile = data.get("volatile_metrics", {})
    
    # Deployment costs
    replacements[r"mint property ~\[TBD\]K gas"] = f"mint property ~{format_gas(amoy_gas.get('property_mint', local_gas.get('property_mint', 0)))} gas"
    replacements[r"create agreement ~\[TBD\]K gas ERC-721"] = f"create agreement ~{format_gas(amoy_gas.get('erc721_agreement', local_gas.get('erc721_agreement', 0)))} gas ERC-721"
    replacements[r"create agreement ~\[TBD\]K gas ERC-1155"] = f"create agreement ~{format_gas(amoy_gas.get('erc1155_agreement', local_gas.get('erc1155_agreement', 0)))} gas ERC-1155"
    
    # Volatile market simulations
    for scenario_name, scenario_data in volatile.items():
        recovery = scenario_data.get("recovery_percentage", "TBD")
        status = scenario_data.get("system_status", "TBD")
        gas = scenario_data.get("gas_used", 0)
        
        # These would need to match specific table rows in the dissertation
        # This is a simplified example
    
    # Apply replacements
    modified_content = original_content
    for pattern, replacement in replacements.items():
        modified_content = re.sub(pattern, replacement, modified_content)
    
    # Write updated file
    with open(DISSERTATION_FILE, 'w') as f:
        f.write(modified_content)
    
    print(f"Updated {DISSERTATION_FILE} with benchmark data.")
    print(f"Backup saved to {backup_file}")

def main():
    """Main execution function."""
    print("=" * 60)
    print("Dissertation [TBD] Placeholder Filler")
    print("=" * 60)
    print()
    
    # Check prerequisites
    print("Checking for benchmark data files...")
    files_exist = {
        "Comprehensive Summary (Anvil)": COMPREHENSIVE_SUMMARY.exists(),
        "Amoy Transactions": AMOY_TRANSACTIONS.exists(),
        "Volatile Simulations Log": VOLATILE_SIMULATIONS_LOG.exists()
    }
    
    for file_name, exists in files_exist.items():
        status = "✓ Found" if exists else "✗ Missing"
        print(f"  {status}: {file_name}")
    
    if not any(files_exist.values()):
        print()
        print("Error: No benchmark data files found.")
        print()
        print("Please run the following commands first:")
        print("  1. Anvil benchmarks:")
        print("     cd Development_Environment/contracts")
        print("     mkdir -p benchmarks")
        print("     forge test --match-path 'test/benchmarks/**/*.sol' --gas-report -vv > benchmarks/comprehensive-summary.json")
        print()
        print("  2. Volatile market simulations:")
        print("     forge test --match-path 'test/simulations/**/*.sol' -vv > benchmarks/volatile-simulations.log")
        print()
        print("  3. Amoy deployment (manual - record transaction hashes and gas)")
        print()
        return 1
    
    print()
    print("Loading benchmark data...")
    data = load_benchmark_data()
    
    print()
    print("Replacing [TBD] markers in dissertation...")
    replace_tbds_in_dissertation(data)
    
    print()
    print("✓ Complete! Review the updated DissertationProgress.md file.")
    print()
    return 0

if __name__ == "__main__":
    exit(main())

