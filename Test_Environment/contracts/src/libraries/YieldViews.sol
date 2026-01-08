// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../storage/YieldStorage.sol";
import "./YieldCalculations.sol";

/// @title YieldViews Library
/// @notice View functions extracted from YieldBase for bytecode optimization
/// @dev Reduces YieldBase contract size by ~4-6KB through library extraction
/// @dev All functions are view/pure and do not modify state
library YieldViews {
    using YieldCalculations for uint256;

    /// @notice Get comprehensive agreement status
    /// @dev Extracted from YieldBase.getAgreementStatus()
    /// @param _agreements Storage mapping of agreements
    /// @param agreementId Agreement to query
    /// @return isActive Whether agreement is active
    /// @return isInDefault Whether agreement is in default
    /// @return missedPaymentCount Number of missed payments
    /// @return accumulatedArrears Total arrears accumulated
    /// @return overpaymentCredit Available overpayment credit
    /// @return remainingBalance Remaining balance to be paid
    /// @return gracePeriodExpiry Timestamp when grace period expires
    /// @return nextPaymentDue Timestamp of next payment due
    function getAgreementStatus(
        mapping(uint256 => YieldStorage.YieldData) storage _agreements,
        uint256 agreementId
    ) internal view returns (
        bool isActive,
        bool isInDefault,
        uint8 missedPaymentCount,
        uint256 accumulatedArrears,
        uint256 overpaymentCredit,
        uint256 remainingBalance,
        uint256 gracePeriodExpiry,
        uint256 nextPaymentDue
    ) {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");

        uint256 elapsedMonths = YieldCalculations.calculateElapsedMonths(
            yieldData.lastRepaymentTimestamp,
            block.timestamp
        );

        remainingBalance = YieldCalculations.calculateRemainingBalance(
            yieldData.upfrontCapital,
            yieldData.totalRepaid,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints,
            elapsedMonths
        );

        gracePeriodExpiry = YieldCalculations.calculateGracePeriodExpiry(
            yieldData.lastMissedPaymentTimestamp,
            yieldData.gracePeriodDays
        );

        nextPaymentDue = yieldData.lastRepaymentTimestamp + 30 days;

        return (
            yieldData.isActive,
            yieldData.isInDefault,
            yieldData.missedPaymentCount,
            yieldData.accumulatedArrears,
            yieldData.overpaymentCredit,
            remainingBalance,
            gracePeriodExpiry,
            nextPaymentDue
        );
    }

    /// @notice Get outstanding balance including arrears
    /// @dev Extracted from YieldBase.getOutstandingBalance()
    /// @param _agreements Storage mapping of agreements
    /// @param agreementId Agreement to query
    /// @return outstandingBalance Total amount still owed
    function getOutstandingBalance(
        mapping(uint256 => YieldStorage.YieldData) storage _agreements,
        uint256 agreementId
    ) internal view returns (uint256 outstandingBalance) {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");

        uint256 elapsedMonths = YieldCalculations.calculateElapsedMonths(
            yieldData.lastRepaymentTimestamp,
            block.timestamp
        );

        uint256 remainingPrincipalAndInterest = YieldCalculations.calculateRemainingBalance(
            yieldData.upfrontCapital,
            yieldData.totalRepaid,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints,
            elapsedMonths
        );

        uint256 totalOwed = remainingPrincipalAndInterest + yieldData.accumulatedArrears;
        if (yieldData.overpaymentCredit >= totalOwed) {
            return 0;
        }
        return totalOwed - yieldData.overpaymentCredit;
    }

    /// @notice Get comprehensive agreement details
    /// @dev Extracted from YieldBase.getAgreement()
    /// @param _agreements Storage mapping of agreements
    /// @param agreementId Agreement to query
    /// @return propertyTokenId Associated property NFT token ID
    /// @return upfrontCapital Initial capital amount
    /// @return termMonths Repayment term in months
    /// @return annualROI Annual ROI in basis points
    /// @return totalRepaid Total amount repaid so far
    /// @return isActive Whether agreement is active
    /// @return isInDefault Whether agreement is in default
    /// @return allowPartialRepayments Whether partial repayments allowed
    /// @return allowEarlyRepayment Whether early repayment allowed
    /// @return gracePeriodDays Grace period in days
    /// @return defaultPenaltyRate Default penalty rate in basis points
    function getAgreement(
        mapping(uint256 => YieldStorage.YieldData) storage _agreements,
        uint256 agreementId
    ) internal view returns (
        uint256 propertyTokenId,
        uint256 upfrontCapital,
        uint16 termMonths,
        uint16 annualROI,
        uint256 totalRepaid,
        bool isActive,
        bool isInDefault,
        bool allowPartialRepayments,
        bool allowEarlyRepayment,
        uint16 gracePeriodDays,
        uint16 defaultPenaltyRate
    ) {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");

        return (
            yieldData.propertyTokenId,
            yieldData.upfrontCapital,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints,
            yieldData.totalRepaid,
            yieldData.isActive,
            yieldData.isInDefault,
            yieldData.allowPartialRepayments,
            yieldData.allowEarlyRepayment,
            yieldData.gracePeriodDays,
            yieldData.defaultPenaltyRate
        );
    }

    /// @notice Get detailed yield agreement information
    /// @dev Extracted from YieldBase.getYieldAgreement()
    /// @param _agreements Storage mapping of agreements
    /// @param agreementId Agreement to query
    /// @return upfrontCapital The upfront capital amount
    /// @return termMonths The repayment term in months
    /// @return annualROI The annual ROI in basis points
    /// @return totalRepaid The total amount repaid so far
    /// @return isActive Whether the agreement is still active
    /// @return monthlyPayment The calculated monthly payment amount
    function getYieldAgreement(
        mapping(uint256 => YieldStorage.YieldData) storage _agreements,
        uint256 agreementId
    ) internal view returns (
        uint256 upfrontCapital,
        uint16 termMonths,
        uint16 annualROI,
        uint256 totalRepaid,
        bool isActive,
        uint256 monthlyPayment
    ) {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");

        monthlyPayment = YieldCalculations.calculateMonthlyRepayment(
            yieldData.upfrontCapital,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints
        );

        return (
            yieldData.upfrontCapital,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints,
            yieldData.totalRepaid,
            yieldData.isActive,
            monthlyPayment
        );
    }
}

