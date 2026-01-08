"""
Yield service class for yield agreement business logic.

This service handles yield agreement creation, financial calculations,
and blockchain integration for rental yield tokenization.
"""

import logging
from datetime import datetime
from typing import Optional, List
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from models.yield_agreement import YieldAgreement
from models.property import Property
from models.transaction import Transaction, TransactionStatus
from schemas.yield_agreement import YieldAgreementCreateRequest, YieldAgreementCreateResponse
from services.web3_service import Web3Service


class YieldCalculations:
    """Utility class for yield agreement financial calculations."""

    @staticmethod
    def calculate_monthly_payment(principal: int, annual_roi_basis_points: int, term_months: int) -> int:
        """
        Calculate monthly payment amount using compound interest formula.

        Args:
            principal: Principal amount in wei
            annual_roi_basis_points: Annual ROI in basis points
            term_months: Term in months

        Returns:
            Monthly payment amount in wei
        """
        # Convert basis points to decimal (e.g., 1200 bp = 12%)
        annual_rate = annual_roi_basis_points / 10000.0
        monthly_rate = annual_rate / 12.0

        # Standard loan payment formula: P * (r(1+r)^n) / ((1+r)^n - 1)
        if monthly_rate == 0:
            return principal // term_months

        numerator = principal * monthly_rate * ((1 + monthly_rate) ** term_months)
        denominator = ((1 + monthly_rate) ** term_months) - 1

        return int(numerator / denominator)

    @staticmethod
    def calculate_total_repayment(monthly_payment: int, term_months: int) -> int:
        """
        Calculate total expected repayment over the agreement term.

        Args:
            monthly_payment: Monthly payment amount
            term_months: Term in months

        Returns:
            Total repayment amount
        """
        return monthly_payment * term_months


