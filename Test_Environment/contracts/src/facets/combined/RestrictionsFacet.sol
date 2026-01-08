// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../../storage/CombinedTokenStorage.sol";
import "../../storage/TransferRestrictionsStorage.sol";
import "../../libraries/CombinedTokenDistribution.sol";
import "../../libraries/TransferRestrictions.sol";

/// @title RestrictionsFacet
/// @notice Facet for managing transfer restrictions on yield tokens
/// @dev Handles lockup periods, max shares per investor, holding periods, and emergency pausing
contract RestrictionsFacet is ERC1155Upgradeable, OwnableUpgradeable {
    using CombinedTokenStorage for CombinedTokenStorage.CombinedTokenStorageLayout;

    // ============ Events ============
    
    event YieldTokenRestrictionsUpdated(
        uint256 indexed yieldTokenId,
        uint256 lockupEndTimestamp,
        uint256 maxSharesPerInvestor
    );
    
    event YieldTokenTransfersPaused(uint256 indexed yieldTokenId);
    event YieldTokenTransfersUnpaused(uint256 indexed yieldTokenId);

    // ============ Custom Errors ============
    
    error NotAYieldTokenID();

    // ============ Restriction Management ============

    /// @notice Set comprehensive restrictions for a yield token
    /// @param yieldTokenId The yield token ID
    /// @param lockupEndTimestamp Timestamp when lockup period ends (0 = no lockup)
    /// @param maxSharesPerInvestor Maximum shares per investor in basis points (e.g., 2000 = 20%)
    /// @param minHoldingPeriod Minimum holding period in seconds (e.g., 7 days = 604800)
    function setYieldTokenRestrictions(
        uint256 yieldTokenId,
        uint256 lockupEndTimestamp,
        uint256 maxSharesPerInvestor,
        uint256 minHoldingPeriod
    ) external onlyOwner {
        if (!CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false)) {
            revert NotAYieldTokenID();
        }
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.lockupEndTimestamp = lockupEndTimestamp;
        restrictions.maxSharesPerInvestor = maxSharesPerInvestor;
        restrictions.minHoldingPeriod = minHoldingPeriod;
        
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        layout.yieldTokenRestrictionsEnabled[yieldTokenId] = true;
        
        emit YieldTokenRestrictionsUpdated(yieldTokenId, lockupEndTimestamp, maxSharesPerInvestor);
    }

    /// @notice Pause transfers for a specific yield token (emergency control)
    /// @param yieldTokenId The yield token ID to pause
    function pauseYieldTokenTransfers(uint256 yieldTokenId) external onlyOwner {
        if (!CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false)) {
            revert NotAYieldTokenID();
        }
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.isTransferPaused = true;
        
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        layout.yieldTokenRestrictionsEnabled[yieldTokenId] = true;
        
        emit YieldTokenTransfersPaused(yieldTokenId);
    }

    /// @notice Unpause transfers for a specific yield token
    /// @param yieldTokenId The yield token ID to unpause
    function unpauseYieldTokenTransfers(uint256 yieldTokenId) external onlyOwner {
        if (!CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false)) {
            revert NotAYieldTokenID();
        }
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.isTransferPaused = false;
        
        emit YieldTokenTransfersUnpaused(yieldTokenId);
    }

    /// @notice Set lockup end timestamp for a yield token
    /// @param yieldTokenId The yield token ID
    /// @param lockupEndTimestamp Timestamp when lockup period ends (0 = no lockup)
    function setYieldTokenLockupEndTimestamp(
        uint256 yieldTokenId, 
        uint256 lockupEndTimestamp
    ) external onlyOwner {
        if (!CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false)) {
            revert NotAYieldTokenID();
        }
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.lockupEndTimestamp = lockupEndTimestamp;
        
        emit YieldTokenRestrictionsUpdated(
            yieldTokenId, 
            lockupEndTimestamp, 
            restrictions.maxSharesPerInvestor
        );
    }

    /// @notice Set maximum shares per investor for a yield token
    /// @param yieldTokenId The yield token ID
    /// @param maxSharesPerInvestor Maximum shares in basis points (e.g., 2000 = 20%)
    function setYieldTokenMaxSharesPerInvestor(
        uint256 yieldTokenId, 
        uint256 maxSharesPerInvestor
    ) external onlyOwner {
        if (!CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false)) {
            revert NotAYieldTokenID();
        }
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.maxSharesPerInvestor = maxSharesPerInvestor;
        
        emit YieldTokenRestrictionsUpdated(
            yieldTokenId, 
            restrictions.lockupEndTimestamp, 
            maxSharesPerInvestor
        );
    }

    /// @notice Set minimum holding period for a yield token
    /// @param yieldTokenId The yield token ID
    /// @param minHoldingPeriod Minimum holding period in seconds (e.g., 7 days = 604800)
    function setYieldTokenMinHoldingPeriod(
        uint256 yieldTokenId, 
        uint256 minHoldingPeriod
    ) external onlyOwner {
        if (!CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false)) {
            revert NotAYieldTokenID();
        }
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.minHoldingPeriod = minHoldingPeriod;
        
        emit YieldTokenRestrictionsUpdated(
            yieldTokenId, 
            restrictions.lockupEndTimestamp, 
            restrictions.maxSharesPerInvestor
        );
    }

    /// @notice Check if a yield token transfer would be allowed
    /// @dev View function for frontend validation
    /// @param yieldTokenId The yield token ID
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Amount to transfer
    /// @return allowed Whether the transfer is allowed
    /// @return reason Reason if not allowed
    function checkYieldTokenTransfer(
        uint256 yieldTokenId,
        address from,
        address to,
        uint256 amount
    ) external view returns (bool allowed, string memory reason) {
        if (!CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false)) {
            return (false, "Not a yield token ID");
        }

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        if (!layout.yieldTokenRestrictionsEnabled[yieldTokenId]) {
            return (true, "");
        }

        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];

        return TransferRestrictions.validateAllRestrictions(
            from,
            to,
            amount,
            balanceOf(to, yieldTokenId),
            layout.totalSupply[yieldTokenId],
            restrictions
        );
    }
}

