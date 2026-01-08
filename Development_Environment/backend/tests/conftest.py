"""
Pytest configuration and shared fixtures for backend testing.

This module provides database fixtures, Web3 mocking, API client setup,
and test data factories for comprehensive test coverage.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from faker import Faker

from config.database import Base, get_db
from main import app
from services.web3_service import Web3Service
from config.web3_config import get_web3_service
from unittest.mock import MagicMock

# Create in-memory SQLite database for testing
TEST_DATABASE_URL = "sqlite:///./test.db"

engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session")
def test_db():
    """
    Create test database session fixture.

    Creates all tables before tests and drops them after.
    Yields database session for test functions.
    """
    # Create all tables
    Base.metadata.create_all(bind=engine)

    # Create session
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

    # Drop all tables after tests
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def test_client(test_db, mock_web3_service):
    """
    FastAPI test client fixture with database dependency override.

    Overrides get_db and get_web3_service dependencies to use test database session and mock Web3 service.
    """
    def override_get_db():
        try:
            yield test_db
        finally:
            test_db.close()

    # Override database and Web3Service dependencies
    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_web3_service] = lambda: mock_web3_service

    # Create test client
    client = TestClient(app)
    return client


@pytest.fixture(scope="function")
def real_web3_service():
    """
    Real Web3Service in testing mode for integration tests.
    
    Returns a real Web3Service instance with testing_mode=True.
    Used by tests that need to access internal testing methods like
    _mint_property_nft_testing(), get_audit_trail(), etc.
    """
    from services.web3_service import Web3Service
    
    # Create Web3Service in testing mode
    service = Web3Service(testing_mode=True)
    
    return service


@pytest.fixture(scope="function")
def mock_web3_service():
    """
    Mock Web3Service for unit testing.
    
    Returns a MagicMock configured to simulate Web3 operations
    without hitting the real blockchain. Matches the return types
    of the real Web3Service methods (tuples, not dicts).
    """
    import time
    from unittest.mock import MagicMock
    
    mock = MagicMock(spec=Web3Service)
    
    # Generate unique transaction hash
    def unique_tx_hash():
        return '0xMockTxHash_' + str(int(time.time() * 1000000))
    
    # Configure mock responses for property operations
    # mint_property_nft returns: Tuple[int, str, int] = (token_id, tx_hash, gas_used)
    mock.mint_property_nft.return_value = (1, unique_tx_hash(), 21000)
    
    # verify_property_nft returns: Tuple[str, int] = (tx_hash, gas_used)
    mock.verify_property_nft.return_value = (unique_tx_hash(), 21000)
    
    # mint_combined_property_token returns: Tuple[int, str, int] = (token_id, tx_hash, gas_used)
    mock.mint_combined_property_token.return_value = (1000001, unique_tx_hash(), 21000)
    
    # verify_property_combined returns: Tuple[str, int] = (tx_hash, gas_used)
    mock.verify_property_combined.return_value = (unique_tx_hash(), 21000)
    
    # Configure mock responses for yield agreement operations
    # create_yield_agreement returns: Tuple[int, str, str, int] = (agreement_id, token_address, tx_hash, gas_used)
    mock.create_yield_agreement.return_value = (1, '0x' + '1' * 40, unique_tx_hash(), 21000)
    
    # verify_signature returns: bool - Allow mock signatures for testing
    mock.verify_signature.return_value = True
    
    # mint_combined_yield_tokens returns: Tuple[int, str, str, int] = (yield_token_id, token_address, tx_hash, gas_used)
    mock.mint_combined_yield_tokens.return_value = (2000001, '0xMockTokenAddress', unique_tx_hash(), 21000)
    
    # Mock contract_addresses property
    mock.contract_addresses = {
        "PropertyNFT": "0x" + "A" * 40,
        "YieldBase": "0x" + "B" * 40,
        "CombinedPropertyYieldToken": "0x" + "C" * 40,
        "GovernanceController": "0x" + "D" * 40
    }
    
    # Mock deployer_account attribute (needs .address property)
    mock_account = MagicMock()
    mock_account.address = "0x" + "E" * 40
    mock.deployer_account = mock_account
    
    # Mock testing_mode attribute
    mock.testing_mode = False
    
    # Mock audit trail and event logs (for integration tests)
    mock.audit_trail = []
    mock.event_logs = []
    mock.event_monitoring_enabled = True
    
    # Mock get_audit_trail() method
    mock.get_audit_trail.return_value = []
    
    # Mock get_event_logs() method  
    mock.get_event_logs.return_value = []
    
    # Mock transaction verification (correct method name)
    mock.validate_transaction_integrity.return_value = True
    
    # Mock _mint_property_nft_testing for integration tests
    def mock_mint_testing(property_hash, metadata_uri):
        token_id = len(mock.audit_trail) + 1
        tx_hash = unique_tx_hash()
        gas_used = 21000
        return (token_id, tx_hash, gas_used)
    
    mock._mint_property_nft_testing.side_effect = mock_mint_testing
    
    return mock


@pytest.fixture(scope="function")
def property_factory():
    """
    Property test data factory using Faker.

    Generates realistic property registration data for testing.
    """
    fake = Faker()

    def _create_property_data(**overrides):
        data = {
            "property_address": fake.address().replace('\n', ', '),
            "deed_hash": "0x" + "1" * 64,  # Valid 32-byte hex
            "rental_agreement_uri": "ipfs://QmXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxX",
            "metadata": {
                "property_type": "residential",
                "square_footage": fake.random_int(min=500, max=5000),
                "year_built": fake.random_int(min=1900, max=2024)
            },
            "token_standard": "ERC721"
        }
        data.update(overrides)
        return data

    return _create_property_data


@pytest.fixture(scope="function")
def yield_agreement_factory():
    """
    Yield agreement test data factory using Faker.

    Generates realistic yield agreement creation data for testing.
    """
    fake = Faker()

    def _create_agreement_data(**overrides):
        # API schema requires specific field names - see schemas/yield_agreement.py
        upfront_wei = fake.random_int(min=1000000000000000000, max=10000000000000000000)  # 1-10 ETH in wei
        term = fake.random_int(min=12, max=36)
        
        data = {
            "property_token_id": fake.random_int(min=1, max=1000),
            "upfront_capital": upfront_wei,  # Required: wei amount
            "upfront_capital_usd": fake.random_int(min=100000, max=1000000),  # Required: USD amount
            "term_months": term,  # Required: term in months
            "annual_roi_basis_points": fake.random_int(min=800, max=1500),  # 8-15%
            "property_payer": None,  # Optional: Ethereum address or None
            "grace_period_days": 30,
            "default_penalty_rate": 200,
            "default_threshold": 3,  # Default threshold in months
            "allow_partial_repayments": True,
            "allow_early_repayment": True,
            "token_standard": "ERC721"
        }
        data.update(overrides)
        return data

    return _create_agreement_data
