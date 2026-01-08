// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Yield Storage Library
/// @notice Implements ERC-7201 namespaced storage pattern for yield tokenization data
/// @dev ERC-7201 ensures storage isolation during contract upgrades by using deterministic namespace calculation
/// This prevents collisions between inherited contract storage and custom storage variables
library YieldStorage {
    /// @dev ERC-7201 namespace identifier for yield data
    /// @notice Calculated as: keccak256(abi.encode(uint256(keccak256("rwa.storage.Yield")) - 1)) & ~bytes32(uint256(0xff))
    /// This creates a deterministic, collision-resistant storage slot
    bytes32 private constant YIELD_STORAGE_SLOT = keccak256(abi.encode(uint256(keccak256("rwa.storage.Yield")) - 1)) & ~bytes32(uint256(0xff));

    /// @dev Storage structure for yield agreement data
    /// @notice Enhanced with autonomous yield management features: default tracking, partial repayment handling, early repayment support
    struct YieldData {
        // Slot 0
        uint256 upfrontCapital;           // Amount of capital requested upfront by property owner
        // Slot 1 (packed)
        uint16 repaymentTermMonths;       // Duration of repayment period in months (max ~18 years)
        uint16 annualROIBasisPoints;      // Annual return on investment in basis points (e.g., 500 = 5%)
        // Slot 2
        uint256 totalRepaid;              // Cumulative amount repaid to investors
        // Slot 3
        uint256 lastRepaymentTimestamp;   // Timestamp of last repayment for term enforcement
        // Slot 4 (packed)
        bool isActive;                    // Whether the yield agreement is currently active
        uint8 missedPaymentCount;         // Consecutive missed monthly payments for default determination
        uint16 gracePeriodDays;           // Configurable grace period before default penalties apply (e.g., 30 days)
        // Slot 5
        uint256 accumulatedArrears;       // Unpaid amounts from partial/missed payments
        // Slot 6
        uint256 overpaymentCredit;        // Excess payments that can offset future obligations
        // Slot 7
        uint256 prepaymentAmount;         // Lump-sum early repayments for rebate calculations
        // Slot 8 (packed)
        uint16 defaultPenaltyRate;        // Penalty rate in basis points for late payments (e.g., 200 = 2%)
        uint256 lastMissedPaymentTimestamp; // Timestamp of last missed payment for grace period tracking
        // Slot 9
        uint256 gracePeriodExpiryTimestamp; // When the current grace period expires (0 if not in grace period)
        // Slot 10 (packed)
        bool isInDefault;                 // Default status flag
        bool allowPartialRepayments;      // Configuration flag for partial payment acceptance
        bool allowEarlyRepayment;         // Configuration flag for early repayment incentives
        uint8 defaultThreshold;           // Number of missed payments before default (e.g., 3)
        uint256 propertyTokenId;          // Reference to associated ERC-721 property NFT (future integration)
        // Slot 11
        uint256 reserveBalance;           // Reserve balance allocated to this agreement for default protection
    }


    /// @notice Returns a storage pointer to the namespaced YieldData location
    /// @dev Uses inline assembly to access the predetermined storage slot
    /// @return data Storage pointer to the YieldData struct
    function getYieldStorage() internal pure returns (YieldData storage data) {
        bytes32 slot = YIELD_STORAGE_SLOT;
        assembly {
            data.slot := slot
        }
    }
}
