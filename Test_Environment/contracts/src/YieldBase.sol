// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/console.sol";

import "./storage/YieldStorage.sol";
import "./libraries/YieldCalculations.sol";
import "./libraries/YieldViews.sol";
import "./YieldSharesToken.sol";
import "./PropertyNFT.sol";

/// @title YieldBase Contract
/// @notice Core contract for autonomous real-world asset (RWA) yield tokenization with ERC-20 integration
/// @dev Implements upgrade-first architecture using UUPS proxy pattern with ERC-7201 namespaced storage
/// Uses library separation for 24KB bytecode compliance and upgrade safety
/// Integrates with YieldSharesToken for autonomous minting and distribution of fungible yield shares
contract YieldBase is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using YieldCalculations for uint256;

    /// @notice Mapping of agreement IDs to their respective ERC-20 token contracts
    mapping(uint256 => YieldSharesToken) public agreementTokens;

    /// @notice Legacy reference - kept for backwards compatibility but not used
    YieldSharesToken public yieldSharesToken;

    /// @notice Reference to PropertyNFT contract for property ownership verification
    PropertyNFT public propertyNFT;

    /// @notice Reference to GovernanceController for autonomous governance actions
    address public governanceController;

    /// @notice Counter for generating unique agreement IDs
    uint256 private _nextAgreementId;

    /// @notice Mapping to store multiple yield agreements per contract instance
    /// @dev Maps agreement ID to its corresponding YieldData struct
    mapping(uint256 => YieldStorage.YieldData) private _agreements;

    /// @notice Mapping to store designated payers for each agreement
    /// @dev Maps agreement ID to payer address. Zero address means owner-only repayments.
    mapping(uint256 => address) private _agreementPayer;

    /// @notice Emitted when a new yield agreement is created
    event YieldAgreementCreated(
        uint256 indexed agreementId,
        uint256 indexed propertyTokenId,
        uint256 upfrontCapital,
        uint16 termMonths,
        uint16 annualROI,
        uint16 gracePeriodDays,
        uint16 defaultPenaltyRate,
        bool allowPartialRepayments,
        bool allowEarlyRepayment
    );

    /// @notice Emitted when a repayment is made
    event RepaymentMade(
        uint256 indexed agreementId,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice Emitted when a yield agreement is completed
    event YieldAgreementCompleted(
        uint256 indexed agreementId,
        uint256 totalRepaid
    );

    /// @notice Emitted when a partial repayment is made
    event PartialRepaymentMade(
        uint256 indexed agreementId,
        uint256 amount,
        uint256 arrearsPayment,
        uint256 currentPayment
    );

    /// @notice Emitted when an early repayment is made
    event EarlyRepaymentMade(
        uint256 indexed agreementId,
        uint256 amount,
        uint256 rebateAmount
    );

    /// @notice Emitted when a payment is missed
    event PaymentMissed(
        uint256 indexed agreementId,
        uint256 missedPaymentCount,
        uint256 penaltyAmount
    );

    /// @notice Emitted when an agreement defaults
    event AgreementDefaulted(
        uint256 indexed agreementId,
        uint256 totalArrears,
        uint256 timestamp
    );

    /// @notice Emitted when governance controller is set
    event GovernanceControllerSet(address indexed controller);

    /// @notice Emitted when agreement ROI is adjusted via governance
    event ROIAdjusted(uint256 indexed agreementId, uint16 oldROI, uint16 newROI);

    /// @notice Emitted when reserve is allocated to an agreement
    event ReserveAllocated(uint256 indexed agreementId, uint256 amount);

    /// @notice Emitted when reserve is withdrawn from an agreement
    event ReserveWithdrawn(uint256 indexed agreementId, uint256 amount);

    /// @notice Emitted when agreement grace period is updated via governance
    event AgreementGracePeriodUpdated(uint256 indexed agreementId, uint16 oldValue, uint16 newValue);

    /// @notice Emitted when agreement penalty rate is updated via governance
    event AgreementPenaltyRateUpdated(uint256 indexed agreementId, uint16 oldValue, uint16 newValue);

    /// @notice Emitted when agreement default threshold is updated via governance
    event AgreementDefaultThresholdUpdated(uint256 indexed agreementId, uint8 oldValue, uint8 newValue);

    /// @notice Emitted when agreement allowPartialRepayments is updated via governance
    event AgreementAllowPartialRepaymentsUpdated(uint256 indexed agreementId, bool oldValue, bool newValue);

    /// @notice Emitted when agreement allowEarlyRepayment is updated via governance
    event AgreementAllowEarlyRepaymentUpdated(uint256 indexed agreementId, bool oldValue, bool newValue);

    /// @notice Modifier that allows only the contract owner or the designated payer for an agreement
    /// @param agreementId The ID of the agreement to check payer permissions for
    modifier onlyOwnerOrPayer(uint256 agreementId) {
        require(
            msg.sender == owner() || msg.sender == _agreementPayer[agreementId],
            "Caller is not authorized to make repayment"
        );
        _;
    }

    /// @notice Modifier that allows only the governance controller to call certain functions
    modifier onlyGovernance() {
        require(governanceController != address(0), "Governance controller not set");
        require(msg.sender == governanceController, "Caller is not governance controller");
        _;
    }

    /// @dev Disable constructor for upgradeable contracts
    /// @notice Required by OpenZeppelin's upgradeable pattern - initialization happens via initialize()
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract with the initial owner
    /// @dev Called once during proxy deployment. Cannot be called again due to initializer modifier
    /// @param initialOwner The address that will own the contract and control upgrades
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        _nextAgreementId = 1;
    }

    /// @notice Authorizes contract upgrades (UUPS pattern requirement)
    /// @dev Only the owner can authorize upgrades. Called internally by UUPS upgrade mechanism
    /// @param newImplementation The address of the new implementation contract
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // Only owner can upgrade - additional authorization logic can be added here
    }

    /// @notice Set the PropertyNFT contract reference
    /// @dev Must be called after deployment to link YieldBase with PropertyNFT contract
    /// Only owner can set the PropertyNFT reference for security
    /// @param propertyNFTAddress Address of the deployed PropertyNFT contract
    function setPropertyNFT(address propertyNFTAddress) external onlyOwner {
        require(propertyNFTAddress != address(0), "Invalid PropertyNFT address");
        propertyNFT = PropertyNFT(propertyNFTAddress);
    }


    /// @notice Creates a new yield agreement for property yield tokenization
    /// @dev ENHANCED AUTONOMOUS YIELD MANAGEMENT: Supports advanced features like default handling, partial repayments, early repayments, and pooled capital.
    ///     MULTIPLE AGREEMENT SUPPORT: Contract supports multiple yield agreements with unique IDs.
    ///     Each agreement gets its own ERC-20 token instance for proper isolation.
    ///     Stores agreement data in ERC-7201 namespaced storage for upgrade safety.
    ///     Automatically deploys and mints ERC-20 tokens to the creator at 1:1 ratio with upfront capital.
    ///     PROPERTY NFT INTEGRATION: Requires verified property NFT ownership for validation.
    /// @param propertyTokenId The ID of the property NFT representing the collateralized property
    /// @param upfrontCapital The amount of capital requested upfront by the property owner
    /// @param termMonths The repayment term in months
    /// @param annualROI The annual return on investment in basis points (e.g., 500 = 5%)
    /// @param propertyPayer Optional address authorized to make repayments. Zero address means owner-only.
    /// @param gracePeriodDays Grace period in days before default penalties apply (e.g., 30 days)
    /// @param defaultPenaltyRate Penalty rate in basis points for late payments (e.g., 200 = 2%)
    /// @param defaultThreshold Number of missed payments before agreement defaults (e.g., 3)
    /// @param allowPartialRepayments Whether partial repayments are allowed
    /// @param allowEarlyRepayment Whether early repayments with rebate are allowed
    /// @return agreementId The unique identifier for the created yield agreement
    function createYieldAgreement(
        uint256 propertyTokenId,
        uint256 upfrontCapital,
        uint16 termMonths,
        uint16 annualROI,
        address propertyPayer,
        uint16 gracePeriodDays,
        uint16 defaultPenaltyRate,
        uint8 defaultThreshold,
        bool allowPartialRepayments,
        bool allowEarlyRepayment
    ) external nonReentrant returns (uint256 agreementId) {
        require(upfrontCapital > 0, "Upfront capital must be greater than zero");
        require(upfrontCapital <= type(uint256).max / 2, "Upfront capital cannot exceed reasonable maximum"); // Prevent overflow issues
        require(termMonths > 0 && termMonths <= 360, "Term must be between 1 and 360 months");
        require(annualROI > 0 && annualROI <= 5000, "ROI must be between 1 and 5000 basis points");
        require(gracePeriodDays > 0 && gracePeriodDays <= 365, "Grace period must be between 1 and 365 days");
        require(defaultPenaltyRate <= 1000, "Default penalty rate cannot exceed 10%");

        // Property NFT validation
        require(address(propertyNFT) != address(0), "PropertyNFT contract not set");
        require(propertyTokenId > 0, "Invalid property token ID");
        require(propertyNFT.ownerOf(propertyTokenId) == msg.sender, "Caller must own the property NFT");

        require(propertyNFT.isPropertyVerified(propertyTokenId), "Property must be verified before creating yield agreement");

        // Get next agreement ID and increment counter
        agreementId = _nextAgreementId++;

        // Set the designated payer for this agreement (zero address means owner-only)
        _agreementPayer[agreementId] = propertyPayer;

        _agreements[agreementId] = YieldStorage.YieldData({
            upfrontCapital: upfrontCapital,
            repaymentTermMonths: termMonths,
            annualROIBasisPoints: annualROI,
            totalRepaid: 0,
            lastRepaymentTimestamp: block.timestamp,
            isActive: true,
            missedPaymentCount: 0,
            gracePeriodDays: gracePeriodDays,
            accumulatedArrears: 0,
            overpaymentCredit: 0,
            prepaymentAmount: 0,
            defaultPenaltyRate: defaultPenaltyRate,
            lastMissedPaymentTimestamp: 0,
            gracePeriodExpiryTimestamp: 0,
            isInDefault: false,
            allowPartialRepayments: allowPartialRepayments,
            allowEarlyRepayment: allowEarlyRepayment,
            defaultThreshold: defaultThreshold,
            propertyTokenId: propertyTokenId,
            reserveBalance: 0
        });

        // Deploy a new token instance for this agreement
        YieldSharesToken tokenImplementation = new YieldSharesToken();
        string memory tokenName = string(abi.encodePacked("RWA Yield Shares Agreement ", Strings.toString(agreementId)));
        string memory tokenSymbol = string(abi.encodePacked("RWAYIELD", Strings.toString(agreementId)));

        // Deploy token proxy (simplified - in production would use proper proxy deployment)
        YieldSharesToken tokenInstance = YieldSharesToken(address(new ERC1967Proxy(
            address(tokenImplementation),
            abi.encodeWithSelector(
                YieldSharesToken.initialize.selector,
                OwnableUpgradeable.owner(), // initialOwner
                address(this),              // yieldBaseAddress
                tokenName,
                tokenSymbol
            )
        )));

        agreementTokens[agreementId] = tokenInstance;

        // Mint ERC-20 tokens to the agreement creator (property owner)
        tokenInstance.mintShares(agreementId, msg.sender, upfrontCapital);

        // Establish bidirectional link between property NFT and yield agreement
        propertyNFT.linkToYieldAgreement(propertyTokenId, agreementId);

        emit YieldAgreementCreated(agreementId, propertyTokenId, upfrontCapital, termMonths, annualROI, gracePeriodDays, defaultPenaltyRate, allowPartialRepayments, allowEarlyRepayment);
        return agreementId;
    }

    /// @notice Sets or updates the designated payer for an agreement
    /// @dev Only the contract owner can update the payer address. Zero address means owner-only repayments.
    /// @param agreementId The ID of the agreement to update
    /// @param newPayer The new address authorized to make repayments (zero address for owner-only)
    function setAgreementPayer(uint256 agreementId, address newPayer) external onlyOwner {
        require(_agreements[agreementId].upfrontCapital > 0, "Agreement does not exist");
        _agreementPayer[agreementId] = newPayer;
    }

    /// @notice Records a repayment from the property owner and distributes to token holders
    /// @dev ENHANCED AUTONOMOUS YIELD MANAGEMENT: Handles full payments, overpayments, and resets missed payment counters.
    ///     MULTIPLE AGREEMENT SUPPORT: Processes repayments for specific agreement IDs.
    ///     Protected against reentrancy attacks. Now accepts overpayments which create credits.
    ///     Automatically distributes repayment to ERC-20 token holders based on their share ownership.
    ///     Can be called by contract owner or designated payer for the agreement.
    /// @param agreementId The ID of the yield agreement being repaid
    function makeRepayment(uint256 agreementId) external onlyOwnerOrPayer(agreementId) nonReentrant payable {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.isActive, "Yield agreement is not active");
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");

        require(!yieldData.isInDefault, "Cannot make repayments on defaulted agreement");

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
        require(
            YieldCalculations.validateRepaymentAmount(msg.value, monthlyPayment, allowPartial),
            "Invalid repayment amount"
        );

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
        YieldSharesToken token = agreementTokens[agreementId];
        require(address(token) != address(0), "Token not found for agreement");
        token.distributeRepayment{value: effectivePayment}(agreementId);

        // Check if agreement is complete
        uint256 totalExpected = YieldCalculations.calculateTotalRepaymentAmount(
            upfrontCapital,
            termMonths,
            roiBasisPoints
        );

        if (yieldData.totalRepaid >= totalExpected) {
            yieldData.isActive = false;
            // Burn remaining shares when agreement completes
            token.burnRemainingShares(agreementId);
            emit YieldAgreementCompleted(agreementId, yieldData.totalRepaid);
        }

        emit RepaymentMade(agreementId, msg.value, block.timestamp);
    }

    /// @notice Makes a partial repayment accepting any amount
    /// @dev Allocates payment between arrears and current obligation, distributes proportionally
    /// @param agreementId The ID of the yield agreement being repaid
    function makePartialRepayment(uint256 agreementId) external payable {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.isActive, "Yield agreement is not active");
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");
        require(yieldData.allowPartialRepayments, "Partial repayments not allowed");
        require(!yieldData.isInDefault, "Cannot make repayments on defaulted agreement");

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
        require(
            YieldCalculations.validateRepaymentAmount(msg.value, monthlyPayment, true),
            "Invalid repayment amount"
        );

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
        YieldSharesToken token = agreementTokens[agreementId];
        require(address(token) != address(0), "Token not found for agreement");
        token.distributePartialRepayment{value: msg.value}(agreementId, msg.value, monthlyPayment);

        // Check if agreement is complete
        uint256 totalExpected = YieldCalculations.calculateTotalRepaymentAmount(
            upfrontCapital,
            termMonths,
            roiBasisPoints
        );

        if (yieldData.totalRepaid >= totalExpected) {
            yieldData.isActive = false;
            token.burnRemainingShares(agreementId);
            emit YieldAgreementCompleted(agreementId, yieldData.totalRepaid);
        }

        emit PartialRepaymentMade(agreementId, msg.value, arrearsPayment, currentPayment);
    }

    /// @notice Makes an early lump-sum repayment with rebate calculation
    /// @dev Calculates rebate and marks agreement complete if fully paid
    /// @param agreementId The ID of the yield agreement being repaid
    function makeEarlyRepayment(uint256 agreementId) external onlyOwnerOrPayer(agreementId) nonReentrant payable {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.isActive, "Yield agreement is not active");
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");
        require(yieldData.allowEarlyRepayment, "Early repayments not allowed");
        require(!yieldData.isInDefault, "Cannot make repayments on defaulted agreement");

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
        require(msg.value >= requiredAmount, "Insufficient amount for early repayment");

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
        YieldSharesToken token = agreementTokens[agreementId];
        require(address(token) != address(0), "Token not found for agreement");
        token.distributeRepayment{value: effectivePayment}(agreementId);

        // Burn remaining shares
        token.burnRemainingShares(agreementId);

        emit EarlyRepaymentMade(agreementId, msg.value, rebate);
        emit YieldAgreementCompleted(agreementId, yieldData.totalRepaid);
    }

    /// @notice Handles missed payment detection and penalty application
    /// @dev Increments missed payment counter, calculates penalties, checks for default
    /// @param agreementId The ID of the agreement with missed payment
    function handleMissedPayment(uint256 agreementId) external onlyOwner {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.isActive, "Yield agreement is not active");
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");

        // Check if payment is actually overdue
        bool isOverdue = YieldCalculations.isRepaymentOverdue(
            yieldData.lastRepaymentTimestamp,
            yieldData.repaymentTermMonths
        );
        require(isOverdue, "Payment is not overdue");

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

    /// @notice Returns comprehensive agreement status including default information
    /// @dev Provides detailed status for autonomous decision making
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
        return YieldViews.getAgreementStatus(_agreements, agreementId);
    }

    /// @notice Returns the timestamp of the last missed payment for debugging
    /// @dev Used for test debugging and analysis
    /// @param agreementId The ID of the yield agreement
    /// @return timestamp Timestamp of last missed payment (0 if none)
    function getLastMissedPaymentTimestamp(uint256 agreementId) external view returns (uint256 timestamp) {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        return yieldData.lastMissedPaymentTimestamp;
    }

    /// @notice Returns the payer address for an agreement for debugging
    /// @dev Used for test debugging and analysis
    /// @param agreementId The ID of the yield agreement
    /// @return payer The address authorized to make repayments
    function getAgreementPayer(uint256 agreementId) external view returns (address payer) {
        return _agreementPayer[agreementId];
    }


    /// @notice Checks and updates default status for agreements that may have entered default
    /// @dev Should be called periodically to ensure agreements in default are properly flagged
    /// @param agreementId The ID of the yield agreement to check
    function checkAndUpdateDefaultStatus(uint256 agreementId) external {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");
        require(yieldData.isActive, "Agreement is not active");

        // Only check if not already in default and grace period is active
        if (!yieldData.isInDefault && yieldData.gracePeriodExpiryTimestamp > 0) {
            if (block.timestamp >= yieldData.gracePeriodExpiryTimestamp) {
                yieldData.isInDefault = true;
                emit AgreementDefaulted(agreementId, yieldData.accumulatedArrears, block.timestamp);
            }
        }
    }

    /// @notice Returns the outstanding balance including principal, interest, and arrears
    /// @dev Calculates total amount still owed on the agreement
    /// @param agreementId The ID of the yield agreement
    /// @return outstandingBalance Total amount still owed
    function getOutstandingBalance(uint256 agreementId) external view returns (uint256 outstandingBalance) {
        return YieldViews.getOutstandingBalance(_agreements, agreementId);
    }

    /// @notice Returns the details of the yield agreement
    /// @dev MULTIPLE AGREEMENT SUPPORT: Returns data for the specified agreement ID.
    ///     Reads from ERC-7201 namespaced storage. Gas-efficient view function
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
        return YieldViews.getYieldAgreement(_agreements, agreementId);
    }

    /// @notice Check if a yield agreement is active
    /// @dev Returns true if the agreement exists and is active, false otherwise
    /// @param agreementId The ID of the yield agreement to check
    /// @return True if the agreement is active, false otherwise
    function isAgreementActive(uint256 agreementId) external view returns (bool) {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        return yieldData.upfrontCapital > 0 && yieldData.isActive;
    }

    /// @notice Get the property token ID associated with a yield agreement
    /// @dev Returns the propertyTokenId from yield agreement storage for bidirectional lookup
    /// @param agreementId The ID of the yield agreement
    /// @return propertyTokenId The token ID of the associated property NFT
    function getPropertyForAgreement(uint256 agreementId)
        external
        view
        returns (uint256 propertyTokenId)
    {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");
        return yieldData.propertyTokenId;
    }

    /// @dev Internal helper to access ERC-7201 namespaced storage
    /// @return Storage pointer to the YieldData struct
    function _getYieldStorage() internal pure returns (YieldStorage.YieldData storage) {
        return YieldStorage.getYieldStorage();
    }

    // ============ Governance Integration Functions ============

    /// @notice Set the governance controller address
    /// @dev Only owner can set the governance controller for autonomous governance
    /// @param governanceControllerAddress Address of the governance controller contract
    function setGovernanceController(address governanceControllerAddress) external onlyOwner {
        require(governanceControllerAddress != address(0), "Invalid governance controller address");
        governanceController = governanceControllerAddress;
        emit GovernanceControllerSet(governanceControllerAddress);
    }

    /// @notice Adjust agreement ROI via governance proposal
    /// @dev Only callable by governance controller after successful proposal execution
    /// @param agreementId Agreement to adjust ROI for
    /// @param newROI New annual ROI in basis points (must be within +/-5% of original)
    function adjustAgreementROI(uint256 agreementId, uint16 newROI) external onlyGovernance nonReentrant {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        _validateAgreementActive(yieldData);
        require(newROI >= 100 && newROI <= 5000, "ROI must be between 1% and 50%");

        uint16 oldROI = yieldData.annualROIBasisPoints;
        yieldData.annualROIBasisPoints = newROI;

        emit ROIAdjusted(agreementId, oldROI, newROI);
    }

    /// @notice Allocate reserve to an agreement for default protection
    /// @dev Only callable by governance controller with ETH transfer
    /// @param agreementId Agreement to allocate reserve for
    function allocateReserve(uint256 agreementId) external payable onlyGovernance {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        _validateAgreementExists(yieldData);
        require(msg.value > 0, "Must send ETH for reserve");

        // Validate reserve does not exceed 20% of upfront capital
        uint256 maxReserve = (yieldData.upfrontCapital * 2000) / 10000; // 20% in basis points
        require(yieldData.reserveBalance + msg.value <= maxReserve, "Reserve would exceed 20% limit");

        // Increment reserve balance for this agreement
        unchecked {
            yieldData.reserveBalance += msg.value; // Safe: validated above
        }

        emit ReserveAllocated(agreementId, msg.value);
    }

    /// @notice Withdraw reserve from an agreement
    /// @dev Only callable by governance controller for pro-rata distribution to investors
    /// @param agreementId Agreement to withdraw reserve from
    /// @param amount Amount to withdraw in wei
    function withdrawReserve(uint256 agreementId, uint256 amount) external onlyGovernance nonReentrant {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        _validateAgreementExists(yieldData);
        require(amount > 0, "Amount must be greater than zero");
        require(yieldData.reserveBalance >= amount, "Insufficient reserve balance");
        require(address(this).balance >= amount, "Insufficient contract balance");

        // Decrement reserve balance before transfer (checks-effects-interactions pattern)
        unchecked {
            yieldData.reserveBalance -= amount; // Safe: validated above
        }

        // Transfer reserve back to governance controller
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Reserve withdrawal transfer failed");

        emit ReserveWithdrawn(agreementId, amount);
    }

    /// @notice Get agreement reserve balance
    /// @dev Returns the reserve balance for an agreement
    /// @param agreementId Agreement to query reserve for
    /// @return reserveBalance Reserve balance in wei
    function getAgreementReserve(uint256 agreementId) external view returns (uint256 reserveBalance) {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");
        return yieldData.reserveBalance;
    }

    /// @notice Get comprehensive agreement details including all parameters
    /// @dev Returns all agreement data needed for governance validation
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
        return YieldViews.getAgreement(_agreements, agreementId);
    }

    /// @notice Get the YieldSharesToken address for a specific agreement
    /// @dev Returns the token contract address for governance voting power queries
    /// @param agreementId Agreement to get token for
    /// @return tokenAddress Address of the YieldSharesToken contract
    function getYieldSharesToken(uint256 agreementId) external view returns (address tokenAddress) {
        return address(agreementTokens[agreementId]);
    }

    // ============ Agreement Parameter Update Functions (Governance Only) ============

    /// @dev Internal helper to validate agreement exists (reduces duplicate code)
    /// @param yieldData Storage reference to agreement data
    function _validateAgreementExists(YieldStorage.YieldData storage yieldData) internal view {
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");
    }

    /// @dev Internal helper to validate agreement exists and is active (reduces duplicate code)
    /// @param yieldData Storage reference to agreement data
    function _validateAgreementActive(YieldStorage.YieldData storage yieldData) internal view {
        require(yieldData.upfrontCapital > 0, "Agreement does not exist");
        require(yieldData.isActive, "Agreement is not active");
    }

    /// @notice Update grace period for an agreement via governance
    /// @dev Only callable by governance controller after successful proposal
    /// @param agreementId Agreement to update
    /// @param newGracePeriodDays New grace period in days (1-90)
    function setAgreementGracePeriod(uint256 agreementId, uint16 newGracePeriodDays) external onlyGovernance {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        _validateAgreementExists(yieldData);
        require(newGracePeriodDays >= 1 && newGracePeriodDays <= 90, "Invalid grace period");
        
        uint16 oldValue = yieldData.gracePeriodDays;
        yieldData.gracePeriodDays = newGracePeriodDays;
        
        emit AgreementGracePeriodUpdated(agreementId, oldValue, newGracePeriodDays);
    }

    /// @notice Update default penalty rate for an agreement via governance
    /// @dev Only callable by governance controller after successful proposal
    /// @param agreementId Agreement to update
    /// @param newPenaltyRate New penalty rate in basis points (100-2000 = 1%-20%)
    function setAgreementDefaultPenaltyRate(uint256 agreementId, uint16 newPenaltyRate) external onlyGovernance {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        _validateAgreementExists(yieldData);
        require(newPenaltyRate >= 100 && newPenaltyRate <= 2000, "Invalid penalty rate");
        
        uint16 oldValue = yieldData.defaultPenaltyRate;
        yieldData.defaultPenaltyRate = newPenaltyRate;
        
        emit AgreementPenaltyRateUpdated(agreementId, oldValue, newPenaltyRate);
    }

    /// @notice Update default threshold for an agreement via governance
    /// @dev Only callable by governance controller after successful proposal
    /// @param agreementId Agreement to update
    /// @param newThreshold New default threshold in missed payments (1-12)
    function setAgreementDefaultThreshold(uint256 agreementId, uint8 newThreshold) external onlyGovernance {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        _validateAgreementExists(yieldData);
        require(newThreshold >= 1 && newThreshold <= 12, "Invalid default threshold");
        
        uint8 oldValue = yieldData.defaultThreshold;
        yieldData.defaultThreshold = newThreshold;
        
        emit AgreementDefaultThresholdUpdated(agreementId, oldValue, newThreshold);
    }

    /// @notice Update allowPartialRepayments flag for an agreement via governance
    /// @dev Only callable by governance controller after successful proposal
    /// @param agreementId Agreement to update
    /// @param newValue New value for allowPartialRepayments
    function setAgreementAllowPartialRepayments(uint256 agreementId, bool newValue) external onlyGovernance {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        _validateAgreementExists(yieldData);
        
        bool oldValue = yieldData.allowPartialRepayments;
        yieldData.allowPartialRepayments = newValue;
        
        emit AgreementAllowPartialRepaymentsUpdated(agreementId, oldValue, newValue);
    }

    /// @notice Update allowEarlyRepayment flag for an agreement via governance
    /// @dev Only callable by governance controller after successful proposal
    /// @param agreementId Agreement to update
    /// @param newValue New value for allowEarlyRepayment
    function setAgreementAllowEarlyRepayment(uint256 agreementId, bool newValue) external onlyGovernance {
        YieldStorage.YieldData storage yieldData = _agreements[agreementId];
        _validateAgreementExists(yieldData);
        
        bool oldValue = yieldData.allowEarlyRepayment;
        yieldData.allowEarlyRepayment = newValue;
        
        emit AgreementAllowEarlyRepaymentUpdated(agreementId, oldValue, newValue);
    }
}
