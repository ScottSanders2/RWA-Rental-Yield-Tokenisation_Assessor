// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title GovernanceStorage
 * @notice ERC-7201 namespaced storage library for governance state
 * @dev Implements collision-free storage using ERC-7201 pattern for governance data
 * 
 * Storage Namespace: keccak256(abi.encode(uint256(keccak256("rwa.storage.Governance")) - 1)) & ~bytes32(uint256(0xff))
 * This ensures no storage collisions with other contracts or upgrades.
 * 
 * Governance Architecture:
 * - Proposals target specific yield agreements for democratic control
 * - Token-weighted voting: 1 token = 1 vote
 * - Quorum enforcement: minimum 10% participation required
 * - Proposal threshold: minimum 1% tokens to create proposals
 * - Voting period: 7 days with 1 day delay before voting starts
 * - Simple majority: forVotes > againstVotes for success
 * 
 * Reserve Management:
 * - Reserves held in YieldBase per agreement for isolated default protection
 * - Maximum 20% of upfront capital can be allocated as reserve
 * - Reserves withdrawable via governance proposals with pro-rata distribution to holders
 * - No central reserve tracking in governance for security and architectural clarity
 */
library GovernanceStorage {
    /// @notice Proposal types for governance actions
    enum ProposalType {
        ROIAdjustment,               // Modify agreement ROI within ±5% bounds
        ReserveAllocation,           // Allocate ETH to agreement reserve
        ReserveWithdrawal,           // Return unused reserves to investors
        GovernanceParameterUpdate,   // Modify governance params (votingDelay, votingPeriod, quorum, threshold)
        AgreementParameterUpdate,    // Modify agreement params (gracePeriod, penalty, defaultThreshold, etc.)
        TransferRestrictionUpdate    // Update transfer restrictions (lockup, concentration limits, holding periods)
    }

    /// @notice Proposal struct containing all proposal state
    struct Proposal {
        uint256 proposalId;           // Unique proposal identifier
        address proposer;             // Address that created the proposal
        uint256 agreementId;          // Target yield agreement for governance action
        ProposalType proposalType;    // Type of governance action
        uint256 targetValue;          // New ROI (basis points) or reserve amount (wei)
        string description;           // Rationale for governance action
        uint256 votingStart;          // Timestamp when voting begins (after delay)
        uint256 votingEnd;            // Timestamp when voting ends
        uint256 forVotes;             // Total votes in favor
        uint256 againstVotes;         // Total votes against
        uint256 abstainVotes;         // Total abstain votes
        bool executed;                // Whether proposal has been executed
        bool defeated;                // Whether proposal was defeated
        bool quorumReached;           // Whether minimum participation achieved
    }

    /// @notice Main governance data structure with ERC-7201 namespace
    struct GovernanceData {
        // Proposal tracking
        mapping(uint256 => Proposal) proposals;           // proposalId => Proposal
        mapping(uint256 => mapping(address => bool)) proposalVotes;  // proposalId => voter => hasVoted
        uint256 proposalCount;                            // Counter for unique proposal IDs
        
        // Governance parameters
        uint256 votingDelay;                              // Delay before voting starts (default 1 day)
        uint256 votingPeriod;                             // Duration of voting period (default 7 days)
        uint16 quorumPercentage;                          // Minimum participation in basis points (default 1000 = 10%)
        uint16 proposalThreshold;                         // Minimum tokens to create proposal in basis points (default 100 = 1%)
        
        // NOTE: Reserve management is handled in YieldBase for per-agreement isolation
        // Removed unused agreementReserves and totalReservesHeld mappings
        
        // Reserved storage gap for future upgrades (ERC-7201 pattern)
        uint256[50] __gap;
    }

    /// @dev ERC-7201 namespace identifier
    /// @dev keccak256(abi.encode(uint256(keccak256("rwa.storage.Governance")) - 1)) & ~bytes32(uint256(0xff))
    /// @dev Computed value: 0xf2113100cfb47b07308c17914bdca6bbd50f09452fc9a54c49a510654fb51800
    bytes32 private constant GOVERNANCE_STORAGE_LOCATION = 
        0xf2113100cfb47b07308c17914bdca6bbd50f09452fc9a54c49a510654fb51800;

    /**
     * @notice Returns storage pointer to governance data
     * @dev Uses assembly to access namespaced storage slot
     * @return $ Storage pointer to GovernanceData struct
     */
    function getGovernanceStorage() internal pure returns (GovernanceData storage $) {
        assembly {
            $.slot := GOVERNANCE_STORAGE_LOCATION
        }
    }

    /**
     * @notice Initialize governance parameters with default values
     * @dev Called during governance controller initialization
     * @param $ Storage pointer to governance data
     */
    function initializeGovernanceParams(GovernanceData storage $) internal {
        $.votingDelay = 1 days;           // 1 day delay before voting starts
        $.votingPeriod = 7 days;          // 7 day voting period
        $.quorumPercentage = 1000;        // 10% quorum (1000 basis points)
        $.proposalThreshold = 100;        // 1% threshold (100 basis points)
    }
}

