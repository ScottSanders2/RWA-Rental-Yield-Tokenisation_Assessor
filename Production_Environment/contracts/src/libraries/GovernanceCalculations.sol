// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title GovernanceCalculations
 * @notice Library for governance calculation logic to reduce GovernanceController bytecode size
 * @dev Pure functions for voting power, quorum, threshold, and validation calculations
 * 
 * Calculation Formulas:
 * - Voting Power: 1 token = 1 vote (1:1 ratio)
 * - Quorum: (totalVotes / totalSupply) >= quorumPercentage
 * - Proposal Threshold: voterTokens >= (totalSupply * thresholdBasisPoints / 10000)
 * - ROI Adjustment Bounds: newROI within originalROI ± (originalROI * maxDeviation / 10000)
 * - Reserve Limit: reserveAmount <= (upfrontCapital * maxReservePercentage / 10000)
 * 
 * Governance Mechanics:
 * - Simple Majority: forVotes > againstVotes (abstain doesn't count toward either)
 * - Quorum Enforcement: Total participation must exceed minimum threshold
 * - Proposal Success: Both quorum AND majority requirements must be met
 */
library GovernanceCalculations {
    /// @notice Basis points denominator (100% = 10000 basis points)
    uint256 private constant BASIS_POINTS = 10000;

    /**
     * @notice Calculate voting power from token balance
     * @dev Simple 1:1 ratio - 1 token = 1 vote
     * @param tokenBalance Number of tokens held by voter
     * @return votingPower Voting power (equal to token balance)
     */
    function calculateVotingPower(uint256 tokenBalance) internal pure returns (uint256 votingPower) {
        return tokenBalance;
    }

    /**
     * @notice Calculate minimum votes required for quorum
     * @dev Formula: totalSupply * quorumPercentageBasisPoints / BASIS_POINTS
     * @param totalSupply Total token supply for the agreement
     * @param quorumPercentageBasisPoints Quorum percentage in basis points (e.g., 1000 = 10%)
     * @return quorumRequired Minimum number of votes needed for quorum
     */
    function calculateQuorum(
        uint256 totalSupply,
        uint16 quorumPercentageBasisPoints
    ) internal pure returns (uint256 quorumRequired) {
        return (totalSupply * quorumPercentageBasisPoints) / BASIS_POINTS;
    }

    /**
     * @notice Calculate minimum tokens required to create proposal
     * @dev Formula: totalSupply * thresholdBasisPoints / BASIS_POINTS
     * @param totalSupply Total token supply for the agreement
     * @param thresholdBasisPoints Threshold percentage in basis points (e.g., 100 = 1%)
     * @return thresholdRequired Minimum tokens needed to create proposal
     */
    function calculateProposalThreshold(
        uint256 totalSupply,
        uint16 thresholdBasisPoints
    ) internal pure returns (uint256 thresholdRequired) {
        return (totalSupply * thresholdBasisPoints) / BASIS_POINTS;
    }

    /**
     * @notice Check if quorum has been reached
     * @dev Total votes (for + against + abstain) must meet quorum requirement
     * @param forVotes Number of votes in favor
     * @param againstVotes Number of votes against
     * @param abstainVotes Number of abstain votes
     * @param quorumRequired Minimum votes needed for quorum
     * @return isReached True if quorum reached, false otherwise
     */
    function isQuorumReached(
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        uint256 quorumRequired
    ) internal pure returns (bool isReached) {
        uint256 totalVotes = forVotes + againstVotes + abstainVotes;
        return totalVotes >= quorumRequired;
    }

    /**
     * @notice Check if proposal has succeeded (simple majority)
     * @dev Requires forVotes > againstVotes (abstain doesn't count)
     * @param forVotes Number of votes in favor
     * @param againstVotes Number of votes against
     * @return hasSucceeded True if proposal succeeded, false otherwise
     */
    function isProposalSucceeded(
        uint256 forVotes,
        uint256 againstVotes
    ) internal pure returns (bool hasSucceeded) {
        return forVotes > againstVotes;
    }

    /**
     * @notice Validate ROI adjustment is within allowed bounds
     * @dev Checks newROI is within originalROI ± maxDeviationBasisPoints (default ±5%)
     * @param originalROI Original agreement ROI in basis points
     * @param newROI Proposed new ROI in basis points
     * @param maxDeviationBasisPoints Maximum allowed deviation in basis points (e.g., 500 = 5%)
     * @return isValid True if ROI adjustment is within bounds
     */
    function validateROIAdjustment(
        uint16 originalROI,
        uint16 newROI,
        uint16 maxDeviationBasisPoints
    ) internal pure returns (bool isValid) {
        uint256 maxDeviation = (uint256(originalROI) * maxDeviationBasisPoints) / BASIS_POINTS;
        uint256 upperBound = uint256(originalROI) + maxDeviation;
        uint256 lowerBound = uint256(originalROI) > maxDeviation 
            ? uint256(originalROI) - maxDeviation 
            : 0;
        
        return newROI >= lowerBound && newROI <= upperBound;
    }

    /**
     * @notice Validate reserve allocation is within allowed limits
     * @dev Checks reserveAmount <= upfrontCapital * maxReservePercentage (default 20%)
     * @param reserveAmount Proposed reserve allocation in wei
     * @param upfrontCapital Total upfront capital for the agreement in wei
     * @param maxReservePercentage Maximum reserve as percentage in basis points (e.g., 2000 = 20%)
     * @return isValid True if reserve allocation is within limits
     */
    function validateReserveAllocation(
        uint256 reserveAmount,
        uint256 upfrontCapital,
        uint16 maxReservePercentage
    ) internal pure returns (bool isValid) {
        uint256 maxReserve = (upfrontCapital * maxReservePercentage) / BASIS_POINTS;
        return reserveAmount <= maxReserve;
    }

    /**
     * @notice Calculate proportional reserve withdrawal for a voter
     * @dev Formula: (totalReserve * voterShares) / totalShares
     * @param totalReserve Total reserve balance available for withdrawal
     * @param voterShares Number of shares held by voter
     * @param totalShares Total shares in the agreement
     * @return voterWithdrawal Amount of reserve the voter is entitled to receive
     */
    function calculateProportionalReserveWithdrawal(
        uint256 totalReserve,
        uint256 voterShares,
        uint256 totalShares
    ) internal pure returns (uint256 voterWithdrawal) {
        if (totalShares == 0) return 0;
        return (totalReserve * voterShares) / totalShares;
    }

    /**
     * @notice Validate proposal parameters are within acceptable ranges
     * @dev Comprehensive validation for all proposal types
     * @param proposalType Type of governance proposal
     * @param targetValue Proposed value (ROI in basis points or reserve in wei)
     * @param originalValue Original value for comparison
     * @param referenceValue Reference value for validation (e.g., upfront capital)
     * @param maxDeviationOrLimit Maximum deviation (ROI) or limit (reserve) in basis points
     * @return isValid True if parameters are valid
     */
    function validateProposalParameters(
        uint8 proposalType,
        uint256 targetValue,
        uint256 originalValue,
        uint256 referenceValue,
        uint16 maxDeviationOrLimit
    ) internal pure returns (bool isValid) {
        // ProposalType.ROIAdjustment = 0
        if (proposalType == 0) {
            return validateROIAdjustment(
                uint16(originalValue),
                uint16(targetValue),
                maxDeviationOrLimit
            );
        }
        // ProposalType.ReserveAllocation = 1
        else if (proposalType == 1) {
            return validateReserveAllocation(
                targetValue,
                referenceValue,
                maxDeviationOrLimit
            );
        }
        // ProposalType.ReserveWithdrawal = 2 or ParameterUpdate = 3
        // Additional validation logic can be added for other proposal types
        return true;
    }
}

