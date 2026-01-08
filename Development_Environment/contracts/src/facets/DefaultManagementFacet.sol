// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../libraries/YieldCalculations.sol";
import "../storage/YieldStorage.sol";
import "../storage/DiamondYieldStorage.sol";

/// @title DefaultManagementFacet
/// @notice Facet for handling missed payments and defaults in YieldBase Diamond
/// @dev Implements missed payment detection, penalty application, grace period management, and default triggering.
///      Uses ERC-7201 namespaced storage via DiamondYieldStorage for storage safety.
///      This facet handles the critical default management flow, including missed payment tracking, penalty calculation, and default status updates.
contract DefaultManagementFacet is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using YieldCalculations for uint256;
    using DiamondYieldStorage for DiamondYieldStorage.AgreementStorage;

    // ============ Events ============
    
    event PaymentMissed(
        uint256 indexed agreementId,
        uint256 missedPaymentCount,
        uint256 penaltyAmount
    );

    event AgreementDefaulted(
        uint256 indexed agreementId,
        uint256 totalArrears,
        uint256 timestamp
    );

    // ============ Custom Errors ============
    
    error AgreementNotActive(uint256 agreementId);
    error AgreementDoesNotExist(uint256 agreementId);
    error PaymentNotOverdue(uint256 agreementId);

    // ============ Internal Helpers ============
    
    /// @dev Validates that an agreement exists and is active
    function _validateAgreementActive(YieldStorage.YieldData storage yieldData, uint256 agreementId) internal view {
        if (yieldData.upfrontCapital == 0) revert AgreementDoesNotExist(agreementId);
        if (!yieldData.isActive) revert AgreementNotActive(agreementId);
    }
    
    /// @dev Validates that an agreement exists
    function _validateAgreementExists(YieldStorage.YieldData storage yieldData, uint256 agreementId) internal view {
        if (yieldData.upfrontCapital == 0) revert AgreementDoesNotExist(agreementId);
    }

    // ============ Default Management Functions ============

    /// @notice Handles missed payment detection and penalty application
    /// @dev Increments missed payment counter, calculates penalties, checks for default.
    ///      When an agreement reaches the default threshold, it enters a grace period.
    ///      If the grace period expires without payment, the agreement is marked as defaulted.
    ///      Only the contract owner can call this function (typically automated via keeper network).
    /// @param agreementId The ID of the agreement with missed payment
    function handleMissedPayment(uint256 agreementId) external onlyOwner {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        _validateAgreementActive(yieldData, agreementId);

        // Check if payment is actually overdue
        bool isOverdue = YieldCalculations.isRepaymentOverdue(
            yieldData.lastRepaymentTimestamp,
            yieldData.repaymentTermMonths
        );
        if (!isOverdue) revert PaymentNotOverdue(agreementId);

        // Update missed payment tracking
        yieldData.missedPaymentCount += 1;
        yieldData.lastMissedPaymentTimestamp = block.timestamp;

        // Calculate and apply penalty
        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(
            yieldData.upfrontCapital,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints
        );

        uint256 penalty = YieldCalculations.calculateDefaultPenalty(
            monthlyPayment,
            yieldData.defaultPenaltyRate,
            yieldData.missedPaymentCount
        );

        yieldData.accumulatedArrears += penalty;

        // Check if agreement should enter grace period (reaches default threshold)
        if (yieldData.missedPaymentCount >= yieldData.defaultThreshold && yieldData.gracePeriodExpiryTimestamp == 0) {
            // Start grace period
            yieldData.gracePeriodExpiryTimestamp = block.timestamp + (yieldData.gracePeriodDays * 1 days);
            emit PaymentMissed(agreementId, yieldData.missedPaymentCount, penalty);
        } else if (yieldData.gracePeriodExpiryTimestamp > 0 && block.timestamp >= yieldData.gracePeriodExpiryTimestamp) {
            // Grace period has expired - set to default
            yieldData.isInDefault = true;
            emit AgreementDefaulted(agreementId, yieldData.accumulatedArrears, block.timestamp);
        } else {
            // Either haven't reached threshold yet, or still in grace period
            emit PaymentMissed(agreementId, yieldData.missedPaymentCount, penalty);
        }
    }

    /// @notice Checks and updates default status for agreements that may have entered default
    /// @dev Should be called periodically to ensure agreements in default are properly flagged.
    ///      This function can be called by anyone and is typically automated via a keeper network.
    ///      It only updates the status if the grace period has expired and the agreement is not already in default.
    /// @param agreementId The ID of the yield agreement to check
    function checkAndUpdateDefaultStatus(uint256 agreementId) external {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        _validateAgreementActive(yieldData, agreementId);

        // Only check if not already in default and grace period is active
        if (!yieldData.isInDefault && yieldData.gracePeriodExpiryTimestamp > 0) {
            if (block.timestamp >= yieldData.gracePeriodExpiryTimestamp) {
                yieldData.isInDefault = true;
                emit AgreementDefaulted(agreementId, yieldData.accumulatedArrears, block.timestamp);
            }
        }
    }

    /// @notice Returns the timestamp of the last missed payment for debugging
    /// @dev Used for test debugging and analysis. Returns 0 if no payments have been missed.
    /// @param agreementId The ID of the yield agreement
    /// @return timestamp Timestamp of last missed payment (0 if none)
    function getLastMissedPaymentTimestamp(uint256 agreementId) external view returns (uint256 timestamp) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        return yieldData.lastMissedPaymentTimestamp;
    }

    /// @dev Required by OpenZeppelin's UUPSUpgradeable.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

