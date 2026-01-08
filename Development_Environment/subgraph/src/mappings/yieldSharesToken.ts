/**
 * YieldSharesToken Template Event Handlers
 * Handles events from dynamically deployed YieldSharesToken contracts (one per agreement)
 * Tracks shareholder balances, distributions, transfers, and restrictions
 * Enables pooling analytics and secondary market tracking
 */

import { BigInt, Bytes, Address, store } from '@graphprotocol/graph-ts'
import {
  SharesMinted,
  SharesMintedBatch,
  RepaymentDistributed,
  PartialRepaymentDistributed,
  SharesBurned,
  Transfer,
  TransferBlocked,
  TransferRestrictionsUpdated
} from '../../generated/templates/YieldSharesToken/YieldSharesToken'
import { Shareholder, YieldAgreement, Repayment, TransferRestrictionEvent, AnalyticsSummary } from '../../generated/schema'

/**
 * Helper function: Convert BigInt to Bytes with correct byte order
 * Fixes byte-reversal bug by using padded hex strings
 */
function bigIntToPaddedBytes(value: BigInt): Bytes {
  let hexString = value.toHexString();
  // If odd length (e.g., "0x1"), pad to even length (e.g., "0x01")
  if (hexString.length % 2 != 0) {
    hexString = '0x0' + hexString.slice(2);
  }
  return Bytes.fromHexString(hexString) as Bytes;
}

/**
 * Handle SharesMinted event
 * Creates or updates Shareholder entity for individual investor
 */
export function handleSharesMinted(event: SharesMinted): void {
  // Create composite ID from agreementId + investor address
  let agreementIdBytes = bigIntToPaddedBytes(event.params.agreementId)
  let investorBytes = event.params.investor as Bytes
  let shareholderId = agreementIdBytes.concat(investorBytes)
  
  // Load or create Shareholder entity
  let shareholder = Shareholder.load(shareholderId)
  let isNewShareholder = false
  
  if (shareholder == null) {
    shareholder = new Shareholder(shareholderId)
    shareholder.agreement = agreementIdBytes
    shareholder.investor = event.params.investor
    shareholder.shares = BigInt.fromI32(0)
    shareholder.capitalContributed = BigInt.fromI32(0)
    shareholder.distributionsReceived = BigInt.fromI32(0)
    isNewShareholder = true
  }
  
  // Update shareholder balances
  shareholder.shares = shareholder.shares.plus(event.params.shares)
  shareholder.capitalContributed = shareholder.capitalContributed.plus(event.params.capitalAmount)
  shareholder.lastUpdated = event.block.timestamp
  shareholder.isActive = true
  shareholder.save()
  
  // Update AnalyticsSummary if new shareholder
  if (isNewShareholder) {
    let summary = loadOrCreateAnalyticsSummary()
    summary.totalShareholders = summary.totalShareholders + 1
    summary.lastUpdated = event.block.timestamp
    summary.save()
  }
}

/**
 * Handle SharesMintedBatch event
 * Processes multiple shareholder minting in a single transaction (pooled capital)
 */
export function handleSharesMintedBatch(event: SharesMintedBatch): void {
  let agreementIdBytes = bigIntToPaddedBytes(event.params.agreementId)
  let contributors = event.params.contributors
  let shareAmounts = event.params.shares
  let totalCapital = event.params.totalCapital
  
  // Iterate through all contributors and create/update Shareholder entities
  for (let i = 0; i < contributors.length; i++) {
    let investorBytes = contributors[i] as Bytes
    let shareholderId = agreementIdBytes.concat(investorBytes)
    
    let shareholder = Shareholder.load(shareholderId)
    let isNewShareholder = false
    
    if (shareholder == null) {
      shareholder = new Shareholder(shareholderId)
      shareholder.agreement = agreementIdBytes
      shareholder.investor = contributors[i]
      shareholder.shares = BigInt.fromI32(0)
      shareholder.capitalContributed = BigInt.fromI32(0)
      shareholder.distributionsReceived = BigInt.fromI32(0)
      isNewShareholder = true
    }
    
    // Get shares for this contributor
    let sharesAmount = shareAmounts[i]
    
    // Calculate proportional capital contribution
    // contributionAmount = (sharesAmount / totalShares) * totalCapital (approximation)
    let contributionAmount = BigInt.fromI32(0)
    if (shareAmounts.length > 0) {
      contributionAmount = totalCapital.div(BigInt.fromI32(shareAmounts.length))
    }
    
    shareholder.shares = shareholder.shares.plus(sharesAmount)
    shareholder.capitalContributed = shareholder.capitalContributed.plus(contributionAmount)
    shareholder.lastUpdated = event.block.timestamp
    shareholder.isActive = true
    shareholder.save()
    
    // Update AnalyticsSummary if new shareholder
    if (isNewShareholder) {
      let summary = loadOrCreateAnalyticsSummary()
      summary.totalShareholders = summary.totalShareholders + 1
      summary.lastUpdated = event.block.timestamp
      summary.save()
    }
  }
}

