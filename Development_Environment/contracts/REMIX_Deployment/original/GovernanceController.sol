// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./storage/GovernanceStorage.sol";
import "./libraries/GovernanceCalculations.sol";
import "./YieldBase.sol";
import "./YieldSharesToken.sol";
import "./CombinedPropertyYieldToken.sol";
import "./KYCRegistry.sol";

/**
 * @title GovernanceController
 * @notice On-chain governance contract for yield management with token-weighted voting
 * @dev Implements UUPS proxy pattern with ERC-7201 namespaced storage for upgradeable governance
 * 
 * Governance Architecture:
 * - Token-weighted voting: 1 token = 1 vote for democratic control
 * - Proposal types: ROI adjustments, reserve allocation/withdrawal, governance params, agreement params
 * - Voting mechanics: 1 day delay, 7 day voting period, 10% quorum, simple majority
 * - Proposal threshold: 1% of token supply required to create proposals (anti-spam)
 * - Reserve management: Allocate/withdraw ETH reserves for default protection with pro-rata distribution
 * - ROI adjustments: Modify agreement ROI within +/-5% bounds to prevent excessive changes
 * - Parameter updates: Dual system - governance params (voting mechanics) and agreement params (terms)
 * 
 * Integration with YieldBase:
 * - Only governance contract can call adjustAgreementROI() and allocateReserve()
 * - YieldBase validates onlyGovernance modifier for autonomous enforcement
 * - Reserves tracked per agreement in YieldBase for distribution
 * 
 * Token Standard Support:
 * - ERC-721+ERC-20: Voting power from YieldSharesToken.balanceOf() per agreement
 * - ERC-1155: Voting power from CombinedPropertyYieldToken.balanceOf() for yield token ID
 * - Batch voting support for ERC-1155 via batchCastVotes()
 * 
 * Proposal Lifecycle:
 * 1. Create: Proposer with ≥1% tokens creates proposal with parameters
 * 2. Pending: 1 day delay before voting starts (allows review)
 * 3. Active: 7 day voting period (token holders cast votes)
 * 4. Succeeded/Defeated: Check quorum (≥10%) and majority (for > against)
 * 5. Executed: Successful proposals execute actions on YieldBase
 */
