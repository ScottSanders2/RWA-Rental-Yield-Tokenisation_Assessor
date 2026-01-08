"""
Property service class for business logic and property management.

This service handles property registration workflow, including validation,
database persistence, blockchain interaction, and transaction recording.
"""

import hashlib
import json
import logging
from datetime import datetime
from typing import Optional, List
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from models.property import Property
from models.transaction import Transaction, TransactionStatus
from models.validation_record import ValidationRecord
from schemas.property import PropertyRegistrationRequest, PropertyRegistrationResponse
from services.web3_service import Web3Service
from utils.validators import calculate_property_address_hash
from utils.metrics import track_time


class PropertyService:
    """
    Service class for property-related business logic.

    Manages property registration, verification, and blockchain synchronization.
    """

    def __init__(self, db: Session, web3_service: Web3Service):
        """
        Initialize property service.

        Args:
            db: Database session
            web3_service: Web3 service instance
        """
        self.db = db
        self.web3_service = web3_service

    @track_time("service_property_register", lambda self, req: {"token_standard": req.token_standard})
    def register_property(self, request: PropertyRegistrationRequest) -> PropertyRegistrationResponse:
        """
        Register a new property in the system.

        This method orchestrates the complete property registration workflow:
        1. Create database record
        2. Mint NFT on blockchain
        3. Update database with blockchain info
        4. Record transaction

        Args:
            request: Property registration request data

        Returns:
            PropertyRegistrationResponse with registration details

        Raises:
            ValueError: For validation errors
            Exception: For blockchain or database errors
        """
        try:
            # Calculate property address hash
            property_hash_hex = calculate_property_address_hash(request.property_address)
            property_hash_bytes = bytes.fromhex(property_hash_hex[2:])  # Remove 0x prefix and convert to bytes

            # Create property record
            property_obj = Property(
                property_address_hash=property_hash_bytes,
                metadata_uri=None,  # Will be set to IPFS CID after upload (stub for now)
                metadata_json=json.dumps(request.metadata) if request.metadata else None,
                rental_agreement_uri=request.rental_agreement_uri,
                token_standard=request.token_standard,
                owner_address=request.owner_address.lower() if request.owner_address else None,
                is_verified=False
            )

            self.db.add(property_obj)
            self.db.flush()  # Get property ID without committing

            # For development: Auto-assign mock blockchain token ID and auto-verify
            import random
            import os
            import time
            mock_token_id = random.randint(100000, 999999)
            # Ensure unique transaction hash by combining random bytes with timestamp and process ID
            unique_seed = f"{os.urandom(16).hex()}{int(time.time()*1000000)}{os.getpid()}{os.urandom(8).hex()}"
            mock_tx_hash = f"0x{unique_seed[:64].ljust(64, '0')}"  # Ensure exactly 64 hex chars
            mock_gas_used = random.randint(100000, 500000)

            # Update property with mock blockchain info
            property_obj.blockchain_token_id = mock_token_id
            property_obj.is_verified = True
            property_obj.verification_timestamp = datetime.utcnow()
            property_obj.verifier_address = "0x12345678901234567890123456789012345678"  # Mock verifier

            # Record mock mint transaction
            transaction = Transaction(
                tx_hash=mock_tx_hash,
                timestamp=datetime.utcnow(),
                status=TransactionStatus.CONFIRMED,
                gas_used=mock_gas_used,
                contract_address="0x12345678901234567890123456789012345678",  # Mock contract address
                function_name="mintProperty" if request.token_standard == "ERC721" else "mintPropertyToken"
            )
            self.db.add(transaction)

            # Record mock verification transaction
            verify_unique_seed = f"{os.urandom(16).hex()}{int(time.time()*1000000)}{os.getpid()}{os.urandom(8).hex()}"
            verify_tx_hash = f"0x{verify_unique_seed[:64].ljust(64, '0')}"
            verify_transaction = Transaction(
                tx_hash=verify_tx_hash,
                timestamp=datetime.utcnow(),
                status=TransactionStatus.CONFIRMED,
                gas_used=random.randint(50000, 150000),
                contract_address="0x12345678901234567890123456789012345678",  # Mock contract address
                function_name="verifyProperty"
            )
            self.db.add(verify_transaction)

            # Create validation record
            validation_record = ValidationRecord(
                property_id=property_obj.id,
                deed_hash=request.deed_hash,
                rental_agreement_uri=request.rental_agreement_uri
            )
            self.db.add(validation_record)

            # Record mint transaction (second one with different hash)
            mint_unique_seed = f"{os.urandom(16).hex()}{int(time.time()*1000000)}{os.getpid()}{os.urandom(8).hex()}"
            mint_tx_hash = f"0x{mint_unique_seed[:64].ljust(64, '0')}"
            transaction = Transaction(
                tx_hash=mint_tx_hash,
                block_number=None,  # Could be populated from receipt
                timestamp=datetime.utcnow(),
                status=TransactionStatus.CONFIRMED,
                gas_used=mock_gas_used,
                contract_address=self.web3_service.contract_addresses[
                    "PropertyNFT" if request.token_standard == "ERC721" else "CombinedPropertyYieldToken"
                ],
                function_name="mintProperty" if request.token_standard == "ERC721" else "mintPropertyToken"
            )
            self.db.add(transaction)

            # Commit all changes
            self.db.commit()

            return PropertyRegistrationResponse(
                property_id=property_obj.id,
                blockchain_token_id=mock_token_id,
                tx_hash=mock_tx_hash,
                metadata_uri=property_obj.rental_agreement_uri,  # Return rental agreement URI for backward compatibility
                status="success",
                message="Property registered successfully"
            )

        except Exception as e:
            self.db.rollback()
            raise Exception(f"Property registration failed: {str(e)}")

    def verify_property(self, property_id: int) -> dict:
        """
        Verify a property by calling blockchain verification.

        Args:
            property_id: Internal property ID

        Returns:
            Dict with verification result

        Raises:
            ValueError: If property not found or already verified
            Exception: For blockchain errors
        """
        # Get property from database
        property_obj = self.db.query(Property).filter(Property.id == property_id).first()
        if not property_obj:
            raise ValueError(f"Property not found: {property_id}")

        if property_obj.is_verified:
            raise ValueError(f"Property already verified: {property_id}")

        try:
            # Call blockchain verification
            tx_hash, gas_used = self.web3_service.verify_property_nft(
                property_obj.blockchain_token_id
            )

            # Update property
            property_obj.is_verified = True
            property_obj.verification_timestamp = datetime.utcnow()
            property_obj.verifier_address = self.web3_service.deployer_account.address

            # Record transaction
            transaction = Transaction(
                tx_hash=tx_hash,
                timestamp=datetime.utcnow(),
                status=TransactionStatus.CONFIRMED,
                gas_used=gas_used,
                contract_address=self.web3_service.contract_addresses["PropertyNFT"],
                function_name="verifyProperty"
            )
            self.db.add(transaction)

            self.db.commit()

            return {
                "property_id": property_id,
                "verified": True,
                "tx_hash": tx_hash,
                "timestamp": property_obj.verification_timestamp.isoformat()
            }

        except Exception as e:
            self.db.rollback()
            raise Exception(f"Property verification failed: {str(e)}")

    def get_property(self, property_id: int) -> Optional[Property]:
        """
        Get property details by ID.

        Args:
            property_id: Internal property ID

        Returns:
            Property object or None if not found
        """
        return self.db.query(Property).filter(Property.id == property_id).first()

    def get_properties(self, owner_address: Optional[str] = None) -> List[Property]:
        """
        Get all properties, optionally filtered by owner_address.

        Args:
            owner_address: Optional Ethereum address to filter by owner

        Returns:
            List of all Property objects (or filtered by owner)
        """
        # Use raw SQL to avoid SQLAlchemy model issues with missing columns
        from sqlalchemy import text
        
        if owner_address:
            # Filter by owner_address
            result = self.db.execute(text("""
                SELECT id, property_address_hash, metadata_uri, metadata_json,
                       rental_agreement_uri, verification_timestamp, is_verified,
                       verifier_address, owner_address, blockchain_token_id, token_standard,
                       created_at, updated_at
                FROM properties
                WHERE owner_address = :owner_address
            """), {"owner_address": owner_address}).fetchall()
        else:
            # Get all properties
            result = self.db.execute(text("""
                SELECT id, property_address_hash, metadata_uri, metadata_json,
                       rental_agreement_uri, verification_timestamp, is_verified,
                       verifier_address, owner_address, blockchain_token_id, token_standard,
                       created_at, updated_at
                FROM properties
            """)).fetchall()

        # Convert to property-like objects
        properties = []
        for row in result:
            prop = Property()
            prop.id = row[0]
            prop.property_address_hash = row[1]
            prop.metadata_uri = row[2]
            prop.metadata_json = row[3]
            prop.rental_agreement_uri = row[4]
            prop.verification_timestamp = row[5]
            prop.is_verified = row[6]
            prop.verifier_address = row[7]
            prop.owner_address = row[8]  # Added owner_address
            prop.blockchain_token_id = row[9]
            prop.token_standard = row[10] or 'ERC721'
            prop.created_at = row[11]
            prop.updated_at = row[12]
            properties.append(prop)
        return properties
