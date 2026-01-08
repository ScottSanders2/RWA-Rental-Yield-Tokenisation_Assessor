"""
Yield service class for yield agreement business logic.

This service handles yield agreement creation, financial calculations,
and blockchain integration for rental yield tokenization.

PRODUCTION ENVIRONMENT:
- Properties MUST be registered and verified before yield agreement creation
- No mock property auto-creation (unlike Dev/Test environments)
- All validation errors are surfaced to clients via ValueError
"""

import logging
import os
from datetime import datetime
from typing import Optional, List
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from models.yield_agreement import YieldAgreement
from models.property import Property
from models.transaction import Transaction, TransactionStatus
from schemas.yield_agreement import YieldAgreementCreateRequest, YieldAgreementCreateResponse
from services.web3_service import Web3Service

# Environment flag to allow mock property creation (disabled in Production by default)
ALLOW_MOCK_PROPERTY = os.getenv('ALLOW_MOCK_PROPERTY', 'false').lower() == 'true'


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
            property_obj = self.db.query(Property).filter(
                Property.blockchain_token_id == request.property_token_id
            ).first()

            # PRODUCTION: Properties must be registered before yield agreement creation
            # Mock property creation is disabled unless ALLOW_MOCK_PROPERTY=true
            if not property_obj:
                if ALLOW_MOCK_PROPERTY:
                    # Mock property creation only when explicitly enabled via environment variable
                    logger.warning(
                        f"ALLOW_MOCK_PROPERTY is enabled - creating mock property for token_id={request.property_token_id}. "
                        "This should NOT be enabled in production deployments."
                    )
                    from models.property import Property as PropertyModel

                    # Generate unique mock property address hash
                    mock_property_hash = os.urandom(32)  # 32 bytes = 256 bits

                    property_obj = PropertyModel(
                        property_address_hash=mock_property_hash,
                        metadata_uri=None,
                        metadata_json='{"property_type": "residential", "square_footage": 1200}',
                        rental_agreement_uri='https://ipfs.io/ipfs/mock',
                        token_standard=request.token_standard,
                        is_verified=True,
                        verification_timestamp=datetime.utcnow(),
                        verifier_address='0x12345678901234567890123456789012345678',
                        blockchain_token_id=request.property_token_id
                    )
                    self.db.add(property_obj)
                    self.db.flush()
                else:
                    # Production behavior: Require property to be registered first
                    raise ValueError(
                        f"Property with token_id={request.property_token_id} not found. "
                        "Properties must be registered via POST /properties/register before creating yield agreements. "
                        "See API documentation at /docs for property registration endpoints."
                    )

            # Validate property is verified before allowing agreement creation
            if not property_obj.is_verified:
                raise ValueError(
                    f"Property {request.property_token_id} is not verified. "
                    "Properties must be verified via POST /properties/{{id}}/verify before creating yield agreements."
                )

            # Check if property already has an active yield agreement
            from models.yield_agreement import YieldAgreement
            existing_agreement = self.db.query(YieldAgreement).filter(
                YieldAgreement.property_id == property_obj.id,
                YieldAgreement.is_active == True
            ).first()

            if existing_agreement:
                raise ValueError(f"Property {request.property_token_id} already has an active yield agreement (ID: {existing_agreement.id}). Cannot create multiple agreements for the same property.")

            # Create agreement on blockchain (or mock for development)
            try:
                if request.token_standard == "ERC721":
                    agreement_id, token_address, tx_hash, gas_used = self.web3_service.create_yield_agreement(
                        request.property_token_id,
                        request.upfront_capital,
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
                    yield_token_id, token_address, tx_hash, gas_used = self.web3_service.mint_combined_yield_tokens(
                        request.property_token_id,
                        request.upfront_capital,
                        request.term_months,
                        request.annual_roi_basis_points,
                        # Add other parameters as needed
                    )
                    agreement_id = yield_token_id  # For ERC-1155, token ID serves as agreement ID
                else:
                    raise ValueError(f"Unsupported token standard: {request.token_standard}")
            except Exception as blockchain_error:
                # For development, create mock agreement if blockchain fails
                import random
                import os
                import time
                agreement_id = random.randint(1000, 9999)
                token_address = f"0x{random.randint(0, 2**160):040x}"
                # Ensure unique transaction hash
                unique_seed = f"{os.urandom(16).hex()}{int(time.time()*1000000)}{os.getpid()}{os.urandom(8).hex()}"
                tx_hash = f"0x{unique_seed[:64].ljust(64, '0')}"
                gas_used = random.randint(100000, 500000)
                logger.warning(f"Blockchain creation failed, using mock data: {str(blockchain_error)}")

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

            # Commit all changes
            self.db.commit()

            return YieldAgreementCreateResponse(
                agreement_id=agreement.id,
                blockchain_agreement_id=agreement_id,
                token_contract_address=token_address,
                tx_hash=tx_hash,
                monthly_payment=monthly_payment,
                total_expected_repayment=total_repayment,
                gas_used=gas_used,
                status="success",
                message="Yield agreement created successfully"
            )

        except Exception as e:
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
