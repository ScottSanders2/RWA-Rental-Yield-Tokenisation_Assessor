// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";

/// @title Yield Calculations Library
/// @notice Pure mathematical functions for yield tokenization calculations
/// @dev Library functions are deployed once and linked at deployment time, reducing main contract bytecode size
/// All functions are pure (no state modifications) for gas efficiency and testability
library YieldCalculations {
    /// @notice Calculates the monthly repayment amount for a yield agreement
    /// @dev Uses compound interest formula: PMT = P * (r(1+r)^n) / ((1+r)^n - 1)
    /// Where: PMT = monthly payment, P = principal, r = monthly rate, n = number of payments
    /// @param upfrontCapital The initial capital amount (principal)
    /// @param termMonths The repayment term in months
    /// @param annualROIBasisPoints The annual ROI in basis points (e.g., 500 = 5%)
    /// @return The monthly repayment amount
    function calculateMonthlyRepayment(
        uint256 upfrontCapital,
        uint16 termMonths,
        uint16 annualROIBasisPoints
    ) internal pure returns (uint256) {
        // Simple calculation: principal / term + simple interest
        // This avoids complex compound interest calculations that can overflow
        uint256 principalPayment = upfrontCapital / termMonths;
        uint256 annualInterest = (upfrontCapital * annualROIBasisPoints) / 10000;
        uint256 monthlyInterest = annualInterest / 12;
        return principalPayment + monthlyInterest;
    }

    /// @notice Calculates the total repayment amount over the full term
    /// @param upfrontCapital The initial capital amount
    /// @param termMonths The repayment term in months
    /// @param annualROIBasisPoints The annual ROI in basis points
    /// @return The total amount to be repaid (principal + interest)
    function calculateTotalRepaymentAmount(
        uint256 upfrontCapital,
        uint16 termMonths,
        uint16 annualROIBasisPoints
    ) internal pure returns (uint256) {
        uint256 monthlyPayment = calculateMonthlyRepayment(upfrontCapital, termMonths, annualROIBasisPoints);
        return monthlyPayment * termMonths;
    }

    /// @notice Calculates pro-rata distribution for pooled investor repayments
    /// @dev Ensures proportional distribution when multiple investors contribute to the upfront capital
    /// @param totalAmount The total amount to distribute
    /// @param investorShares The investor's share of the total pool
    /// @param totalShares The total shares in the pool
    /// @return The amount allocated to this investor
    function calculateProRataDistribution(
        uint256 totalAmount,
        uint256 investorShares,
        uint256 totalShares
    ) internal pure returns (uint256) {
        require(totalShares > 0, "Total shares cannot be zero");
        return (totalAmount * investorShares) / totalShares;
    }

    /// @notice Checks if a repayment is overdue based on the last repayment timestamp
    /// @param lastRepaymentTimestamp The timestamp of the last repayment
    /// @param termMonths The total term in months (parameter kept for future extensibility)
    /// @return True if the last repayment was more than 30 days ago
    function isRepaymentOverdue(
        uint256 lastRepaymentTimestamp,
        uint16 termMonths
    ) internal view returns (bool) {
        // Use constant 30-day monthly interval for repayment checks
        uint256 monthlyInterval = 30 days;
        return block.timestamp > lastRepaymentTimestamp + monthlyInterval;
    }

    /// @dev Helper function to calculate (1 + r)^n with high precision
    /// @param monthlyRate The monthly interest rate (18 decimal places)
    /// @param termMonths The number of months
    /// @return The compound factor (1+r)^n (18 decimal places)
    function _calculateCompoundFactor(
        uint256 monthlyRate,
        uint16 termMonths
    ) private pure returns (uint256) {
        uint256 result = 1e18; // Start with 1.0 (18 decimal places)

        for (uint16 i = 0; i < termMonths; i++) {
            // result = result * (1 + monthlyRate)
            result = (result * (1e18 + monthlyRate)) / 1e18;
        }

        return result;
    }

    /// @notice Calculates cumulative penalty for missed payments
    /// @dev Uses penalty rate and missed payment count to calculate total penalty amount
    /// @param monthlyPayment The standard monthly payment amount
    /// @param penaltyRateBasisPoints The penalty rate in basis points (e.g., 200 = 2%)
    /// @param missedPaymentCount The number of consecutive missed payments
    /// @return The cumulative penalty amount
    function calculateDefaultPenalty(
        uint256 monthlyPayment,
        uint16 penaltyRateBasisPoints,
        uint8 missedPaymentCount
    ) internal pure returns (uint256) {
        if (missedPaymentCount == 0) return 0;

        uint256 penaltyPerMonth = (monthlyPayment * penaltyRateBasisPoints) / 10000;
        return penaltyPerMonth * missedPaymentCount;
    }

    /// @notice Calculates rebate for early lump-sum repayment
    /// @dev Provides incentive for prepayment by waiving portion of remaining interest
    /// @param remainingPrincipal The outstanding principal amount
    /// @param remainingInterest The remaining interest to be paid
    /// @param rebatePercentage The rebate percentage in basis points (e.g., 1000 = 10%)
    /// @return The rebate amount to deduct from remaining balance
    function calculateEarlyRepaymentRebate(
        uint256 remainingPrincipal,
        uint256 remainingInterest,
        uint16 rebatePercentage
    ) internal pure returns (uint256) {
        uint256 totalRemaining = remainingPrincipal + remainingInterest;
        return (totalRemaining * rebatePercentage) / 10000;
    }

    /// @notice Allocates partial payment between arrears and current obligation
    /// @dev Priority allocation: arrears first, then current payment
    /// @param paymentAmount The total payment amount received
    /// @param accumulatedArrears The current arrears balance
    /// @param currentMonthlyPayment The standard monthly payment amount
    /// @return arrearsPayment Amount allocated to arrears
    /// @return currentPayment Amount allocated to current payment
    function calculatePartialRepaymentAllocation(
        uint256 paymentAmount,
        uint256 accumulatedArrears,
        uint256 currentMonthlyPayment
    ) internal pure returns (uint256 arrearsPayment, uint256 currentPayment) {
        // First allocate to arrears
        arrearsPayment = paymentAmount >= accumulatedArrears ? accumulatedArrears : paymentAmount;

        // Remaining amount goes to current payment
        uint256 remainingAmount = paymentAmount - arrearsPayment;
        currentPayment = remainingAmount >= currentMonthlyPayment ? currentMonthlyPayment : remainingAmount;
    }

    /// @notice Determines if agreement is in default based on grace period and threshold
    /// @dev Uses predictable grace period calculation starting from threshold reach time
    /// @param lastRepaymentTimestamp Timestamp of last successful repayment
    /// @param lastMissedPaymentTimestamp Timestamp when last missed payment was recorded
    /// @param gracePeriodDays Grace period in days before penalties apply
    /// @param missedPaymentCount Current consecutive missed payment count
    /// @param defaultThreshold Number of missed payments that trigger default
    /// @return True if agreement is in default
    function isAgreementInDefault(
        uint256 lastRepaymentTimestamp,
        uint256 lastMissedPaymentTimestamp,
        uint16 gracePeriodDays,
        uint8 missedPaymentCount,
        uint8 defaultThreshold
    ) internal view returns (bool) {
        // Check if missed payment threshold reached
        if (missedPaymentCount < defaultThreshold) return false;

        // Use a more predictable grace period calculation
        // Start grace period from when threshold was reached, not from last missed payment
        uint256 thresholdReachedTime = lastMissedPaymentTimestamp - ((missedPaymentCount - defaultThreshold) * 30 days);
        uint256 gracePeriodExpiry = thresholdReachedTime + (gracePeriodDays * 1 days);

        return block.timestamp > gracePeriodExpiry;
    }

    /// @notice Calculates remaining balance including principal and interest
    /// @dev Simple calculation: total expected - repaid (for dissertation simplicity)
    /// @param upfrontCapital The original capital amount
    /// @param totalRepaid The cumulative amount repaid so far
    /// @param termMonths The total term in months
    /// @param annualROIBasisPoints The annual ROI in basis points
    /// @param elapsedMonths The number of months elapsed since agreement start
    /// @return The remaining balance (principal + interest)
    function calculateRemainingBalance(
        uint256 upfrontCapital,
        uint256 totalRepaid,
        uint16 termMonths,
        uint16 annualROIBasisPoints,
        uint256 elapsedMonths
    ) internal pure returns (uint256) {
        uint256 totalExpected = calculateTotalRepaymentAmount(upfrontCapital, termMonths, annualROIBasisPoints);
        return totalExpected > totalRepaid ? totalExpected - totalRepaid : 0;
    }

    /// @notice Calculates months elapsed since agreement start
    /// @dev Approximates months using 30-day periods for simplicity
    /// @param startTimestamp The agreement start timestamp
    /// @param currentTimestamp The current timestamp
    /// @return The number of months elapsed
    function calculateElapsedMonths(
        uint256 startTimestamp,
        uint256 currentTimestamp
    ) internal pure returns (uint256) {
        require(currentTimestamp >= startTimestamp, "Current timestamp before start");
        uint256 elapsedSeconds = currentTimestamp - startTimestamp;
        uint256 secondsPerMonth = 30 days; // Approximation
        return elapsedSeconds / secondsPerMonth;
    }

    /// @notice Calculates grace period expiry timestamp
    /// @dev Adds grace period days to last missed payment timestamp
    /// @param lastMissedPaymentTimestamp When the last missed payment was recorded
    /// @param gracePeriodDays Grace period in days
    /// @return The grace period expiry timestamp
    function calculateGracePeriodExpiry(
        uint256 lastMissedPaymentTimestamp,
        uint16 gracePeriodDays
    ) internal pure returns (uint256) {
        return lastMissedPaymentTimestamp + (gracePeriodDays * 1 days);
    }

    /// @notice Validates repayment amount based on configuration
    /// @dev Checks if payment amount is acceptable (full, partial, or zero)
    /// @param paymentAmount The payment amount received
    /// @param monthlyPayment The standard monthly payment amount
    /// @param allowPartial Whether partial payments are allowed
    /// @return True if payment amount is valid
    function validateRepaymentAmount(
        uint256 paymentAmount,
        uint256 monthlyPayment,
        bool allowPartial
    ) internal pure returns (bool) {
        if (paymentAmount == 0) return false; // Zero payments not allowed

        // Allow 1% tolerance (100 basis points) for overpayments and underpayments
        uint256 tolerance = (monthlyPayment * 100) / 10000; // 1% of monthly payment
        uint256 minAcceptable = monthlyPayment - tolerance;
        uint256 maxAcceptable = monthlyPayment + tolerance;

        if (allowPartial) {
            // For partial repayments, allow any amount up to the monthly payment
            return paymentAmount <= monthlyPayment && paymentAmount > 0;
        }
        return paymentAmount >= minAcceptable && paymentAmount <= maxAcceptable;
    }
}
