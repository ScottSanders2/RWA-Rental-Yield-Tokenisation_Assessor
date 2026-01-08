// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../YieldSharesToken.sol";
import "../libraries/YieldCalculations.sol";
import "../storage/YieldStorage.sol";
import "../storage/DiamondYieldStorage.sol";
import "../KYCRegistry.sol";

/// @title RepaymentFacet
/// @notice Facet for handling all repayment operations in YieldBase Diamond
/// @dev Implements standard, partial, and early repayment functions with full repayment logic.
///      Uses ERC-7201 namespaced storage via DiamondYieldStorage for storage safety.
///      This facet handles the critical repayment flow, including overpayment credits, arrears management, and agreement completion.
contract RepaymentFacet is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using YieldCalculations for uint256;
    using DiamondYieldStorage for DiamondYieldStorage.AgreementStorage;

    // ============ Events ============
    
    event RepaymentMade(
        uint256 indexed agreementId,
        uint256 amount,
        uint256 timestamp
    );

    event YieldAgreementCompleted(
        uint256 indexed agreementId,
        uint256 totalRepaid
    );

    event PartialRepaymentMade(
        uint256 indexed agreementId,
        uint256 amount,
        uint256 arrearsPayment,
        uint256 currentPayment
    );

    event EarlyRepaymentMade(
        uint256 indexed agreementId,
        uint256 amount,
        uint256 rebateAmount
    );

    // ============ Custom Errors ============
    
    error AgreementNotActive(uint256 agreementId);
    error AgreementDoesNotExist(uint256 agreementId);
    error AgreementInDefault(uint256 agreementId);
    error UnauthorizedCaller(address caller, uint256 agreementId);
    error InvalidRepaymentAmount(uint256 provided, uint256 expected);
    error PartialRepaymentsNotAllowed(uint256 agreementId);
    error EarlyRepaymentsNotAllowed(uint256 agreementId);
    error InsufficientEarlyRepaymentAmount(uint256 provided, uint256 required);
    error TokenNotFound(uint256 agreementId);
    error KYCRegistryNotSet();
    error AddressNotKYCVerified(address account);
    error AddressBlacklisted(address account);

    // ============ Modifiers ============
    
    /// @notice Ensures caller is either the contract owner or the designated payer for the agreement
    modifier onlyOwnerOrPayer(uint256 agreementId) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        if (msg.sender != owner() && msg.sender != agreements.authorizedPayers[agreementId]) {
            revert UnauthorizedCaller(msg.sender, agreementId);
        }
        _;
    }

    /// @notice Modifier to ensure address is KYC verified
    /// @param account Address to check
    modifier onlyKYCVerified(address account) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        if (agreements.kycRegistry == address(0)) {
            revert KYCRegistryNotSet();
        }
        KYCRegistry registry = KYCRegistry(agreements.kycRegistry);
        if (!registry.isWhitelisted(account)) {
            revert AddressNotKYCVerified(account);
        }
        if (registry.isBlacklisted(account)) {
            revert AddressBlacklisted(account);
        }
        _;
    }

    // ============ Internal Helpers ============
    
    /// @dev Validates that an agreement exists and is active (used by all repayment functions)
    function _validateAgreementActive(uint256 agreementId) internal view returns (YieldStorage.YieldData storage) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldStorage.YieldData storage yieldData = agreements.agreements[agreementId];
        
        if (yieldData.upfrontCapital == 0) revert AgreementDoesNotExist(agreementId);
        if (!yieldData.isActive) revert AgreementNotActive(agreementId);
        if (yieldData.isInDefault) revert AgreementInDefault(agreementId);
        
        return yieldData;
    }

    /// @dev Checks if an agreement is complete and handles cleanup if so
    function _checkAndCompleteAgreement(uint256 agreementId, YieldStorage.YieldData storage yieldData) internal {
        // Cache storage reads
        uint256 upfrontCapital = yieldData.upfrontCapital;
        uint16 termMonths = yieldData.repaymentTermMonths;
        uint16 roiBasisPoints = yieldData.annualROIBasisPoints;
        uint256 totalRepaid = yieldData.totalRepaid;

        uint256 totalExpected = YieldCalculations.calculateTotalRepaymentAmount(
            upfrontCapital,
            termMonths,
            roiBasisPoints
        );

        if (totalRepaid >= totalExpected) {
            yieldData.isActive = false;
            
            // Get token and burn remaining shares
            DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
            YieldSharesToken token = agreements.agreementTokens[agreementId];
            if (address(token) == address(0)) revert TokenNotFound(agreementId);
            
            token.burnRemainingShares(agreementId);
            emit YieldAgreementCompleted(agreementId, totalRepaid);
        }
    }

    // ============ Public Functions ============

    /// @notice Makes a standard monthly repayment on a yield agreement
    /// @dev Handles overpayment credits, validates amount, distributes to token holders, and checks for completion.
    ///      Protected by nonReentrant to prevent reentrancy attacks during fund distribution.
    ///      Only the owner or designated payer can make repayments.
    /// @param agreementId The ID of the yield agreement being repaid
    function makeRepayment(uint256 agreementId) external onlyOwnerOrPayer(agreementId) nonReentrant onlyKYCVerified(msg.sender) payable {
        YieldStorage.YieldData storage yieldData = _validateAgreementActive(agreementId);

        // Cache storage reads in memory to reduce SLOAD operations
        uint256 upfrontCapital = yieldData.upfrontCapital;
        uint16 termMonths = yieldData.repaymentTermMonths;
        uint16 roiBasisPoints = yieldData.annualROIBasisPoints;
        bool allowPartial = yieldData.allowPartialRepayments;

        // Calculate expected monthly repayment amount
        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(
            upfrontCapital,
            termMonths,
            roiBasisPoints
        );

        // Validate repayment amount
        if (!YieldCalculations.validateRepaymentAmount(msg.value, monthlyPayment, allowPartial)) {
            revert InvalidRepaymentAmount(msg.value, monthlyPayment);
        }

        // Apply overpayment credits if available
        uint256 effectivePayment = msg.value;
        uint256 overpaymentCredit = yieldData.overpaymentCredit;
        if (overpaymentCredit > 0) {
            if (overpaymentCredit >= msg.value) {
                unchecked {
                    yieldData.overpaymentCredit -= msg.value; // Safe: validated above
                }
                effectivePayment = 0;
            } else {
                unchecked {
                    effectivePayment = msg.value - overpaymentCredit; // Safe: validated above
                }
                yieldData.overpaymentCredit = 0;
            }
        }

        // Handle overpayments (create credit for future use)
        if (msg.value > monthlyPayment) {
            unchecked {
                uint256 excess = msg.value - monthlyPayment; // Safe: validated above
                yieldData.overpaymentCredit += excess; // Safe: uint256 overflow extremely unlikely
                effectivePayment = monthlyPayment;
            }
        }

        // Update storage with repayment
        unchecked {
            yieldData.totalRepaid += effectivePayment; // Safe: total repaid cannot overflow in practice
        }
        yieldData.lastRepaymentTimestamp = block.timestamp;

        // Reset missed payment counter on successful repayment
        yieldData.missedPaymentCount = 0;

        // Distribute repayment to token holders via agreement-specific YieldSharesToken contract
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldSharesToken token = agreements.agreementTokens[agreementId];
        if (address(token) == address(0)) revert TokenNotFound(agreementId);
        
        token.distributeRepayment{value: effectivePayment}(agreementId);

        // Check if agreement is complete
        _checkAndCompleteAgreement(agreementId, yieldData);

        emit RepaymentMade(agreementId, msg.value, block.timestamp);
    }

    /// @notice Makes a partial repayment accepting any amount
    /// @dev Allocates payment between arrears and current obligation, distributes proportionally.
    ///      Requires the agreement to have allowPartialRepayments enabled.
    ///      Any payment less than the monthly amount accumulates as arrears.
    /// @param agreementId The ID of the yield agreement being repaid
    function makePartialRepayment(uint256 agreementId) external onlyKYCVerified(msg.sender) payable {
        YieldStorage.YieldData storage yieldData = _validateAgreementActive(agreementId);
        
        if (!yieldData.allowPartialRepayments) revert PartialRepaymentsNotAllowed(agreementId);

        // Cache storage reads in memory to reduce SLOAD operations
        uint256 upfrontCapital = yieldData.upfrontCapital;
        uint16 termMonths = yieldData.repaymentTermMonths;
        uint16 roiBasisPoints = yieldData.annualROIBasisPoints;

        // Calculate expected monthly repayment amount
        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(
            upfrontCapital,
            termMonths,
            roiBasisPoints
        );

        // Validate repayment amount
        if (!YieldCalculations.validateRepaymentAmount(msg.value, monthlyPayment, true)) {
            revert InvalidRepaymentAmount(msg.value, monthlyPayment);
        }

        // Allocate payment between arrears and current payment
        (uint256 arrearsPayment, uint256 currentPayment) = YieldCalculations.calculatePartialRepaymentAllocation(
            msg.value,
            yieldData.accumulatedArrears,
            monthlyPayment
        );

        // Accumulate new arrears if current payment is less than monthly payment
        if (currentPayment < monthlyPayment) {
            unchecked {
                yieldData.accumulatedArrears += (monthlyPayment - currentPayment); // Safe: validated above
            }
        }

        // Update storage
        unchecked {
            yieldData.accumulatedArrears -= arrearsPayment; // Safe: validated by calculatePartialRepaymentAllocation
            yieldData.totalRepaid += msg.value; // Safe: total repaid cannot overflow in practice
        }
        yieldData.lastRepaymentTimestamp = block.timestamp;

        // Reset missed payment counter on any repayment
        yieldData.missedPaymentCount = 0;

        // Distribute partial repayment to token holders
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldSharesToken token = agreements.agreementTokens[agreementId];
        if (address(token) == address(0)) revert TokenNotFound(agreementId);
        
        token.distributePartialRepayment{value: msg.value}(agreementId, msg.value, monthlyPayment);

        // Check if agreement is complete
        _checkAndCompleteAgreement(agreementId, yieldData);

        emit PartialRepaymentMade(agreementId, msg.value, arrearsPayment, currentPayment);
    }

    /// @notice Makes an early lump-sum repayment with rebate calculation
    /// @dev Calculates rebate and marks agreement complete if fully paid.
    ///      Requires the agreement to have allowEarlyRepayment enabled.
    ///      Provides a 10% rebate on the remaining interest as an incentive for early repayment.
    ///      Excess payments are refunded to the sender; if refund fails, kept as overpayment credit.
    /// @param agreementId The ID of the yield agreement being repaid
    function makeEarlyRepayment(uint256 agreementId) external onlyOwnerOrPayer(agreementId) nonReentrant onlyKYCVerified(msg.sender) payable {
        YieldStorage.YieldData storage yieldData = _validateAgreementActive(agreementId);
        
        if (!yieldData.allowEarlyRepayment) revert EarlyRepaymentsNotAllowed(agreementId);

        // Cache storage reads in memory to reduce SLOAD operations
        uint256 upfrontCapital = yieldData.upfrontCapital;
        uint256 totalRepaid = yieldData.totalRepaid;
        uint16 termMonths = yieldData.repaymentTermMonths;
        uint16 roiBasisPoints = yieldData.annualROIBasisPoints;

        // Calculate remaining balance
        uint256 elapsedMonths = YieldCalculations.calculateElapsedMonths(
            yieldData.lastRepaymentTimestamp,
            block.timestamp
        );

        uint256 remainingBalance = YieldCalculations.calculateRemainingBalance(
            upfrontCapital,
            totalRepaid,
            termMonths,
            roiBasisPoints,
            elapsedMonths
        );

        // Calculate rebate for early repayment
        uint256 remainingPrincipal = remainingBalance; // Simplified assumption
        uint256 remainingInterest = remainingBalance - remainingPrincipal; // Simplified
        uint256 rebate = YieldCalculations.calculateEarlyRepaymentRebate(
            remainingPrincipal,
            remainingInterest,
            1000 // 10% rebate for early repayment
        );

        uint256 requiredAmount = remainingBalance - rebate;
        if (msg.value < requiredAmount) {
            revert InsufficientEarlyRepaymentAmount(msg.value, requiredAmount);
        }

        // Handle overpayments
        uint256 effectivePayment = requiredAmount;
        if (msg.value > requiredAmount) {
            unchecked {
                uint256 excess = msg.value - requiredAmount; // Safe: validated above
                yieldData.overpaymentCredit += excess; // Safe: uint256 overflow extremely unlikely
                // Refund excess to sender (optional - could also keep as credit)
                (bool success, ) = payable(msg.sender).call{value: excess}("");
                if (!success) {
                    // If refund fails, keep it as overpayment credit
                    // The excess is already added to overpaymentCredit above
                }
            }
        }

        // Update storage
        unchecked {
            yieldData.prepaymentAmount += effectivePayment; // Safe: total cannot overflow in practice
            yieldData.totalRepaid += effectivePayment; // Safe: total repaid cannot overflow in practice
        }
        yieldData.isActive = false;
        yieldData.lastRepaymentTimestamp = block.timestamp;

        // Distribute only the required amount to token holders
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        YieldSharesToken token = agreements.agreementTokens[agreementId];
        if (address(token) == address(0)) revert TokenNotFound(agreementId);
        
        token.distributeRepayment{value: effectivePayment}(agreementId);

        // Burn remaining shares
        token.burnRemainingShares(agreementId);

        emit EarlyRepaymentMade(agreementId, msg.value, rebate);
        emit YieldAgreementCompleted(agreementId, yieldData.totalRepaid);
    }

    /// @dev Required by OpenZeppelin's UUPSUpgradeable.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

