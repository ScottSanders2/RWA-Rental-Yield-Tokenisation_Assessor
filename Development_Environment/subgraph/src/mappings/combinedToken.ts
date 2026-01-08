/**
 * CombinedPropertyYieldToken Contract Event Handlers (ERC-1155 Variant)
 * Handles events from the ERC-1155 combined token contract
 * Tracks property and yield token minting, distributions, and transfers
 */

import { BigInt, Bytes } from '@graphprotocol/graph-ts'

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
import {
  PropertyTokenMinted,
  YieldTokenMinted,
  RepaymentDistributed,
  PropertyVerified,
  TransferSingle,
  TransferBatch
} from '../../generated/CombinedPropertyYieldToken/CombinedPropertyYieldToken'
import { Property, YieldAgreement, Repayment, Shareholder, AnalyticsSummary } from '../../generated/schema'

/**
 * Handle PropertyTokenMinted event
 * Creates Property entity for ERC-1155 property token (ID scheme: 1-999,999)
 */
export function handlePropertyTokenMinted(event: PropertyTokenMinted): void {
  // Create Property entity with tokenId as primary key
  // Use helper function to ensure correct byte order
  let propertyIdBytes = bigIntToPaddedBytes(event.params.tokenId)
  let property = new Property(propertyIdBytes)
  
  // Set property fields from event parameters
  property.propertyAddressHash = event.params.propertyAddressHash
  property.metadataURI = event.params.metadataURI
  property.isVerified = false
  property.createdAt = event.block.timestamp
  property.createdAtBlock = event.block.number
  
  // Save Property entity
  property.save()
}

/**
 * Handle YieldTokenMinted event
 * Creates YieldAgreement entity for ERC-1155 yield token (ID scheme: 1,000,000+)
 * Links to property token via propertyTokenId
 */
export function handleYieldTokenMinted(event: YieldTokenMinted): void {
  // Create YieldAgreement entity with yieldTokenId as primary key
  // Use helper function to ensure correct byte order
  let yieldTokenIdBytes = bigIntToPaddedBytes(event.params.yieldTokenId)
  let agreement = new YieldAgreement(yieldTokenIdBytes)
  
  // Set basic fields from event parameters (Enhancement #11 + USD parameter)
  agreement.tokenContract = event.address // Store contract address as tokenContract reference
  agreement.tokenStandard = 'ERC1155'
  agreement.createdAt = event.block.timestamp
  agreement.createdAtBlock = event.block.number
  agreement.isActive = true
  agreement.isCompleted = false
  agreement.totalRepaid = BigInt.fromI32(0)
  
  // Set agreement parameters from event (11 total parameters)
  agreement.upfrontCapital = event.params.upfrontCapital
  agreement.upfrontCapitalUsd = event.params.upfrontCapitalUsd
  agreement.termMonths = event.params.termMonths
  agreement.annualROIBasisPoints = event.params.annualROIBasisPoints
  
  // Calculate expected payments based on ROI formula
  // totalExpectedRepayment = upfrontCapital * (1 + annualROI / 10000)
  let annualROIMultiplier = BigInt.fromI32(10000 + agreement.annualROIBasisPoints)
  agreement.totalExpectedRepayment = agreement.upfrontCapital
    .times(annualROIMultiplier)
    .div(BigInt.fromI32(10000))
  agreement.monthlyPaymentExpected = agreement.totalExpectedRepayment
    .div(BigInt.fromI32(agreement.termMonths))
  
  // Link to Property entity
  let propertyIdBytes = bigIntToPaddedBytes(event.params.propertyTokenId)
  let property = Property.load(propertyIdBytes)
  if (property != null) {
    agreement.property = property.id
    property.yieldAgreement = agreement.id
    property.save()
  }
  
  // Save YieldAgreement entity
  agreement.save()
  
  // Update AnalyticsSummary singleton
  let summary = loadOrCreateAnalyticsSummary()
  summary.totalAgreements = summary.totalAgreements + 1
  summary.totalCapitalDeployed = summary.totalCapitalDeployed.plus(agreement.upfrontCapital)
  summary.totalCapitalDeployedUsd = summary.totalCapitalDeployedUsd.plus(agreement.upfrontCapitalUsd)
  summary.activeAgreements = summary.activeAgreements + 1
  summary.erc1155AgreementCount = summary.erc1155AgreementCount + 1
  summary.lastUpdated = event.block.timestamp
  summary.save()
}

/**
 * Handle RepaymentDistributed event (ERC-1155)
 * Creates Repayment entity and updates YieldAgreement totalRepaid
 */
export function handleRepaymentDistributed(event: RepaymentDistributed): void {
  // Create Repayment entity
  let repaymentIdStr = event.transaction.hash.toHexString() + '-' + event.logIndex.toString()
  let repayment = new Repayment(Bytes.fromHexString(repaymentIdStr))
  
  // For ERC-1155, yieldTokenId is the agreement identifier
  let yieldTokenIdBytes = bigIntToPaddedBytes(event.params.yieldTokenId)
  repayment.agreement = yieldTokenIdBytes
  repayment.amount = event.params.amount
  repayment.timestamp = event.block.timestamp
  repayment.blockNumber = event.block.number
  repayment.isPartial = false
  repayment.isEarly = false
  repayment.transactionHash = event.transaction.hash
  repayment.save()
  
  // Update YieldAgreement
  let agreement = YieldAgreement.load(yieldTokenIdBytes)
  if (agreement != null) {
    agreement.totalRepaid = agreement.totalRepaid.plus(event.params.amount)
    agreement.lastRepaymentAt = event.block.timestamp
    
    // Calculate actual ROI
    if (agreement.upfrontCapital.gt(BigInt.fromI32(0))) {
      let profit = agreement.totalRepaid.minus(agreement.upfrontCapital)
      let actualROI = profit.times(BigInt.fromI32(10000)).div(agreement.upfrontCapital)
      agreement.actualROIBasisPoints = actualROI.toI32()
    }
    
    agreement.save()
  }
  
  // Update AnalyticsSummary
  let summary = loadOrCreateAnalyticsSummary()
  summary.totalRepaymentsDistributed = summary.totalRepaymentsDistributed.plus(event.params.amount)
  summary.lastUpdated = event.block.timestamp
  summary.save()
}

