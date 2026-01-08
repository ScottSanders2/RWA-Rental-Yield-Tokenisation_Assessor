/**
 * YieldBase Contract Event Handlers
 * Transforms YieldBase events into indexed entities for analytics
 * Handles agreement creation, repayments, defaults, and ROI adjustments
 */

import { BigInt, Bytes, Address, dataSource } from '@graphprotocol/graph-ts'

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
  YieldAgreementCreated,
  RepaymentMade,
  PartialRepaymentMade,
  EarlyRepaymentMade,
  YieldAgreementCompleted,
  PaymentMissed,
  AgreementDefaulted,
  ROIAdjusted,
  ReserveAllocated,
  ReserveWithdrawn,
  YieldBase
} from '../../generated/YieldBase/YieldBase'
import { YieldSharesToken as YieldSharesTokenTemplate } from '../../generated/templates'
import { YieldAgreement, Repayment, AnalyticsSummary, Property } from '../../generated/schema'

/**
 * Handle YieldAgreementCreated event
 * Creates YieldAgreement entity, links to Property, calculates expected payments
 * Creates YieldSharesToken template data source for dynamic token contract indexing
 */
export function handleYieldAgreementCreated(event: YieldAgreementCreated): void {
  // Load or create YieldAgreement entity
  let agreement = new YieldAgreement(bigIntToPaddedBytes(event.params.agreementId))
  
  // Set basic fields from event parameters (updated to match actual event signature)
  agreement.upfrontCapital = event.params.upfrontCapital
  agreement.upfrontCapitalUsd = event.params.upfrontCapitalUsd
  agreement.termMonths = event.params.termMonths
  agreement.annualROIBasisPoints = event.params.annualROI
  agreement.totalRepaid = BigInt.fromI32(0)
  agreement.isActive = true
  agreement.isCompleted = false
  agreement.createdAt = event.block.timestamp
  agreement.createdAtBlock = event.block.number
  
  // Get token contract address by calling YieldBase contract
  // Import YieldBase contract binding at top of file to call getYieldSharesToken
  let yieldBaseContract = YieldBase.bind(event.address)
  let tokenAddressResult = yieldBaseContract.try_getYieldSharesToken(event.params.agreementId)
  
  if (!tokenAddressResult.reverted) {
    agreement.tokenContract = tokenAddressResult.value
    // Token standard is ERC-721+ERC-20 mode with separate contracts
    agreement.tokenStandard = 'ERC721'
    
    // Create YieldSharesToken template data source for dynamic indexing
    // This enables The Graph to monitor events from the dynamically deployed token contract
    YieldSharesTokenTemplate.create(tokenAddressResult.value)
  } else {
    // Fallback: use zero address if contract call fails
    agreement.tokenContract = Address.fromString('0x0000000000000000000000000000000000000000')
    agreement.tokenStandard = 'ERC721'
  }
  
  // Calculate expected payments based on ROI formula
  // totalExpectedRepayment = upfrontCapital * (1 + annualROI / 10000)
  let annualROIMultiplier = BigInt.fromI32(10000 + agreement.annualROIBasisPoints)
  agreement.totalExpectedRepayment = agreement.upfrontCapital
    .times(annualROIMultiplier)
    .div(BigInt.fromI32(10000))
  agreement.monthlyPaymentExpected = agreement.totalExpectedRepayment
    .div(BigInt.fromI32(agreement.termMonths))
  
  // Link to Property entity
  let property = Property.load(bigIntToPaddedBytes(event.params.propertyTokenId))
  if (property != null) {
    agreement.property = property.id
  }
  
  // Save YieldAgreement entity
  agreement.save()
  
  // Update AnalyticsSummary singleton
  let summary = loadOrCreateAnalyticsSummary()
  summary.totalAgreements = summary.totalAgreements + 1
  summary.totalCapitalDeployed = summary.totalCapitalDeployed.plus(agreement.upfrontCapital)
  summary.totalCapitalDeployedUsd = summary.totalCapitalDeployedUsd.plus(agreement.upfrontCapitalUsd)
  summary.activeAgreements = summary.activeAgreements + 1
  summary.erc721AgreementCount = summary.erc721AgreementCount + 1
  summary.lastUpdated = event.block.timestamp
  summary.save()
}

/**
 * Handle RepaymentMade event
 * Creates Repayment entity, updates YieldAgreement totalRepaid, calculates actualROI
 */
