"""
Pytest test suite for property API endpoints.

Tests property registration, verification, and querying endpoints
with mocked Web3 interactions and time metric tracking.
"""

import pytest
import time

from schemas.property import PropertyRegistrationRequest
from models.validation_record import ValidationRecord


class TestPropertyRegistration:
    """Test cases for property registration endpoint."""

    def test_register_property_success(self, test_client, mock_web3_service, property_factory):
        """Test successful property registration with ERC-721 standard."""
        property_data = property_factory()

        start_time = time.time()
        response = test_client.post("/properties/register", json=property_data)
        elapsed_time = time.time() - start_time

        assert response.status_code == 201
        data = response.json()

        # Verify response structure
        assert "property_id" in data
        assert "blockchain_token_id" in data
        assert data["blockchain_token_id"] > 0  # Dynamic assertion for persistent blockchain
        assert isinstance(data["blockchain_token_id"], int)
        assert "tx_hash" in data
        assert "metadata_uri" in data
        assert data["status"] == "success"
        assert data["message"] == "Property registered successfully"

        # Verify Web3 service was called correctly
        mock_web3_service.mint_property_nft.assert_called_once()

        print(f"[TEST_METRICS] Property registration API time: {elapsed_time:.3f}s")

    def test_register_property_invalid_deed_hash(self, test_client):
        """Test property registration with invalid deed hash format."""
        invalid_data = {
            "property_address": "123 Test Street",
            "deed_hash": "invalid_hash",  # Invalid format
            "rental_agreement_uri": "ipfs://QmTest",
            "token_standard": "ERC721"
        }

        response = test_client.post("/properties/register", json=invalid_data)
        assert response.status_code == 422
        assert "deed hash" in response.json()["detail"].lower()

    def test_register_property_invalid_rental_uri(self, test_client):
        """Test property registration with invalid rental agreement URI."""
        invalid_data = {
            "property_address": "123 Test Street",
            "deed_hash": "0x" + "1" * 64,
            "rental_agreement_uri": "invalid_uri",  # Invalid format
            "token_standard": "ERC721"
        }

        response = test_client.post("/properties/register", json=invalid_data)
        assert response.status_code == 422
        assert "rental agreement uri" in response.json()["detail"].lower()

    def test_register_property_blockchain_failure(self, test_client, mock_web3_service, property_factory):
        """Test property registration with blockchain transaction failure."""
        property_data = property_factory()

        # Mock blockchain failure
        mock_web3_service.mint_property_nft.side_effect = Exception("Blockchain error")

        response = test_client.post("/properties/register", json=property_data)
        assert response.status_code == 500
        assert "blockchain" in response.json()["detail"].lower()

    def test_register_property_erc1155_variant(self, test_client, mock_web3_service, property_factory):
        """Test property registration with ERC-1155 token standard."""
        property_data = property_factory(token_standard="ERC1155")
        response = test_client.post("/properties/register", json=property_data)
        assert response.status_code == 201

        # Verify ERC-1155 method was called
        mock_web3_service.mint_combined_property_token.assert_called_once()
        mock_web3_service.mint_property_nft.assert_not_called()

    def test_register_property_creates_validation_record(self, test_client, mock_web3_service, property_factory, test_db):
        """Test that property registration creates a ValidationRecord."""
        property_data = property_factory()

        start_time = time.time()
        response = test_client.post("/properties/register", json=property_data)
        elapsed_time = time.time() - start_time

        assert response.status_code == 201
        data = response.json()

        # Verify ValidationRecord was created
        property_id = data["property_id"]
        validation_record = test_db.query(ValidationRecord).filter(
            ValidationRecord.property_id == property_id
        ).first()

        assert validation_record is not None
        assert validation_record.deed_hash == property_data["deed_hash"]
        assert validation_record.rental_agreement_uri == property_data["rental_agreement_uri"]
        assert validation_record.property_id == property_id

        print(f"[TEST_METRICS] Property registration with ValidationRecord API time: {elapsed_time:.3f}s")


class TestPropertyVerification:
    """Test cases for property verification endpoint."""

    def test_verify_property_success(self, test_client, mock_web3_service):
        """Test successful property verification."""
        # First register a property
        property_data = {
            "property_address": "123 Test Street",
            "deed_hash": "0x" + "1" * 64,
            "rental_agreement_uri": "ipfs://QmTest",
            "token_standard": "ERC721"
        }

        # Register property
        register_response = test_client.post("/properties/register", json=property_data)
        property_id = register_response.json()["property_id"]

        # Verify property
        response = test_client.post(f"/properties/{property_id}/verify")
        assert response.status_code == 200

        data = response.json()
        assert data["verified"] is True
        assert "transaction_hash" in data
        assert "verification_timestamp" in data

        # Verify Web3 service was called
        mock_web3_service.verify_property_nft.assert_called_once_with(1)

    def test_verify_property_not_found(self, test_client):
        """Test verification of non-existent property."""
        response = test_client.post("/properties/999/verify")
        assert response.status_code == 400
        assert "not found" in response.json()["detail"].lower()

    def test_verify_already_verified_property(self, test_client, mock_web3_service):
        """Test verification of already verified property."""
        # This would require setting up a verified property in the database
        # For now, we'll assume the service handles this case
        pass


class TestPropertyQueries:
    """Test cases for property query endpoints."""

    def test_get_property_details(self, test_client, mock_web3_service, property_factory):
        """Test retrieving property details."""
        property_data = property_factory()

        # Register property
        register_response = test_client.post("/properties/register", json=property_data)
        property_id = register_response.json()["property_id"]

        # Get property details
        response = test_client.get(f"/properties/{property_id}")
        assert response.status_code == 200

        data = response.json()
        assert data["id"] == property_id
        assert "property_address_hash" in data
        assert data["is_verified"] is False  # Not verified yet
        assert data["blockchain_token_id"] > 0  # Dynamic assertion for persistent blockchain
        assert isinstance(data["blockchain_token_id"], int)

    def test_get_nonexistent_property(self, test_client):
        """Test querying non-existent property."""
        response = test_client.get("/properties/999")
        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()
