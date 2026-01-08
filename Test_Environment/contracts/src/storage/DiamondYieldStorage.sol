// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../YieldSharesToken.sol";
import "./YieldStorage.sol";

/// @title DiamondYieldStorage
/// @notice ERC-7201 namespaced storage for YieldBase Diamond facets
/// @dev Prevents storage collisions between facets by using namespaced slots
///      This is CRITICAL for Diamond pattern safety - all facets MUST use these storage accessors
library DiamondYieldStorage {
    // ============ ERC-7201 Storage Namespaces ============
    
    /// @notice Storage namespace for core agreement data
    /// @dev Uses ERC-7201 pattern: keccak256(abi.encode(uint256(keccak256("yieldbase.diamond.agreement.storage")) - 1)) & ~bytes32(uint256(0xff))
    function getAgreementStorageSlot() private pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("yieldbase.diamond.agreement.storage")) - 1)) & ~bytes32(uint256(0xff));
    }
    
    /// @notice Storage namespace for repayment tracking
    /// @dev Uses ERC-7201 pattern: keccak256(abi.encode(uint256(keccak256("yieldbase.diamond.repayment.storage")) - 1)) & ~bytes32(uint256(0xff))
    function getRepaymentStorageSlot() private pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("yieldbase.diamond.repayment.storage")) - 1)) & ~bytes32(uint256(0xff));
    }
    
    /// @notice Storage namespace for governance data
    /// @dev Uses ERC-7201 pattern: keccak256(abi.encode(uint256(keccak256("yieldbase.diamond.governance.storage")) - 1)) & ~bytes32(uint256(0xff))
    function getGovernanceStorageSlot() private pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("yieldbase.diamond.governance.storage")) - 1)) & ~bytes32(uint256(0xff));
    }
    
    /// @notice Storage namespace for default management
    /// @dev Uses ERC-7201 pattern: keccak256(abi.encode(uint256(keccak256("yieldbase.diamond.default.storage")) - 1)) & ~bytes32(uint256(0xff))
    function getDefaultStorageSlot() private pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256("yieldbase.diamond.default.storage")) - 1)) & ~bytes32(uint256(0xff));
    }

    // ============ Storage Structs ============
    
    /// @notice Core agreement storage (used by YieldBaseFacet, ViewsFacet)
    struct AgreementStorage {
        /// @notice Mapping from agreement ID to agreement data
        mapping(uint256 => YieldStorage.YieldData) agreements;
        
        /// @notice Mapping from agreement ID to YieldSharesToken contract
        mapping(uint256 => YieldSharesToken) agreementTokens;
        
        /// @notice Counter for agreement IDs
        uint256 agreementCount;
        
        /// @notice Address of the PropertyNFT contract
        address propertyNFT;
        
        /// @notice Address of the GovernanceController contract
        address governanceController;
        
        /// @notice Mapping from property token ID to agreement ID
        mapping(uint256 => uint256) propertyToAgreement;
        
        /// @notice Mapping from agreement ID to authorized payer address
        mapping(uint256 => address) authorizedPayers;
    }
    
    /// @notice Repayment tracking storage (used by RepaymentFacet)
    struct RepaymentStorage {
        /// @notice Mapping from agreement ID to total repayment amount
        mapping(uint256 => uint256) totalRepayments;
        
        /// @notice Mapping from agreement ID to last repayment timestamp
        mapping(uint256 => uint256) lastRepaymentTimestamps;
        
        /// @notice Mapping from agreement ID to overpayment credit balance
        mapping(uint256 => uint256) overpaymentCredits;
        
        /// @notice Mapping from agreement ID to accumulated arrears
        mapping(uint256 => uint256) accumulatedArrears;
        
        /// @notice Mapping from agreement ID to prepayment amount
        mapping(uint256 => uint256) prepaymentAmounts;
    }
    
    /// @notice Governance storage (used by GovernanceFacet)
    struct GovernanceStorage {
        /// @notice Mapping from agreement ID to reserve balance
        mapping(uint256 => uint256) reserveBalances;
        
        /// @notice Mapping from agreement ID to grace period days
        mapping(uint256 => uint16) gracePeriods;
        
        /// @notice Mapping from agreement ID to default penalty rate (basis points)
        mapping(uint256 => uint16) penaltyRates;
        
        /// @notice Mapping from agreement ID to default threshold (missed payments)
        mapping(uint256 => uint8) defaultThresholds;
    }
    
    /// @notice Default management storage (used by DefaultManagementFacet)
    struct DefaultStorage {
        /// @notice Mapping from agreement ID to missed payment count
        mapping(uint256 => uint8) missedPaymentCounts;
        
        /// @notice Mapping from agreement ID to default status
        mapping(uint256 => bool) inDefault;
        
        /// @notice Mapping from agreement ID to default trigger timestamp
        mapping(uint256 => uint256) defaultTriggeredAt;
        
        /// @notice Mapping from agreement ID to total penalties accumulated
        mapping(uint256 => uint256) accumulatedPenalties;
    }

    // ============ Storage Accessors ============
    
    /// @notice Get the agreement storage reference
    /// @dev Uses assembly to load storage at the namespaced slot
    /// @return $ Storage reference to AgreementStorage
    function getAgreementStorage() internal pure returns (AgreementStorage storage $) {
        bytes32 slot = getAgreementStorageSlot();
        assembly {
            $.slot := slot
        }
    }
    
    /// @notice Get the repayment storage reference
    /// @dev Uses assembly to load storage at the namespaced slot
    /// @return $ Storage reference to RepaymentStorage
    function getRepaymentStorage() internal pure returns (RepaymentStorage storage $) {
        bytes32 slot = getRepaymentStorageSlot();
        assembly {
            $.slot := slot
        }
    }
    
    /// @notice Get the governance storage reference
    /// @dev Uses assembly to load storage at the namespaced slot
    /// @return $ Storage reference to GovernanceStorage
    function getGovernanceStorage() internal pure returns (GovernanceStorage storage $) {
        bytes32 slot = getGovernanceStorageSlot();
        assembly {
            $.slot := slot
        }
    }
    
    /// @notice Get the default management storage reference
    /// @dev Uses assembly to load storage at the namespaced slot
    /// @return $ Storage reference to DefaultStorage
    function getDefaultStorage() internal pure returns (DefaultStorage storage $) {
        bytes32 slot = getDefaultStorageSlot();
        assembly {
            $.slot := slot
        }
    }
    
    // ============ Storage Migration Helpers ============
    
    /// @notice Migrate agreement data from old YieldBase to Diamond storage
    /// @dev Called once during Diamond deployment to copy existing data
    /// @param agreementId Agreement ID to migrate
    /// @param oldAgreement Agreement data from old contract
    function migrateAgreementData(
        uint256 agreementId,
        YieldStorage.YieldData memory oldAgreement
    ) internal {
        AgreementStorage storage agreements = getAgreementStorage();
        agreements.agreements[agreementId] = oldAgreement;
    }
    
    /// @notice Verify no storage collisions between namespaced slots
    /// @dev Should be called in tests to ensure safety
    /// @return success True if all slots are unique
    function verifyStorageSlots() internal pure returns (bool success) {
        bytes32 agreementSlot = getAgreementStorageSlot();
        bytes32 repaymentSlot = getRepaymentStorageSlot();
        bytes32 governanceSlot = getGovernanceStorageSlot();
        bytes32 defaultSlot = getDefaultStorageSlot();
        
        // Ensure all slots are different
        require(agreementSlot != repaymentSlot, "Agreement/Repayment slot collision");
        require(agreementSlot != governanceSlot, "Agreement/Governance slot collision");
        require(agreementSlot != defaultSlot, "Agreement/Default slot collision");
        require(repaymentSlot != governanceSlot, "Repayment/Governance slot collision");
        require(repaymentSlot != defaultSlot, "Repayment/Default slot collision");
        require(governanceSlot != defaultSlot, "Governance/Default slot collision");
        
        return true;
    }
}

