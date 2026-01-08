"""
Pytest test suite for yield agreement API endpoints.

Tests yield agreement creation and querying endpoints with mocked
Web3 interactions and comprehensive time metric tracking.
"""

import pytest
import time


class TestYieldAgreementCreation:
    """Test cases for yield agreement creation endpoint."""

    def test_create_yield_agreement_success(self, test_client, mock_web3_service, yield_agreement_factory):
        """Test successful yield agreement creation."""
        # First register and verify a property
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
        test_client.post(f"/properties/{property_id}/verify")

        # Create yield agreement
        agreement_data = yield_agreement_factory(property_token_id=1)

        start_time = time.time()
        response = test_client.post("/yield-agreements/create", json=agreement_data)
        elapsed_time = time.time() - start_time

        assert response.status_code == 201
        data = response.json()

        # Verify response structure
        assert "agreement_id" in data
        assert "blockchain_agreement_id" in data
        assert "token_contract_address" in data
        assert "tx_hash" in data
        assert "monthly_payment" in data
        assert "total_expected_repayment" in data
        assert data["status"] == "success"

        # Verify financial calculations are present
        assert isinstance(data["monthly_payment"], int)
        assert isinstance(data["total_expected_repayment"], int)

        # Verify Web3 service was called
        mock_web3_service.create_yield_agreement.assert_called_once()

        print(f"[TEST_METRICS] Yield agreement creation API time: {elapsed_time:.3f}s")

    def test_create_agreement_property_not_verified(self, test_client, mock_web3_service, yield_agreement_factory):
        """Test yield agreement creation with unverified property."""
        # Register property but don't verify
        property_data = {
        "property_address": "123 Test Street",
        "deed_hash": "0x" + "1" * 64,
        "rental_agreement_uri": "ipfs://QmTest",
        "token_standard": "ERC721"
        }

        # Removed patch - using dependency injection
        test_client.post("/properties/register", json=property_data)

        agreement_data = yield_agreement_factory(property_token_id=1)
        response = test_client.post("/yield-agreements/create", json=agreement_data)

        assert response.status_code == 400
        assert "not verified" in response.json()["detail"].lower()

    def test_create_agreement_invalid_parameters(self, test_client, mock_web3_service):
        """Test yield agreement creation with invalid parameters."""
        # Register and verify property first
        property_data = {
        "property_address": "123 Test Street",
        "deed_hash": "0x" + "1" * 64,
        "rental_agreement_uri": "ipfs://QmTest",
        "token_standard": "ERC721"
        }

        # Removed patch - using dependency injection
        test_client.post("/properties/register", json=property_data)
        test_client.post("/properties/1/verify")

        # Test invalid term_months (too low)
        invalid_data = {
            "property_token_id": 1,
            "upfront_capital": 1000000000000000000,
            "term_months": 0,  # Invalid: below minimum
            "annual_roi_basis_points": 1200,
            "token_standard": "ERC721"
        }

        response = test_client.post("/yield-agreements/create", json=invalid_data)
        assert response.status_code == 422

        # Test invalid ROI (too high)
        invalid_data["term_months"] = 24
        invalid_data["annual_roi_basis_points"] = 6000  # Invalid: above maximum

        response = test_client.post("/yield-agreements/create", json=invalid_data)
        assert response.status_code == 422

    def test_create_agreement_erc1155_variant(self, test_client, mock_web3_service):
        """Test yield agreement creation with ERC-1155 token standard."""
        # Register and verify ERC-1155 property
        property_data = {
        "property_address": "123 Test Street",
        "deed_hash": "0x" + "1" * 64,
        "rental_agreement_uri": "ipfs://QmTest",
        "token_standard": "ERC1155"
        }

        # Removed patch - using dependency injection
        test_client.post("/properties/register", json=property_data)
        test_client.post("/properties/1/verify")

        agreement_data = {
            "property_token_id": 1,
            "upfront_capital": 1000000000000000000,
            "term_months": 24,
            "annual_roi_basis_points": 1200,
            "token_standard": "ERC1155"
        }

        response = test_client.post("/yield-agreements/create", json=agreement_data)
        assert response.status_code == 201

        # Verify ERC-1155 method was called
        mock_web3_service.mint_combined_yield_tokens.assert_called_once()
        mock_web3_service.create_yield_agreement.assert_not_called()


class TestYieldAgreementQueries:
    """Test cases for yield agreement query endpoints."""

    def test_get_yield_agreement_details(self, test_client, mock_web3_service):
        """Test retrieving yield agreement details."""
        # Register, verify property, and create agreement
        property_data = {
        "property_address": "123 Test Street",
        "deed_hash": "0x" + "1" * 64,
        "rental_agreement_uri": "ipfs://QmTest",
        "token_standard": "ERC721"
        }

        agreement_data = {
        "property_token_id": 1,
        "upfront_capital": 1000000000000000000,
        "term_months": 24,
        "annual_roi_basis_points": 1200,
        "token_standard": "ERC721"
        }

        # Removed patch - using dependency injection
        test_client.post("/properties/register", json=property_data)
        test_client.post("/properties/1/verify")

        create_response = test_client.post("/yield-agreements/create", json=agreement_data)
        agreement_id = create_response.json()["agreement_id"]

        # Get agreement details
        response = test_client.get(f"/yield-agreements/{agreement_id}")
        assert response.status_code == 200

        data = response.json()
        assert data["id"] == agreement_id
        assert data["property_id"] == 1
        assert data["upfront_capital"] == 1000000000000000000
        assert data["repayment_term_months"] == 24
        assert data["annual_roi_basis_points"] == 1200
        assert data["is_active"] is True

    def test_get_nonexistent_agreement(self, test_client):
        """Test querying non-existent yield agreement."""
        response = test_client.get("/yield-agreements/999")
        assert response.status_code == 404
        assert "not found" in response.json()["detail"].lower()
