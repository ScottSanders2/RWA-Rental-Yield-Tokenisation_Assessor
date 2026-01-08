"""
Web3 provider configuration module for blockchain interaction.

This module provides Web3 connection setup, account management, and contract
address configuration. It abstracts blockchain connectivity and ensures proper
error handling for connection failures and invalid configurations.

Contract addresses must be populated after running deployment script in Foundry container.
"""

import os
from web3 import Web3
from eth_account import Account
from fastapi import Depends
from sqlalchemy.orm import Session
from .settings import settings
from .database import get_db

# Global Web3Service instance for dependency injection
_web3_service_instance = None


def get_web3() -> Web3:
    """
    Create and return configured Web3 instance connected to Anvil.

    Returns:
        Web3: Configured Web3 instance

    Raises:
        ConnectionError: If unable to connect to Web3 provider
    """
    w3 = Web3(Web3.HTTPProvider(settings.web3_provider_uri))

    # Validate connection
    if not w3.is_connected():
        raise ConnectionError(
            f"Failed to connect to Web3 provider at {settings.web3_provider_uri}"
        )

    # Validate chain ID
    if w3.eth.chain_id != settings.anvil_chain_id:
        raise ValueError(
            f"Chain ID mismatch. Expected {settings.anvil_chain_id}, "
            f"got {w3.eth.chain_id}"
        )

    return w3


def get_deployer_account() -> Account:
    """
    Create and return deployer account for transaction signing.

    Returns:
        Account: Deployer account instance

    Raises:
        ValueError: If private key is invalid
    """
    try:
        account = Account.from_key(settings.deployer_private_key)
        return account
    except Exception as e:
        raise ValueError(f"Invalid deployer private key: {e}")


def get_contract_addresses() -> dict:
    """
    Return dictionary of deployed contract addresses.

    Contract addresses must be populated after running deployment script
    in Foundry container. These are used by Web3Service for contract interactions.

    Returns:
        dict: Contract addresses keyed by contract name
    """
    return {
        "PropertyNFT": settings.property_nft_address,
        "YieldBase": settings.yield_base_address,
        "CombinedPropertyYieldToken": settings.combined_token_address,
        "KYCRegistry": settings.kyc_registry_address,
    }


def get_web3_service(db: Session = Depends(get_db)):
    """
    Dependency injection function for Web3Service instance.

    In testing mode, creates a new Web3Service instance per request with database session.
    In production mode, returns a singleton instance (no db session needed for blockchain queries).

    Args:
        db: Database session (injected via FastAPI dependency)

    Returns:
        Web3Service: Configured Web3Service instance with database session for testing mode
    """
    # Import Web3Service here to avoid circular import
    from services.web3_service import Web3Service

    # Check if testing mode is enabled
    testing_mode = os.getenv('WEB3_TESTING_MODE', 'false').lower() == 'true'
    
    if testing_mode:
        # In testing mode, create new instance per request with database session
        # This allows total_supply queries to work correctly from database
        return Web3Service(testing_mode=True, db=db)
    else:
        # In production mode, use singleton (no db session needed for blockchain)
        global _web3_service_instance
        if _web3_service_instance is None:
            _web3_service_instance = Web3Service(testing_mode=False)
        return _web3_service_instance
