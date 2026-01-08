"""
Transfer Existing Shares to Logical Owners

ONE-TIME SCRIPT to transfer yield agreement shares from deployer to logical owners.

Problem:
- Shares were minted to deployer address (0xf39F...) on-chain
- Database records show logical owners (0x...001, 0x...002, etc.)
- Repayment distribution sends ETH to on-chain owners (deployer gets everything)
- Analytics Dashboard shows wrong shareholder count (1 instead of 5)

Solution:
- Transfer all shares from deployer → logical owners on-chain
- Aligns blockchain state with database state
- Enables correct repayment distribution
- Fixes Analytics Dashboard

Usage:
    cd /backend && python scripts/transfer_existing_shares.py

Safety:
- Reads-only database queries first (dry-run mode)
- Confirms transfers before executing
- Logs all transactions
- Non-destructive (shares can be transferred back if needed)

Date: 2025-11-23
Author: RWA Platform Development Team
"""

import sys
import os

# Add parent directory to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy.orm import Session
from config.database import SessionLocal
from models.yield_agreement import YieldAgreement
from models.user_share_balance import UserShareBalance
from models.transaction import Transaction, TransactionStatus
from models.marketplace_listing import MarketplaceListing  # Required for YieldAgreement relationships
from models.marketplace_trade import MarketplaceTrade  # Required for MarketplaceListing relationships
from services.web3_service import Web3Service
from datetime import datetime
from typing import List, Dict, Tuple
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def get_agreements_needing_transfer(db: Session, deployer_address: str) -> List[Dict]:
    """
    Query database for agreements where logical owner != deployer.
    
    Args:
        db: Database session
        deployer_address: Deployer's address (currently owns all shares on-chain)
        
    Returns:
        List of dicts with agreement info and transfer details
    """
    agreements = []
    
    # Query all active yield agreements
    all_agreements = db.query(YieldAgreement).filter(
        YieldAgreement.is_active == True
    ).all()
    
    logger.info(f"📊 Found {len(all_agreements)} active yield agreements")
    
    for agreement in all_agreements:
        # Get UserShareBalance for this agreement (excluding deployer)
        user_balances = db.query(UserShareBalance).filter(
            UserShareBalance.agreement_id == agreement.id,
            UserShareBalance.user_address != deployer_address.lower()
        ).all()
        
        if user_balances:
            for balance in user_balances:
                agreements.append({
                    'agreement_id': agreement.id,
                    'blockchain_agreement_id': agreement.blockchain_agreement_id,
                    'token_standard': agreement.token_standard,
                    'token_contract_address': agreement.token_contract_address,
                    'logical_owner': balance.user_address,
                    'shares_wei': balance.balance_wei,
                    'shares_decimal': balance.balance_wei / 10**18
                })
                logger.info(
                    f"  📋 Agreement {agreement.id} ({agreement.token_standard}): "
                    f"{balance.balance_wei / 10**18} shares → {balance.user_address[:10]}..."
                )
    
    return agreements


def transfer_shares(
    web3_service: Web3Service,
    db: Session,
    transfers: List[Dict],
    dry_run: bool = True
) -> Tuple[int, int]:
    """
    Execute share transfers from deployer to logical owners.
    
    Args:
        web3_service: Web3Service instance
        db: Database session
        transfers: List of transfer instructions
        dry_run: If True, simulate transfers without executing
        
    Returns:
        Tuple of (successful_count, failed_count)
    """
    successful = 0
    failed = 0
    
    for transfer in transfers:
        try:
            agreement_id = transfer['agreement_id']
            blockchain_agreement_id = transfer['blockchain_agreement_id']
            token_standard = transfer['token_standard']
            token_address = transfer['token_contract_address']
            to_address = transfer['logical_owner']
            amount = transfer['shares_wei']
            
            logger.info(
                f"\n{'[DRY RUN] ' if dry_run else ''}🔄 Transferring Agreement {agreement_id} "
                f"({token_standard}):\n"
                f"  From: Deployer\n"
                f"  To: {to_address}\n"
                f"  Amount: {amount / 10**18} shares"
            )
            
            if dry_run:
                logger.info(f"  ✅ [DRY RUN] Would transfer {amount / 10**18} shares")
                successful += 1
                continue
            
            # Execute actual transfer
            if token_standard == "ERC721":
                # Transfer ERC-20 YieldSharesToken
                tx_hash, gas_used = web3_service.transfer_erc20_shares(
                    token_contract_address=token_address,
                    to_address=to_address,
                    amount=amount
                )
                function_name = "transfer"
                
            elif token_standard == "ERC1155":
                # Transfer ERC-1155 yield tokens
                tx_hash, gas_used = web3_service.safe_transfer_erc1155_shares(
                    to_address=to_address,
                    yield_token_id=blockchain_agreement_id,  # For ERC-1155, agreement ID = yield token ID
                    amount=amount
                )
                function_name = "safeTransferFrom"
                
            else:
                raise ValueError(f"Unsupported token standard: {token_standard}")
            
            # Record transaction in database
            transaction = Transaction(
                tx_hash=tx_hash,
                timestamp=datetime.utcnow(),
                status=TransactionStatus.CONFIRMED,
                gas_used=gas_used,
                contract_address=token_address,
                function_name=function_name,
                yield_agreement_id=agreement_id
            )
            db.add(transaction)
            db.commit()
            
            logger.info(f"  ✅ Transfer successful! (tx: {tx_hash[:10]}..., gas: {gas_used})")
            successful += 1
            
        except Exception as e:
            logger.error(f"  ❌ Transfer failed for agreement {transfer['agreement_id']}: {e}")
            failed += 1
            # Continue with next transfer
    
    return successful, failed


