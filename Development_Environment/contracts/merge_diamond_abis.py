#!/usr/bin/env python3
"""
Merge Diamond Facet ABIs into Combined ABI Files
Combines multiple facet ABIs into single files for The Graph subgraph indexing
"""

import json
import sys
from pathlib import Path

def load_abi_from_file(file_path):
    """Load ABI array from a Foundry JSON output file"""
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
            return data.get('abi', [])
    except Exception as e:
        print(f"❌ Error loading {file_path}: {e}")
        return []

def get_item_signature(item):
    """Generate unique signature for ABI item to detect duplicates"""
    if item.get('type') == 'function':
        name = item.get('name', '')
        inputs = ','.join([inp.get('type', '') for inp in item.get('inputs', [])])
        return f"{item['type']}:{name}({inputs})"
    elif item.get('type') == 'event':
        name = item.get('name', '')
        inputs = ','.join([inp.get('type', '') for inp in item.get('inputs', [])])
        return f"{item['type']}:{name}({inputs})"
    elif item.get('type') == 'error':
        name = item.get('name', '')
        inputs = ','.join([inp.get('type', '') for inp in item.get('inputs', [])])
        return f"{item['type']}:{name}({inputs})"
    else:
        # constructor, fallback, receive
        return f"{item.get('type', 'unknown')}"

def merge_abis(abi_files, output_name):
    """Merge multiple ABIs, removing duplicates"""
    print(f"\n📦 Merging ABIs for: {output_name}")
    print(f"   Input facets: {len(abi_files)}")
    
    combined_abi = []
    seen_signatures = set()
    
    for file_path in abi_files:
        facet_name = file_path.stem
        abi = load_abi_from_file(file_path)
        
        if not abi:
            print(f"   ⚠️  {facet_name}: No ABI found")
            continue
        
        added_count = 0
        for item in abi:
            sig = get_item_signature(item)
            if sig not in seen_signatures:
                combined_abi.append(item)
                seen_signatures.add(sig)
                added_count += 1
        
        print(f"   ✅ {facet_name}: Added {added_count} unique items")
    
    print(f"   📊 Total combined items: {len(combined_abi)}")
    
    # Count by type
    type_counts = {}
    for item in combined_abi:
        item_type = item.get('type', 'unknown')
        type_counts[item_type] = type_counts.get(item_type, 0) + 1
    
    print(f"   Breakdown: {dict(type_counts)}")
    
    return combined_abi

def main():
    # Base path for contract outputs
    base_path = Path(__file__).parent / "out"
    
    if not base_path.exists():
        print(f"❌ Contract output directory not found: {base_path}")
        sys.exit(1)
    
    print("=" * 70)
    print("DIAMOND ABI MERGER")
    print("=" * 70)
    
    # ========================================================================
    # YieldBase Diamond - Merge all YieldBase facets
    # ========================================================================
    yieldbase_facets = [
        base_path / "YieldBaseFacet.sol" / "YieldBaseFacet.json",
        base_path / "RepaymentFacet.sol" / "RepaymentFacet.json",
        base_path / "DefaultManagementFacet.sol" / "DefaultManagementFacet.json",
        base_path / "GovernanceFacet.sol" / "GovernanceFacet.json",
        base_path / "ViewsFacet.sol" / "ViewsFacet.json",
    ]
    
    yieldbase_abi = merge_abis(yieldbase_facets, "DiamondYieldBase")
    
    # Save YieldBase combined ABI
    output_file = base_path / "DiamondYieldBase_ABI.json"
    with open(output_file, 'w') as f:
        json.dump({"abi": yieldbase_abi}, f, indent=2)
    print(f"   💾 Saved to: {output_file}")
    
    # ========================================================================
    # CombinedToken Diamond - Merge all CombinedToken facets
    # ========================================================================
    combined_token_facets = [
        base_path / "MintingFacet.sol" / "MintingFacet.json",
        base_path / "DistributionFacet.sol" / "DistributionFacet.json",
        base_path / "CombinedTokenCoreFacet.sol" / "CombinedTokenCoreFacet.json",
        base_path / "RestrictionsFacet.sol" / "RestrictionsFacet.json",
        base_path / "CombinedViewsFacet.sol" / "CombinedViewsFacet.json",
    ]
    
    combined_token_abi = merge_abis(combined_token_facets, "DiamondCombinedToken")
    
    # Save CombinedToken combined ABI
    output_file = base_path / "DiamondCombinedToken_ABI.json"
    with open(output_file, 'w') as f:
        json.dump({"abi": combined_token_abi}, f, indent=2)
    print(f"   💾 Saved to: {output_file}")
    
    print("\n" + "=" * 70)
    print("✅ ABI MERGE COMPLETE")
    print("=" * 70)
    print("\nCombined ABI files created:")
    print(f"  - DiamondYieldBase_ABI.json")
    print(f"  - DiamondCombinedToken_ABI.json")
    print("\nThese files can now be used in subgraph.yaml for event indexing.")

if __name__ == "__main__":
    main()

