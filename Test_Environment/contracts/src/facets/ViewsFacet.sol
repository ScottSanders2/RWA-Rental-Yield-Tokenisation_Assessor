// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../libraries/YieldViews.sol";
import "../storage/YieldStorage.sol";
import "../storage/DiamondYieldStorage.sol";

/// @title ViewsFacet
/// @notice Facet for all view/read-only operations in YieldBase Diamond
/// @dev Implements comprehensive view functions for querying agreement data, status, and balances.
///      All functions are read-only (view) and gas-efficient.
///      Uses YieldViews library for complex calculations and ERC-7201 namespaced storage.
contract ViewsFacet is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using DiamondYieldStorage for DiamondYieldStorage.AgreementStorage;

    // ============ Custom Errors ============
    
    error AgreementDoesNotExist(uint256 agreementId);

    // ============ View Functions ============

    /// @notice Get comprehensive agreement details including all parameters
    /// @dev Returns all agreement data needed for governance validation and frontend display.
    ///      This is the primary function for retrieving complete agreement information.
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
    function getAgreement(uint256 agreementId) external view returns (
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
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return YieldViews.getAgreement(agreements.agreements, agreementId);
    }

    /// @notice Returns comprehensive agreement status including default information
    /// @dev Provides detailed status for autonomous decision making.
    ///      Calculates remaining balance, next payment due, and grace period expiry dynamically.
    /// @param agreementId The ID of the yield agreement
    /// @return isActive Whether the agreement is active
    /// @return isInDefault Whether the agreement is in default
    /// @return missedPaymentCount Number of missed payments
    /// @return accumulatedArrears Total arrears accumulated
    /// @return overpaymentCredit Available overpayment credit
    /// @return remainingBalance Remaining balance to be paid
    /// @return gracePeriodExpiry Timestamp when grace period expires
    /// @return nextPaymentDue Timestamp when next payment is due
    function getAgreementStatus(uint256 agreementId) external view returns (
        bool isActive,
        bool isInDefault,
        uint8 missedPaymentCount,
        uint256 accumulatedArrears,
        uint256 overpaymentCredit,
        uint256 remainingBalance,
        uint256 gracePeriodExpiry,
        uint256 nextPaymentDue
    ) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return YieldViews.getAgreementStatus(agreements.agreements, agreementId);
    }

    /// @notice Returns the outstanding balance including principal, interest, and arrears
    /// @dev Calculates total amount still owed on the agreement, accounting for overpayment credits.
    ///      This is the amount the property owner needs to pay to complete the agreement.
    /// @param agreementId The ID of the yield agreement
    /// @return outstandingBalance Total amount still owed
    function getOutstandingBalance(uint256 agreementId) external view returns (uint256 outstandingBalance) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return YieldViews.getOutstandingBalance(agreements.agreements, agreementId);
    }

    /// @notice Returns the details of the yield agreement
    /// @dev MULTIPLE AGREEMENT SUPPORT: Returns data for the specified agreement ID.
    ///      Reads from ERC-7201 namespaced storage. Gas-efficient view function.
    ///      Includes calculated monthly payment for convenience.
    /// @param agreementId The ID of the yield agreement
    /// @return upfrontCapital The upfront capital amount
    /// @return termMonths The repayment term in months
    /// @return annualROI The annual ROI in basis points
    /// @return totalRepaid The total amount repaid so far
    /// @return isActive Whether the agreement is still active
    /// @return monthlyPayment The calculated monthly payment amount
    function getYieldAgreement(uint256 agreementId)
        external
        view
        returns (
            uint256 upfrontCapital,
            uint16 termMonths,
            uint16 annualROI,
            uint256 totalRepaid,
            bool isActive,
            uint256 monthlyPayment
        )
    {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return YieldViews.getYieldAgreement(agreements.agreements, agreementId);
    }

    /// @notice Returns the payer address for an agreement for debugging
    /// @dev Used for test debugging and analysis. Returns the address authorized to make repayments.
    ///      Zero address means only the agreement creator (property owner) can make repayments.
    /// @param agreementId The ID of the yield agreement
    /// @return payer The address authorized to make repayments
    function getAgreementPayer(uint256 agreementId) external view returns (address payer) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return agreements.authorizedPayers[agreementId];
    }

    /// @dev Required by OpenZeppelin's UUPSUpgradeable.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

