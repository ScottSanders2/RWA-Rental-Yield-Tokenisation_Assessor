#!/usr/bin/env python3
"""
Script to fix total_token_supply for existing yield agreements.
Sets total_token_supply = upfront_capital_usd for all agreements.
"""

import sys
import os

# Add parent directory to path to import modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from config.database import engine

def fix_token_supply():
    """Update total_token_supply to match upfront_capital_usd for all agreements."""
    
    with engine.connect() as conn:
        # Update all agreements
        result = conn.execute(text("""
            UPDATE yield_agreements 
            SET total_token_supply = CAST(upfront_capital_usd AS INTEGER)
            WHERE total_token_supply != CAST(upfront_capital_usd AS INTEGER);
        """))
        
        conn.commit()
        
        print(f"✅ Updated {result.rowcount} yield agreements")
        
        # Display updated agreements
        result = conn.execute(text("""
            SELECT id, upfront_capital_usd, total_token_supply 
            FROM yield_agreements 
            ORDER BY id;
        """))
        
        print("\n📊 Current Agreement Token Supplies:")
        print("ID | Upfront Capital | Total Token Supply")
        print("-" * 50)
        for row in result:
            match = "✅" if row[1] == row[2] else "❌"
            print(f"{row[0]:2d} | ${row[1]:14,.2f} | {row[2]:18,} {match}")

if __name__ == "__main__":
    try:
        fix_token_supply()
        print("\n✅ Script completed successfully")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)