export function handleRepaymentMade(event: RepaymentMade): void {
  // Create Repayment entity
  let repaymentId = event.transaction.hash.toHexString() + '-' + event.logIndex.toString()
  let repayment = new Repayment(Bytes.fromHexString(repaymentId))
  
  // Set repayment fields
  repayment.agreement = bigIntToPaddedBytes(event.params.agreementId)
  repayment.amount = event.params.amount
  repayment.timestamp = event.params.timestamp
  repayment.blockNumber = event.block.number
  repayment.isPartial = false
  repayment.isEarly = false
  repayment.transactionHash = event.transaction.hash
  repayment.save()
  
  // Update YieldAgreement
  let agreement = YieldAgreement.load(bigIntToPaddedBytes(event.params.agreementId))
  if (agreement != null) {
    agreement.totalRepaid = agreement.totalRepaid.plus(event.params.amount)
    agreement.lastRepaymentAt = event.params.timestamp
    
    // Calculate actual ROI: (totalRepaid - upfrontCapital) / upfrontCapital * 10000
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
 * Handle PartialRepaymentMade event
 * Similar to RepaymentMade but tracks arrears and current payment allocation
 */
export function handlePartialRepaymentMade(event: PartialRepaymentMade): void {
  // Create Repayment entity with partial payment details
  let repaymentId = event.transaction.hash.toHexString() + '-' + event.logIndex.toString()
  let repayment = new Repayment(Bytes.fromHexString(repaymentId))
  
  repayment.agreement = bigIntToPaddedBytes(event.params.agreementId)
  repayment.amount = event.params.amount
  repayment.timestamp = event.block.timestamp
  repayment.blockNumber = event.block.number
  repayment.isPartial = true
  repayment.arrearsPayment = event.params.arrearsPayment
  repayment.currentPayment = event.params.currentPayment
  repayment.isEarly = false
  repayment.transactionHash = event.transaction.hash
  repayment.save()
  
  // Update YieldAgreement totalRepaid and actualROI
  let agreement = YieldAgreement.load(bigIntToPaddedBytes(event.params.agreementId))
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
 * Handle EarlyRepaymentMade event
 * Tracks early payoffs with rebate amounts
 */
export function handleEarlyRepaymentMade(event: EarlyRepaymentMade): void {
  // Create Repayment entity with early payment details
  let repaymentId = event.transaction.hash.toHexString() + '-' + event.logIndex.toString()
  let repayment = new Repayment(Bytes.fromHexString(repaymentId))
  
  repayment.agreement = bigIntToPaddedBytes(event.params.agreementId)
  repayment.amount = event.params.amount
  repayment.timestamp = event.block.timestamp
  repayment.blockNumber = event.block.number
  repayment.isPartial = false
  repayment.isEarly = true
  repayment.rebateAmount = event.params.rebateAmount
  repayment.transactionHash = event.transaction.hash
  repayment.save()
  
  // Update YieldAgreement
  let agreement = YieldAgreement.load(bigIntToPaddedBytes(event.params.agreementId))
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
 * Handle YieldAgreementCompleted event
 * Marks agreement as completed and inactive
 */
export function handleYieldAgreementCompleted(event: YieldAgreementCompleted): void {
  let agreement = YieldAgreement.load(bigIntToPaddedBytes(event.params.agreementId))
  
  if (agreement != null) {
    agreement.isActive = false
    agreement.isCompleted = true
    agreement.completedAt = event.block.timestamp
    agreement.save()
    
    // Update AnalyticsSummary
    let summary = loadOrCreateAnalyticsSummary()
    summary.activeAgreements = summary.activeAgreements - 1
    summary.completedAgreements = summary.completedAgreements + 1
    summary.lastUpdated = event.block.timestamp
    summary.save()
  }
}

/**
 * Handle PaymentMissed event
 * Tracks missed payments for default analytics
 */
export function handlePaymentMissed(event: PaymentMissed): void {
  // Track missed payment in agreement metadata
  // For now, just update analytics summary
  let summary = loadOrCreateAnalyticsSummary()
  summary.lastUpdated = event.block.timestamp
  summary.save()
}

/**
 * Handle AgreementDefaulted event
 * Marks agreement as defaulted (inactive)
 */
export function handleAgreementDefaulted(event: AgreementDefaulted): void {
  let agreement = YieldAgreement.load(bigIntToPaddedBytes(event.params.agreementId))
  
  if (agreement != null) {
    agreement.isActive = false
    agreement.save()
    
    // Update AnalyticsSummary
    let summary = loadOrCreateAnalyticsSummary()
    summary.activeAgreements = summary.activeAgreements - 1
    summary.lastUpdated = event.block.timestamp
    summary.save()
  }
}

/**
 * Handle ROIAdjusted event
 * Updates agreement ROI via governance
 */
export function handleROIAdjusted(event: ROIAdjusted): void {
  let agreement = YieldAgreement.load(bigIntToPaddedBytes(event.params.agreementId))
  
  if (agreement != null) {
    agreement.annualROIBasisPoints = event.params.newROI
    
    // Recalculate expected payments with new ROI
    let annualROIMultiplier = BigInt.fromI32(10000 + agreement.annualROIBasisPoints)
    agreement.totalExpectedRepayment = agreement.upfrontCapital
      .times(annualROIMultiplier)
      .div(BigInt.fromI32(10000))
    agreement.monthlyPaymentExpected = agreement.totalExpectedRepayment
      .div(BigInt.fromI32(agreement.termMonths))
    
    agreement.save()
  }
}

/**
 * Handle ReserveAllocated event
 * Tracks reserve allocation for agreements
 */
export function handleReserveAllocated(event: ReserveAllocated): void {
  // Track reserve allocation in agreement or separate entity
  // For now, just update analytics summary timestamp
  let summary = loadOrCreateAnalyticsSummary()
  summary.lastUpdated = event.block.timestamp
  summary.save()
}

/**
 * Handle ReserveWithdrawn event
 * Tracks reserve withdrawals
 */
export function handleReserveWithdrawn(event: ReserveWithdrawn): void {
  // Track reserve withdrawal
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

