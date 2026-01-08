"""
Comprehensive integration tests for RWA Tokenization Platform.

This module provides end-to-end testing with simulated blockchain interactions,
event monitoring, audit trail verification, and comprehensive validation of
the entire property registration and tokenization workflow.
"""

import pytest
import json
from unittest.mock import MagicMock
from services.web3_service import Web3Service
from services.property_service import PropertyService
from models.property import Property
from models.validation_record import ValidationRecord
from models.transaction import Transaction
from schemas.property import PropertyRegistrationRequest


class TestComprehensiveIntegration:
    """
    Comprehensive integration tests covering the full RWA tokenization workflow.

    Tests include:
    - Property registration with testing mode
    - Event emission simulation and validation
    - Audit trail verification
    - Database consistency checks
    - Schema validation
    """

    def test_property_registration_full_workflow(self, test_client, mock_web3_service, test_db):
        """
        Test complete property registration workflow with testing mode.

        Verifies:
        - API endpoint functionality
        - Database persistence
        - ValidationRecord creation
        - Audit trail logging
        - Event monitoring (if enabled)
        """
        # Test data
        property_data = {
            "property_address": "789 Integration Test Boulevard, Birmingham, UK",
            "deed_hash": "0x789abcdef123456789abcdef123456789abcdef123456789abcdef123456789",
            "rental_agreement_uri": "ipfs://QmIntegrationTest1234567890abcdef1234567890abcdef1234567890",
            "metadata": {
                "property_type": "industrial",
                "square_footage": 5000,
                "year_built": 2010,
                "floors": 2,
                "parking_spaces": 20
            },
            "token_standard": "ERC721"
        }

        # Register property
        response = test_client.post("/register-property", json=property_data)
        assert response.status_code == 201

        data = response.json()
        assert "property_id" in data
        assert "blockchain_token_id" in data
        assert "tx_hash" in data
        assert "metadata_uri" in data
        assert data["status"] == "success"

        property_id = data["property_id"]

        # Verify database persistence
        property_obj = test_db.query(Property).filter(Property.id == property_id).first()
        assert property_obj is not None
        assert property_obj.rental_agreement_uri == property_data["rental_agreement_uri"]
        assert property_obj.metadata_json == json.dumps(property_data["metadata"])
        assert property_obj.metadata_uri is None  # Not yet set (future IPFS CID)
        assert property_obj.token_standard == "ERC721"
        assert property_obj.is_verified is False

        # Verify ValidationRecord creation
        validation_record = test_db.query(ValidationRecord).filter(
            ValidationRecord.property_id == property_id
        ).first()
        assert validation_record is not None
        assert validation_record.deed_hash == property_data["deed_hash"]
        assert validation_record.rental_agreement_uri == property_data["rental_agreement_uri"]

        # Verify audit trail
        audit_trail = mock_web3_service.get_audit_trail()
        assert len(audit_trail) > 0

        # Find the mint_property_nft_test operation
        mint_operation = None
        for entry in audit_trail:
            if entry['operation'] == 'mint_property_nft_test':
                mint_operation = entry
                break

        assert mint_operation is not None
        assert mint_operation['data']['property_id'] == property_id
        assert mint_operation['data']['testing_mode'] is True

    def test_event_monitoring_and_validation(self, mock_web3_service):
        """
        Test event monitoring and validation capabilities.

        Verifies:
        - Event log capture
        - Transaction integrity validation
        - Event data structure validation
        """
        # Clear existing logs
        mock_web3_service.event_logs.clear()
        mock_web3_service.audit_trail.clear()

        # Simulate multiple transactions
        tx_hashes = []
        for i in range(3):
            # Create mock property data
            property_hash = f"0x{i:064x}".encode()
            metadata_uri = f"ipfs://QmTest{i}"

            # Call testing mint function
            token_id, tx_hash, gas_used = mock_web3_service._mint_property_nft_testing(
                property_hash, metadata_uri
            )
            tx_hashes.append(tx_hash)

        # Verify audit trail has all transactions
        audit_trail = mock_web3_service.get_audit_trail()
        assert len(audit_trail) == 3

        for entry in audit_trail:
            assert entry['operation'] == 'mint_property_nft_test'
            assert 'data' in entry
            assert entry['data']['testing_mode'] is True

        # Verify transaction integrity validation
        for tx_hash in tx_hashes:
            assert mock_web3_service.validate_transaction_integrity(tx_hash)

        # Verify invalid transaction fails
        assert not mock_web3_service.validate_transaction_integrity("0xinvalid")

    def test_schema_validation_and_error_handling(self, test_client):
        """
        Test comprehensive schema validation and error handling.

        Verifies:
        - Input validation for all required fields
        - Proper error messages
        - Edge case handling
        """
        # Test invalid deed hash format
        invalid_data = {
            "property_address": "Test Address",
            "deed_hash": "invalid_hash",
            "rental_agreement_uri": "ipfs://QmTest",
            "metadata": {},
            "token_standard": "ERC721"
        }

        response = test_client.post("/register-property", json=invalid_data)
        assert response.status_code == 422

        errors = response.json()["detail"]
        assert len(errors) > 0
        assert any("deed_hash" in str(error) for error in errors)

        # Test invalid token standard
        invalid_data["deed_hash"] = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
        invalid_data["token_standard"] = "INVALID"

        response = test_client.post("/register-property", json=invalid_data)
        assert response.status_code == 422

        errors = response.json()["detail"]
        assert any("token_standard" in str(error) for error in errors)

        # Test invalid rental agreement URI
        invalid_data["token_standard"] = "ERC721"
        invalid_data["rental_agreement_uri"] = "invalid_uri"

        response = test_client.post("/register-property", json=invalid_data)
        assert response.status_code == 422

        errors = response.json()["detail"]
        assert any("rental_agreement_uri" in str(error) for error in errors)

    def test_metadata_separation_validation(self, test_client, test_db):
        """
        Test metadata URI vs rental agreement URI separation.

        Verifies:
        - metadata_uri is stored as NULL (for future IPFS CID)
        - rental_agreement_uri is stored correctly
        - metadata_json contains structured data
        - API response returns rental_agreement_uri as metadata_uri for compatibility
        """
        property_data = {
            "property_address": "999 Metadata Test Street, Leeds, UK",
            "deed_hash": "0x999abcdef123456789abcdef123456789abcdef123456789abcdef123456789",
            "rental_agreement_uri": "ipfs://QmMetadataTest1234567890abcdef1234567890abcdef1234567890",
            "metadata": {
                "property_type": "retail",
                "square_footage": 1500,
                "year_built": 2015,
                "location": "city_center"
            },
            "token_standard": "ERC721"
        }

        # Register property
        response = test_client.post("/register-property", json=property_data)
        assert response.status_code == 201

        data = response.json()
        property_id = data["property_id"]

        # Verify API response shows rental_agreement_uri as metadata_uri (backward compatibility)
        assert data["metadata_uri"] == property_data["rental_agreement_uri"]

        # Verify database stores them separately
        property_obj = test_db.query(Property).filter(Property.id == property_id).first()
        assert property_obj.metadata_uri is None  # Not yet set
        assert property_obj.rental_agreement_uri == property_data["rental_agreement_uri"]
        assert property_obj.metadata_json == json.dumps(property_data["metadata"])

    def test_duplicate_property_prevention(self, test_client):
        """
        Test that duplicate properties (same address hash) are prevented.

        Verifies database integrity constraints work correctly.
        """
        property_data = {
            "property_address": "111 Duplicate Test Road, Bristol, UK",
            "deed_hash": "0x111abcdef123456789abcdef123456789abcdef123456789abcdef123456789",
            "rental_agreement_uri": "ipfs://QmDuplicateTest1234567890abcdef1234567890abcdef1234567890",
            "metadata": {"property_type": "office"},
            "token_standard": "ERC721"
        }

        # First registration should succeed
        response1 = test_client.post("/register-property", json=property_data)
        assert response1.status_code == 201

        # Second registration with same address should fail
        response2 = test_client.post("/register-property", json=property_data)
        assert response2.status_code == 500  # Internal server error due to unique constraint

        error_detail = response2.json()["detail"]
        assert "duplicate key" in error_detail.lower() or "unique constraint" in error_detail.lower()

    def test_web3_service_testing_mode_functionality(self):
        """
        Test Web3Service testing mode functionality comprehensively.

        Verifies:
        - Testing mode initialization
        - Mock receipt creation
        - Event parsing simulation
        - Transaction logging
        """
        # Test production mode
        prod_service = Web3Service(testing_mode=False)
        assert not prod_service.testing_mode
        assert prod_service.w3 is not None  # Would be Web3 instance in real environment

        # Test testing mode
        test_service = Web3Service(testing_mode=True)
        assert test_service.testing_mode
        assert test_service.w3 is None  # No real Web3 connection
        assert test_service.contract_addresses is not None

        # Test mock receipt creation
        mock_receipt = test_service._create_mock_receipt("TestEvent", {"value": 123})
        assert "events" in mock_receipt
        assert "TestEvent" in mock_receipt["events"]
        assert mock_receipt["events"]["TestEvent"]["value"] == 123

        # Test event parsing in testing mode
        token_id = test_service._parse_property_minted_event(mock_receipt)
        assert token_id == 123

        # Test transaction logging
        initial_audit_length = len(test_service.audit_trail)
        test_service._log_transaction("test_operation", {"test": "data"})

        assert len(test_service.audit_trail) == initial_audit_length + 1
        last_entry = test_service.audit_trail[-1]
        assert last_entry["operation"] == "test_operation"
        assert last_entry["data"]["test"] == "data"