/**
 * Handle PropertyVerified event (ERC-1155)
 * Updates Property entity with verification status
 */
export function handlePropertyVerified(event: PropertyVerified): void {
  // Load Property entity
  let propertyIdBytes = bigIntToPaddedBytes(event.params.tokenId)
  let property = Property.load(propertyIdBytes)
  
  if (property == null) {
    return
  }
  
  // Update verification fields
  property.isVerified = true
  property.verificationTimestamp = event.block.timestamp
  // Note: ERC-1155 PropertyVerified event should include verifier address
  // For now, we don't have verifier in the event parameters
  
  // Save updated Property entity
  property.save()
}

/**
 * Handle TransferSingle event (ERC-1155)
 * Updates Shareholder entities for yield token transfers
 * ID scheme: 1,000,000+ are yield tokens
 */
export function handleTransferSingle(event: TransferSingle): void {
  let tokenId = event.params.id
  
  // Check if this is a yield token (ID >= 1,000,000)
  let ONE_MILLION = BigInt.fromI32(1000000)
  if (tokenId.lt(ONE_MILLION)) {
    // This is a property token, not a yield token - skip
    return
  }
  
  let from = event.params.from
  let to = event.params.to
  let amount = event.params.value
  
  // CRITICAL FIX: Handle mint events (from == 0x0) to create initial shareholder
  // Previously skipped with comment "handled by YieldTokenMinted", but that event
  // doesn't include recipient address, so shareholders were never created!
  
  // Skip burn (to == 0x0) events only
  if (to.toHexString() == '0x0000000000000000000000000000000000000000') {
    return
  }
  
  let yieldTokenIdBytes = bigIntToPaddedBytes(tokenId)
  
  // Update sender shareholder (reduce balance) - skip for mints (from == 0x0)
  if (from.toHexString() != '0x0000000000000000000000000000000000000000') {
    let fromShareholderId = yieldTokenIdBytes.concat(from as Bytes)
    let fromShareholder = Shareholder.load(fromShareholderId)
    if (fromShareholder != null) {
      fromShareholder.shares = fromShareholder.shares.minus(amount)
      fromShareholder.lastUpdated = event.block.timestamp
      if (fromShareholder.shares.le(BigInt.fromI32(0))) {
        fromShareholder.isActive = false
      }
      fromShareholder.save()
    }
  }
  
  // Update recipient shareholder (increase balance or create new)
  let toShareholderId = yieldTokenIdBytes.concat(to as Bytes)
  let toShareholder = Shareholder.load(toShareholderId)
  let isNewShareholder = false
  
  if (toShareholder == null) {
    toShareholder = new Shareholder(toShareholderId)
    toShareholder.agreement = yieldTokenIdBytes
    toShareholder.investor = to
    toShareholder.shares = BigInt.fromI32(0)
    toShareholder.capitalContributed = BigInt.fromI32(0) // For mints, capital is in YieldAgreement
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
 * Handle TransferBatch event (ERC-1155)
 * Batch transfer of multiple tokens in a single transaction
 * Demonstrates ERC-1155 gas efficiency advantage
 */
export function handleTransferBatch(event: TransferBatch): void {
  let from = event.params.from
  let to = event.params.to
  let ids = event.params.ids
  let values = event.params.values
  
  // CRITICAL FIX: Handle mint events (from == 0x0) in batch transfers
  // Skip burn events (to == 0x0) only
  if (to.toHexString() == '0x0000000000000000000000000000000000000000') {
    return
  }
  
  // Iterate through all tokens in the batch
  for (let i = 0; i < ids.length; i++) {
    let tokenId = ids[i]
    let amount = values[i]
    
    // Check if this is a yield token (ID >= 1,000,000)
    let ONE_MILLION = BigInt.fromI32(1000000)
    if (tokenId.lt(ONE_MILLION)) {
      // Property token, skip
      continue
    }
    
    let yieldTokenIdBytes = bigIntToPaddedBytes(tokenId)
    
    // Update sender shareholder (reduce balance) - skip for mints (from == 0x0)
    if (from.toHexString() != '0x0000000000000000000000000000000000000000') {
      let fromShareholderId = yieldTokenIdBytes.concat(from as Bytes)
      let fromShareholder = Shareholder.load(fromShareholderId)
      if (fromShareholder != null) {
        fromShareholder.shares = fromShareholder.shares.minus(amount)
        fromShareholder.lastUpdated = event.block.timestamp
        if (fromShareholder.shares.le(BigInt.fromI32(0))) {
          fromShareholder.isActive = false
        }
        fromShareholder.save()
      }
    }
    
    // Update recipient shareholder (increase balance or create new)
    let toShareholderId = yieldTokenIdBytes.concat(to as Bytes)
    let toShareholder = Shareholder.load(toShareholderId)
    let isNewShareholder = false
    
    if (toShareholder == null) {
      toShareholder = new Shareholder(toShareholderId)
      toShareholder.agreement = yieldTokenIdBytes
      toShareholder.investor = to
      toShareholder.shares = BigInt.fromI32(0)
      toShareholder.capitalContributed = BigInt.fromI32(0)
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

