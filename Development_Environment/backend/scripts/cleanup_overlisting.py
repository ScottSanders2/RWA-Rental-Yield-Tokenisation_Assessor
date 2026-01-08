#!/usr/bin/env python3
"""
Script to identify and clean up over-listing issues.
Cancels listings where total listed shares exceed available balance.
"""

import sys
import os

# Add parent directory to path to import modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text, func
from config.database import engine, SessionLocal
from models.marketplace_listing import MarketplaceListing, ListingStatus
from models.yield_agreement import YieldAgreement
from models.user_share_balance import UserShareBalance

def find_overlisting_issues():
    """Find and report over-listing issues."""
    
    db = SessionLocal()
    
    try:
        print("🔍 Scanning for over-listing issues...\n")
        
        # Get all active listings grouped by seller and agreement
        active_listings = db.query(
            MarketplaceListing.seller_address,
            MarketplaceListing.agreement_id,
            func.sum(MarketplaceListing.shares_for_sale).label('total_listed_wei'),
            func.count(MarketplaceListing.id).label('listing_count')
        ).filter(
            MarketplaceListing.listing_status == ListingStatus.ACTIVE
        ).group_by(
            MarketplaceListing.seller_address,
            MarketplaceListing.agreement_id
        ).all()
        
        issues_found = []
        
        for listing_group in active_listings:
            seller = listing_group.seller_address
            agreement_id = listing_group.agreement_id
            total_listed_wei = listing_group.total_listed_wei
            listing_count = listing_group.listing_count
            
            # Get user's total balance
            balance = db.query(UserShareBalance).filter(
                UserShareBalance.user_address == seller,
                UserShareBalance.agreement_id == agreement_id
            ).first()
            
            total_balance_wei = int(balance.balance_wei) if balance else 0
            
            # Get agreement details
            agreement = db.query(YieldAgreement).filter(
                YieldAgreement.id == agreement_id
            ).first()
            
            # Check for over-listing
            if int(total_listed_wei) > total_balance_wei:
                over_amount_wei = int(total_listed_wei) - total_balance_wei
                over_amount_shares = float(over_amount_wei) / 10**18
                total_balance_shares = float(total_balance_wei) / 10**18
                total_listed_shares = float(total_listed_wei) / 10**18
                
                issues_found.append({
                    'seller': seller[:10] + '...',
                    'agreement_id': agreement_id,
                    'listing_count': listing_count,
                    'total_balance': total_balance_shares,
                    'total_listed': total_listed_shares,
                    'over_amount': over_amount_shares,
                    'percentage': (total_listed_shares / agreement.total_token_supply * 100) if agreement else 0
                })
                
                print(f"❌ OVER-LISTING DETECTED!")
                print(f"   Agreement #{agreement_id}")
                print(f"   Seller: {seller[:10]}...")
                print(f"   Number of active listings: {listing_count}")
                print(f"   Total balance: {total_balance_shares:,.2f} shares")
                print(f"   Total listed: {total_listed_shares:,.2f} shares")
                print(f"   Over-listed by: {over_amount_shares:,.2f} shares")
                print(f"   Percentage: {(total_listed_shares / agreement.total_token_supply * 100):.1f}% of total supply")
                print()
        
        if not issues_found:
            print("✅ No over-listing issues found!\n")
            return []
        
        print(f"\n📊 Summary: Found {len(issues_found)} over-listing issue(s)\n")
        return issues_found
        
    finally:
        db.close()


def cancel_specific_listings(listing_ids: list):
    """Cancel specific listings by ID."""
    
    db = SessionLocal()
    
    try:
        for listing_id in listing_ids:
            listing = db.query(MarketplaceListing).filter(
                MarketplaceListing.id == listing_id
            ).first()
            
            if listing:
                listing.listing_status = ListingStatus.CANCELLED
                print(f"✅ Cancelled listing #{listing_id}")
            else:
                print(f"⚠️  Listing #{listing_id} not found")
        
        db.commit()
        print(f"\n✅ Cancelled {len(listing_ids)} listing(s)")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    # Find issues
    issues = find_overlisting_issues()
    
    if issues:
        print("\n" + "="*60)
        print("RECOMMENDED ACTION:")
        print("="*60)
        print("\nCancel problematic listings using:")
        print("  python scripts/cleanup_overlisting.py --cancel LISTING_ID [LISTING_ID...]")
        print("\nFor Agreement #70, recommend cancelling:")
        print("  - Listing #10 (75,000 shares, 150% of total)")
        print("  - OR Listing #8 (50,000 shares, 100% of total)")
        print("\nKeep only one listing per seller per agreement.")
    else:
        print("✅ Database is clean - no action needed!")











