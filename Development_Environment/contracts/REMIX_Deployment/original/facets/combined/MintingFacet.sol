// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../../storage/CombinedTokenStorage.sol";
import "../../libraries/CombinedTokenDistribution.sol";
import "../../KYCRegistry.sol";

/// @title MintingFacet
/// @notice Facet for minting property and yield tokens in CombinedPropertyYieldToken Diamond
/// @dev Handles property NFT creation, yield token minting, and property verification
///      Uses ERC-7201 namespaced storage via CombinedTokenStorage
///      Implements Role-Based Access Control (RBAC) for platform-operated minting
contract MintingFacet is ERC1155Upgradeable, OwnableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using CombinedTokenStorage for CombinedTokenStorage.CombinedTokenStorageLayout;
    
    // ============ Role Definitions ============
    
    /// @notice Role identifier for platform minters (backend operators)
    /// @dev This role allows the platform to mint yield tokens on behalf of property owners
    ///      following property verification and KYC/AML compliance checks.
    ///      Standard practice for RWA tokenization platforms (Centrifuge, Polymath, Securitize).
    bytes32 public constant PLATFORM_MINTER_ROLE = keccak256("PLATFORM_MINTER_ROLE");

    // ============ Events ============
    
    event PropertyTokenMinted(
        uint256 indexed tokenId,
        bytes32 propertyAddressHash,
        string metadataURI
    );

    event YieldTokenMinted(
        uint256 indexed yieldTokenId,
        uint256 indexed propertyTokenId,
        uint256 tokenAmount,
        uint256 upfrontCapital,
        uint256 upfrontCapitalUsd,
        uint16 termMonths,
        uint16 annualROIBasisPoints,
        uint16 gracePeriodDays,
        uint16 defaultPenaltyRate,
        bool allowPartialRepayments,
        bool allowEarlyRepayment
    );

    event PropertyVerified(uint256 indexed tokenId);

    event BatchYieldTokensMinted(
        uint256[] propertyTokenIds,
        uint256[] yieldTokenIds,
        uint256[] totalAmounts
    );

    // ============ Custom Errors ============
    
    error InvalidPropertyAddressHash();
    error EmptyMetadataURI();
    error InvalidPropertyTokenIdRange();
    error InvalidCapitalAmount();
    error InvalidTermMonths();
    error InvalidAnnualROI();
    error InvalidGracePeriod();
    error InvalidDefaultPenaltyRate();
    error CallerMustOwnPropertyToken();
    error PropertyMustBeVerified();
    error InvalidYieldTokenID();
    error UnauthorizedMinter();
    error PropertyAlreadyVerified();
    error ArrayLengthMismatch();
    error ZeroContributionNotAllowed();
    error KYCRegistryNotSet();
    error AddressNotKYCVerified(address account);
    error AddressBlacklisted(address account);
    
    // ============ Modifiers ============
    
    /// @notice Modifier to ensure address is KYC verified
    /// @param account Address to check
    modifier onlyKYCVerified(address account) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        if (layout.kycRegistry == address(0)) {
            revert KYCRegistryNotSet();
        }
        KYCRegistry registry = KYCRegistry(layout.kycRegistry);
        if (!registry.isWhitelisted(account)) {
            revert AddressNotKYCVerified(account);
        }
        if (registry.isBlacklisted(account)) {
            revert AddressBlacklisted(account);
        }
        _;
    }
    
    // ============ Interface Support ============
    
    /// @notice Check if contract supports an interface
    /// @dev Override required due to multiple inheritance (ERC1155 + AccessControl)
    /// @param interfaceId The interface identifier
    /// @return bool True if interface is supported
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC1155Upgradeable, AccessControlUpgradeable) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }

    // ============ Property Token Minting ============

    /// @notice Mint a new property token
    /// @dev Only callable by contract owner. Creates non-fungible property token with supply of 1
    /// @param propertyAddressHash keccak256 hash of the property address for verification
    /// @param metadataURI IPFS URI containing detailed property documents
    /// @return tokenId The token ID of the newly minted property token
    function mintPropertyToken(
        bytes32 propertyAddressHash,
        string memory metadataURI
    ) external onlyOwner nonReentrant onlyKYCVerified(msg.sender) returns (uint256 tokenId) {
        if (propertyAddressHash == bytes32(0)) revert InvalidPropertyAddressHash();
        if (bytes(metadataURI).length == 0) revert EmptyMetadataURI();

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        tokenId = ++layout.propertyTokenIdCounter;

        if (!CombinedTokenDistribution.validateTokenIdRange(tokenId, true)) {
            revert InvalidPropertyTokenIdRange();
        }

        _mint(msg.sender, tokenId, 1, ""); // Mint 1 unit of non-fungible property token

        layout.propertyMetadata[tokenId] = CombinedTokenStorage.PropertyMetadata({
            propertyAddressHash: propertyAddressHash,
            verificationTimestamp: 0, // Set during verification
            metadataURI: metadataURI,
            isVerified: false, // Set during verification
            verifierAddress: address(0) // Set during verification
        });

        emit PropertyTokenMinted(tokenId, propertyAddressHash, metadataURI);
    }

    /// @notice Verify a property token
    /// @dev Only callable by contract owner. Marks property as verified
    /// @param propertyTokenId The property token ID to verify
    function verifyProperty(uint256 propertyTokenId) external onlyOwner {
        if (!CombinedTokenDistribution.isPropertyToken(propertyTokenId)) {
            revert InvalidPropertyTokenIdRange();
        }
        if (balanceOf(msg.sender, propertyTokenId) != 1) {
            revert CallerMustOwnPropertyToken();
        }

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        CombinedTokenStorage.PropertyMetadata storage metadata = layout.propertyMetadata[propertyTokenId];

        if (metadata.isVerified) revert PropertyAlreadyVerified();

        metadata.isVerified = true;
        metadata.verificationTimestamp = block.timestamp;
        metadata.verifierAddress = msg.sender;

        emit PropertyVerified(propertyTokenId);
    }

    // ============ Yield Token Minting ============

    /// @notice Mint yield tokens for a property
    /// @dev ENHANCED AUTONOMOUS YIELD MANAGEMENT: Configures advanced yield features
    /// @param propertyTokenId The property token ID to mint yield tokens for
    /// @param capitalAmount The upfront capital amount (determines token supply)
    /// @param termMonths The repayment term in months
    /// @param annualROI The annual ROI in basis points (e.g., 500 = 5%)
    /// @param gracePeriodDays Grace period in days before default penalties apply
    /// @param defaultPenaltyRate Penalty rate in basis points for late payments
    /// @param allowPartialRepayments Whether partial repayments are allowed
    /// @param allowEarlyRepayment Whether early repayments with rebate are allowed
    /// @return yieldTokenId The token ID of the minted yield tokens
    function mintYieldTokens(
        uint256 propertyTokenId,
        uint256 capitalAmount,
        uint256 capitalAmountUsd,
        uint16 termMonths,
        uint16 annualROI,
        uint16 gracePeriodDays,
        uint16 defaultPenaltyRate,
        bool allowPartialRepayments,
        bool allowEarlyRepayment
    ) external nonReentrant onlyKYCVerified(msg.sender) returns (uint256 yieldTokenId) {
        // Validate inputs
        if (capitalAmount == 0) revert InvalidCapitalAmount();
        if (termMonths == 0 || termMonths > 360) revert InvalidTermMonths();
        if (annualROI == 0 || annualROI > 5000) revert InvalidAnnualROI();
        if (gracePeriodDays == 0 || gracePeriodDays > 365) revert InvalidGracePeriod();
        if (defaultPenaltyRate > 1000) revert InvalidDefaultPenaltyRate();

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();

        // ✅ ALIGNED WITH ERC-721: Validate msg.sender owns the property token
        // This matches YieldBaseFacet.createYieldAgreement() validation pattern
        // msg.sender must own exactly 1 unit of the property token to create yield agreement
        require(balanceOf(msg.sender, propertyTokenId) == 1, "Caller must own the property token");
        
        if (!layout.propertyMetadata[propertyTokenId].isVerified) {
            revert PropertyMustBeVerified();
        }

        // Generate yield token ID
        yieldTokenId = CombinedTokenDistribution.getYieldTokenIdForProperty(propertyTokenId);

        // Calculate token amount (1:1 with capital, 18 decimals)
        uint256 tokenAmount = CombinedTokenDistribution.calculateYieldSharesForCapital(capitalAmount);

        // ✅ ALIGNED WITH ERC-721: Mint yield tokens to msg.sender (the caller)
        // This matches YieldBaseFacet pattern where msg.sender is the property owner
        // The caller who owns the property receives the yield tokens
        _mint(msg.sender, yieldTokenId, tokenAmount, "");

        // Store yield agreement data
        layout.yieldAgreementData[yieldTokenId] = CombinedTokenStorage.YieldAgreementData({
            upfrontCapital: capitalAmount,
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
            defaultThreshold: 3 // Default threshold of 3 missed payments
        });

        // Create bidirectional mapping
        layout.propertyToYieldMapping[propertyTokenId] = yieldTokenId;
        layout.yieldToPropertyMapping[yieldTokenId] = propertyTokenId;

        emit YieldTokenMinted(
            yieldTokenId,
            propertyTokenId,
            tokenAmount,
            capitalAmount,
            capitalAmountUsd,
            termMonths,
            annualROI,
            gracePeriodDays,
            defaultPenaltyRate,
            allowPartialRepayments,
            allowEarlyRepayment
        );
    }

    /// @notice Batch mint yield tokens for multiple properties with pooled contributions
    /// @dev Allows multiple investors to contribute capital for yield agreements
    /// @param propertyTokenIds Array of property token IDs
    /// @param contributorsByProperty Array of contributor arrays per property
    /// @param contributionsByProperty Array of contribution arrays per property
    /// @return yieldTokenIds Array of minted yield token IDs
    function batchMintYieldTokens(
        uint256[] memory propertyTokenIds,
        address[][] memory contributorsByProperty,
        uint256[][] memory contributionsByProperty
    ) external onlyOwner nonReentrant returns (uint256[] memory yieldTokenIds) {
        if (propertyTokenIds.length != contributorsByProperty.length) {
            revert ArrayLengthMismatch();
        }
        if (contributorsByProperty.length != contributionsByProperty.length) {
            revert ArrayLengthMismatch();
        }

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();

        uint256 batchSize = propertyTokenIds.length;
        yieldTokenIds = new uint256[](batchSize);
        uint256[] memory totalAmounts = new uint256[](batchSize);

        for (uint256 i = 0; i < batchSize; i++) {
            uint256 propertyTokenId = propertyTokenIds[i];

            // Validate property token exists and is verified
            if (balanceOf(msg.sender, propertyTokenId) != 1) {
                revert CallerMustOwnPropertyToken();
            }
            if (!layout.propertyMetadata[propertyTokenId].isVerified) {
                revert PropertyMustBeVerified();
            }

            // Validate contributors and contributions for this property
            address[] memory contributors = contributorsByProperty[i];
            uint256[] memory contributions = contributionsByProperty[i];
            
            if (contributors.length != contributions.length) {
                revert ArrayLengthMismatch();
            }

            // Calculate total capital and validate
            uint256 totalCapital = 0;
            for (uint256 j = 0; j < contributions.length; j++) {
                if (contributions[j] == 0) revert ZeroContributionNotAllowed();
                totalCapital += contributions[j];
            }

            // Generate yield token ID
            uint256 yieldTokenId = CombinedTokenDistribution.getYieldTokenIdForProperty(propertyTokenId);
            yieldTokenIds[i] = yieldTokenId;

            // Calculate total token amount
            uint256 tokenAmount = CombinedTokenDistribution.calculateYieldSharesForCapital(totalCapital);
            totalAmounts[i] = tokenAmount;

            // Mint yield tokens to each contributor proportionally
            for (uint256 j = 0; j < contributors.length; j++) {
                uint256 contributorShare = (tokenAmount * contributions[j]) / totalCapital;
                _mint(contributors[j], yieldTokenId, contributorShare, "");
            }

            // Store pooled contribution data
            CombinedTokenStorage.PooledContributionData storage pooledData = 
                layout.yieldPooledContributions[yieldTokenId];
            
            pooledData.totalPooledCapital = totalCapital;
            
            for (uint256 j = 0; j < contributors.length; j++) {
                pooledData.contributorBalances[contributors[j]] = contributions[j];
                pooledData.contributorAddresses.push(contributors[j]);
            }

            // Create bidirectional mapping
            layout.propertyToYieldMapping[propertyTokenId] = yieldTokenId;
            layout.yieldToPropertyMapping[yieldTokenId] = propertyTokenId;
        }

        emit BatchYieldTokensMinted(propertyTokenIds, yieldTokenIds, totalAmounts);
    }

}

