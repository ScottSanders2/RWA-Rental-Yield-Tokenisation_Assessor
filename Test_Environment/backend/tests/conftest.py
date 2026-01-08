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
def mock_web3_service():
    """
    Web3Service fixture for unit testing with testing mode enabled.

    Returns Web3Service instance in testing mode with simulated blockchain operations.
    Provides realistic transaction receipts and event parsing for comprehensive testing.
    """
    from services.web3_service import Web3Service

    # Create Web3Service in testing mode
    service = Web3Service(testing_mode=True)

    return service


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
        data = {
            "property_token_id": fake.random_int(min=1, max=1000),
            "upfront_capital": fake.random_int(min=1000000000000000000, max=10000000000000000000),  # 1-10 ETH
            "term_months": fake.random_int(min=12, max=36),
            "annual_roi_basis_points": fake.random_int(min=800, max=1500),  # 8-15%
            "property_payer": "0x" + "0" * 40,  # Valid zero address
            "grace_period_days": 30,
            "default_penalty_rate": 200,
            "default_threshold": 3,
            "allow_partial_repayments": True,
            "allow_early_repayment": True,
            "token_standard": "ERC721"
        }
        data.update(overrides)
        return data

    return _create_agreement_data
