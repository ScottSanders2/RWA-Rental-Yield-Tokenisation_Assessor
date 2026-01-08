// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IGovernanceController
 * @notice Interface for GovernanceController to enable batch voting from CombinedPropertyYieldToken
 */
interface IGovernanceController {
    /**
     * @notice Cast a vote on a governance proposal
     * @param proposalId Proposal to vote on
     * @param support Vote direction (0=Against, 1=For, 2=Abstain)
     */
    function castVote(uint256 proposalId, uint8 support) external;
}

