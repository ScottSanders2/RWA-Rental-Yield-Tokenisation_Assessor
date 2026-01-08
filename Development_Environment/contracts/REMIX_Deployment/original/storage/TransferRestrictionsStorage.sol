// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title TransferRestrictionsStorage
 * @notice ERC-7201 namespaced storage library for transfer restriction rules
 * @dev Provides collision-free storage separate from YieldStorage, YieldSharesStorage,
 * PropertyStorage, GovernanceStorage, and CombinedTokenStorage using ERC-7201 pattern.
 * Enables autonomous enforcement of lockup periods, concentration limits, minimum holding
 * periods, and emergency pause controls through transfer hooks without breaking ERC-20/ERC-1155
 * standard compliance.
 *
 * Architecture:
 * - ERC-7201 namespace ensures no storage collisions with UUPS upgradeable contracts
 * - Transfer restrictions validated in _update hook before every transfer
 * - Governance integration enables democratic control over restriction parameters
 * - Restrictions are optional (disabled by default) per agreement for regulatory compliance
 *
 * Restriction Types:
 * 1. Lockup Period: Prevents immediate flipping after minting (e.g., 30 days)
 * 2. Concentration Limit: Prevents whale dominance (e.g., max 20% of supply per investor)
 * 3. Minimum Holding Period: Anti-churn mechanism (e.g., 7 days minimum hold before transfer)
 * 4. Emergency Pause: Owner or governance can pause all transfers during security incidents
 *
 * Standard Compliance:
 * - Restrictions are additional validation checks, not modifications to ERC-20/ERC-1155 interfaces
 * - Mint and burn operations bypass restrictions (from/to == address(0))
 * - Transfer, transferFrom, safeTransferFrom remain compliant with token standards
 */
library TransferRestrictionsStorage {
    /**
     * @notice Transfer restriction data structure
     * @dev Contains all configurable restriction parameters per agreement
     */
    struct TransferRestrictionData {
        /// @notice Timestamp when lockup period ends (0 = no lockup)
        uint256 lockupEndTimestamp;
        
        /// @notice Emergency pause flag controlled by owner or governance
        bool isTransferPaused;
        
        /// @notice Maximum shares per investor in basis points (e.g., 2000 = 20%)
        uint256 maxSharesPerInvestor;
        
        /// @notice Minimum holding period in seconds before transfer allowed (e.g., 7 days)
        uint256 minHoldingPeriod;
        
        /// @notice Whitelisted addresses that can receive transfers (optional, deferred to Iteration 14 KYC)
        mapping(address => bool) whitelistedAddresses;
        
        /// @notice Blacklisted addresses that cannot receive transfers (optional)
        mapping(address => bool) blacklistedAddresses;
        
        /// @notice Transfer count per investor for rate limiting (optional)
        mapping(address => uint256) transferCount;
        
        /// @notice Last transfer timestamp per address for holding period enforcement
        mapping(address => uint256) lastTransferTimestamp;
        
        /// @notice Whether whitelist is enabled (false by default)
        bool whitelistEnabled;
        
        /// @notice Whether blacklist is enabled (false by default)
        bool blacklistEnabled;
    }

    /**
     * @notice Per-yield-token restriction storage for ERC-1155
     * @dev Maps yieldTokenId to its specific restriction parameters
     */
    struct YieldTokenRestrictionsStorage {
        /// @notice Mapping from yieldTokenId to restriction data
        mapping(uint256 => TransferRestrictionData) restrictionsById;
    }

    /// @custom:storage-location erc7201:rwa.storage.TransferRestrictions
    /// keccak256(abi.encode(uint256(keccak256("rwa.storage.TransferRestrictions")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TRANSFER_RESTRICTIONS_STORAGE_LOCATION = 
        0x43c39570a45a5d3dc0bba8859663155f33e33210cd87b04924328494bbfbaa00;

    /// @custom:storage-location erc7201:rwa.storage.YieldTokenRestrictions
    /// keccak256(abi.encode(uint256(keccak256("rwa.storage.YieldTokenRestrictions")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant YIELD_TOKEN_RESTRICTIONS_STORAGE_LOCATION = 
        0xf76f648740fb3b29b1bc1c5645ebe4e3f37188b193d1e9364144ecdc769d1100;

    /**
     * @notice Get storage pointer for transfer restrictions using ERC-7201 (for ERC-20)
     * @return $ Storage pointer to TransferRestrictionData
     */
    function getTransferRestrictionsStorage() internal pure returns (TransferRestrictionData storage $) {
        assembly {
            $.slot := TRANSFER_RESTRICTIONS_STORAGE_LOCATION
        }
    }

    /**
     * @notice Get storage pointer for per-yield-token restrictions using ERC-7201 (for ERC-1155)
     * @return $ Storage pointer to YieldTokenRestrictionsStorage
     */
    function getYieldTokenRestrictionsStorage() internal pure returns (YieldTokenRestrictionsStorage storage $) {
        assembly {
            $.slot := YIELD_TOKEN_RESTRICTIONS_STORAGE_LOCATION
        }
    }
}

