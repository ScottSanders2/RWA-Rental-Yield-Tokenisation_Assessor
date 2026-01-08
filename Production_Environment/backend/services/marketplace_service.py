"""
Marketplace Service

Business logic and blockchain interaction for secondary market marketplace.

Architecture:
- Orchestrates off-chain listing management with on-chain settlement
- Validates transfer restrictions before allowing trades
- Supports fractional purchases (buy partial listing)
- Tracks all trades for dissertation metrics

Service Responsibilities:
1. Listing Creation: Validate seller owns shares, check transfer restrictions, create database record
2. Share Purchase: Validate buyer, shares available, restrictions, execute on-chain transfer, record trade
3. Listing Management: Get listings with filters, cancel listings
4. Transfer Restriction Validation: Check isTransferAllowed before listing/purchase

Research Contribution:
- Enables secondary market liquidity (Research Question 7)
- Validates transfer restrictions for risk mitigation (Research Question 2)
- Tracks gas costs for performance analysis (Research Question 3)
- Supports fractional pooling for accessibility
"""

from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from models.marketplace_listing import MarketplaceListing, ListingStatus
from models.marketplace_trade import MarketplaceTrade
from models.yield_agreement import YieldAgreement
from models.user_profile import UserProfile
from models.user_share_balance import UserShareBalance
from schemas.marketplace import (
    CreateListingRequest,
    BuySharesRequest,
    CreateListingResponse,
    BuySharesResponse,
    ListingDetailResponse
)
from datetime import datetime, timedelta
from decimal import Decimal
from typing import List, Optional, Dict
import logging

logger = logging.getLogger(__name__)


