// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {CombinedTokenStorage} from "./storage/CombinedTokenStorage.sol";
import {TransferRestrictionsStorage} from "./storage/TransferRestrictionsStorage.sol";
import {CombinedTokenDistribution} from "./libraries/CombinedTokenDistribution.sol";
import {YieldCalculations} from "./libraries/YieldCalculations.sol";
import {TransferRestrictions} from "./libraries/TransferRestrictions.sol";
import {IGovernanceController} from "./interfaces/IGovernanceController.sol";

/// @title CombinedPropertyYieldToken
/// @notice ERC-1155 contract combining property NFTs and yield shares in single standard
/// @dev Implements UUPS proxy pattern with ERC-7201 storage isolation for dual-token functionality
/// Token ID scheme: 1-999,999 (properties), 1,000,000+ (yield shares)
/// Access control: Only owner can mint both property and yield tokens
/// Advantages: Single contract deployment, batch operations, unified interface, gas savings
contract CombinedPropertyYieldToken is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC1155Upgradeable,
    ReentrancyGuardUpgradeable
{
    using CombinedTokenStorage for CombinedTokenStorage.CombinedTokenStorageLayout;
    using CombinedTokenDistribution for uint256;
    using YieldCalculations for uint256;

    /// @notice Emitted when a property token is minted
    /// @param tokenId The token ID of the minted property
    /// @param propertyAddressHash Hash of the property address for verification
    event PropertyTokenMinted(
        uint256 indexed tokenId,
        bytes32 propertyAddressHash,
        string metadataURI
    );

    /// @notice Emitted when yield tokens are minted for a property
    /// @param yieldTokenId The token ID of the yield tokens
    /// @param propertyTokenId The associated property token ID
    /// @param amount The amount of yield tokens minted
    event YieldTokenMinted(
        uint256 indexed yieldTokenId,
        uint256 indexed propertyTokenId,
        uint256 amount
    );

    /// @notice Emitted when a repayment is distributed to yield token holders
    /// @param yieldTokenId The yield token ID receiving the distribution
    /// @param amount The total amount distributed
    event RepaymentDistributed(uint256 indexed yieldTokenId, uint256 amount);

    /// @notice Emitted when a property is verified
    /// @param tokenId The property token ID that was verified
    event PropertyVerified(uint256 indexed tokenId);

    /// @notice Emitted when yield tokens are minted for multiple properties
    /// @param propertyTokenIds Array of property token IDs
    /// @param yieldTokenIds Array of corresponding yield token IDs
    /// @param totalAmounts Array of total token amounts minted for each property
    event BatchYieldTokensMinted(uint256[] propertyTokenIds, uint256[] yieldTokenIds, uint256[] totalAmounts);

    /// @notice Emitted when repayments are distributed to multiple yield tokens
    /// @param yieldTokenIds Array of yield token IDs receiving distributions
    /// @param amounts Array of repayment amounts for each yield token
    /// @param totalDistributed Total amount distributed across all tokens
    event BatchRepaymentsDistributed(uint256[] yieldTokenIds, uint256[] amounts, uint256 totalDistributed);

    /// @notice Emitted when partial repayment is distributed to yield token holders
    /// @param yieldTokenId The yield token ID receiving partial distribution
    /// @param partialAmount The partial repayment amount
    /// @param fullAmount The standard full monthly payment amount
    event PartialYieldRepaymentDistributed(uint256 indexed yieldTokenId, uint256 partialAmount, uint256 fullAmount);

    /// @notice Emitted when a yield agreement defaults
    /// @param yieldTokenId The yield token ID that defaulted
    /// @param totalArrears The total arrears amount at time of default
    event YieldAgreementDefaulted(uint256 indexed yieldTokenId, uint256 totalArrears);

    /// @notice Emitted when yield token transfer restrictions are updated
    /// @param yieldTokenId The yield token ID with updated restrictions
    /// @param lockupEndTimestamp Lockup end timestamp
    /// @param maxSharesPerInvestor Maximum shares per investor in basis points
    event YieldTokenRestrictionsUpdated(uint256 indexed yieldTokenId, uint256 lockupEndTimestamp, uint256 maxSharesPerInvestor);

    /// @notice Emitted when yield token transfers are paused
    /// @param yieldTokenId The yield token ID that was paused
    event YieldTokenTransfersPaused(uint256 indexed yieldTokenId);

    /// @notice Emitted when yield token transfers are unpaused
    /// @param yieldTokenId The yield token ID that was unpaused
    event YieldTokenTransfersUnpaused(uint256 indexed yieldTokenId);

    /// @notice Emitted when a yield token transfer is blocked by restrictions
    /// @param yieldTokenId The yield token ID
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Transfer amount
    /// @param reason Restriction violation reason
    event YieldTokenTransferBlocked(uint256 indexed yieldTokenId, address from, address to, uint256 amount, string reason);

    /// @notice Mapping of yield token IDs to whether restrictions are enabled
    /// @dev Property tokens (tokenId < 1,000,000) remain unrestricted
    mapping(uint256 => bool) public yieldTokenRestrictionsEnabled;

    /// @dev Disable constructor for UUPS proxy pattern
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the CombinedPropertyYieldToken contract
    /// @dev Sets up ERC-1155 with base URI, initializes UUPS proxy
    /// @param initialOwner Address that will own the contract
    /// @param baseURI Base URI for token metadata (can be empty for custom URI logic)
    function initialize(address initialOwner, string memory baseURI) public initializer {
        __ERC1155_init(baseURI);
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    /// @notice Mint a new property token
    /// @dev Only callable by contract owner. Creates non-fungible property token with supply of 1
    /// @param propertyAddressHash keccak256 hash of the property address for verification
    /// @param metadataURI IPFS URI containing detailed property documents
    /// @return tokenId The token ID of the newly minted property token
    function mintPropertyToken(
        bytes32 propertyAddressHash,
        string memory metadataURI
    ) external onlyOwner nonReentrant returns (uint256 tokenId) {
        require(propertyAddressHash != bytes32(0), "Property address hash cannot be zero");
        require(bytes(metadataURI).length > 0, "Metadata URI cannot be empty");

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        tokenId = ++layout.propertyTokenIdCounter;

        require(CombinedTokenDistribution.validateTokenIdRange(tokenId, true), "Invalid property token ID range");

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

    /// @notice Mint yield tokens for a property
    /// @dev ENHANCED AUTONOMOUS YIELD MANAGEMENT: Configures advanced yield features like defaults, partial repayments, early repayments
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
        uint16 termMonths,
        uint16 annualROI,
        uint16 gracePeriodDays,
        uint16 defaultPenaltyRate,
        bool allowPartialRepayments,
        bool allowEarlyRepayment
    ) external onlyOwner nonReentrant returns (uint256 yieldTokenId) {
        require(capitalAmount > 0, "Capital amount must be greater than zero");
        require(termMonths > 0 && termMonths <= 360, "Term must be between 1 and 360 months");
        require(annualROI > 0 && annualROI <= 5000, "ROI must be between 1 and 5000 basis points");
        require(gracePeriodDays > 0 && gracePeriodDays <= 365, "Grace period must be between 1 and 365 days");
        require(defaultPenaltyRate <= 1000, "Default penalty rate cannot exceed 10%");

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();

        // Validate property token exists and is owned by caller
        require(balanceOf(msg.sender, propertyTokenId) == 1, "Caller must own the property token");
        require(layout.propertyMetadata[propertyTokenId].isVerified, "Property must be verified");

        // Generate yield token ID
        yieldTokenId = CombinedTokenDistribution.getYieldTokenIdForProperty(propertyTokenId);

        // Calculate token amount (1:1 with capital, 18 decimals)
        uint256 tokenAmount = CombinedTokenDistribution.calculateYieldSharesForCapital(capitalAmount);

        _mint(msg.sender, yieldTokenId, tokenAmount, ""); // Mint fungible yield tokens

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

        emit YieldTokenMinted(yieldTokenId, propertyTokenId, tokenAmount);
    }

    /// @notice Distribute yield repayment to holders of yield tokens
    /// @dev Only callable by contract owner. Calculates pro-rata distribution and transfers ETH
    /// @param yieldTokenId The yield token ID to distribute repayment for
    function distributeYieldRepayment(uint256 yieldTokenId)
        external
        onlyOwner
        nonReentrant
        payable
    {
        require(CombinedTokenDistribution.isYieldToken(yieldTokenId), "Invalid yield token ID");

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        CombinedTokenStorage.YieldAgreementData storage yieldData = layout.yieldAgreementData[yieldTokenId];

        require(yieldData.isActive, "Yield agreement is not active");
        require(yieldData.upfrontCapital > 0, "Yield agreement does not exist");

        // Get all holders of this yield token
        address[] memory holders = CombinedTokenStorage.getHolders(layout, yieldTokenId);

        // Calculate expected monthly repayment
        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(
            yieldData.upfrontCapital,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints
        );

        require(msg.value >= monthlyPayment, "Insufficient repayment amount");

        // Update storage
        yieldData.totalRepaid += msg.value;
        yieldData.lastRepaymentTimestamp = block.timestamp;

        // Distribute repayment to all token holders proportionally
        // Check all tracked holders and verify they still have balances
        uint256 tokenTotalSupply = layout.totalSupply[yieldTokenId];
        uint256 totalDistributed = 0;

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 holderBalance = balanceOf(holder, yieldTokenId);
            if (holderBalance > 0) {
                uint256 holderShare = (msg.value * holderBalance) / tokenTotalSupply;
                if (holderShare > 0) {
                    (bool success, ) = payable(holder).call{value: holderShare}("");
                    if (!success) {
                        // On failure, accumulate to unclaimed remainder
                        layout.unclaimedRemainder[holder] += holderShare;
                    } else {
                        totalDistributed += holderShare;
                    }
                }
            }
        }

        // Handle any undistributed amount (rounding dust)
        uint256 remainder = msg.value - totalDistributed;
        if (remainder > 0) {
            // Send remainder to owner
            (bool success, ) = payable(owner()).call{value: remainder}("");
            if (!success) {
                layout.unclaimedRemainder[owner()] += remainder;
            }
        }

        // Check if agreement is complete
        uint256 totalExpected = YieldCalculations.calculateTotalRepaymentAmount(
            yieldData.upfrontCapital,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints
        );

        if (yieldData.totalRepaid >= totalExpected) {
            yieldData.isActive = false;
            // Could burn remaining tokens here
        }

        emit RepaymentDistributed(yieldTokenId, msg.value);
    }

    /// @notice Verify a property token
    /// @dev Only callable by contract owner. Sets verification timestamp and marks property as verified
    /// @param propertyTokenId The property token ID to verify
    function verifyProperty(uint256 propertyTokenId) external onlyOwner {
        require(CombinedTokenDistribution.isPropertyToken(propertyTokenId), "Invalid property token ID");
        require(balanceOf(msg.sender, propertyTokenId) == 1, "Caller must own the property token");

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        CombinedTokenStorage.PropertyMetadata storage metadata = layout.propertyMetadata[propertyTokenId];

        require(!metadata.isVerified, "Property already verified");

        metadata.isVerified = true;
        metadata.verificationTimestamp = block.timestamp;
        metadata.verifierAddress = msg.sender;

        emit PropertyVerified(propertyTokenId);
    }

    /// @notice Get property metadata
    /// @dev Returns property metadata for a given token ID
    /// @param tokenId The property token ID
    /// @return PropertyMetadata struct
    function getPropertyMetadata(uint256 tokenId)
        external
        view
        returns (CombinedTokenStorage.PropertyMetadata memory)
    {
        require(CombinedTokenDistribution.isPropertyToken(tokenId), "Invalid property token ID");
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        return layout.propertyMetadata[tokenId];
    }

    /// @notice Get yield agreement data
    /// @dev Returns yield agreement data for a given token ID
    /// @param tokenId The yield token ID
    /// @return YieldAgreementData struct
    function getYieldAgreementData(uint256 tokenId)
        external
        view
        returns (CombinedTokenStorage.YieldAgreementData memory)
    {
        require(CombinedTokenDistribution.isYieldToken(tokenId), "Invalid yield token ID");
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        return layout.yieldAgreementData[tokenId];
    }

    /// @notice Override uri to return custom metadata URIs
    /// @dev Returns metadata URI from storage for property tokens, generated URI for yield tokens
    /// @param tokenId The token ID
    /// @return URI string for token metadata
    function uri(uint256 tokenId) public view override returns (string memory) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();

        if (CombinedTokenDistribution.isPropertyToken(tokenId)) {
            return layout.propertyMetadata[tokenId].metadataURI;
        } else {
            // For yield tokens, return a generated URI or base URI
            return string(abi.encodePacked(super.uri(tokenId), Strings.toString(tokenId)));
        }
    }


    /// @notice Get the total supply of a token
    /// @dev Public view function to get total supply from storage
    /// @param tokenId The token ID to query
    /// @return The total supply of the token
    function totalSupply(uint256 tokenId) external view returns (uint256) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        return layout.totalSupply[tokenId];
    }

    /// @notice Get the list of holders for a token
    /// @dev Public view function to check token holders (for testing purposes)
    /// @param tokenId The token ID to query holders for
    /// @return Array of addresses holding the token
    function getTokenHolders(uint256 tokenId) external view returns (address[] memory) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        return CombinedTokenStorage.getHolders(layout, tokenId);
    }

    /// @notice Sets transfer restrictions for a specific yield token
    /// @dev Only owner can call this function. Property tokens remain unrestricted.
    /// @param yieldTokenId The yield token ID to set restrictions for
    /// @param lockupEndTimestamp Timestamp when lockup period ends (0 = no lockup)
    /// @param maxSharesPerInvestor Maximum shares per investor in basis points (e.g., 2000 = 20%)
    /// @param minHoldingPeriod Minimum holding period in seconds (e.g., 7 days = 604800)
    function setYieldTokenRestrictions(
        uint256 yieldTokenId,
        uint256 lockupEndTimestamp,
        uint256 maxSharesPerInvestor,
        uint256 minHoldingPeriod
    ) external onlyOwner {
        require(CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false), "Not a yield token ID");
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.lockupEndTimestamp = lockupEndTimestamp;
        restrictions.maxSharesPerInvestor = maxSharesPerInvestor;
        restrictions.minHoldingPeriod = minHoldingPeriod;
        
        // Enable restrictions for this yield token
        yieldTokenRestrictionsEnabled[yieldTokenId] = true;
        
        emit YieldTokenRestrictionsUpdated(yieldTokenId, lockupEndTimestamp, maxSharesPerInvestor);
    }

    /// @notice Pauses transfers for a specific yield token (emergency control)
    /// @dev Only owner can call this function
    /// @param yieldTokenId The yield token ID to pause
    function pauseYieldTokenTransfers(uint256 yieldTokenId) external onlyOwner {
        require(CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false), "Not a yield token ID");
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.isTransferPaused = true;
        yieldTokenRestrictionsEnabled[yieldTokenId] = true;
        
        emit YieldTokenTransfersPaused(yieldTokenId);
    }

    /// @notice Unpauses transfers for a specific yield token
    /// @dev Only owner can call this function
    /// @param yieldTokenId The yield token ID to unpause
    function unpauseYieldTokenTransfers(uint256 yieldTokenId) external onlyOwner {
        require(CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false), "Not a yield token ID");
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.isTransferPaused = false;
        
        emit YieldTokenTransfersUnpaused(yieldTokenId);
    }

    /// @notice Sets lockup end timestamp for a specific yield token (governance pathway)
    /// @dev Only owner or governance can call this function
    /// @param yieldTokenId The yield token ID to update
    /// @param lockupEndTimestamp Timestamp when lockup period ends (0 = no lockup)
    function setYieldTokenLockupEndTimestamp(uint256 yieldTokenId, uint256 lockupEndTimestamp) external onlyOwner {
        require(CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false), "Not a yield token ID");
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.lockupEndTimestamp = lockupEndTimestamp;
        
        // Emit update event with current values
        emit YieldTokenRestrictionsUpdated(yieldTokenId, lockupEndTimestamp, restrictions.maxSharesPerInvestor);
    }

    /// @notice Sets maximum shares per investor for a specific yield token (governance pathway)
    /// @dev Only owner or governance can call this function
    /// @param yieldTokenId The yield token ID to update
    /// @param maxSharesPerInvestor Maximum shares per investor in basis points (e.g., 2000 = 20%)
    function setYieldTokenMaxSharesPerInvestor(uint256 yieldTokenId, uint256 maxSharesPerInvestor) external onlyOwner {
        require(CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false), "Not a yield token ID");
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.maxSharesPerInvestor = maxSharesPerInvestor;
        
        // Emit update event with current values
        emit YieldTokenRestrictionsUpdated(yieldTokenId, restrictions.lockupEndTimestamp, maxSharesPerInvestor);
    }

    /// @notice Sets minimum holding period for a specific yield token (governance pathway)
    /// @dev Only owner or governance can call this function
    /// @param yieldTokenId The yield token ID to update
    /// @param minHoldingPeriod Minimum holding period in seconds (e.g., 7 days = 604800)
    function setYieldTokenMinHoldingPeriod(uint256 yieldTokenId, uint256 minHoldingPeriod) external onlyOwner {
        require(CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false), "Not a yield token ID");
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        restrictions.minHoldingPeriod = minHoldingPeriod;
        
        // Emit update event with current values
        emit YieldTokenRestrictionsUpdated(yieldTokenId, restrictions.lockupEndTimestamp, restrictions.maxSharesPerInvestor);
    }

    /// @notice Checks if a yield token transfer would be allowed under current restrictions
    /// @dev View function for frontend validation before user initiates transfer
    /// @param yieldTokenId The yield token ID
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Transfer amount
    /// @return allowed True if transfer would be allowed
    /// @return reason Human-readable reason if transfer would be blocked (empty if allowed)
    function isYieldTokenTransferAllowed(
        uint256 yieldTokenId,
        address from,
        address to,
        uint256 amount
    ) external view returns (bool allowed, string memory reason) {
        // Property tokens always allowed (no restrictions)
        if (!CombinedTokenDistribution.validateTokenIdRange(yieldTokenId, false)) {
            return (true, "");
        }
        
        // If restrictions disabled for this yield token, allow transfer
        if (!yieldTokenRestrictionsEnabled[yieldTokenId]) {
            return (true, "");
        }
        
        // Mint and burn operations bypass restrictions
        if (from == address(0) || to == address(0)) {
            return (true, "");
        }
        
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
            yieldRestrictions.restrictionsById[yieldTokenId];
        
        uint256 recipientBalance = balanceOf(to, yieldTokenId);
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        uint256 supply = layout.totalSupply[yieldTokenId];
        
        return TransferRestrictions.validateAllRestrictions(
            from,
            to,
            amount,
            recipientBalance,
            supply,
            restrictions
        );
    }

    /// @notice Override ERC-1155 transfer hook to enforce yield token restrictions and maintain holder tracking
    /// @dev Updates totalSupply and holder lists for accurate distribution tracking
    ///      TRANSFER RESTRICTIONS: Validates restrictions for yield tokens (tokenId >= 1,000,000) only.
    ///      Property tokens (tokenId < 1,000,000) remain unrestricted for NFT liquidity.
    /// @param from Address sending tokens (address(0) for mint)
    /// @param to Address receiving tokens (address(0) for burn)
    /// @param ids Array of token IDs
    /// @param values Array of token amounts
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();

        // Validate yield token transfer restrictions BEFORE updating
        // Only check restrictions for actual transfers (not mint/burn) of yield tokens
        if (from != address(0) && to != address(0)) {
            TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
                TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
            
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];
                uint256 amount = values[i];
                
                // Only enforce restrictions for yield tokens (tokenId >= 1,000,000)
                bool isYieldToken = !CombinedTokenDistribution.validateTokenIdRange(id, true);
                
                if (isYieldToken && yieldTokenRestrictionsEnabled[id]) {
                    TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
                        yieldRestrictions.restrictionsById[id];
                    
                    uint256 recipientBalance = balanceOf(to, id);
                    uint256 supply = layout.totalSupply[id];
                    
                    (bool allowed, string memory reason) = TransferRestrictions.validateAllRestrictions(
                        from,
                        to,
                        amount,
                        recipientBalance,
                        supply,
                        restrictions
                    );
                    
                    if (!allowed) {
                        emit YieldTokenTransferBlocked(id, from, to, amount, reason);
                        revert(reason);
                    }
                }
            }
        }

        // Call parent implementation to perform actual balance updates
        super._update(from, to, ids, values);

        // Update lastTransferTimestamp AFTER successful transfer/mint (for holding period enforcement)
        TransferRestrictionsStorage.YieldTokenRestrictionsStorage storage yieldRestrictions = 
            TransferRestrictionsStorage.getYieldTokenRestrictionsStorage();
        
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            
            // Only update timestamp for yield tokens with restrictions enabled
            bool isYieldToken = !CombinedTokenDistribution.validateTokenIdRange(id, true);
            
            if (isYieldToken && yieldTokenRestrictionsEnabled[id]) {
                TransferRestrictionsStorage.TransferRestrictionData storage restrictions = 
                    yieldRestrictions.restrictionsById[id];
                
                // Set timestamp on mint (from == address(0)) if holding period is configured
                if (from == address(0) && restrictions.minHoldingPeriod > 0) {
                    restrictions.lastTransferTimestamp[to] = block.timestamp;
                }
                // Update timestamp on transfer (from != address(0) && to != address(0))
                else if (from != address(0) && to != address(0)) {
                    restrictions.lastTransferTimestamp[to] = block.timestamp;
                }
            }
        }

        // Process each token ID and amount for totalSupply updates
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = values[i];

            if (from == address(0)) {
                // Mint: increment total supply
                layout.totalSupply[id] += amount;
            } else if (to == address(0)) {
                // Burn: decrement total supply
                layout.totalSupply[id] -= amount;
            }
        }

        // Now update holder tracking based on final balances
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];

            if (from == address(0)) {
                // Mint: add holder
                if (to != address(0)) {
                    CombinedTokenStorage.addHolder(layout, id, to);
                }
            } else if (to == address(0)) {
                // Burn: remove holder if balance is now 0
                if (balanceOf(from, id) == 0 && from != address(0)) {
                    CombinedTokenStorage.removeHolder(layout, id, from);
                }
            } else {
                // Transfer: update holder tracking
                // Add recipient as holder if they now have balance
                if (balanceOf(to, id) > 0 && to != address(0)) {
                    CombinedTokenStorage.addHolder(layout, id, to);
                }
                // Remove sender as holder if their balance is now 0
                if (balanceOf(from, id) == 0 && from != address(0)) {
                    CombinedTokenStorage.removeHolder(layout, id, from);
                }
            }
        }
    }

    /// @notice Authorize contract upgrades
    /// @dev Only owner can upgrade the contract (UUPS proxy pattern)
    /// @param newImplementation Address of the new implementation contract
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /// @notice Burn tokens from an account
    /// @dev Burns amount of tokens of a given id from account, reducing total supply and updating holders
    /// @param account The account to burn tokens from
    /// @param id The token id to burn
    /// @param amount The amount to burn
    function burn(address account, uint256 id, uint256 amount) external {
        require(msg.sender == account || isApprovedForAll(account, msg.sender), "ERC1155: caller is not owner nor approved");
        require(balanceOf(account, id) >= amount, "ERC1155: burn amount exceeds balance");
        _burn(account, id, amount);
    }

    /// @notice Batch mint yield tokens for multiple properties with pooled contributors
    /// @dev ERC-1155 BATCH OPTIMIZATION: Mints yield tokens for multiple properties in single transaction
    /// @param propertyTokenIds Array of property token IDs to create yield tokens for
    /// @param contributorsByProperty Nested array of contributor addresses for each property
    /// @param contributionsByProperty Nested array of capital amounts for each property
    function batchMintYieldTokens(
        uint256[] memory propertyTokenIds,
        address[][] memory contributorsByProperty,
        uint256[][] memory contributionsByProperty
    ) external nonReentrant {
        require(propertyTokenIds.length == contributorsByProperty.length, "Array length mismatch");
        require(contributorsByProperty.length == contributionsByProperty.length, "Array length mismatch");

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();

        uint256 batchSize = propertyTokenIds.length;
        uint256[] memory yieldTokenIds = new uint256[](batchSize);
        uint256[] memory totalAmounts = new uint256[](batchSize);

        for (uint256 i = 0; i < batchSize; i++) {
            uint256 propertyTokenId = propertyTokenIds[i];

            // Validate property token exists and is verified
            require(balanceOf(msg.sender, propertyTokenId) == 1, "Caller must own all property tokens");
            require(layout.propertyMetadata[propertyTokenId].isVerified, "All properties must be verified");

            // Validate contributors and contributions for this property
            address[] memory contributors = contributorsByProperty[i];
            uint256[] memory contributions = contributionsByProperty[i];
            require(contributors.length == contributions.length, "Contributor array mismatch");

            // Calculate total capital and validate
            uint256 totalCapital = 0;
            for (uint256 j = 0; j < contributions.length; j++) {
                require(contributions[j] > 0, "Zero contribution not allowed");
                totalCapital += contributions[j];
            }

            // Generate yield token ID
            uint256 yieldTokenId = CombinedTokenDistribution.getYieldTokenIdForProperty(propertyTokenId);
            yieldTokenIds[i] = yieldTokenId;
            totalAmounts[i] = totalCapital;

            // Calculate shares for each contributor
            uint256[] memory shareAmounts = CombinedTokenDistribution.batchCalculateYieldShares(contributions);

            // Mint tokens to each contributor and update pooled contribution tracking
            for (uint256 j = 0; j < contributors.length; j++) {
                address contributor = contributors[j];
                uint256 sharesToMint = shareAmounts[j];
                uint256 capitalContribution = contributions[j];

                _mint(contributor, yieldTokenId, sharesToMint, "");

                // Update pooled contribution tracking
                CombinedTokenStorage.PooledContributionData storage pooledData = layout.yieldPooledContributions[yieldTokenId];
                pooledData.contributorBalances[contributor] += capitalContribution;
                pooledData.totalPooledCapital += capitalContribution;

                if (pooledData.contributorAddresses.length == 0 ||
                    pooledData.contributorAddresses[pooledData.contributorAddresses.length - 1] != contributor) {
                    pooledData.contributorAddresses.push(contributor);
                }
            }

            // Store enhanced yield agreement data (using default values - could be made configurable)
            layout.yieldAgreementData[yieldTokenId] = CombinedTokenStorage.YieldAgreementData({
                upfrontCapital: totalCapital,
                repaymentTermMonths: 12, // Default
                annualROIBasisPoints: 500, // Default 5%
                totalRepaid: 0,
                lastRepaymentTimestamp: block.timestamp,
                isActive: true,
                missedPaymentCount: 0,
                gracePeriodDays: 30, // Default 30 days
                accumulatedArrears: 0,
                overpaymentCredit: 0,
                prepaymentAmount: 0,
                defaultPenaltyRate: 200, // Default 2%
                lastMissedPaymentTimestamp: 0,
                gracePeriodExpiryTimestamp: 0,
                isInDefault: false,
                allowPartialRepayments: true, // Default enabled
                allowEarlyRepayment: true, // Default enabled
                defaultThreshold: 3 // Default 3 missed payments
            });

            // Create bidirectional mapping
            layout.propertyToYieldMapping[propertyTokenId] = yieldTokenId;
            layout.yieldToPropertyMapping[yieldTokenId] = propertyTokenId;
        }

        emit BatchYieldTokensMinted(propertyTokenIds, yieldTokenIds, totalAmounts);
    }

    /// @notice Batch distribute repayments to multiple yield tokens
    /// @dev ERC-1155 BATCH OPTIMIZATION: Distributes repayments to multiple yield tokens in single transaction
    /// @param yieldTokenIds Array of yield token IDs to distribute repayments to
    /// @param repaymentAmounts Array of repayment amounts for each yield token
    function batchDistributeRepayments(
        uint256[] memory yieldTokenIds,
        uint256[] memory repaymentAmounts
    ) external onlyOwner nonReentrant payable {
        require(yieldTokenIds.length == repaymentAmounts.length, "Array length mismatch");

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();

        uint256 batchSize = yieldTokenIds.length;
        uint256 totalRequired = 0;

        // Calculate total required payment
        for (uint256 i = 0; i < batchSize; i++) {
            totalRequired += repaymentAmounts[i];
        }
        require(msg.value >= totalRequired, "Insufficient total payment amount");

        // Get holders for each token (simplified - in production would need actual balance checking)
        address[][] memory holdersByToken = new address[][](batchSize);
        uint256[] memory totalSupplies = new uint256[](batchSize);

        for (uint256 i = 0; i < batchSize; i++) {
            uint256 yieldTokenId = yieldTokenIds[i];
            require(CombinedTokenDistribution.isYieldToken(yieldTokenId), "Invalid yield token ID");

            holdersByToken[i] = CombinedTokenStorage.getHolders(layout, yieldTokenId);
            totalSupplies[i] = layout.totalSupply[yieldTokenId];

            // Update yield agreement data
            CombinedTokenStorage.YieldAgreementData storage yieldData = layout.yieldAgreementData[yieldTokenId];
            require(yieldData.isActive, "All yield agreements must be active");

            yieldData.totalRepaid += repaymentAmounts[i];
            yieldData.lastRepaymentTimestamp = block.timestamp;
        }

        // Calculate distributions for each token and holder
        uint256 totalDistributions = 0;
        for (uint256 i = 0; i < batchSize; i++) {
            totalDistributions += holdersByToken[i].length;
        }

        address[] memory allRecipients = new address[](totalDistributions);
        uint256[] memory allAmounts = new uint256[](totalDistributions);
        uint256 currentIndex = 0;

        // Calculate actual distributions using balanceOf
        for (uint256 i = 0; i < batchSize; i++) {
            uint256 yieldTokenId = yieldTokenIds[i];
            uint256 repaymentAmount = repaymentAmounts[i];
            uint256 totalSupply = totalSupplies[i];
            address[] memory holders = holdersByToken[i];

            for (uint256 j = 0; j < holders.length; j++) {
                address holder = holders[j];
                uint256 balance = balanceOf(holder, yieldTokenId);

                if (balance > 0) {
                    uint256 share = YieldCalculations.calculateProRataDistribution(
                        repaymentAmount,
                        balance,
                        totalSupply
                    );

                    allRecipients[currentIndex] = holder;
                    allAmounts[currentIndex] = share;
                    currentIndex++;
                }
            }
        }

        // Trim arrays if needed
        if (currentIndex < totalDistributions) {
            address[] memory trimmedRecipients = new address[](currentIndex);
            uint256[] memory trimmedAmounts = new uint256[](currentIndex);

            for (uint256 i = 0; i < currentIndex; i++) {
                trimmedRecipients[i] = allRecipients[i];
                trimmedAmounts[i] = allAmounts[i];
            }

            allRecipients = trimmedRecipients;
            allAmounts = trimmedAmounts;
        }

        // Transfer ETH to recipients using .call with failure handling
        uint256 totalDistributed = 0;
        for (uint256 i = 0; i < allRecipients.length; i++) {
            if (allAmounts[i] > 0) {
                (bool success, ) = payable(allRecipients[i]).call{value: allAmounts[i]}("");
                if (!success) {
                    // On failure, accumulate to unclaimed remainder
                    layout.unclaimedRemainder[allRecipients[i]] += allAmounts[i];
                } else {
                    totalDistributed += allAmounts[i];
                }
            }
        }

        // Ensure total distributed equals sum of repayment amounts
        uint256 expectedTotal = 0;
        for (uint256 i = 0; i < repaymentAmounts.length; i++) {
            expectedTotal += repaymentAmounts[i];
        }
        require(totalDistributed == expectedTotal, "Distribution amount mismatch");

        emit BatchRepaymentsDistributed(yieldTokenIds, repaymentAmounts, totalDistributed);
    }

    /// @notice Distribute partial yield repayment to holders of a yield token
    /// @dev Handles partial repayments using proportional allocation
    /// @param yieldTokenId The yield token ID to distribute partial repayment for
    /// @param partialAmount The partial repayment amount received
    /// @param fullMonthlyPayment The standard full monthly payment amount
    function distributePartialYieldRepayment(
        uint256 yieldTokenId,
        uint256 partialAmount,
        uint256 fullMonthlyPayment
    ) external onlyOwner nonReentrant payable {
        require(CombinedTokenDistribution.isYieldToken(yieldTokenId), "Invalid yield token ID");
        require(partialAmount > 0 && msg.value == partialAmount, "Invalid partial amount");

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        CombinedTokenStorage.YieldAgreementData storage yieldData = layout.yieldAgreementData[yieldTokenId];

        require(yieldData.isActive, "Yield agreement is not active");
        require(yieldData.allowPartialRepayments, "Partial repayments not allowed");

        // Get holders and calculate proportional distribution
        address[] memory holders = CombinedTokenStorage.getHolders(layout, yieldTokenId);
        uint256 totalSupply = layout.totalSupply[yieldTokenId];

        // Calculate allocation between arrears and current payment
        (uint256 arrearsPayment, uint256 currentPayment) = YieldCalculations.calculatePartialRepaymentAllocation(
            partialAmount,
            yieldData.accumulatedArrears,
            fullMonthlyPayment
        );

        // Update storage
        yieldData.accumulatedArrears -= arrearsPayment;
        yieldData.totalRepaid += partialAmount;
        yieldData.lastRepaymentTimestamp = block.timestamp;

        // Distribute proportionally using .call with failure handling
        uint256 totalDistributed = 0;
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 balance = balanceOf(holder, yieldTokenId);
            if (balance > 0) {
                uint256 holderShare = (partialAmount * balance) / totalSupply;
                if (holderShare > 0) {
                    (bool success, ) = payable(holder).call{value: holderShare}("");
                    if (!success) {
                        // On failure, accumulate to unclaimed remainder
                        layout.unclaimedRemainder[holder] += holderShare;
                    } else {
                        totalDistributed += holderShare;
                    }
                }
            }
        }

        // Handle any undistributed amount (rounding dust)
        uint256 remainder = partialAmount - totalDistributed;
        if (remainder > 0) {
            (bool success, ) = payable(owner()).call{value: remainder}("");
            if (!success) {
                layout.unclaimedRemainder[owner()] += remainder;
            }
        }

        emit PartialYieldRepaymentDistributed(yieldTokenId, partialAmount, fullMonthlyPayment);
    }

    /// @notice Handle yield agreement default
    /// @dev Marks agreement as defaulted and calculates final penalties
    /// @param yieldTokenId The yield token ID to mark as defaulted
    function handleYieldDefault(uint256 yieldTokenId) external onlyOwner {
        require(CombinedTokenDistribution.isYieldToken(yieldTokenId), "Invalid yield token ID");

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        CombinedTokenStorage.YieldAgreementData storage yieldData = layout.yieldAgreementData[yieldTokenId];

        require(yieldData.isActive, "Yield agreement is not active");

        // Check if should default based on missed payments and grace period
        bool shouldDefault = YieldCalculations.isAgreementInDefault(
            yieldData.lastRepaymentTimestamp,
            yieldData.lastMissedPaymentTimestamp,
            yieldData.gracePeriodDays,
            yieldData.missedPaymentCount,
            yieldData.defaultThreshold
        );

        require(shouldDefault, "Agreement does not meet default criteria");

        yieldData.isInDefault = true;

        emit YieldAgreementDefaulted(yieldTokenId, yieldData.accumulatedArrears);
    }

    /// @notice Get comprehensive yield agreement status
    /// @dev Returns detailed status including default information
    /// @param yieldTokenId The yield token ID to get status for
    /// @return isActive Whether the agreement is active
    /// @return isInDefault Whether the agreement is in default
    /// @return missedPaymentCount Number of missed payments
    /// @return accumulatedArrears Total arrears accumulated
    /// @return overpaymentCredit Available overpayment credit
    /// @return remainingBalance Remaining balance to be paid
    /// @return gracePeriodExpiry Timestamp when grace period expires
    /// @return nextPaymentDue Timestamp when next payment is due
    function getYieldAgreementStatus(uint256 yieldTokenId) external view returns (
        bool isActive,
        bool isInDefault,
        uint8 missedPaymentCount,
        uint256 accumulatedArrears,
        uint256 overpaymentCredit,
        uint256 remainingBalance,
        uint256 gracePeriodExpiry,
        uint256 nextPaymentDue
    ) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        CombinedTokenStorage.YieldAgreementData storage yieldData = layout.yieldAgreementData[yieldTokenId];
        require(yieldData.upfrontCapital > 0, "Yield agreement does not exist");

        uint256 elapsedMonths = YieldCalculations.calculateElapsedMonths(
            yieldData.lastRepaymentTimestamp,
            block.timestamp
        );

        uint256 remainingBalance = YieldCalculations.calculateRemainingBalance(
            yieldData.upfrontCapital,
            yieldData.totalRepaid,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints,
            elapsedMonths
        );

        uint256 gracePeriodExpiry = YieldCalculations.calculateGracePeriodExpiry(
            yieldData.lastMissedPaymentTimestamp,
            yieldData.gracePeriodDays
        );

        uint256 nextPaymentDue = yieldData.lastRepaymentTimestamp + 30 days; // Simplified monthly

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

    /// @notice Get outstanding yield balance including principal, interest, and arrears
    /// @dev Calculates total amount still owed on the yield agreement
    /// @param yieldTokenId The yield token ID to calculate outstanding balance for
    /// @return outstandingBalance Total amount still owed
    function getOutstandingYieldBalance(uint256 yieldTokenId) external view returns (uint256 outstandingBalance) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        CombinedTokenStorage.YieldAgreementData storage yieldData = layout.yieldAgreementData[yieldTokenId];
        require(yieldData.upfrontCapital > 0, "Yield agreement does not exist");

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

        return remainingPrincipalAndInterest + yieldData.accumulatedArrears - yieldData.overpaymentCredit;
    }

    /// @notice Allows users to claim unclaimed ETH due to failed transfers
    /// @dev Pull-payment pattern to handle failed .call transfers
    function claimUnclaimedRemainder() external {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        uint256 amount = layout.unclaimedRemainder[msg.sender];
        require(amount > 0, "No unclaimed remainder");

        layout.unclaimedRemainder[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Claim transfer failed");
    }

    /// @notice Gets the unclaimed remainder amount for an address
    /// @param account Address to check
    /// @return Amount of unclaimed ETH available
    function getUnclaimedRemainder(address account) external view returns (uint256) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        return layout.unclaimedRemainder[account];
    }

    /// @notice Get the combined token storage reference (internal helper)
    /// @dev Internal function to access ERC-7201 storage layout
    /// @return layout Reference to CombinedTokenStorageLayout
    function _getCombinedTokenStorage()
        internal
        pure
        returns (CombinedTokenStorage.CombinedTokenStorageLayout storage layout)
    {
        return CombinedTokenStorage.getCombinedTokenStorage();
    }

    // ============ Governance Support Functions ============

    /// @notice Get all holders of a specific yield token
    /// @dev Returns array of addresses holding yield tokens for governance voting
    /// @param yieldTokenId The yield token ID to query holders for
    /// @return holders Array of addresses holding this yield token
    function getYieldTokenHolders(uint256 yieldTokenId) external view returns (address[] memory holders) {
        require(yieldTokenId >= 1_000_000, "Invalid yield token ID");
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = _getCombinedTokenStorage();
        return layout.yieldHolders[yieldTokenId];
    }

    /// @notice Get voting power for a voter on a specific yield token
    /// @dev Voting power equals token balance for ERC-1155 governance
    /// @param voter Address to check voting power for
    /// @param yieldTokenId Yield token ID representing the agreement
    /// @return votingPower Number of votes (token balance)
    function getYieldTokenVotingPower(address voter, uint256 yieldTokenId) external view returns (uint256 votingPower) {
        require(yieldTokenId >= 1_000_000, "Invalid yield token ID");
        return balanceOf(voter, yieldTokenId);
    }

    /// @notice Batch cast votes on multiple proposals (ERC-1155 efficiency)
    /// @dev Allows voters to cast votes on multiple proposals in single transaction
    /// @param proposalIds Array of proposal IDs to vote on
    /// @param voteSupports Array of vote directions (0=Against, 1=For, 2=Abstain)
    /// @param governanceController Address of governance controller to call
    function batchCastVotes(
        uint256[] memory proposalIds,
        uint8[] memory voteSupports,
        address governanceController
    ) external {
        require(proposalIds.length == voteSupports.length, "Array length mismatch");
        require(governanceController != address(0), "Invalid governance controller");

        // Import interface
        IGovernanceController gov = IGovernanceController(governanceController);

        // Cast votes for each proposal
        for (uint256 i = 0; i < proposalIds.length; i++) {
            gov.castVote(proposalIds[i], voteSupports[i]);
        }

        // Emit batch event for tracking (voting powers would be tracked by individual events)
        uint256[] memory votingPowers = new uint256[](proposalIds.length);
        emit BatchVotesCast(msg.sender, proposalIds, voteSupports, votingPowers);
    }

    /// @notice Emitted when batch votes are cast
    /// @param voter Address that cast the votes
    /// @param proposalIds Array of proposal IDs voted on
    /// @param voteSupports Array of vote directions
    /// @param votingPowers Array of voting powers used
    event BatchVotesCast(
        address indexed voter,
        uint256[] proposalIds,
        uint8[] voteSupports,
        uint256[] votingPowers
    );
}
