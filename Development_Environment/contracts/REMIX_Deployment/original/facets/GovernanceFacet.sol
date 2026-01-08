// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../storage/YieldStorage.sol";
import "../storage/DiamondYieldStorage.sol";

/// @title GovernanceFacet
/// @notice Facet for governance-controlled operations in YieldBase Diamond
/// @dev Implements ROI adjustments, reserve management, and agreement parameter updates.
///      All functions are restricted to the GovernanceController contract.
///      Uses ERC-7201 namespaced storage via DiamondYieldStorage for storage safety.
contract GovernanceFacet is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using DiamondYieldStorage for DiamondYieldStorage.AgreementStorage;

    // ============ Events ============
    
    event ROIAdjusted(uint256 indexed agreementId, uint16 oldROI, uint16 newROI);
    
    event ReserveAllocated(uint256 indexed agreementId, uint256 amount);
    
    event ReserveWithdrawn(uint256 indexed agreementId, uint256 amount);
    
    event AgreementGracePeriodUpdated(uint256 indexed agreementId, uint16 oldValue, uint16 newValue);
    
    event AgreementPenaltyRateUpdated(uint256 indexed agreementId, uint16 oldValue, uint16 newValue);
    
    event AgreementDefaultThresholdUpdated(uint256 indexed agreementId, uint8 oldValue, uint8 newValue);
    
    event AgreementAllowPartialRepaymentsUpdated(uint256 indexed agreementId, bool oldValue, bool newValue);
    
    event AgreementAllowEarlyRepaymentUpdated(uint256 indexed agreementId, bool oldValue, bool newValue);

    // ============ Custom Errors ============
    
    error GovernanceControllerNotSet();
    error UnauthorizedGovernanceCaller(address caller);
    error AgreementDoesNotExist(uint256 agreementId);
    error AgreementNotActive(uint256 agreementId);
    error InvalidROI(uint16 roi);
    error MustSendETHForReserve();
    error ReserveExceedsLimit(uint256 current, uint256 limit);
    error InvalidAmount();
    error InsufficientReserveBalance(uint256 requested, uint256 available);
    error InsufficientContractBalance(uint256 requested, uint256 available);
    error ReserveWithdrawalFailed();
    error InvalidGracePeriod(uint16 gracePeriod);
    error InvalidPenaltyRate(uint16 rate);
    error InvalidDefaultThreshold(uint8 threshold);

    // ============ Modifiers ============
    
    /// @notice Ensures caller is the governance controller
    modifier onlyGovernance() {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        if (agreements.governanceController == address(0)) revert GovernanceControllerNotSet();
        if (msg.sender != agreements.governanceController) revert UnauthorizedGovernanceCaller(msg.sender);
        _;
    }

    // ============ Internal Helpers ============
    
    /// @dev Validates that an agreement exists
    function _validateAgreementExists(YieldStorage.YieldData storage yieldData, uint256 agreementId) internal view {
        if (yieldData.upfrontCapital == 0) revert AgreementDoesNotExist(agreementId);
    }
    
    /// @dev Validates that an agreement exists and is active
    function _validateAgreementActive(YieldStorage.YieldData storage yieldData, uint256 agreementId) internal view {
        if (yieldData.upfrontCapital == 0) revert AgreementDoesNotExist(agreementId);
        if (!yieldData.isActive) revert AgreementNotActive(agreementId);
    }

    // ============ ROI Management ============

    /// @notice Adjusts the annual ROI for an active agreement via governance vote
    /// @dev Only callable by governance controller after successful proposal.
    ///      Requires agreement to be active. ROI must be between 1% and 50% (100-5000 basis points).
    /// @param agreementId The ID of the agreement to adjust
    /// @param newROI The new annual ROI in basis points (e.g., 500 = 5%)
    function adjustAgreementROI(uint256 agreementId, uint16 newROI) external onlyGovernance nonReentrant {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        _validateAgreementActive(yieldData, agreementId);
        
        if (newROI < 100 || newROI > 5000) revert InvalidROI(newROI);

        uint16 oldROI = yieldData.annualROIBasisPoints;
        yieldData.annualROIBasisPoints = newROI;

        emit ROIAdjusted(agreementId, oldROI, newROI);
    }

    // ============ Reserve Management ============

    /// @notice Allocate reserve to an agreement for default protection
    /// @dev Only callable by governance controller with ETH transfer.
    ///      Reserve is capped at 20% of the upfront capital.
    ///      This reserve can be used to cover investor losses in case of default.
    /// @param agreementId Agreement to allocate reserve for
    function allocateReserve(uint256 agreementId) external payable onlyGovernance {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        _validateAgreementExists(yieldData, agreementId);
        
        if (msg.value == 0) revert MustSendETHForReserve();

        // Validate reserve does not exceed 20% of upfront capital
        uint256 maxReserve = (yieldData.upfrontCapital * 2000) / 10000; // 20% in basis points
        uint256 newReserveBalance = yieldData.reserveBalance + msg.value;
        if (newReserveBalance > maxReserve) revert ReserveExceedsLimit(newReserveBalance, maxReserve);

        // Increment reserve balance for this agreement
        unchecked {
            yieldData.reserveBalance += msg.value; // Safe: validated above
        }

        emit ReserveAllocated(agreementId, msg.value);
    }

    /// @notice Withdraw reserve from an agreement
    /// @dev Only callable by governance controller for pro-rata distribution to investors.
    ///      Uses checks-effects-interactions pattern to prevent reentrancy.
    ///      Reserve is transferred back to the governance controller for distribution.
    /// @param agreementId Agreement to withdraw reserve from
    /// @param amount Amount to withdraw in wei
    function withdrawReserve(uint256 agreementId, uint256 amount) external onlyGovernance nonReentrant {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        _validateAgreementExists(yieldData, agreementId);
        
        if (amount == 0) revert InvalidAmount();
        if (yieldData.reserveBalance < amount) {
            revert InsufficientReserveBalance(amount, yieldData.reserveBalance);
        }
        if (address(this).balance < amount) {
            revert InsufficientContractBalance(amount, address(this).balance);
        }

        // Decrement reserve balance before transfer (checks-effects-interactions pattern)
        unchecked {
            yieldData.reserveBalance -= amount; // Safe: validated above
        }

        // Transfer reserve back to governance controller
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert ReserveWithdrawalFailed();

        emit ReserveWithdrawn(agreementId, amount);
    }

    /// @notice Get agreement reserve balance
    /// @dev Returns the reserve balance for an agreement
    /// @param agreementId Agreement to query reserve for
    /// @return reserveBalance Reserve balance in wei
    function getAgreementReserve(uint256 agreementId) external view returns (uint256 reserveBalance) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        if (yieldData.upfrontCapital == 0) revert AgreementDoesNotExist(agreementId);
        return yieldData.reserveBalance;
    }

    // ============ Agreement Parameter Update Functions ============

    /// @notice Update grace period for an agreement via governance
    /// @dev Only callable by governance controller after successful proposal.
    ///      Grace period is the number of days before default penalties apply.
    /// @param agreementId Agreement to update
    /// @param newGracePeriodDays New grace period in days (1-90)
    function setAgreementGracePeriod(uint256 agreementId, uint16 newGracePeriodDays) external onlyGovernance {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        _validateAgreementExists(yieldData, agreementId);
        
        if (newGracePeriodDays < 1 || newGracePeriodDays > 90) revert InvalidGracePeriod(newGracePeriodDays);
        
        uint16 oldValue = yieldData.gracePeriodDays;
        yieldData.gracePeriodDays = newGracePeriodDays;
        
        emit AgreementGracePeriodUpdated(agreementId, oldValue, newGracePeriodDays);
    }

    /// @notice Update default penalty rate for an agreement via governance
    /// @dev Only callable by governance controller after successful proposal.
    ///      Penalty rate is applied to late payments after the grace period expires.
    /// @param agreementId Agreement to update
    /// @param newPenaltyRate New penalty rate in basis points (100-2000 = 1%-20%)
    function setAgreementDefaultPenaltyRate(uint256 agreementId, uint16 newPenaltyRate) external onlyGovernance {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        _validateAgreementExists(yieldData, agreementId);
        
        if (newPenaltyRate < 100 || newPenaltyRate > 2000) revert InvalidPenaltyRate(newPenaltyRate);
        
        uint16 oldValue = yieldData.defaultPenaltyRate;
        yieldData.defaultPenaltyRate = newPenaltyRate;
        
        emit AgreementPenaltyRateUpdated(agreementId, oldValue, newPenaltyRate);
    }

    /// @notice Update default threshold for an agreement via governance
    /// @dev Only callable by governance controller after successful proposal.
    ///      Default threshold is the number of missed payments before the agreement defaults.
    /// @param agreementId Agreement to update
    /// @param newThreshold New default threshold in missed payments (1-12)
    function setAgreementDefaultThreshold(uint256 agreementId, uint8 newThreshold) external onlyGovernance {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        _validateAgreementExists(yieldData, agreementId);
        
        if (newThreshold < 1 || newThreshold > 12) revert InvalidDefaultThreshold(newThreshold);
        
        uint8 oldValue = yieldData.defaultThreshold;
        yieldData.defaultThreshold = newThreshold;
        
        emit AgreementDefaultThresholdUpdated(agreementId, oldValue, newThreshold);
    }

    /// @notice Update allowPartialRepayments flag for an agreement via governance
    /// @dev Only callable by governance controller after successful proposal.
    ///      When enabled, property owners can make partial repayments that are less than the monthly amount.
    /// @param agreementId Agreement to update
    /// @param newValue New value for allowPartialRepayments
    function setAgreementAllowPartialRepayments(uint256 agreementId, bool newValue) external onlyGovernance {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        _validateAgreementExists(yieldData, agreementId);
        
        bool oldValue = yieldData.allowPartialRepayments;
        yieldData.allowPartialRepayments = newValue;
        
        emit AgreementAllowPartialRepaymentsUpdated(agreementId, oldValue, newValue);
    }

    /// @notice Update allowEarlyRepayment flag for an agreement via governance
    /// @dev Only callable by governance controller after successful proposal.
    ///      When enabled, property owners can make early lump-sum repayments with a rebate incentive.
    /// @param agreementId Agreement to update
    /// @param newValue New value for allowEarlyRepayment
    function setAgreementAllowEarlyRepayment(uint256 agreementId, bool newValue) external onlyGovernance {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        _validateAgreementExists(yieldData, agreementId);
        
        bool oldValue = yieldData.allowEarlyRepayment;
        yieldData.allowEarlyRepayment = newValue;
        
        emit AgreementAllowEarlyRepaymentUpdated(agreementId, oldValue, newValue);
    }

    /// @dev Required by OpenZeppelin's UUPSUpgradeable.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