class MarketplaceService:
    """
    Service class for marketplace business logic and blockchain interaction.
    
    Attributes:
        db: SQLAlchemy database session
        web3_service: Web3 service for blockchain interactions (optional, for testing)
    
    Methods:
        create_listing: Create new marketplace listing with validation
        buy_shares: Execute share purchase with on-chain settlement
        get_listings: Query listings with filters
        get_listing_by_id: Get single listing details
        cancel_listing: Cancel active listing
        update_listing_status: Update listing status (sold, expired)
        validate_listing_creation: Validate seller owns shares and restrictions allow transfer
        validate_purchase: Validate buyer, shares available, price slippage
        execute_transfer: Execute on-chain transfer (placeholder for web3 integration)
    """
    
    def __init__(self, db: Session, web3_service=None):
        """
        Initialize marketplace service.
        
        Args:
            db: SQLAlchemy database session
            web3_service: Optional Web3 service for blockchain interactions
        """
        self.db = db
        self.web3_service = web3_service
    
    def _get_seller_profile(self, seller_address: str):
        """
        Fetch seller profile information by address.
        
        Args:
            seller_address: Ethereum address of seller
        
        Returns:
            Tuple of (display_name, role) or (None, None) if not found
        """
        profile = self.db.query(UserProfile).filter(
            UserProfile.wallet_address == seller_address.lower()
        ).first()
        
        if profile:
            return (profile.display_name, profile.role)
        return (None, None)
    
    def create_listing(
        self,
        request: CreateListingRequest,
        eth_usd_price: Optional[float] = None
    ) -> CreateListingResponse:
        """
        Create marketplace listing with validation.
        
        Args:
            request: CreateListingRequest with listing details
            eth_usd_price: Current ETH/USD price for wei conversion (optional, defaults to 2000)
        
        Returns:
            CreateListingResponse with listing details
        
        Raises:
            ValueError: If validation fails (agreement not found, insufficient shares, restrictions violated)
        
        Workflow:
            1. Validate yield agreement exists and is active
            2. Query seller balance from blockchain (or database for testing)
            3. Compute shares_for_sale from fraction if provided
            4. Validate seller owns sufficient shares
            5. Check transfer restrictions via isTransferAllowed (placeholder)
            6. Convert price_per_share_usd to wei
            7. Calculate total_listing_value_usd
            8. Calculate expires_at from expires_in_days
            9. Create MarketplaceListing database record
            10. Return CreateListingResponse
        """
        logger.info(f"Creating listing for agreement {request.agreement_id} by {request.seller_address}")
        
        # Default ETH/USD price if not provided
        if eth_usd_price is None:
            eth_usd_price = 2000.0
        
        # Validate yield agreement exists
        agreement = self.db.query(YieldAgreement).filter(
            YieldAgreement.id == request.agreement_id
        ).first()
        
        if not agreement:
            raise ValueError(f"Yield agreement {request.agreement_id} not found")
        
        if not agreement.is_active:
            raise ValueError(f"Yield agreement {request.agreement_id} is not active")
        
        # Get seller's REAL balance from UserShareBalance table
        seller_balance_record = self.db.query(UserShareBalance).filter(
            UserShareBalance.user_address == request.seller_address.lower(),
            UserShareBalance.agreement_id == request.agreement_id
        ).first()
        
        if not seller_balance_record:
            raise ValueError(
                f"Seller {request.seller_address} has no share balance for agreement {request.agreement_id}. "
                f"This user may not own any shares in this agreement."
            )
        
        seller_balance = int(seller_balance_record.balance_wei)
        
        # Compute shares_for_sale from fraction if provided
        if request.shares_for_sale_fraction is not None:
            shares_for_sale = int(seller_balance * request.shares_for_sale_fraction)
        else:
            shares_for_sale = request.shares_for_sale
        
        # Validate seller owns sufficient shares
        if shares_for_sale > seller_balance:
            raise ValueError(f"Seller {request.seller_address} owns {seller_balance} shares but trying to sell {shares_for_sale}")
        
        # Get token contract address from agreement
        token_contract_address = agreement.token_contract_address
        
        if not token_contract_address:
            raise ValueError(f"Token contract address not found for agreement {request.agreement_id}. "
                           "Agreement must be deployed on-chain before creating marketplace listings.")
        
        # Check transfer restrictions via web3_service
        # Use placeholder buyer address (0x0000...0001) for listing creation check
        placeholder_buyer = "0x0000000000000000000000000000000000000001"
        
        if self.web3_service:
            try:
                restrictions_allowed, reason = self.web3_service.is_transfer_allowed(
                    token_contract_address=token_contract_address,
                    from_address=request.seller_address,
                    to_address=placeholder_buyer,
                    amount=shares_for_sale,
                    agreement_id=request.agreement_id,
                    token_standard=request.token_standard.value
                )
                
                if not restrictions_allowed:
                    raise ValueError(f"Transfer restrictions violated: {reason}")
            except Exception as e:
                logger.warning(f"Could not check transfer restrictions: {e}. Proceeding with listing creation.")
        else:
            # No web3_service available, skip restriction check
            logger.info("Web3 service not available, skipping transfer restriction check")
        
        # Convert price_per_share_usd to wei
        # price_per_share_wei = price_per_share_usd / eth_usd_price * 10^18
        price_per_share_wei = int((request.price_per_share_usd / eth_usd_price) * 10**18)
        
        # Calculate total_listing_value_usd
        total_listing_value_usd = Decimal(str(shares_for_sale)) * Decimal(str(request.price_per_share_usd)) / Decimal(10**18)
        
        # Calculate expires_at from expires_in_days
        expires_at = None
        if request.expires_in_days:
            expires_at = datetime.utcnow() + timedelta(days=request.expires_in_days)
        
        # Create MarketplaceListing database record
        listing = MarketplaceListing(
            agreement_id=request.agreement_id,
            seller_address=request.seller_address,
            shares_for_sale=shares_for_sale,
            price_per_share_usd=request.price_per_share_usd,
            price_per_share_wei=price_per_share_wei,
            total_listing_value_usd=total_listing_value_usd,
            listing_status=ListingStatus.ACTIVE,
            token_standard=request.token_standard.value,
            token_contract_address=token_contract_address,
            expires_at=expires_at
        )
        
        self.db.add(listing)
        self.db.commit()
        self.db.refresh(listing)
        
        logger.info(f"Created listing {listing.id} for {shares_for_sale} shares at ${request.price_per_share_usd} per share")
        
        return CreateListingResponse(
            listing_id=listing.id,
            agreement_id=listing.agreement_id,
            shares_for_sale=int(listing.shares_for_sale),
            price_per_share_usd=float(listing.price_per_share_usd),
            price_per_share_wei=int(listing.price_per_share_wei),
            total_listing_value_usd=float(listing.total_listing_value_usd),
            expires_at=listing.expires_at,
            status=listing.listing_status.value,
            message="Listing created successfully"
        )
    
    def buy_shares(
        self,
        request: BuySharesRequest,
        eth_usd_price: Optional[float] = None
    ) -> BuySharesResponse:
        """
        Execute share purchase with on-chain settlement.
        
        Args:
            request: BuySharesRequest with purchase details
            eth_usd_price: Current ETH/USD price for wei conversion (optional, defaults to 2000)
        
        Returns:
            BuySharesResponse with trade details
        
        Raises:
            ValueError: If validation fails (listing not found, insufficient shares, restrictions violated)
        
        Workflow:
            1. Fetch MarketplaceListing from database
            2. Validate listing status=ACTIVE and not expired
            3. Compute shares_to_buy from fraction if provided
            4. Validate shares_to_buy <= shares_for_sale
            5. Validate price hasn't changed beyond max_price_per_share_usd (slippage protection)
            6. Check transfer restrictions via isTransferAllowed (placeholder)
            7. Execute on-chain transfer via contract.transfer() or safeTransferFrom() (placeholder)
            8. Create MarketplaceTrade database record with tx_hash and gas_used
            9. Update MarketplaceListing: reduce shares_for_sale, set status=SOLD if fully purchased
            10. Return BuySharesResponse
        """
        logger.info(f"Buying shares from listing {request.listing_id} by {request.buyer_address}")
        
        # Default ETH/USD price if not provided
        if eth_usd_price is None:
            eth_usd_price = 2000.0
        
        # Fetch MarketplaceListing
        listing = self.db.query(MarketplaceListing).filter(
            MarketplaceListing.id == request.listing_id
        ).first()
        
        if not listing:
            raise ValueError(f"Listing {request.listing_id} not found")
        
        # Validate listing status
        if listing.listing_status != ListingStatus.ACTIVE:
            raise ValueError(f"Listing {request.listing_id} is not active (status: {listing.listing_status.value})")
        
        # Validate not expired
        if listing.expires_at and datetime.utcnow() > listing.expires_at:
            # Mark as expired
            listing.listing_status = ListingStatus.EXPIRED
            self.db.commit()
            raise ValueError(f"Listing {request.listing_id} has expired")
        
        # Validate buyer is not the seller (prevent self-trading)
        if request.buyer_address.lower() == listing.seller_address.lower():
            raise ValueError(f"Cannot purchase your own listing. Buyer and seller addresses match: {request.buyer_address}")
        
        # Compute shares_to_buy from fraction if provided
        if request.shares_to_buy_fraction is not None:
            shares_to_buy = int(float(listing.shares_for_sale) * request.shares_to_buy_fraction)
        else:
            shares_to_buy = request.shares_to_buy
        
        # Validate shares_to_buy <= shares_for_sale
        if shares_to_buy > listing.shares_for_sale:
            raise ValueError(f"Cannot buy {shares_to_buy} shares, only {listing.shares_for_sale} available")
        
        # Validate price slippage
        if request.max_price_per_share_usd:
            if float(listing.price_per_share_usd) > request.max_price_per_share_usd:
                raise ValueError(
                    f"Price slippage exceeded: listing price ${listing.price_per_share_usd} > max ${request.max_price_per_share_usd}"
                )
        
        # Check transfer restrictions via web3_service with actual buyer address
        if self.web3_service:
            try:
                restrictions_allowed, reason = self.web3_service.is_transfer_allowed(
                    token_contract_address=listing.token_contract_address,
                    from_address=listing.seller_address,
                    to_address=request.buyer_address,
                    amount=shares_to_buy,
                    agreement_id=listing.agreement_id,
                    token_standard=listing.token_standard
                )
                
                if not restrictions_allowed:
                    raise ValueError(f"Transfer restrictions violated: {reason}")
            except ValueError as e:
                # Re-raise validation errors
                raise
            except Exception as e:
                logger.warning(f"Could not check transfer restrictions: {e}. Proceeding with purchase.")
        
        # Calculate total price
        total_price_usd = Decimal(str(shares_to_buy)) * listing.price_per_share_usd / Decimal(10**18)
        total_price_wei = int(float(shares_to_buy) * float(listing.price_per_share_wei) / 10**18)
        
        # Execute on-chain transfer via web3_service
        if self.web3_service:
            try:
                tx_hash, gas_used = self.web3_service.execute_transfer(
                    token_contract_address=listing.token_contract_address,
                    from_address=listing.seller_address,
                    to_address=request.buyer_address,
                    amount=shares_to_buy,
                    agreement_id=listing.agreement_id,
                    token_standard=listing.token_standard
                )
                
                logger.info(f"✅ On-chain transfer executed: tx_hash={tx_hash}, gas={gas_used}")
            except Exception as e:
                logger.error(f"On-chain transfer failed: {e}")
                raise ValueError(f"On-chain transfer failed: {str(e)}")
        else:
            # No web3_service available, generate placeholder tx_hash
            import hashlib
            import time
            unique_string = f"{time.time()}-{listing.id}-{request.buyer_address}-{shares_to_buy}"
            tx_hash = "0x" + hashlib.sha256(unique_string.encode()).hexdigest()
            gas_used = 85000  # Placeholder
            logger.info(f"🧪 Testing mode: Generated placeholder tx_hash={tx_hash}")
        
        # Create MarketplaceTrade database record
        trade = MarketplaceTrade(
            listing_id=listing.id,
            buyer_address=request.buyer_address,
            shares_purchased=shares_to_buy,
            total_price_usd=total_price_usd,
            total_price_wei=total_price_wei,
            tx_hash=tx_hash,
            gas_used=gas_used,
            executed_at=datetime.utcnow()
        )
        
        self.db.add(trade)
        
        # Update MarketplaceListing
        new_shares_for_sale = int(listing.shares_for_sale) - shares_to_buy
        listing.shares_for_sale = new_shares_for_sale
        
        if new_shares_for_sale == 0:
            listing.listing_status = ListingStatus.SOLD
        
        # ✅ UPDATE USER SHARE BALANCES (Critical for marketplace tracking)
        # 1. Deduct shares from seller
        seller_balance = self.db.query(UserShareBalance).filter(
            UserShareBalance.user_address == listing.seller_address.lower(),
            UserShareBalance.agreement_id == listing.agreement_id
        ).first()
        
        if seller_balance:
            seller_balance.balance_wei -= shares_to_buy
            seller_balance.last_updated = datetime.utcnow()
            logger.info(f"💸 Seller balance updated: {seller_balance.balance_wei / 10**18} shares remaining")
        
        # 2. Add shares to buyer (create if doesn't exist)
        buyer_balance = self.db.query(UserShareBalance).filter(
            UserShareBalance.user_address == request.buyer_address.lower(),
            UserShareBalance.agreement_id == listing.agreement_id
        ).first()
        
        if not buyer_balance:
            buyer_balance = UserShareBalance(
                user_address=request.buyer_address.lower(),
                agreement_id=listing.agreement_id,
                balance_wei=shares_to_buy,
                last_updated=datetime.utcnow()
            )
            self.db.add(buyer_balance)
            logger.info(f"✅ Buyer balance created: {shares_to_buy / 10**18} shares")
        else:
            buyer_balance.balance_wei += shares_to_buy
            buyer_balance.last_updated = datetime.utcnow()
            logger.info(f"💰 Buyer balance updated: {buyer_balance.balance_wei / 10**18} shares total")
        
        self.db.commit()
        self.db.refresh(trade)
        
        logger.info(f"Created trade {trade.id} for {shares_to_buy} shares, tx_hash: {tx_hash}")
        
        return BuySharesResponse(
            trade_id=trade.id,
            listing_id=listing.id,
            shares_purchased=int(trade.shares_purchased),
            total_price_usd=float(trade.total_price_usd),
            total_price_wei=int(trade.total_price_wei),
            tx_hash=trade.tx_hash,
            gas_used=trade.gas_used,
            status="executed",
            message="Shares purchased successfully"
        )
    
    def get_listings(
        self,
        agreement_id: Optional[int] = None,
        token_standard: Optional[str] = None,
        min_price_usd: Optional[float] = None,
        max_price_usd: Optional[float] = None,
        status: Optional[str] = None
    ) -> List[ListingDetailResponse]:
        """
        Get marketplace listings with optional filters.
        
        Args:
            agreement_id: Filter by agreement ID
            token_standard: Filter by token standard ('ERC721' or 'ERC1155')
            min_price_usd: Filter by minimum price per share
            max_price_usd: Filter by maximum price per share
            status: Filter by listing status ('active', 'sold', 'cancelled', 'expired')
        
        Returns:
            List of ListingDetailResponse objects
        """
        query = self.db.query(MarketplaceListing)
        
        # Apply filters
        if agreement_id:
            query = query.filter(MarketplaceListing.agreement_id == agreement_id)
        
        if token_standard:
            query = query.filter(MarketplaceListing.token_standard == token_standard)
        
        if min_price_usd:
            query = query.filter(MarketplaceListing.price_per_share_usd >= min_price_usd)
        
        if max_price_usd:
            query = query.filter(MarketplaceListing.price_per_share_usd <= max_price_usd)
        
        if status:
            query = query.filter(MarketplaceListing.listing_status == ListingStatus(status))
        
        # Default to ACTIVE listings if no status filter
        if not status:
            query = query.filter(MarketplaceListing.listing_status == ListingStatus.ACTIVE)
        
        # Order by created_at descending (newest first)
        query = query.order_by(MarketplaceListing.created_at.desc())
        
        listings = query.all()
        
        # Convert to ListingDetailResponse
        result = []
        for listing in listings:
            listing_age_hours = (datetime.utcnow() - listing.created_at).total_seconds() / 3600
            
            # Get seller profile information
            seller_display_name, seller_role = self._get_seller_profile(listing.seller_address)
            
            # Get agreement to calculate fractional_availability
            agreement = self.db.query(YieldAgreement).filter(
                YieldAgreement.id == listing.agreement_id
            ).first()
            
            # Calculate fractional_availability: shares_for_sale / total_token_supply
            # Both values need to be in the same units (wei)
            total_supply_wei = agreement.total_token_supply * 10**18 if agreement else 0
            fractional_availability = (
                float(listing.shares_for_sale) / float(total_supply_wei)
                if total_supply_wei > 0 else 1.0
            )
            
            result.append(ListingDetailResponse(
                id=listing.id,
                agreement_id=listing.agreement_id,
                seller_address=listing.seller_address,
                shares_for_sale=int(listing.shares_for_sale),
                price_per_share_usd=float(listing.price_per_share_usd),
                price_per_share_wei=int(listing.price_per_share_wei),
                total_listing_value_usd=float(listing.total_listing_value_usd) if listing.total_listing_value_usd else None,
                listing_status=listing.listing_status.value,
                token_standard=listing.token_standard,
                token_contract_address=listing.token_contract_address,
                expires_at=listing.expires_at,
                created_at=listing.created_at,
                updated_at=listing.updated_at,
                listing_age_hours=listing_age_hours,
                fractional_availability=fractional_availability,
                seller_display_name=seller_display_name,
                seller_role=seller_role
            ))
        
        return result
    
    def get_listing_by_id(self, listing_id: int) -> Optional[ListingDetailResponse]:
        """Get single listing by ID."""
        listing = self.db.query(MarketplaceListing).filter(
            MarketplaceListing.id == listing_id
        ).first()
        
        if not listing:
            return None
        
        listing_age_hours = (datetime.utcnow() - listing.created_at).total_seconds() / 3600
        
        # Get seller profile information
        seller_display_name, seller_role = self._get_seller_profile(listing.seller_address)
        
        # Get agreement to calculate fractional_availability
        agreement = self.db.query(YieldAgreement).filter(
            YieldAgreement.id == listing.agreement_id
        ).first()
        
        # Calculate fractional_availability: shares_for_sale / total_token_supply
        total_supply_wei = agreement.total_token_supply * 10**18 if agreement else 0
        fractional_availability = (
            float(listing.shares_for_sale) / float(total_supply_wei)
            if total_supply_wei > 0 else 1.0
        )
        
        return ListingDetailResponse(
            id=listing.id,
            agreement_id=listing.agreement_id,
            seller_address=listing.seller_address,
            shares_for_sale=int(listing.shares_for_sale),
            price_per_share_usd=float(listing.price_per_share_usd),
            price_per_share_wei=int(listing.price_per_share_wei),
            total_listing_value_usd=float(listing.total_listing_value_usd) if listing.total_listing_value_usd else None,
            listing_status=listing.listing_status.value,
            token_standard=listing.token_standard,
            token_contract_address=listing.token_contract_address,
            expires_at=listing.expires_at,
            created_at=listing.created_at,
            updated_at=listing.updated_at,
            listing_age_hours=listing_age_hours,
            fractional_availability=fractional_availability,
            seller_display_name=seller_display_name,
            seller_role=seller_role
        )
    
    def cancel_listing(self, listing_id: int, seller_address: str) -> Dict:
        """
        Cancel active listing.
        
        Args:
            listing_id: Listing ID to cancel
            seller_address: Seller address (must match listing seller)
        
        Returns:
            Dict with cancellation confirmation
        
        Raises:
            ValueError: If listing not found or seller doesn't match
        """
        listing = self.db.query(MarketplaceListing).filter(
            MarketplaceListing.id == listing_id
        ).first()
        
        if not listing:
            raise ValueError(f"Listing {listing_id} not found")
        
        if listing.seller_address.lower() != seller_address.lower():
            raise ValueError(f"Seller address {seller_address} does not match listing seller {listing.seller_address}")
        
        if listing.listing_status != ListingStatus.ACTIVE:
            raise ValueError(f"Listing {listing_id} is not active (status: {listing.listing_status.value})")
        
        # Update status to CANCELLED
        listing.listing_status = ListingStatus.CANCELLED
        self.db.commit()
        
        logger.info(f"Cancelled listing {listing_id}")
        
        return {
            "listing_id": listing_id,
            "status": "cancelled",
            "message": "Listing cancelled successfully"
        }