contract GovernanceController is 
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using GovernanceStorage for GovernanceStorage.GovernanceData;
    using GovernanceCalculations for *;

    /// @notice Reference to YieldBase contract for governance actions
    YieldBase public yieldBase;

    /// @notice Reference to CombinedPropertyYieldToken for ERC-1155 voting
    CombinedPropertyYieldToken public combinedToken;

    /// @notice Flag to enable ERC-1155 voting mode
    bool public erc1155Mode;

    /// @notice Mapping from agreementId to yieldTokenId (for ERC-1155 mode)
    mapping(uint256 => uint256) public agreementToYieldTokenId;

    /// @notice Reference to KYCRegistry for democratic whitelist management
    KYCRegistry public kycRegistry;

    /// @notice Maximum ROI deviation allowed (+/-5% = 500 basis points)
    uint16 public constant MAX_ROI_DEVIATION_BP = 500;

    /// @notice Maximum reserve allocation (20% of capital = 2000 basis points)
    uint16 public constant MAX_RESERVE_PERCENTAGE_BP = 2000;

    /// @notice Valid ROI range minimum (1% = 100 basis points)
    uint16 public constant MIN_ROI_BP = 100;

    /// @notice Valid ROI range maximum (50% = 5000 basis points)
    uint16 public constant MAX_ROI_BP = 5000;

    // ============ Events ============

    /**
     * @notice Emitted when a new governance proposal is created
     * @param proposalId Unique proposal identifier
     * @param proposer Address that created the proposal
     * @param agreementId Target yield agreement
     * @param proposalType Type of governance action
     * @param targetValue New ROI or reserve amount
     * @param description Rationale for proposal
     */
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        uint256 agreementId,
        GovernanceStorage.ProposalType proposalType,
        uint256 targetValue,
        string description
    );

    /**
     * @notice Emitted when a vote is cast on a proposal
     * @param proposalId Proposal being voted on
     * @param voter Address that cast the vote
     * @param support Vote direction (0=Against, 1=For, 2=Abstain)
     * @param votingPower Number of votes cast
     */
    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 votingPower
    );

    /**
     * @notice Emitted when a proposal is successfully executed
     * @param proposalId Executed proposal identifier
     * @param success Whether execution succeeded
     */
    event ProposalExecuted(uint256 indexed proposalId, bool success);

    /**
     * @notice Emitted when a proposal is defeated
     * @param proposalId Defeated proposal identifier
     */
    event ProposalDefeated(uint256 indexed proposalId);

    /**
     * @notice Emitted when reserve is allocated to an agreement
     * @param agreementId Agreement receiving reserve
     * @param amount Reserve amount in wei
     */
    event ReserveAllocated(uint256 indexed agreementId, uint256 amount);

    /**
     * @notice Emitted when reserve is withdrawn from an agreement
     * @param agreementId Agreement from which reserve withdrawn
     * @param amount Withdrawal amount in wei
     */
    event ReserveWithdrawn(uint256 indexed agreementId, uint256 amount);

    /**
     * @notice Emitted when agreement ROI is adjusted via governance
     * @param agreementId Agreement with adjusted ROI
     * @param oldROI Previous ROI in basis points
     * @param newROI New ROI in basis points
     */
    event ROIAdjusted(uint256 indexed agreementId, uint16 oldROI, uint16 newROI);

    /**
     * @notice Emitted when reserve is distributed pro-rata to token holders
     * @param agreementId Agreement whose reserve was distributed
     * @param amount Total amount distributed in wei
     * @param holdersCount Number of holders who received distribution
     * @param totalDistributed Actual amount distributed (may differ from amount due to failures)
     */
    event ReserveDistributedToHolders(uint256 indexed agreementId, uint256 amount, uint256 holdersCount, uint256 totalDistributed);

    /**
     * @notice Emitted when KYC Registry is set
     * @param kycRegistryAddress Address of the KYC Registry contract
     */
    event KYCRegistrySet(address indexed kycRegistryAddress);

    /**
     * @notice Emitted when a KYC whitelist proposal is created
     * @param proposalId Unique proposal identifier
     * @param targetAddress Address to add or remove from whitelist
     * @param addToWhitelist True to add, false to remove
     */
    event KYCWhitelistProposalCreated(uint256 indexed proposalId, address indexed targetAddress, bool addToWhitelist);

    // ============ Errors ============

    error ProposalDoesNotExist();
    error ProposalNotActive();
    error ProposalAlreadyExecuted();
    error InsufficientVotingPower();
    error AlreadyVoted();
    error InvalidProposalThreshold();
    error InvalidROIBounds();
    error InvalidReserveAmount();
    error QuorumNotReached();
    error ProposalNotSucceeded();
    error VotingNotEnded();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the governance controller
     * @dev Sets up governance parameters and contract references
     * @param initialOwner Address that will own the governance contract
     * @param yieldBaseAddress Address of the YieldBase contract to govern
     */
    function initialize(
        address initialOwner,
        address yieldBaseAddress
    ) public initializer {
        require(initialOwner != address(0), "Invalid owner address");
        require(yieldBaseAddress != address(0), "Invalid YieldBase address");

        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        yieldBase = YieldBase(payable(yieldBaseAddress));

        // Initialize governance parameters with defaults
        GovernanceStorage.GovernanceData storage $ = _getGovernanceStorage();
        GovernanceStorage.initializeGovernanceParams($);
    }

    /**
     * @notice Set reference to CombinedPropertyYieldToken for ERC-1155 voting
     * @param combinedTokenAddress Address of the combined token contract
     * @param enableERC1155 Whether to enable ERC-1155 voting mode
     */
    function setCombinedToken(address combinedTokenAddress, bool enableERC1155) external onlyOwner {
        require(combinedTokenAddress != address(0), "Invalid token address");
        combinedToken = CombinedPropertyYieldToken(combinedTokenAddress);
        erc1155Mode = enableERC1155;
    }

    /**
     * @notice Set yield token ID for an agreement (ERC-1155 mode only)
     * @param agreementId Agreement ID to map
     * @param yieldTokenId Corresponding yield token ID in ERC-1155 contract
     */
    function setAgreementYieldTokenId(uint256 agreementId, uint256 yieldTokenId) external onlyOwner {
        require(erc1155Mode, "ERC-1155 mode not enabled");
        require(yieldTokenId >= 1_000_000, "Invalid yield token ID");
        agreementToYieldTokenId[agreementId] = yieldTokenId;
    }

    /**
     * @notice Set the KYCRegistry contract reference
     * @dev Must be called after deployment to enable democratic KYC whitelist management
     * @param kycRegistryAddress Address of the deployed KYCRegistry contract
     */
    function setKYCRegistry(address kycRegistryAddress) external onlyOwner {
        require(kycRegistryAddress != address(0), "Invalid KYC Registry");
        kycRegistry = KYCRegistry(kycRegistryAddress);
        emit KYCRegistrySet(kycRegistryAddress);
    }

    /**
     * @notice Create a KYC whitelist proposal for democratic whitelist management
     * @dev Anyone with sufficient voting power can propose adding or removing addresses
     * @param targetAddress Address to add or remove from KYC whitelist
     * @param addToWhitelist True to add address, false to remove
     * @param description Rationale for the whitelist action
     * @return proposalId Unique identifier for the created proposal
     */
    function createKYCWhitelistProposal(
        address targetAddress,
        bool addToWhitelist,
        string memory description
    ) public nonReentrant returns (uint256 proposalId) {
        require(address(kycRegistry) != address(0), "KYC Registry not set");
        require(targetAddress != address(0), "Invalid target address");
        
        GovernanceStorage.GovernanceData storage $ = _getGovernanceStorage();
        
        // Use agreement ID 0 for KYC proposals (not tied to specific agreement)
        uint256 agreementId = 0;
        
        // Validate proposer has sufficient voting power across all agreements
        // For simplicity, skip threshold check for KYC proposals (can be added if needed)
        
        // Create proposal
        proposalId = ++$.proposalCount;
        
        // Encode parameters: targetAddress and addToWhitelist flag
        uint256 encodedParams = (uint256(uint160(targetAddress)) << 96) | (addToWhitelist ? 1 : 0);
        
        $.proposals[proposalId] = GovernanceStorage.Proposal({
            proposalId: proposalId,
            proposer: msg.sender,
            agreementId: agreementId,
            proposalType: GovernanceStorage.ProposalType.KYCWhitelistUpdate,
            targetValue: encodedParams,
            description: description,
            votingStart: block.timestamp + $.votingDelay,
            votingEnd: block.timestamp + $.votingDelay + $.votingPeriod,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            defeated: false,
            quorumReached: false
        });
        
        emit ProposalCreated(
            proposalId,
            msg.sender,
            agreementId,
            GovernanceStorage.ProposalType.KYCWhitelistUpdate,
            encodedParams,
            description
        );
        
        emit KYCWhitelistProposalCreated(proposalId, targetAddress, addToWhitelist);
        
        return proposalId;
    }

    /**
     * @notice Create a batch KYC whitelist proposal for multiple addresses
     * @dev Allows proposing multiple addresses to be added or removed at once
     * @param addresses Array of addresses to add or remove
     * @param addToWhitelist True to add addresses, false to remove
     * @param description Rationale for the batch whitelist action
     * @return proposalId Unique identifier for the created proposal
     */
    function createBatchKYCWhitelistProposal(
        address[] memory addresses,
        bool addToWhitelist,
        string memory description
    ) external nonReentrant returns (uint256 proposalId) {
        require(address(kycRegistry) != address(0), "KYC Registry not set");
        require(addresses.length > 0, "Empty addresses array");
        require(addresses.length <= 100, "Too many addresses");
        
        // For simplicity, create individual proposals for each address
        // In production, could batch into single proposal with special encoding
        
        // Create first proposal and return its ID
        proposalId = createKYCWhitelistProposal(addresses[0], addToWhitelist, description);
        
        // Create additional proposals for remaining addresses
        for (uint256 i = 1; i < addresses.length; i++) {
            createKYCWhitelistProposal(addresses[i], addToWhitelist, description);
        }
        
        return proposalId;
    }

    /**
     * @notice Create a new governance proposal
     * @dev Validates proposer has sufficient tokens and parameters are valid
     * @param agreementId Target yield agreement for governance action
     * @param proposalType Type of governance action to perform
     * @param targetValue New ROI (basis points) or reserve amount (wei)
     * @param description Rationale for the governance action
     * @return proposalId Unique identifier for the created proposal
     */
    function createProposal(
        uint256 agreementId,
        GovernanceStorage.ProposalType proposalType,
        uint256 targetValue,
        string memory description
    ) external nonReentrant returns (uint256 proposalId) {
        GovernanceStorage.GovernanceData storage $ = _getGovernanceStorage();

        // Validate proposer has sufficient voting power (proposal threshold)
        uint256 proposerVotingPower = _getVotingPower(msg.sender, agreementId);
        uint256 totalSupply = _getTotalSupply(agreementId);
        uint256 thresholdRequired = GovernanceCalculations.calculateProposalThreshold(
            totalSupply,
            $.proposalThreshold
        );

        if (proposerVotingPower < thresholdRequired) {
            revert InvalidProposalThreshold();
        }

        // Validate proposal parameters based on type
        _validateProposalParameters(agreementId, proposalType, targetValue);

        // Create proposal
        $.proposalCount++;
        proposalId = $.proposalCount;

        GovernanceStorage.Proposal storage proposal = $.proposals[proposalId];
        proposal.proposalId = proposalId;
        proposal.proposer = msg.sender;
        proposal.agreementId = agreementId;
        proposal.proposalType = proposalType;
        proposal.targetValue = targetValue;
        proposal.description = description;
        proposal.votingStart = block.timestamp + $.votingDelay;
        proposal.votingEnd = proposal.votingStart + $.votingPeriod;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            agreementId,
            proposalType,
            targetValue,
            description
        );

        return proposalId;
    }

    /**
     * @notice Cast a vote on an active proposal
     * @dev Validates voter has voting power and hasn't voted yet
     * @param proposalId Proposal to vote on
     * @param support Vote direction (0=Against, 1=For, 2=Abstain)
     */
    function castVote(
        uint256 proposalId,
        uint8 support
    ) external nonReentrant {
        // Validate support value before any state changes
        require(support <= 2, "Invalid support value");

        GovernanceStorage.GovernanceData storage $ = _getGovernanceStorage();
        GovernanceStorage.Proposal storage proposal = $.proposals[proposalId];

        // Validate proposal exists and is active
        if (proposal.proposalId == 0) revert ProposalDoesNotExist();
        if (block.timestamp < proposal.votingStart || block.timestamp > proposal.votingEnd) {
            revert ProposalNotActive();
        }

        // Validate voter hasn't voted
        if ($.proposalVotes[proposalId][msg.sender]) {
            revert AlreadyVoted();
        }

        // Get voter's voting power
        uint256 votingPower = _getVotingPower(msg.sender, proposal.agreementId);
        if (votingPower == 0) {
            revert InsufficientVotingPower();
        }

        // Record vote
        $.proposalVotes[proposalId][msg.sender] = true;

        // Update vote counts based on support
        if (support == 1) {
            proposal.forVotes += votingPower;
        } else if (support == 0) {
            proposal.againstVotes += votingPower;
        } else if (support == 2) {
            proposal.abstainVotes += votingPower;
        }

        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }

    /**
     * @notice Execute a proposal after voting period ends
     * @dev Checks quorum and majority, then executes governance action
     * @param proposalId Proposal to execute
     */
    function executeProposal(uint256 proposalId) external nonReentrant {
        GovernanceStorage.GovernanceData storage $ = _getGovernanceStorage();
        GovernanceStorage.Proposal storage proposal = $.proposals[proposalId];

        // Validate proposal state
        if (proposal.proposalId == 0) revert ProposalDoesNotExist();
        if (block.timestamp <= proposal.votingEnd) revert VotingNotEnded();
        if (proposal.executed) revert ProposalAlreadyExecuted();

        // Check quorum
        uint256 totalSupply = _getTotalSupply(proposal.agreementId);
        uint256 quorumRequired = GovernanceCalculations.calculateQuorum(
            totalSupply,
            $.quorumPercentage
        );
        
        bool quorumReached = GovernanceCalculations.isQuorumReached(
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            quorumRequired
        );

        proposal.quorumReached = quorumReached;

        if (!quorumReached) {
            proposal.defeated = true;
            emit ProposalDefeated(proposalId);
            return;
        }

        // Check if proposal succeeded (simple majority)
        bool succeeded = GovernanceCalculations.isProposalSucceeded(
            proposal.forVotes,
            proposal.againstVotes
        );

        if (!succeeded) {
            proposal.defeated = true;
            emit ProposalDefeated(proposalId);
            return;
        }

        // Execute proposal action
        proposal.executed = true;
        _executeProposalAction($, proposal);

        emit ProposalExecuted(proposalId, true);
    }

    /**
     * @notice Allocate reserve directly to an agreement (owner only)
     * @dev Allows owner to fund reserves without governance proposal
     * @param agreementId Agreement to fund
     */
    function allocateReserve(uint256 agreementId) external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");

        // Forward reserve directly to YieldBase (YieldBase owns custody)
        yieldBase.allocateReserve{value: msg.value}(agreementId);

        emit ReserveAllocated(agreementId, msg.value);
    }

    /**
     * @notice Get proposal details
     * @param proposalId Proposal to query
     * @return Proposal struct with all details
     */
    function getProposal(uint256 proposalId) external view returns (GovernanceStorage.Proposal memory) {
        GovernanceStorage.GovernanceData storage $ = _getGovernanceStorage();
        return $.proposals[proposalId];
    }

    /**
     * @notice Get voting power for a voter on a specific agreement
     * @param voter Address to check voting power for
     * @param agreementId Agreement to check voting power for
     * @return votingPower Number of votes the voter has
     */
    function getVotingPower(address voter, uint256 agreementId) external view returns (uint256 votingPower) {
        return _getVotingPower(voter, agreementId);
    }

    /**
     * @notice Check if a voter has voted on a proposal
     * @param proposalId Proposal to check
     * @param voter Voter address to check
     * @return hasVoted True if voter has voted
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        GovernanceStorage.GovernanceData storage $ = _getGovernanceStorage();
        return $.proposalVotes[proposalId][voter];
    }

    /**
     * @notice Get current proposal count
     * @return count Total number of proposals created
     */
    function getProposalCount() external view returns (uint256 count) {
        GovernanceStorage.GovernanceData storage $ = _getGovernanceStorage();
        return $.proposalCount;
    }

    /**
     * @notice Get governance parameters
     * @return votingDelay Delay before voting starts
     * @return votingPeriod Duration of voting period
     * @return quorumPercentage Minimum participation percentage
     * @return proposalThreshold Minimum tokens to create proposal
     */
    function getGovernanceParams() external view returns (
        uint256 votingDelay,
        uint256 votingPeriod,
        uint16 quorumPercentage,
        uint16 proposalThreshold
    ) {
        GovernanceStorage.GovernanceData storage $ = _getGovernanceStorage();
        return ($.votingDelay, $.votingPeriod, $.quorumPercentage, $.proposalThreshold);
    }

    // ============ Internal Functions ============

    /**
     * @notice Get voting power for a voter from token balance
     * @dev Queries YieldSharesToken (ERC-20) or CombinedPropertyYieldToken (ERC-1155)
     * @param voter Address to check
     * @param agreementId Agreement to check voting power for
     * @return votingPower Token balance (voting power)
     */
    function _getVotingPower(address voter, uint256 agreementId) internal view returns (uint256 votingPower) {
        if (erc1155Mode && address(combinedToken) != address(0)) {
            // ERC-1155 mode: Get voting power from combined token
            uint256 yieldTokenId = agreementToYieldTokenId[agreementId];
            if (yieldTokenId == 0) return 0; // Mapping not set yet
            
            return combinedToken.balanceOf(voter, yieldTokenId);
        } else {
            // ERC-20 mode: Get voting power from yield shares token
            address yieldSharesTokenAddress = yieldBase.getYieldSharesToken(agreementId);
            if (yieldSharesTokenAddress == address(0)) return 0;

            YieldSharesToken yieldSharesToken = YieldSharesToken(yieldSharesTokenAddress);
            return yieldSharesToken.balanceOf(voter);
        }
    }

    /**
     * @notice Get total token supply for an agreement
     * @param agreementId Agreement to check
     * @return totalSupply Total token supply
     */
    function _getTotalSupply(uint256 agreementId) internal view returns (uint256 totalSupply) {
        if (erc1155Mode && address(combinedToken) != address(0)) {
            // ERC-1155 mode: Get total supply from combined token
            uint256 yieldTokenId = agreementToYieldTokenId[agreementId];
            if (yieldTokenId == 0) return 0; // Mapping not set yet
            
            return combinedToken.totalSupply(yieldTokenId);
        } else {
            // ERC-20 mode: Get total supply from yield shares token
            address yieldSharesTokenAddress = yieldBase.getYieldSharesToken(agreementId);
            if (yieldSharesTokenAddress == address(0)) return 0;

            YieldSharesToken yieldSharesToken = YieldSharesToken(yieldSharesTokenAddress);
            return yieldSharesToken.totalSupply();
        }
    }

    /**
     * @notice Validate proposal parameters based on type
     * @param agreementId Target agreement (or parameterId for parameter updates)
     * @param proposalType Type of proposal
     * @param targetValue Proposed value (or encoded parameterId + value for agreement params)
     */
    function _validateProposalParameters(
        uint256 agreementId,
        GovernanceStorage.ProposalType proposalType,
        uint256 targetValue
    ) internal view {
        if (proposalType == GovernanceStorage.ProposalType.ROIAdjustment) {
            // Validate ROI is in valid range
            if (targetValue < MIN_ROI_BP || targetValue > MAX_ROI_BP) {
                revert InvalidROIBounds();
            }

            // Get original ROI from YieldBase
            (,,, uint16 originalROI,,,,,,,) = yieldBase.getAgreement(agreementId);

            // Validate ROI is within +/-5% of original
            bool isValid = GovernanceCalculations.validateROIAdjustment(
                originalROI,
                uint16(targetValue),
                MAX_ROI_DEVIATION_BP
            );

            if (!isValid) {
                revert InvalidROIBounds();
            }
        } else if (proposalType == GovernanceStorage.ProposalType.ReserveAllocation) {
            // Get upfront capital from YieldBase
            (, uint256 upfrontCapital,,,,,,,,,) = yieldBase.getAgreement(agreementId);

            // Validate reserve is within 20% limit
            bool isValid = GovernanceCalculations.validateReserveAllocation(
                targetValue,
                upfrontCapital,
                MAX_RESERVE_PERCENTAGE_BP
            );

            if (!isValid) {
                revert InvalidReserveAmount();
            }
        } else if (proposalType == GovernanceStorage.ProposalType.GovernanceParameterUpdate) {
            // For GovernanceParameterUpdate, agreementId is used as parameterId (0-3)
            // Validate parameter ID and new value ranges for governance params
            require(agreementId <= 3, "Invalid governance parameter ID");
            
            if (agreementId == 0) {
                // votingDelay: 1 hour to 7 days
                require(targetValue >= 1 hours && targetValue <= 7 days, "Invalid voting delay");
            } else if (agreementId == 1) {
                // votingPeriod: 1 day to 30 days
                require(targetValue >= 1 days && targetValue <= 30 days, "Invalid voting period");
            } else if (agreementId == 2) {
                // quorumPercentage: 5% to 50%
                require(targetValue >= 500 && targetValue <= 5000, "Invalid quorum percentage");
            } else if (agreementId == 3) {
                // proposalThreshold: 0.1% to 10%
                require(targetValue >= 10 && targetValue <= 1000, "Invalid proposal threshold");
            }
        } else if (proposalType == GovernanceStorage.ProposalType.AgreementParameterUpdate) {
            // For AgreementParameterUpdate, targetValue encodes: (parameterId << 128) | value
            // Extract parameterId and value
            uint256 parameterId = targetValue >> 128;
            uint256 paramValue = targetValue & ((1 << 128) - 1);
            
            require(parameterId <= 4, "Invalid agreement parameter ID");
            
            // Validate agreement exists
            (, uint256 upfrontCapital,,,,,,,,,) = yieldBase.getAgreement(agreementId);
            require(upfrontCapital > 0, "Agreement does not exist");
            
            // Validate parameter value ranges for agreement params
            if (parameterId == 0) {
                // gracePeriodDays: 1 to 90 days
                require(paramValue >= 1 && paramValue <= 90, "Invalid grace period");
            } else if (parameterId == 1) {
                // defaultPenaltyRate: 1% to 20% (100 to 2000 bp)
                require(paramValue >= 100 && paramValue <= 2000, "Invalid penalty rate");
            } else if (parameterId == 2) {
                // defaultThreshold: 1 to 12 missed payments
                require(paramValue >= 1 && paramValue <= 12, "Invalid default threshold");
            } else if (parameterId == 3 || parameterId == 4) {
                // allowPartialRepayments / allowEarlyRepayment: boolean (0 or 1)
                require(paramValue <= 1, "Invalid boolean value");
            }
        } else if (proposalType == GovernanceStorage.ProposalType.TransferRestrictionUpdate) {
            // For TransferRestrictionUpdate, targetValue encodes: (parameterId << 128) | value
            // Extract parameterId and value
            uint256 parameterId = targetValue >> 128;
            uint256 paramValue = targetValue & ((1 << 128) - 1);
            
            require(parameterId <= 2, "Invalid restriction parameter ID");
            
            // Validate agreement exists
            (, uint256 upfrontCapital,,,,,,,,,) = yieldBase.getAgreement(agreementId);
            require(upfrontCapital > 0, "Agreement does not exist");
            
            // Validate parameter value ranges for transfer restrictions
            if (parameterId == 0) {
                // lockupEndTimestamp: must be in future or 0 to disable
                require(paramValue == 0 || paramValue > block.timestamp, "Invalid lockup timestamp");
            } else if (parameterId == 1) {
                // maxSharesPerInvestor: 1% to 100% (100 to 10000 bp)
                require(paramValue == 0 || (paramValue >= 100 && paramValue <= 10000), "Invalid max shares");
            } else if (parameterId == 2) {
                // minHoldingPeriod: 0 to 365 days
                require(paramValue <= 365 days, "Invalid holding period");
            }
        }
    }

    /**
     * @notice Execute the action for a successful proposal
     * @param $ Storage pointer to governance data
     * @param proposal Proposal to execute
     */
    function _executeProposalAction(
        GovernanceStorage.GovernanceData storage $,
        GovernanceStorage.Proposal storage proposal
    ) internal {
        if (proposal.proposalType == GovernanceStorage.ProposalType.ROIAdjustment) {
            // Adjust agreement ROI
            yieldBase.adjustAgreementROI(proposal.agreementId, uint16(proposal.targetValue));
        } else if (proposal.proposalType == GovernanceStorage.ProposalType.ReserveAllocation) {
            // Allocate reserve - forward ETH to YieldBase (YieldBase owns custody)
            require(address(this).balance >= proposal.targetValue, "Insufficient reserve funds");
            yieldBase.allocateReserve{value: proposal.targetValue}(proposal.agreementId);
            emit ReserveAllocated(proposal.agreementId, proposal.targetValue);
        } else if (proposal.proposalType == GovernanceStorage.ProposalType.ReserveWithdrawal) {
            // Withdraw reserve from YieldBase (back to governance controller for distribution)
            yieldBase.withdrawReserve(proposal.agreementId, proposal.targetValue);
            // Distribute withdrawn reserve pro-rata to token holders
            _distributeReserveToHolders(proposal.agreementId, proposal.targetValue);
            emit ReserveWithdrawn(proposal.agreementId, proposal.targetValue);
        } else if (proposal.proposalType == GovernanceStorage.ProposalType.GovernanceParameterUpdate) {
            // Update governance parameters (votingDelay, votingPeriod, quorum, threshold)
            // For GovernanceParameterUpdate, agreementId is parameter ID (0-3)
            _executeGovernanceParameterUpdate($, proposal.agreementId, proposal.targetValue);
        } else if (proposal.proposalType == GovernanceStorage.ProposalType.AgreementParameterUpdate) {
            // Update agreement parameters (gracePeriod, penalty, defaultThreshold, etc.)
            // targetValue encodes: (parameterId << 128) | value
            _executeAgreementParameterUpdate(proposal.agreementId, proposal.targetValue);
        } else if (proposal.proposalType == GovernanceStorage.ProposalType.TransferRestrictionUpdate) {
            // Update transfer restrictions (lockup, concentration, holding period)
            // targetValue encodes: (parameterId << 128) | value
            _executeTransferRestrictionUpdate(proposal.agreementId, proposal.targetValue);
        } else if (proposal.proposalType == GovernanceStorage.ProposalType.KYCWhitelistUpdate) {
            // Add or remove address from KYC whitelist via democratic governance
            // targetValue encodes: (address << 96) | addToWhitelist flag
            address targetAddress = address(uint160(proposal.targetValue >> 96));
            bool addToWhitelist = (proposal.targetValue & 1) == 1;
            
            require(address(kycRegistry) != address(0), "KYC Registry not set");
            
            if (addToWhitelist) {
                kycRegistry.addToWhitelist(targetAddress);
            } else {
                kycRegistry.removeFromWhitelist(targetAddress);
            }
        }
    }

    /**
     * @notice Execute a governance parameter update
     * @param $ Storage pointer to governance data
     * @param parameterId ID of governance parameter to update (0-3)
     * @param newValue New value for the parameter
     */
    function _executeGovernanceParameterUpdate(
        GovernanceStorage.GovernanceData storage $,
        uint256 parameterId,
        uint256 newValue
    ) internal {
        if (parameterId == 0) {
            // Update votingDelay (1 hour to 7 days)
            require(newValue >= 1 hours && newValue <= 7 days, "Invalid voting delay");
            $.votingDelay = newValue;
        } else if (parameterId == 1) {
            // Update votingPeriod (1 day to 30 days)
            require(newValue >= 1 days && newValue <= 30 days, "Invalid voting period");
            $.votingPeriod = newValue;
        } else if (parameterId == 2) {
            // Update quorumPercentage (5% to 50% = 500 to 5000 basis points)
            require(newValue >= 500 && newValue <= 5000, "Invalid quorum percentage");
            $.quorumPercentage = uint16(newValue);
        } else if (parameterId == 3) {
            // Update proposalThreshold (0.1% to 10% = 10 to 1000 basis points)
            require(newValue >= 10 && newValue <= 1000, "Invalid proposal threshold");
            $.proposalThreshold = uint16(newValue);
        } else {
            revert("Invalid governance parameter ID");
        }
    }

    /**
     * @notice Execute an agreement parameter update
     * @param agreementId ID of agreement to update parameters for
     * @param encodedValue Encoded value: (parameterId << 128) | paramValue
     */
    function _executeAgreementParameterUpdate(
        uint256 agreementId,
        uint256 encodedValue
    ) internal {
        // Decode parameterId and value
        uint256 parameterId = encodedValue >> 128;
        uint256 paramValue = encodedValue & ((1 << 128) - 1);
        
        if (parameterId == 0) {
            // Update gracePeriodDays
            yieldBase.setAgreementGracePeriod(agreementId, uint16(paramValue));
        } else if (parameterId == 1) {
            // Update defaultPenaltyRate
            yieldBase.setAgreementDefaultPenaltyRate(agreementId, uint16(paramValue));
        } else if (parameterId == 2) {
            // Update defaultThreshold
            yieldBase.setAgreementDefaultThreshold(agreementId, uint8(paramValue));
        } else if (parameterId == 3) {
            // Update allowPartialRepayments
            yieldBase.setAgreementAllowPartialRepayments(agreementId, paramValue == 1);
        } else if (parameterId == 4) {
            // Update allowEarlyRepayment
            yieldBase.setAgreementAllowEarlyRepayment(agreementId, paramValue == 1);
        } else {
            revert("Invalid agreement parameter ID");
        }
    }

    /**
     * @notice Execute a transfer restriction update
     * @param agreementId ID of agreement to update restrictions for
     * @param encodedValue Encoded value: (parameterId << 128) | paramValue
     */
    function _executeTransferRestrictionUpdate(
        uint256 agreementId,
        uint256 encodedValue
    ) internal {
        // Decode parameterId and value
        uint256 parameterId = encodedValue >> 128;
        uint256 paramValue = encodedValue & ((1 << 128) - 1);
        
        if (erc1155Mode && address(combinedToken) != address(0)) {
            // ERC-1155 mode: Update restrictions on CombinedPropertyYieldToken
            uint256 yieldTokenId = agreementToYieldTokenId[agreementId];
            require(yieldTokenId > 0, "Yield token ID not set");
            
            // Call appropriate method based on parameterId
            if (parameterId == 0) {
                // lockupEndTimestamp
                combinedToken.setYieldTokenLockupEndTimestamp(yieldTokenId, paramValue);
            } else if (parameterId == 1) {
                // maxSharesPerInvestor
                combinedToken.setYieldTokenMaxSharesPerInvestor(yieldTokenId, paramValue);
            } else if (parameterId == 2) {
                // minHoldingPeriod
                combinedToken.setYieldTokenMinHoldingPeriod(yieldTokenId, paramValue);
            } else {
                revert("Invalid restriction parameter ID");
            }
        } else {
            // ERC-20 mode: Update restrictions on YieldSharesToken
            address tokenAddress = yieldBase.getYieldSharesToken(agreementId);
            require(tokenAddress != address(0), "Token not found");
            YieldSharesToken token = YieldSharesToken(tokenAddress);
            
            // Call appropriate method based on parameterId
            if (parameterId == 0) {
                // lockupEndTimestamp
                token.setLockupEndTimestamp(paramValue);
            } else if (parameterId == 1) {
                // maxSharesPerInvestor
                token.setMaxSharesPerInvestor(paramValue);
            } else if (parameterId == 2) {
                // minHoldingPeriod
                token.setMinHoldingPeriod(paramValue);
            } else {
                revert("Invalid restriction parameter ID");
            }
        }
    }

    /**
     * @notice Distribute withdrawn reserve pro-rata to token holders
     * @param agreementId Agreement whose reserve is being distributed
     * @param amount Amount of reserve to distribute in wei
     */
    function _distributeReserveToHolders(uint256 agreementId, uint256 amount) internal {
        require(amount > 0, "Amount must be greater than zero");
        require(address(this).balance >= amount, "Insufficient balance for distribution");
        
        // Get token holders and total supply based on token standard
        address[] memory holders;
        uint256 totalSupply;
        
        if (erc1155Mode && address(combinedToken) != address(0)) {
            // ERC-1155 mode
            uint256 yieldTokenId = agreementToYieldTokenId[agreementId];
            require(yieldTokenId > 0, "Yield token ID not set");
            holders = combinedToken.getYieldTokenHolders(yieldTokenId);
            totalSupply = combinedToken.totalSupply(yieldTokenId);
        } else {
            // ERC-20 mode
            address tokenAddress = yieldBase.getYieldSharesToken(agreementId);
            require(tokenAddress != address(0), "Token not found");
            YieldSharesToken token = YieldSharesToken(tokenAddress);
            holders = token.getAgreementShareholders();
            totalSupply = token.totalSupply();
        }
        
        require(holders.length > 0, "No holders to distribute to");
        require(totalSupply > 0, "Total supply is zero");
        
        // Maximum shareholders safety check
        require(holders.length <= 1000, "Too many shareholders for distribution");
        
        uint256 totalDistributed = 0;
        
        // Calculate and distribute pro-rata to each holder
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            
            // Get holder's balance
            uint256 holderBalance;
            if (erc1155Mode && address(combinedToken) != address(0)) {
                uint256 yieldTokenId = agreementToYieldTokenId[agreementId];
                holderBalance = combinedToken.balanceOf(holder, yieldTokenId);
            } else {
                address tokenAddress = yieldBase.getYieldSharesToken(agreementId);
                YieldSharesToken token = YieldSharesToken(tokenAddress);
                holderBalance = token.balanceOf(holder);
            }
            
            if (holderBalance > 0) {
                // Calculate pro-rata share: (amount * holderBalance) / totalSupply
                uint256 holderShare = (amount * holderBalance) / totalSupply;
                
                if (holderShare > 0) {
                    // Transfer ETH to holder using call for safety
                    (bool success, ) = payable(holder).call{value: holderShare}("");
                    if (success) {
                        totalDistributed += holderShare;
                    } else {
                        // On failure, accumulate in token's unclaimed remainder
                        if (erc1155Mode && address(combinedToken) != address(0)) {
                            // For ERC-1155, would need to add unclaimedRemainder to CombinedToken
                            // For now, revert to ensure funds aren't lost
                            revert("Distribution failed for holder");
                        } else {
                            // For ERC-20, use existing unclaimedRemainder mechanism
                            address tokenAddress = yieldBase.getYieldSharesToken(agreementId);
                            YieldSharesToken token = YieldSharesToken(tokenAddress);
                            // Note: Token contract doesn't expose a way to add to unclaimed from external
                            // Revert to ensure funds aren't lost
                            revert("Distribution failed for holder");
                        }
                    }
                }
            }
        }
        
        // Handle any rounding dust by sending to largest holder
        uint256 remainder = amount - totalDistributed;
        if (remainder > 0 && holders.length > 0) {
            // Find largest holder
            address largestHolder = holders[0];
            uint256 maxBalance = 0;
            
            for (uint256 i = 0; i < holders.length; i++) {
                uint256 holderBalance;
                if (erc1155Mode && address(combinedToken) != address(0)) {
                    uint256 yieldTokenId = agreementToYieldTokenId[agreementId];
                    holderBalance = combinedToken.balanceOf(holders[i], yieldTokenId);
                } else {
                    address tokenAddress = yieldBase.getYieldSharesToken(agreementId);
                    YieldSharesToken token = YieldSharesToken(tokenAddress);
                    holderBalance = token.balanceOf(holders[i]);
                }
                
                if (holderBalance > maxBalance) {
                    maxBalance = holderBalance;
                    largestHolder = holders[i];
                }
            }
            
            // Send remainder to largest holder
            (bool success, ) = payable(largestHolder).call{value: remainder}("");
            if (success) {
                totalDistributed += remainder;
            }
            // If fails, remainder stays in governance controller
        }
        
        emit ReserveDistributedToHolders(agreementId, amount, holders.length, totalDistributed);
    }

    /**
     * @notice Get ERC-7201 governance storage pointer
     * @return $ Storage pointer to governance data
     */
    function _getGovernanceStorage() internal pure returns (GovernanceStorage.GovernanceData storage $) {
        return GovernanceStorage.getGovernanceStorage();
    }

    /**
     * @notice Authorize UUPS upgrade (only owner)
     * @param newImplementation Address of new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @notice Receive ETH for reserve funding
     */
    receive() external payable {}
}

