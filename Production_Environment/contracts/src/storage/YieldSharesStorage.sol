// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Yield Shares Storage Library
/// @notice Implements ERC-7201 namespaced storage pattern for ERC-20 token data
/// @dev ERC-7201 ensures storage isolation during contract upgrades by using deterministic namespace calculation
/// This prevents collisions between inherited ERC20Upgradeable storage and custom token storage variables
/// Separate namespace from YieldStorage enables independent upgradeability of both contracts
library YieldSharesStorage {
    /// @dev ERC-7201 namespace identifier for yield shares token data
    /// @notice Calculated as: keccak256(abi.encode(uint256(keccak256("rwa.storage.YieldShares")) - 1)) & ~bytes32(uint256(0xff))
    /// This creates a deterministic, collision-resistant storage slot independent from YieldStorage
    bytes32 private constant YIELD_SHARES_STORAGE_SLOT = keccak256(abi.encode(uint256(keccak256("rwa.storage.YieldShares")) - 1)) & ~bytes32(uint256(0xff));

    /// @dev Storage structure for yield shares token data
    /// @notice Enhanced with pooled capital contribution tracking to support multi-investor upfront capital
    /// @dev SINGLE AGREEMENT CONSTRAINT: This token instance supports only one agreement to prevent bookkeeping complexity
    struct YieldSharesData {
        // Slot 0
        address yieldBaseContract;        // Reference to YieldBase contract for access control validation
        uint256 currentAgreementId;       // The single agreement ID this token instance supports

        // Slot 1 - Shares and shareholder tracking (scoped to single agreement)
        uint256 totalShares;              // Total shares minted for the current agreement
        uint256 shareholderCount;         // Number of unique shareholders for the current agreement

        // Slot 2 - Shareholder tracking arrays
        address[] shareholderAddresses;   // Array of shareholder addresses for the current agreement

        // Slot 3 - Shareholder-to-shares mappings
        mapping(address => uint256) shareholderShares;  // Shares held by each address for the current agreement

        // Slot 4 - Shareholder membership mapping (for O(1) lookups)
        mapping(address => bool) isShareholder;  // Whether an address is a shareholder for the current agreement

        // Slot 5 - Unclaimed remainder tracking
        mapping(address => uint256) unclaimedRemainder;  // Unclaimed ETH due to failed transfers or rounding dust

        // Slot 6 - Pooled capital contribution tracking
        mapping(address => uint256) pooledContributions; // Capital contributed by each investor during agreement creation
        address[] contributorAddresses;    // Array of addresses who contributed to upfront capital pool
        uint256 totalPooledCapital;       // Sum of all pooled contributions for validation

        // Slot 7 - Contributor membership tracking (for O(1) lookups)
        mapping(address => bool) isContributor; // Whether an address is a contributor to the capital pool
        uint256 contributorCount;         // Number of unique contributors to the capital pool
    }

    /// @notice Returns a storage pointer to the namespaced YieldSharesData location
    /// @dev Uses inline assembly to access the predetermined storage slot
    /// @return data Storage pointer to the YieldSharesData struct
    function getYieldSharesStorage() internal pure returns (YieldSharesData storage data) {
        bytes32 slot = YIELD_SHARES_STORAGE_SLOT;
        assembly {
            data.slot := slot
        }
    }
}
