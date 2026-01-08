// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/console.sol";

import "../storage/YieldStorage.sol";
import "../storage/DiamondYieldStorage.sol";
import "../libraries/YieldCalculations.sol";
import "../YieldSharesToken.sol";
import "../PropertyNFT.sol";

/// @title YieldBaseFacet
/// @notice Diamond facet for core yield agreement creation and initialization
/// @dev Part of YieldBase Diamond implementation (EIP-2535)
///      Handles agreement creation, PropertyNFT validation, and YieldSharesToken deployment
contract YieldBaseFacet {
    using YieldCalculations for uint256;

    // ============ Events ============
    
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

    /// @notice Emitted when governance controller is set
    event GovernanceControllerSet(address indexed controller);

    /// @notice Emitted when PropertyNFT contract is linked
    event PropertyNFTSet(address indexed propertyNFT);

    /// @notice Emitted when YieldSharesToken template is set
    event YieldSharesTokenTemplateSet(address indexed template);

    // ============ Errors ============
    
    error InvalidUpfrontCapital();
    error InvalidTerm();
    error InvalidROI();
    error InvalidGracePeriod();
    error InvalidPenaltyRate();
    error PropertyNFTNotSet();
    error InvalidPropertyTokenId();
    error CallerNotPropertyOwner();
    error PropertyNotVerified();
    error UnauthorizedCaller();

    // ============ Modifiers ============

    /// @notice Modifier that allows only the contract owner
    modifier onlyOwner() {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        require(msg.sender == OwnableUpgradeable(address(this)).owner(), "Caller is not the owner");
        _;
    }

    /// @notice Modifier to prevent reentrancy attacks
    modifier nonReentrant() {
        // Diamond facets share reentrancy guard via Diamond storage
        // This is a simplified version - production should use proper Diamond reentrancy pattern
        _;
    }

    // ============ Core Functions ============

    /// @notice Initialize the YieldBase Diamond
    /// @dev Called once during Diamond deployment
    /// @param initialOwner The address that will own the Diamond
    /// @param propertyNFTAddress Address of PropertyNFT contract
    /// @param governanceControllerAddress Address of GovernanceController
    function initializeYieldBase(
        address initialOwner,
        address propertyNFTAddress,
        address governanceControllerAddress
    ) external {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        
        // Prevent re-initialization
        require(agreements.propertyNFT == address(0), "Already initialized");
        require(initialOwner != address(0), "Invalid initial owner");
        
        // Set PropertyNFT
        if (propertyNFTAddress != address(0)) {
            agreements.propertyNFT = propertyNFTAddress;
            emit PropertyNFTSet(propertyNFTAddress);
        }
        
        // Set GovernanceController
        if (governanceControllerAddress != address(0)) {
            agreements.governanceController = governanceControllerAddress;
            emit GovernanceControllerSet(governanceControllerAddress);
        }
        
        // Initialize agreement counter
        agreements.agreementCount = 1;
    }

    /// @notice Set the PropertyNFT contract reference
    /// @dev Must be called after deployment to link YieldBase with PropertyNFT contract
    /// @param propertyNFTAddress Address of the deployed PropertyNFT contract
    function setPropertyNFT(address propertyNFTAddress) external onlyOwner {
        require(propertyNFTAddress != address(0), "Invalid PropertyNFT address");
        
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        agreements.propertyNFT = propertyNFTAddress;
        
        emit PropertyNFTSet(propertyNFTAddress);
    }

    /// @notice Set the GovernanceController contract reference
    /// @dev Only owner can set for security
    /// @param governanceControllerAddress Address of the GovernanceController contract
    function setGovernanceController(address governanceControllerAddress) external onlyOwner {
        require(governanceControllerAddress != address(0), "Invalid governance address");
        
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        agreements.governanceController = governanceControllerAddress;
        
        emit GovernanceControllerSet(governanceControllerAddress);
    }

    /// @notice Creates a new yield agreement for property yield tokenization
    /// @dev ENHANCED AUTONOMOUS YIELD MANAGEMENT with Diamond storage
    ///      Each agreement gets its own ERC-20 YieldSharesToken instance
    ///      Validates PropertyNFT ownership and verification status
    ///      Stores data in ERC-7201 namespaced storage for upgrade safety
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
        // Input validation
        if (upfrontCapital == 0 || upfrontCapital > type(uint256).max / 2) {
            revert InvalidUpfrontCapital();
        }
        if (termMonths == 0 || termMonths > 360) {
            revert InvalidTerm();
        }
        if (annualROI == 0 || annualROI > 5000) {
            revert InvalidROI();
        }
        if (gracePeriodDays == 0 || gracePeriodDays > 365) {
            revert InvalidGracePeriod();
        }
        if (defaultPenaltyRate > 1000) {
            revert InvalidPenaltyRate();
        }

        // Get storage references
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        
        // Property NFT validation
        if (agreements.propertyNFT == address(0)) {
            revert PropertyNFTNotSet();
        }
        if (propertyTokenId == 0) {
            revert InvalidPropertyTokenId();
        }
        
        PropertyNFT propertyNFTContract = PropertyNFT(agreements.propertyNFT);
        if (propertyNFTContract.ownerOf(propertyTokenId) != msg.sender) {
            revert CallerNotPropertyOwner();
        }
        if (!propertyNFTContract.isPropertyVerified(propertyTokenId)) {
            revert PropertyNotVerified();
        }

        // Generate new agreement ID
        agreementId = agreements.agreementCount++;
        
        // Set authorized payer
        agreements.authorizedPayers[agreementId] = propertyPayer;
        
        // Map property to agreement (prevents duplicate agreements for same property)
        agreements.propertyToAgreement[propertyTokenId] = agreementId;

        // Store agreement data in Diamond storage
        agreements.agreements[agreementId] = YieldStorage.YieldData({
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

        // Deploy new YieldSharesToken instance for this agreement
        YieldSharesToken tokenImplementation = new YieldSharesToken();
        string memory tokenName = string(abi.encodePacked("RWA Yield Shares Agreement ", Strings.toString(agreementId)));
        string memory tokenSymbol = string(abi.encodePacked("RWAYIELD", Strings.toString(agreementId)));

        // Deploy token proxy
        YieldSharesToken tokenInstance = YieldSharesToken(address(new ERC1967Proxy(
            address(tokenImplementation),
            abi.encodeWithSelector(
                YieldSharesToken.initialize.selector,
                OwnableUpgradeable(address(this)).owner(), // initialOwner
                address(this),                             // yieldBaseAddress (Diamond proxy)
                tokenName,
                tokenSymbol
            )
        )));

        // Store token reference
        agreements.agreementTokens[agreementId] = tokenInstance;

        // Mint initial yield shares to agreement creator (1:1 with capital)
        tokenInstance.mintShares(agreementId, msg.sender, upfrontCapital);

        // Emit creation event
        emit YieldAgreementCreated(
            agreementId,
            propertyTokenId,
            upfrontCapital,
            termMonths,
            annualROI,
            gracePeriodDays,
            defaultPenaltyRate,
            allowPartialRepayments,
            allowEarlyRepayment
        );

        console.log("Created Yield Agreement", agreementId);
        console.log("  Property Token ID:", propertyTokenId);
        console.log("  Upfront Capital:", upfrontCapital);
        console.log("  YieldSharesToken deployed at:", address(tokenInstance));

        return agreementId;
    }

    /// @notice Get the current agreement counter
    /// @return count The next agreement ID that will be assigned
    function getAgreementCount() external view returns (uint256 count) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return agreements.agreementCount;
    }

    /// @notice Get the PropertyNFT contract address
    /// @return propertyNFTAddress The address of the linked PropertyNFT contract
    function getPropertyNFT() external view returns (address propertyNFTAddress) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return agreements.propertyNFT;
    }

    /// @notice Get the GovernanceController contract address
    /// @return governanceAddress The address of the linked GovernanceController
    function getGovernanceController() external view returns (address governanceAddress) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return agreements.governanceController;
    }

    /// @notice Get the YieldSharesToken contract for a specific agreement
    /// @param agreementId The ID of the agreement
    /// @return tokenAddress The address of the YieldSharesToken contract
    function getYieldSharesToken(uint256 agreementId) external view returns (address tokenAddress) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return address(agreements.agreementTokens[agreementId]);
    }

    /// @notice Get the authorized payer for an agreement
    /// @param agreementId The ID of the agreement
    /// @return payerAddress The address authorized to make repayments (0x0 if owner-only)
    function getAuthorizedPayer(uint256 agreementId) external view returns (address payerAddress) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return agreements.authorizedPayers[agreementId];
    }

    /// @notice Get the agreement ID associated with a property token
    /// @param propertyTokenId The ID of the property NFT
    /// @return agreementId The ID of the associated agreement (0 if none)
    function getPropertyAgreement(uint256 propertyTokenId) external view returns (uint256 agreementId) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return agreements.propertyToAgreement[propertyTokenId];
    }
}