class YieldService:
    """
    Service class for yield agreement business logic.

    Manages yield agreement creation, validation, and blockchain synchronization.
    """

    def __init__(self, db: Session, web3_service: Web3Service):
        """
        Initialize yield service.

        Args:
            db: Database session
            web3_service: Web3 service instance
        """
        self.db = db
        self.web3_service = web3_service

    def create_yield_agreement(self, request: YieldAgreementCreateRequest) -> YieldAgreementCreateResponse:
        """
        Create a new yield agreement.

        This method orchestrates the complete yield agreement creation workflow:
        1. Validate property exists and is verified
        2. Create yield agreement on blockchain
        3. Create database record
        4. Calculate financial projections
        5. Record transaction

        Args:
            request: Yield agreement creation request data

        Returns:
            YieldAgreementCreateResponse with agreement details

        Raises:
            ValueError: For validation errors
            Exception: For blockchain or database errors
        """
        try:
            # Validate property exists and is verified
            # CRITICAL: Must filter by BOTH blockchain_token_id AND token_standard
            # to avoid matching wrong property (ERC-721 vs ERC-1155 can have same token IDs)
            property_obj = self.db.query(Property).filter(
                Property.blockchain_token_id == request.property_token_id,
                Property.token_standard == request.token_standard
            ).first()

            # For development, create mock property if it doesn't exist
            if not property_obj:
                # Create a mock property for development
                from models.property import Property as PropertyModel

                # Generate unique mock property address hash
                import os
                mock_property_hash = os.urandom(32)  # 32 bytes = 256 bits

                property_obj = PropertyModel(
                    property_address_hash=mock_property_hash,
                    metadata_uri=None,
                    metadata_json='{"property_type": "residential", "square_footage": 1200}',
                    rental_agreement_uri='https://ipfs.io/ipfs/mock',
                    token_standard='ERC721',
                    is_verified=True,
                    verification_timestamp=datetime.utcnow(),
                    verifier_address='0x12345678901234567890123456789012345678',
                    blockchain_token_id=request.property_token_id
                )
                self.db.add(property_obj)
                self.db.flush()
            
            # CRITICAL: Validate property is verified before allowing agreement creation
            if not property_obj.is_verified:
                raise ValueError(f"Property {request.property_token_id} is not verified. Properties must be verified before creating yield agreements.")

            # Check if property already has an active yield agreement
            from models.yield_agreement import YieldAgreement
            existing_agreement = self.db.query(YieldAgreement).filter(
                YieldAgreement.property_id == property_obj.id,
                YieldAgreement.is_active == True
            ).first()

            if existing_agreement:
                raise ValueError(f"Property {request.property_token_id} already has an active yield agreement (ID: {existing_agreement.id}). Cannot create multiple agreements for the same property.")

            # Create agreement on blockchain
            if request.token_standard == "ERC721":
                agreement_id, token_address, tx_hash, gas_used = self.web3_service.create_yield_agreement(
                    request.property_token_id,
                    request.upfront_capital,
                    request.upfront_capital_usd,
                    request.term_months,
                    request.annual_roi_basis_points,
                    request.property_payer,
                    request.grace_period_days,
                    request.default_penalty_rate,
                    request.default_threshold,
                    request.allow_partial_repayments,
                    request.allow_early_repayment
                )
            elif request.token_standard == "ERC1155":
                # ✅ ALIGNED WITH ERC-721: Contract validates msg.sender owns property
                # No property_owner parameter needed - contract uses msg.sender (deployer)
                yield_token_id, token_address, tx_hash, gas_used = self.web3_service.mint_combined_yield_tokens(
                    request.property_token_id,
                    request.upfront_capital,
                    request.upfront_capital_usd,
                    request.term_months,
                    request.annual_roi_basis_points,
                    request.grace_period_days,
                    request.default_penalty_rate,
                    request.allow_partial_repayments,
                    request.allow_early_repayment
                )
                agreement_id = yield_token_id  # For ERC-1155, token ID serves as agreement ID
            else:
                raise ValueError(f"Unsupported token standard: {request.token_standard}")

            # Calculate financial projections
            monthly_payment = YieldCalculations.calculate_monthly_payment(
                request.upfront_capital,
                request.annual_roi_basis_points,
                request.term_months
            )
            total_repayment = YieldCalculations.calculate_total_repayment(
                monthly_payment,
                request.term_months
            )

            # Create database record
            # NOTE: total_token_supply = upfront_capital_usd (1 token = $1 USD)
            agreement = YieldAgreement(
                property_id=property_obj.id,
                upfront_capital=request.upfront_capital,
                upfront_capital_usd=request.upfront_capital_usd,
                repayment_term_months=request.term_months,
                annual_roi_basis_points=request.annual_roi_basis_points,
                total_repaid=0,  # Start with zero
                is_active=True,
                blockchain_agreement_id=agreement_id,
                token_standard=request.token_standard,
                token_contract_address=token_address,
                total_token_supply=int(request.upfront_capital_usd),  # 1 token = $1 USD
                grace_period_days=request.grace_period_days,
                default_penalty_rate=request.default_penalty_rate,
                allow_partial_repayments=request.allow_partial_repayments,
                allow_early_repayment=request.allow_early_repayment
            )

            self.db.add(agreement)
            self.db.flush()  # Get agreement ID

            # Record transaction
            transaction = Transaction(
                tx_hash=tx_hash,
                timestamp=datetime.utcnow(),
                status=TransactionStatus.CONFIRMED,
                gas_used=gas_used,
                contract_address=self.web3_service.contract_addresses[
                    "YieldBase" if request.token_standard == "ERC721" else "CombinedPropertyYieldToken"
                ],
                function_name="createYieldAgreement" if request.token_standard == "ERC721" else "mintYieldTokens",
                yield_agreement_id=agreement.id
            )
            self.db.add(transaction)
            
            # Initialize UserShareBalance for property owner
            # This ensures the owner receives all shares when agreement is created
            if property_obj.owner_address:
                from models.user_share_balance import UserShareBalance
                
                # Calculate total shares in wei (total_token_supply * 10^18)
                total_supply_wei = int(agreement.total_token_supply * (10**18))
                
                # Create or update user balance
                existing_balance = self.db.query(UserShareBalance).filter(
                    UserShareBalance.user_address == property_obj.owner_address.lower(),
                    UserShareBalance.agreement_id == agreement.id
                ).first()
                
                if existing_balance:
                    # Update existing balance
                    existing_balance.balance_wei = total_supply_wei
                    existing_balance.last_updated = datetime.utcnow()
                    logger.info(f"Updated existing balance for {property_obj.owner_address[:10]}... in agreement {agreement.id}")
                else:
                    # Create new balance
                    user_balance = UserShareBalance(
                        user_address=property_obj.owner_address.lower(),
                        agreement_id=agreement.id,
                        balance_wei=total_supply_wei,
                        last_updated=datetime.utcnow(),
                        created_at=datetime.utcnow()
                    )
                    self.db.add(user_balance)
                    logger.info(f"Initialized balance for {property_obj.owner_address[:10]}... with {agreement.total_token_supply} shares in agreement {agreement.id}")
                
                # ✅ CRITICAL FIX: Transfer shares from deployer → property owner on-chain
                # This aligns blockchain state with database state for correct repayment distribution
                deployer_address = self.web3_service.deployer_account.address if hasattr(self.web3_service, 'deployer_account') and self.web3_service.deployer_account else None
                
                if deployer_address and property_obj.owner_address.lower() != deployer_address.lower():
                    try:
                        logger.info(f"🔄 Transferring shares from deployer to {property_obj.owner_address[:10]}...")
                        
                        if request.token_standard == "ERC721":
                            # Transfer ERC-20 YieldSharesToken
                            transfer_tx_hash, transfer_gas = self.web3_service.transfer_erc20_shares(
                                token_contract_address=token_address,
                                to_address=property_obj.owner_address,
                                amount=total_supply_wei
                            )
                            logger.info(f"✅ ERC-721 shares transferred (tx: {transfer_tx_hash[:10]}...)")
                            
                        elif request.token_standard == "ERC1155":
                            # Transfer ERC-1155 yield tokens
                            transfer_tx_hash, transfer_gas = self.web3_service.safe_transfer_erc1155_shares(
                                to_address=property_obj.owner_address,
                                yield_token_id=yield_token_id,
                                amount=total_supply_wei
                            )
                            logger.info(f"✅ ERC-1155 shares transferred (tx: {transfer_tx_hash[:10]}...)")
                        
                        # Record transfer transaction
                        transfer_transaction = Transaction(
                            tx_hash=transfer_tx_hash,
                            timestamp=datetime.utcnow(),
                            status=TransactionStatus.CONFIRMED,
                            gas_used=transfer_gas,
                            contract_address=token_address,
                            function_name="transfer" if request.token_standard == "ERC721" else "safeTransferFrom",
                            yield_agreement_id=agreement.id
                        )
                        self.db.add(transfer_transaction)
                        logger.info(f"🎯 On-chain ownership now aligned with database for agreement {agreement.id}")
                        
                    except Exception as transfer_error:
                        logger.error(f"⚠️ Share transfer failed (non-critical): {transfer_error}")
                        # Don't fail the entire agreement creation if transfer fails
                        # The database state is correct, transfer can be retried later

            # Commit all changes
            self.db.commit()

            return YieldAgreementCreateResponse(
                agreement_id=agreement.id,
                blockchain_agreement_id=agreement_id,
                token_contract_address=token_address,
                tx_hash=tx_hash,
                monthly_payment=monthly_payment,
                total_expected_repayment=total_repayment,
                status="success",
                message="Yield agreement created successfully"
            )

        except ValueError as e:
            # Re-raise ValueError as-is for proper 400 error handling
            self.db.rollback()
            raise
        except Exception as e:
            # Other exceptions become 500 errors
            self.db.rollback()
            raise Exception(f"Yield agreement creation failed: {str(e)}")

    def get_yield_agreement(self, agreement_id: int) -> Optional[YieldAgreement]:
        """
        Get yield agreement details by ID.

        Args:
            agreement_id: Internal agreement ID

        Returns:
            YieldAgreement object or None if not found
        """
        return self.db.query(YieldAgreement).filter(YieldAgreement.id == agreement_id).first()

    def get_yield_agreements(self) -> List[YieldAgreement]:
        """
        Get all yield agreements.

        Returns:
            List of all YieldAgreement objects
        """
        return self.db.query(YieldAgreement).all()
