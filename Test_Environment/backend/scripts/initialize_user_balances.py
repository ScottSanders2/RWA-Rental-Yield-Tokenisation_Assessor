"""
Initialize User Share Balances

One-time script to populate user_share_balances table for existing yield agreements.

Logic:
1. For each yield agreement:
   - Find the property owner (from properties.owner_address)
   - Create UserShareBalance record with full total_token_supply
   - Handle existing marketplace trades (adjust balances based on trade history)

Usage:
    python scripts/initialize_user_balances.py

Note: This script is idempotent - can be run multiple times safely.
"""

import sys
import os

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.orm import Session
from config.database import SessionLocal, engine, Base
from models.user_share_balance import UserShareBalance
from models.yield_agreement import YieldAgreement
from models.property import Property
from models.marketplace_trade import MarketplaceTrade
from models.marketplace_listing import MarketplaceListing
from datetime import datetime


def initialize_balances(db: Session):
    """
    Initialize user share balances for all existing yield agreements.
    
    Args:
        db: SQLAlchemy database session
    """
    print("🚀 Starting user share balance initialization...")
    
    # Drop and recreate user_share_balances table to ensure correct schema
    print("📋 Dropping existing user_share_balances table if present...")
    try:
        from sqlalchemy import text
        with engine.connect() as conn:
            conn.execute(text("DROP TABLE IF EXISTS user_share_balances CASCADE;"))
            conn.commit()
        print("  ✅ Table dropped successfully")
    except Exception as e:
        print(f"  ⚠️  Could not drop table: {e}")
    
    # Create tables
    print("📋 Creating user_share_balances table with correct schema...")
    Base.metadata.create_all(bind=engine)
    
    # Get all yield agreements
    agreements = db.query(YieldAgreement).all()
    print(f"📊 Found {len(agreements)} yield agreements")
    
    initialized_count = 0
    updated_count = 0
    
    for agreement in agreements:
        print(f"\n🔍 Processing Agreement #{agreement.id}")
        
        # Get property owner
        property_obj = db.query(Property).filter(
            Property.id == agreement.property_id
        ).first()
        
        if not property_obj:
            print(f"  ⚠️  Property {agreement.property_id} not found, using default owner")
        
        # DEMO APPROACH: Assign ownership based on property_id
        # Property IDs 1-10 → Owner #1, Property IDs 11-20 → Owner #2, etc.
        # This simulates different property owners
        owner_index = ((agreement.property_id - 1) % 2) + 1  # Alternates between 1 and 2
        owner_address = f"0x{'0' * 40}{owner_index:02d}".lower()  # 0x00...0001 or 0x00...0002
        print(f"  👤 Assigned Owner: Property Owner #{owner_index} ({owner_address})")
        
        # Calculate initial owner balance (total supply in wei)
        total_supply_wei = int(agreement.total_token_supply * 10**18)
        print(f"  📊 Total supply: {agreement.total_token_supply} shares ({total_supply_wei} wei)")
        
        # Check if owner balance already exists
        owner_balance = db.query(UserShareBalance).filter(
            UserShareBalance.user_address == owner_address,
            UserShareBalance.agreement_id == agreement.id
        ).first()
        
        if not owner_balance:
            # Create new balance for owner
            owner_balance = UserShareBalance(
                user_address=owner_address,
                agreement_id=agreement.id,
                balance_wei=total_supply_wei,
                last_updated=datetime.utcnow()
            )
            db.add(owner_balance)
            print(f"  ✅ Created balance for owner: {agreement.total_token_supply} shares")
            initialized_count += 1
        else:
            print(f"  ℹ️  Owner balance already exists: {owner_balance.balance_wei / 10**18} shares")
        
        # Process marketplace trades to adjust balances
        trades = db.query(MarketplaceTrade).join(
            MarketplaceListing,
            MarketplaceTrade.listing_id == MarketplaceListing.id
        ).filter(
            MarketplaceListing.agreement_id == agreement.id
        ).all()
        
        if trades:
            print(f"  🔄 Processing {len(trades)} marketplace trades...")
            
            for trade in trades:
                # Get listing to find seller
                listing = db.query(MarketplaceListing).filter(
                    MarketplaceListing.id == trade.listing_id
                ).first()
                
                if not listing:
                    continue
                
                # Normalize addresses to 42 characters (0x + 40 hex digits)
                seller_address = listing.seller_address.lower()[:42].ljust(42, '0') if len(listing.seller_address) < 42 else listing.seller_address.lower()[:42]
                buyer_address = trade.buyer_address.lower()[:42].ljust(42, '0') if len(trade.buyer_address) < 42 else trade.buyer_address.lower()[:42]
                shares_traded = int(trade.shares_purchased)
                
                print(f"    💱 Trade: {shares_traded / 10**18} shares from {seller_address[:10]}... to {buyer_address[:10]}...")
                
                # Get or create seller balance
                seller_balance = db.query(UserShareBalance).filter(
                    UserShareBalance.user_address == seller_address,
                    UserShareBalance.agreement_id == agreement.id
                ).first()
                
                if seller_balance:
                    # Deduct from seller (if not already deducted)
                    if seller_balance.balance_wei >= shares_traded:
                        seller_balance.balance_wei -= shares_traded
                        seller_balance.last_updated = datetime.utcnow()
                        print(f"      ⬇️  Seller balance: {seller_balance.balance_wei / 10**18} shares")
                        updated_count += 1
                
                # Get or create buyer balance
                buyer_balance = db.query(UserShareBalance).filter(
                    UserShareBalance.user_address == buyer_address,
                    UserShareBalance.agreement_id == agreement.id
                ).first()
                
                if not buyer_balance:
                    buyer_balance = UserShareBalance(
                        user_address=buyer_address,
                        agreement_id=agreement.id,
                        balance_wei=shares_traded,
                        last_updated=datetime.utcnow()
                    )
                    db.add(buyer_balance)
                    print(f"      ✅ Created buyer balance: {shares_traded / 10**18} shares")
                    initialized_count += 1
                else:
                    # Add to buyer (if not already added)
                    buyer_balance.balance_wei += shares_traded
                    buyer_balance.last_updated = datetime.utcnow()
                    print(f"      ⬆️  Buyer balance: {buyer_balance.balance_wei / 10**18} shares")
                    updated_count += 1
    
    # Commit all changes
    try:
        db.commit()
        print(f"\n✅ Initialization complete!")
        print(f"   📊 Created: {initialized_count} new balances")
        print(f"   🔄 Updated: {updated_count} existing balances")
    except Exception as e:
        db.rollback()
        print(f"\n❌ Error committing changes: {e}")
        raise


def main():
    """Main entry point."""
    print("\n" + "="*60)
    print("User Share Balance Initialization Script")
    print("="*60 + "\n")
    
    db = SessionLocal()
    try:
        initialize_balances(db)
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()
    
    print("\n" + "="*60)
    print("Script completed")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()

