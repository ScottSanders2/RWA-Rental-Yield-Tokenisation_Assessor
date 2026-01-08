#!/usr/bin/env python3
"""
Script to check specific yield agreements' total_token_supply values
"""
import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.append(str(Path(__file__).parent.parent))

from sqlalchemy import text
from config.database import engine

def main():
    """Check specific agreements"""
    
    with engine.connect() as conn:
        print("=" * 80)
        print("CHECKING AGREEMENTS #75, #69, #71, #78")
        print("=" * 80)
        
        result = conn.execute(text("""
            SELECT 
                id, 
                property_id, 
                upfront_capital_usd, 
                total_token_supply, 
                token_standard 
            FROM yield_agreements 
            WHERE id IN (75, 69, 71, 78)
            ORDER BY id
        """))
        
        rows = result.fetchall()
        
        print(f"\nFound {len(rows)} agreement(s):\n")
        for row in rows:
            agreement_id, property_id, upfront_capital, total_supply, token_standard = row
            print(f"Agreement #{agreement_id}:")
            print(f"  Property ID: {property_id}")
            print(f"  Upfront Capital: ${upfront_capital:,.2f} USD")
            print(f"  Total Token Supply: {total_supply:,}")
            print(f"  Token Standard: {token_standard}")
            
            if total_supply == 0:
                print(f"  ⚠️  WARNING: total_token_supply = 0")
            elif total_supply != int(upfront_capital):
                print(f"  ⚠️  MISMATCH: total_token_supply ({total_supply:,}) ≠ upfront_capital ({int(upfront_capital):,})")
            else:
                print(f"  ✅ MATCH: total_token_supply = upfront_capital")
            print()

if __name__ == "__main__":
    main()











