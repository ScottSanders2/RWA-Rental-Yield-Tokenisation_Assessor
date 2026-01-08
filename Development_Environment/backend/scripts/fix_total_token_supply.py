#!/usr/bin/env python3
"""
Script to fix total_token_supply = 0 issues in yield_agreements table
"""
import sys
import os
from pathlib import Path

# Add parent directory to path
sys.path.append(str(Path(__file__).parent.parent))

from sqlalchemy import text
from config.database import engine

def main():
    """Fix agreements with total_token_supply = 0"""
    
    with engine.connect() as conn:
        # First, check which agreements have this issue
        print("=" * 80)
        print("CHECKING AGREEMENTS WITH total_token_supply = 0")
        print("=" * 80)
        
        result = conn.execute(text("""
            SELECT 
                id, 
                property_id, 
                upfront_capital_usd, 
                total_token_supply, 
                token_standard 
            FROM yield_agreements 
            WHERE total_token_supply = 0 OR total_token_supply IS NULL
            ORDER BY id
        """))
        
        rows = result.fetchall()
        
        if not rows:
            print("✅ No agreements found with total_token_supply = 0")
            return
        
        print(f"\nFound {len(rows)} agreement(s) with total_token_supply = 0:\n")
        for row in rows:
            print(f"Agreement #{row[0]}: property={row[1]}, upfront_capital={row[2]}, total_supply={row[3]}, standard={row[4]}")
        
        print("\n" + "=" * 80)
        print("FIXING AGREEMENTS")
        print("=" * 80)
        
        # Fix each agreement: set total_token_supply = upfront_capital_usd
        for row in rows:
            agreement_id = row[0]
            upfront_capital = row[2]
            
            if upfront_capital and upfront_capital > 0:
                # Set total_token_supply = upfront_capital_usd
                conn.execute(text("""
                    UPDATE yield_agreements 
                    SET total_token_supply = :supply
                    WHERE id = :agreement_id
                """), {"supply": int(upfront_capital), "agreement_id": agreement_id})
                
                print(f"✅ Agreement #{agreement_id}: Set total_token_supply = {int(upfront_capital)}")
            else:
                print(f"⚠️  Agreement #{agreement_id}: Skipped (upfront_capital = {upfront_capital})")
        
        conn.commit()
        
        print("\n" + "=" * 80)
        print("VERIFICATION - Checking updated values")
        print("=" * 80)
        
        # Verify the updates
        result = conn.execute(text("""
            SELECT 
                id, 
                property_id, 
                upfront_capital_usd, 
                total_token_supply, 
                token_standard 
            FROM yield_agreements 
            WHERE id IN (
                SELECT id FROM yield_agreements 
                WHERE total_token_supply = 0 OR total_token_supply IS NULL
            )
            ORDER BY id
        """))
        
        remaining_rows = result.fetchall()
        
        if remaining_rows:
            print(f"\n⚠️  {len(remaining_rows)} agreement(s) still have total_token_supply = 0:\n")
            for row in remaining_rows:
                print(f"Agreement #{row[0]}: property={row[1]}, upfront_capital={row[2]}, total_supply={row[3]}, standard={row[4]}")
        else:
            print("\n✅ All agreements now have valid total_token_supply values!")
        
        print("\n" + "=" * 80)
        print("DONE")
        print("=" * 80)

if __name__ == "__main__":
    main()