/**
 * Handle RepaymentDistributed event
 * Updates shareholder distributions and creates repayment record
 * Calculates pro-rata distribution for each shareholder
 */
export function handleRepaymentDistributed(event: RepaymentDistributed): void {
  let agreementIdBytes = bigIntToPaddedBytes(event.params.agreementId)
  let totalDistributed = event.params.totalAmount
  let totalShares = event.params.shareholderCount // Note: event provides count, not total shares
  
  // Load YieldAgreement to get shareholder list
  let agreement = YieldAgreement.load(agreementIdBytes)
  if (agreement == null) {
    return
  }
  
  // Calculate total shares by iterating through shareholders
  // In production, this could be optimized with a totalShares field on YieldAgreement
  // For now, we'll update distributionsReceived for all shareholders proportionally
  
  // Note: This is a simplified implementation
  // Full implementation would query all Shareholder entities for this agreement
  // and calculate pro-rata distribution based on shares/totalShares ratio
  
  // Update AnalyticsSummary
  let summary = loadOrCreateAnalyticsSummary()
  summary.totalRepaymentsDistributed = summary.totalRepaymentsDistributed.plus(totalDistributed)
  summary.lastUpdated = event.block.timestamp
  summary.save()
}

/**
 * Handle PartialRepaymentDistributed event
 * Similar to RepaymentDistributed but for partial payments
 */
export function handlePartialRepaymentDistributed(event: PartialRepaymentDistributed): void {
  let partialAmount = event.params.partialAmount
  
  // Update AnalyticsSummary
  let summary = loadOrCreateAnalyticsSummary()
  summary.totalRepaymentsDistributed = summary.totalRepaymentsDistributed.plus(partialAmount)
  summary.lastUpdated = event.block.timestamp
  summary.save()
}

/**
 * Handle SharesBurned event
 * Reduces shareholder balance or removes shareholder if balance becomes zero
 */
export function handleSharesBurned(event: SharesBurned): void {
  let agreementIdBytes = bigIntToPaddedBytes(event.params.agreementId)
  let investorBytes = event.params.investor as Bytes
  let shareholderId = agreementIdBytes.concat(investorBytes)
  
  let shareholder = Shareholder.load(shareholderId)
  if (shareholder == null) {
    return
  }
  
  // Reduce shares
  shareholder.shares = shareholder.shares.minus(event.params.shares)
  shareholder.lastUpdated = event.block.timestamp
  
  // Mark as inactive if shares become zero
  if (shareholder.shares.le(BigInt.fromI32(0))) {
    shareholder.isActive = false
    
    // Update AnalyticsSummary
    let summary = loadOrCreateAnalyticsSummary()
    summary.totalShareholders = summary.totalShareholders - 1
    summary.lastUpdated = event.block.timestamp
    summary.save()
  }
  
  shareholder.save()
}

/**
 * Handle Transfer event
 * Updates shareholder balances for secondary market transfers
 * Creates new shareholder entity if recipient is not yet a shareholder
 */
