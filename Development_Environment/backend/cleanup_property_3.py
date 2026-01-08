#!/usr/bin/env python3
"""Clean up out-of-sync Property 3 from database."""

from database.db import SessionLocal
from database.models import Property

def main():
    db = SessionLocal()
    try:
        # Delete property 3
        prop = db.query(Property).filter(Property.id == 3).first()
        if prop:
            print(f"Deleting Property {prop.id}: blockchain_token_id={prop.blockchain_token_id}, standard={prop.token_standard}")
            db.delete(prop)
            db.commit()
            print("✅ Property 3 deleted successfully")
        else:
            print("⚠️ Property 3 not found in database")
        
        # Show remaining properties
        props = db.query(Property).order_by(Property.id).all()
        print(f"\n📊 Remaining Properties ({len(props)} total):")
        print("="*80)
        for p in props:
            print(f"ID: {p.id:2d} | Token ID: {p.blockchain_token_id:2d} | Standard: {p.token_standard:7s} | Owner: {p.owner_address}")
        print("="*80)
        
    finally:
        db.close()

if __name__ == "__main__":
    main()

