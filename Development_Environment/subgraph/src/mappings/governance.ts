/**
 * GovernanceController Contract Event Handlers
 * Tracks on-chain governance: proposals, votes, execution
 * Enables governance analytics and participation metrics
 */

import { BigInt, Bytes } from '@graphprotocol/graph-ts'
import {
  ProposalCreated,
  VoteCast,
  ProposalExecuted,
  ProposalDefeated,
  ReserveDistributedToHolders
} from '../../generated/GovernanceController/GovernanceController'
import { GovernanceProposal, Vote, YieldAgreement, AnalyticsSummary } from '../../generated/schema'

/**
 * Handle ProposalCreated event
 * Creates GovernanceProposal entity when a new proposal is submitted
 */
export function handleProposalCreated(event: ProposalCreated): void {
  // Create GovernanceProposal entity
  let proposalId = event.params.proposalId.toHexString()
  let proposal = new GovernanceProposal(Bytes.fromHexString(proposalId))
  
  // Set proposal fields from event parameters
  proposal.proposer = event.params.proposer
  
  // Link to YieldAgreement
  let agreementId = event.params.agreementId.toHexString()
  proposal.agreement = Bytes.fromHexString(agreementId)
  
  // Convert proposal type enum to string
  // 0=ROI_ADJUSTMENT, 1=RESERVE_ALLOCATION, 2=TERM_EXTENSION, etc.
  let proposalTypeValue = event.params.proposalType
  let proposalTypeString = 'UNKNOWN'
  if (proposalTypeValue == 0) {
    proposalTypeString = 'ROI_ADJUSTMENT'
  } else if (proposalTypeValue == 1) {
    proposalTypeString = 'RESERVE_ALLOCATION'
  } else if (proposalTypeValue == 2) {
    proposalTypeString = 'TERM_EXTENSION'
  } else if (proposalTypeValue == 3) {
    proposalTypeString = 'PARAMETER_CHANGE'
  }
  proposal.proposalType = proposalTypeString
  
  proposal.targetValue = event.params.targetValue
  proposal.description = event.params.description
  
  // Set voting timestamps (event doesn't provide these, use block timestamp as created time)
  // In practice, voting typically starts immediately and ends after a set period
  proposal.votingStart = event.block.timestamp
  proposal.votingEnd = event.block.timestamp.plus(BigInt.fromI32(7 * 24 * 60 * 60)) // Default: 7 days
  
  // Initialize vote counts
  proposal.forVotes = BigInt.fromI32(0)
  proposal.againstVotes = BigInt.fromI32(0)
  proposal.abstainVotes = BigInt.fromI32(0)
  
  // Initialize status flags
  proposal.executed = false
  proposal.defeated = false
  proposal.quorumReached = false
  
  proposal.createdAt = event.block.timestamp
  
  // Save GovernanceProposal entity
  proposal.save()
  
  // Update AnalyticsSummary
  let summary = loadOrCreateAnalyticsSummary()
  summary.totalGovernanceProposals = summary.totalGovernanceProposals + 1
  summary.lastUpdated = event.block.timestamp
  summary.save()
}

/**
 * Handle VoteCast event
 * Creates Vote entity and updates GovernanceProposal vote counts
 */
export function handleVoteCast(event: VoteCast): void {
  // Create Vote entity
  let proposalId = event.params.proposalId.toHexString()
  let voterAddress = event.params.voter.toHexString()
  let voteId = proposalId + '-' + voterAddress
  let vote = new Vote(Bytes.fromHexString(voteId))
  
  // Set vote fields
  vote.proposal = Bytes.fromHexString(proposalId)
  vote.voter = event.params.voter
  vote.support = event.params.support // 0=against, 1=for, 2=abstain
  vote.votingPower = event.params.votingPower
  vote.timestamp = event.block.timestamp
  vote.transactionHash = event.transaction.hash
  
  // Save Vote entity
  vote.save()
  
  // Update GovernanceProposal vote counts
  let proposal = GovernanceProposal.load(Bytes.fromHexString(proposalId))
  if (proposal != null) {
    // Update vote counts based on support value
    if (vote.support == 1) {
      // For vote
      proposal.forVotes = proposal.forVotes.plus(event.params.votingPower)
    } else if (vote.support == 0) {
      // Against vote
      proposal.againstVotes = proposal.againstVotes.plus(event.params.votingPower)
    } else if (vote.support == 2) {
      // Abstain vote
      proposal.abstainVotes = proposal.abstainVotes.plus(event.params.votingPower)
    }
    
    // Calculate quorum (simplified: forVotes + abstainVotes >= threshold)
    // In production, would query YieldAgreement.totalShares and calculate quorum percentage
    let totalVotes = proposal.forVotes.plus(proposal.abstainVotes).plus(proposal.againstVotes)
    // Assume quorum threshold of 50% (would need to fetch from contract)
    // For now, just check if total votes > 0
    if (totalVotes.gt(BigInt.fromI32(0))) {
      proposal.quorumReached = true
    }
    
    proposal.save()
  }
  
  // Update AnalyticsSummary
  let summary = loadOrCreateAnalyticsSummary()
  summary.totalVotesCast = summary.totalVotesCast + 1
  summary.lastUpdated = event.block.timestamp
  summary.save()
}

/**
 * Handle ProposalExecuted event
 * Marks proposal as executed
 */
export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposalId = event.params.proposalId.toHexString()
  let proposal = GovernanceProposal.load(Bytes.fromHexString(proposalId))
  
  if (proposal != null) {
    proposal.executed = true
    proposal.executedAt = event.block.timestamp
    proposal.save()
  }
}

/**
 * Handle ProposalDefeated event
 * Marks proposal as defeated
 */
export function handleProposalDefeated(event: ProposalDefeated): void {
  let proposalId = event.params.proposalId.toHexString()
  let proposal = GovernanceProposal.load(Bytes.fromHexString(proposalId))
  
  if (proposal != null) {
    proposal.defeated = true
    proposal.save()
  }
}

/**
 * Handle ReserveDistributedToHolders event
 * Tracks reserve distributions to shareholders
 */
export function handleReserveDistributedToHolders(event: ReserveDistributedToHolders): void {
  // Track reserve distribution
  // Could update YieldAgreement or create separate ReserveDistribution entity
  // For now, just update analytics summary
  let summary = loadOrCreateAnalyticsSummary()
  summary.lastUpdated = event.block.timestamp
  summary.save()
}

/**
 * Load or create AnalyticsSummary singleton entity
 */
function loadOrCreateAnalyticsSummary(): AnalyticsSummary {
  let summaryId = Bytes.fromHexString('0x474c4f42414c') // 'GLOBAL' in hex
  let summary = AnalyticsSummary.load(summaryId)
  
  if (summary == null) {
    summary = new AnalyticsSummary(summaryId)
    summary.totalAgreements = 0
    summary.totalCapitalDeployed = BigInt.fromI32(0)
    summary.totalCapitalDeployedUsd = BigInt.fromI32(0)
    summary.totalRepaymentsDistributed = BigInt.fromI32(0)
    summary.activeAgreements = 0
    summary.completedAgreements = 0
    summary.totalShareholders = 0
    summary.averageROIBasisPoints = 0
    summary.erc721AgreementCount = 0
    summary.erc1155AgreementCount = 0
    summary.totalGovernanceProposals = 0
    summary.totalVotesCast = 0
    summary.lastUpdated = BigInt.fromI32(0)
  }
  
  return summary as AnalyticsSummary
}