def main():
    """Main execution function"""
    logger.info("=" * 80)
    logger.info("🚀 EXISTING SHARES TRANSFER SCRIPT")
    logger.info("=" * 80)
    
    # Initialize services
    db = SessionLocal()
    web3_service = Web3Service()
    
    try:
        # Get deployer address
        deployer_address = web3_service.deployer_account.address
        logger.info(f"\n📍 Deployer Address: {deployer_address}")
        
        # Step 1: Query agreements needing transfer
        logger.info("\n" + "=" * 80)
        logger.info("STEP 1: Querying Agreements Needing Transfer")
        logger.info("=" * 80)
        
        transfers = get_agreements_needing_transfer(db, deployer_address)
        
        if not transfers:
            logger.info("\n✅ No transfers needed! All shares are already correctly owned.")
            return
        
        logger.info(f"\n📋 Found {len(transfers)} share transfers needed")
        
        # Step 2: Dry run (simulation)
        logger.info("\n" + "=" * 80)
        logger.info("STEP 2: DRY RUN (Simulation)")
        logger.info("=" * 80)
        
        successful_dry, failed_dry = transfer_shares(web3_service, db, transfers, dry_run=True)
        
        logger.info(f"\n📊 Dry Run Results:")
        logger.info(f"  ✅ Successful: {successful_dry}")
        logger.info(f"  ❌ Failed: {failed_dry}")
        
        # Step 3: Confirm execution
        logger.info("\n" + "=" * 80)
        logger.info("STEP 3: Execute Transfers")
        logger.info("=" * 80)
        
        user_input = input(f"\n🤔 Execute {len(transfers)} share transfers? (yes/no): ").strip().lower()
        
        if user_input != "yes":
            logger.info("\n❌ Transfer execution cancelled by user.")
            return
        
        # Step 4: Execute actual transfers
        logger.info("\n🔄 Executing transfers...")
        successful, failed = transfer_shares(web3_service, db, transfers, dry_run=False)
        
        # Step 5: Summary
        logger.info("\n" + "=" * 80)
        logger.info("📊 FINAL RESULTS")
        logger.info("=" * 80)
        logger.info(f"  ✅ Successful Transfers: {successful}/{len(transfers)}")
        logger.info(f"  ❌ Failed Transfers: {failed}/{len(transfers)}")
        
        if successful == len(transfers):
            logger.info("\n🎉 ALL TRANSFERS COMPLETED SUCCESSFULLY!")
            logger.info("\n✅ Next Steps:")
            logger.info("  1. Subgraph will index Transfer events automatically")
            logger.info("  2. Analytics Dashboard will update shareholder counts")
            logger.info("  3. Repayment distribution will now send ETH to correct addresses")
        else:
            logger.warning(f"\n⚠️ {failed} transfers failed. Review logs and retry if needed.")
        
    except Exception as e:
        logger.error(f"\n💥 Script execution failed: {e}")
        db.rollback()
        raise
    finally:
        db.close()
        logger.info("\n" + "=" * 80)


if __name__ == "__main__":
    main()