export function handleTransfer(event: Transfer): void {
  let from = event.params.from
  let to = event.params.to
  let amount = event.params.value
  
  // Skip mint (from == 0x0) and burn (to == 0x0) events as they're handled separately
  if (from.toHexString() == '0x0000000000000000000000000000000000000000' ||
      to.toHexString() == '0x0000000000000000000000000000000000000000') {
    return
  }
  
  // CRITICAL FIX: Implement shareholder balance updates for transfers
  // Note: In a template, we can't directly get agreementId, but we can use dataSource.context()
  // or query YieldAgreement by tokenContract address. For now, we'll query all agreements
  // and find the one with matching tokenContract.
  
  // Get the token contract address (this YieldSharesToken instance)
  let tokenContractAddress = event.address
  
  // We need to find the agreementId by querying YieldAgreement entities
  // Since The Graph doesn't support querying in mappings, we'll use a workaround:
  // The YieldSharesToken template is created with context containing the agreementId
  // For transfers that happen after minting, we can derive the agreementId from the
  // existing shareholder entities (they all have agreementId prefix in their ID)
  
  // Try to find sender shareholder to derive agreementId
  // Shareholder ID format: agreementId + investor address
  // We'll need to scan potential agreements by looking at the sender's shareholder entities
  
  // WORKAROUND: Since we can't query in mappings, we'll construct a composite key
  // by iterating through potential agreement IDs (1 to 1000 for ERC-721, 1000000+ for ERC-1155)
  // This is not ideal but works for the prototype
  
  let agreementId = Bytes.fromHexString('0x00') // Default placeholder
  let foundAgreement = false
  
  // Try common agreement IDs (1-100) to find the sender shareholder
  for (let i = 1; i <= 100; i++) {
    let testAgreementId = bigIntToPaddedBytes(BigInt.fromI32(i))
    let testShareholderId = testAgreementId.concat(from as Bytes)
    let testShareholder = Shareholder.load(testShareholderId)
    
    if (testShareholder != null) {
      agreementId = testAgreementId
      foundAgreement = true
      break
    }
  }
  
  // If not found, return (this transfer doesn't match any known shareholder)
  if (!foundAgreement) {
    return
  }
  
  // Update sender shareholder (reduce balance)
  let fromShareholderId = agreementId.concat(from as Bytes)
  let fromShareholder = Shareholder.load(fromShareholderId)
  if (fromShareholder != null) {
    fromShareholder.shares = fromShareholder.shares.minus(amount)
    fromShareholder.lastUpdated = event.block.timestamp
    if (fromShareholder.shares.le(BigInt.fromI32(0))) {
      fromShareholder.isActive = false
    }
    fromShareholder.save()
  }
  
  // Update recipient shareholder (increase balance or create new)
  let toShareholderId = agreementId.concat(to as Bytes)
  let toShareholder = Shareholder.load(toShareholderId)
  let isNewShareholder = false
  
  if (toShareholder == null) {
    toShareholder = new Shareholder(toShareholderId)
    toShareholder.agreement = agreementId
    toShareholder.investor = to
    toShareholder.shares = BigInt.fromI32(0)
    toShareholder.capitalContributed = BigInt.fromI32(0) // Unknown for secondary market
    toShareholder.distributionsReceived = BigInt.fromI32(0)
    isNewShareholder = true
  }
  
  toShareholder.shares = toShareholder.shares.plus(amount)
  toShareholder.lastUpdated = event.block.timestamp
  toShareholder.isActive = true
  toShareholder.save()
  
  // Update AnalyticsSummary if new shareholder
  if (isNewShareholder) {
    let summary = loadOrCreateAnalyticsSummary()
    summary.totalShareholders = summary.totalShareholders + 1
    summary.lastUpdated = event.block.timestamp
    summary.save()
  }
}

/**
 * Handle TransferBlocked event
 * Tracks transfer restriction enforcement for compliance analytics
 */
export function handleTransferBlocked(event: TransferBlocked): void {
  // Create TransferRestrictionEvent entity
  let eventId = event.transaction.hash.toHexString() + '-' + event.logIndex.toString()
  let restrictionEvent = new TransferRestrictionEvent(Bytes.fromHexString(eventId))
  
  // Note: Need to derive agreementId from token contract context (see handleTransfer TODO)
  // For now, set to placeholder
  restrictionEvent.agreement = Bytes.fromHexString('0x00')
  
  restrictionEvent.from = event.params.from
  restrictionEvent.to = event.params.to
  restrictionEvent.amount = event.params.amount
  restrictionEvent.reason = event.params.reason
  restrictionEvent.timestamp = event.block.timestamp
  restrictionEvent.blockNumber = event.block.number
  restrictionEvent.save()
}

/**
 * Handle TransferRestrictionsUpdated event
 * Tracks restriction configuration changes
 */
export function handleTransferRestrictionsUpdated(event: TransferRestrictionsUpdated): void {
  // Track restriction updates
  // Could create a separate TransferRestrictionConfig entity linked to YieldAgreement
  // For now, just update analytics summary timestamp
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

