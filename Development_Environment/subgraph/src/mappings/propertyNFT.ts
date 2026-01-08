/**
 * PropertyNFT Contract Event Handlers
 * Tracks property tokenization lifecycle: mint → verify → link to agreement
 * Creates Property entities with metadata and verification status
 */

import { BigInt, Bytes } from '@graphprotocol/graph-ts'
import {
  PropertyMinted,
  PropertyVerified,
  PropertyLinkedToYieldAgreement
} from '../../generated/PropertyNFT/PropertyNFT'
import { Property, YieldAgreement } from '../../generated/schema'

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
 * Handle PropertyMinted event
 * Creates Property entity when a new property NFT is minted
 */
export function handlePropertyMinted(event: PropertyMinted): void {
  // Create Property entity with tokenId as primary key
  let property = new Property(bigIntToPaddedBytes(event.params.tokenId))
  
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
 * Handle PropertyVerified event
 * Updates Property entity with verification details
 */
export function handlePropertyVerified(event: PropertyVerified): void {
  // Load Property entity
  let property = Property.load(bigIntToPaddedBytes(event.params.tokenId))
  
  if (property == null) {
    // Property should exist from PropertyMinted event
    // If not, log warning and return
    return
  }
  
  // Update verification fields
  property.isVerified = true
  property.verifier = event.params.verifier
  property.verificationTimestamp = event.block.timestamp
  
  // Save updated Property entity
  property.save()
}

/**
 * Handle PropertyLinkedToYieldAgreement event
 * Establishes bidirectional link between Property and YieldAgreement entities
 */
export function handlePropertyLinkedToYieldAgreement(event: PropertyLinkedToYieldAgreement): void {
  // Load Property entity
  let property = Property.load(bigIntToPaddedBytes(event.params.tokenId))
  
  if (property == null) {
    return
  }
  
  // Load YieldAgreement entity
  let agreementId = event.params.yieldAgreementId.toHexString()
  let agreement = YieldAgreement.load(Bytes.fromHexString(agreementId))
  
  if (agreement == null) {
    return
  }
  
  // Establish bidirectional relationship
  // Property -> YieldAgreement (one-to-one)
  property.yieldAgreement = agreement.id
  property.save()
  
  // YieldAgreement -> Property (already set in handleYieldAgreementCreated)
  // But set here as well for safety
  agreement.property = property.id
  agreement.save()
}

