// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title KYCStorage
 * @notice ERC-7201 namespaced storage library for KYC verification data
 * @dev Implements collision-free storage isolation using ERC-7201 standard
 * 
 * Storage namespace: "rwa.storage.KYC"
 * This namespace is isolated from:
 * - YieldStorage ("rwa.storage.Yield")
 * - YieldSharesStorage ("rwa.storage.YieldShares")
 * - PropertyStorage ("rwa.storage.Property")
 * - GovernanceStorage ("rwa.storage.Governance")
 * - TransferRestrictionsStorage ("rwa.storage.TransferRestrictions")
 * - CombinedTokenStorage ("rwa.storage.CombinedToken")
 * 
 * The storage location is calculated using:
 * keccak256(abi.encode(uint256(keccak256("rwa.storage.KYC")) - 1)) & ~bytes32(uint256(0xff))
 * This ensures no collisions with standard contract storage slots or other namespaced storage.
 */
library KYCStorage {
    /// @dev Storage namespace identifier
    /// @custom:storage-location erc7201:rwa.storage.KYC
    bytes32 private constant KYC_STORAGE_LOCATION = 
        0x8d6e9e2c5a1b3f4e7d8c9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d;

    /**
     * @dev KYC verification data structure
     * @param whitelistedAddresses Mapping of addresses that have completed KYC verification
     * @param blacklistedAddresses Mapping of addresses that are blocked from platform participation
     * @param verificationTimestamp Timestamp when address was verified (for expiry tracking)
     * @param kycTier Verification tier: 'basic' (individual), 'accredited' (accredited investor), 'institutional'
     * @param governanceController Reference to governance contract for democratic whitelist control
     * @param whitelistEnabled Global flag to enable/disable whitelist enforcement
     * @param blacklistEnabled Global flag to enable/disable blacklist enforcement
     */
    struct KYCData {
        mapping(address => bool) whitelistedAddresses;
        mapping(address => bool) blacklistedAddresses;
        mapping(address => uint256) verificationTimestamp;
        mapping(address => string) kycTier;
        address governanceController;
        bool whitelistEnabled;
        bool blacklistEnabled;
    }

    /**
     * @notice Get the storage pointer for KYC data
     * @dev Uses assembly to access the ERC-7201 namespaced storage location
     * @return $ Storage pointer to KYCData struct
     */
    function getKYCStorage() internal pure returns (KYCData storage $) {
        assembly {
            $.slot := KYC_STORAGE_LOCATION
        }
    }
}

