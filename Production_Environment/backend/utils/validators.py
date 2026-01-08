"""
Validation utility functions for input data and blockchain compatibility.

This module provides reusable validation functions for deed hashes,
Ethereum addresses, IPFS URIs, and other data formats used in the
RWA tokenization platform.
"""

import re
from web3 import Web3


def validate_ethereum_address(address: str) -> bool:
    """
    Validate Ethereum address format and checksum.

    Args:
        address: Ethereum address string (0x-prefixed)

    Returns:
        bool: True if address is valid

    Examples:
        >>> validate_ethereum_address("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
        True
        >>> validate_ethereum_address("invalid_address")
        False
    """
    if not isinstance(address, str):
        return False

    # Basic format check
    if not re.match(r"^0x[a-fA-F0-9]{40}$", address):
        return False

    # Checksum validation
    try:
        w3 = Web3()
        return w3.is_address(address)
    except Exception:
        return False


def validate_deed_hash(deed_hash: str) -> bool:
    """
    Validate deed hash format (bytes32 hex string).

    Args:
        deed_hash: Deed hash as 0x-prefixed hex string

    Returns:
        bool: True if deed hash is valid 32-byte hex

    Examples:
        >>> validate_deed_hash("0x1234567890abcdef" * 4)
        True
        >>> validate_deed_hash("invalid_hash")
        False
    """
    if not isinstance(deed_hash, str):
        return False

    # Must be 0x-prefixed, 66 characters total (0x + 64 hex chars = 32 bytes)
    if not re.match(r"^0x[a-fA-F0-9]{64}$", deed_hash):
        return False

    # Validate hex conversion
    try:
        int(deed_hash, 16)
        return True
    except ValueError:
        return False


def validate_ipfs_uri(uri: str) -> bool:
    """
    Validate IPFS URI format.

    Args:
        uri: IPFS URI string

    Returns:
        bool: True if URI is valid IPFS format

    Examples:
        >>> validate_ipfs_uri("ipfs://QmXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxX")
        True
        >>> validate_ipfs_uri("https://ipfs.io/ipfs/QmXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxXxxX")
        True
        >>> validate_ipfs_uri("invalid_uri")
        False
    """
    if not isinstance(uri, str):
        return False

    # Check for valid IPFS URI patterns
    ipfs_patterns = [
        r"^ipfs://[a-zA-Z0-9]{46}$",  # ipfs:// + base58 hash
        r"^https?://[^/]+/ipfs/[a-zA-Z0-9]{46}(/.*)?$",  # HTTP gateway URL
        r"^https?://[^/]+/ipfs/[a-zA-Z0-9]{46}/?.*$"  # Gateway with optional path
    ]

    return any(re.match(pattern, uri) for pattern in ipfs_patterns)


def calculate_property_address_hash(property_address: str) -> str:
    """
    Calculate keccak256 hash of property address for blockchain storage.

    Args:
        property_address: Human-readable property address

    Returns:
        str: 0x-prefixed hex string of keccak256 hash (bytes32)

    Examples:
        >>> hash = calculate_property_address_hash("123 Main St, London")
        >>> len(hash)
        66
        >>> hash.startswith("0x")
        True
    """
    if not isinstance(property_address, str) or not property_address.strip():
        raise ValueError("Property address must be non-empty string")

    w3 = Web3()
    address_bytes = property_address.strip().encode('utf-8')
    hash_bytes = w3.keccak(address_bytes)

    return w3.to_hex(hash_bytes)
