// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../storage/DiamondYieldStorage.sol";
import "../KYCRegistry.sol";
import "../YieldSharesToken.sol";

/// @title KYCFacet
/// @notice Diamond facet for KYC/AML compliance checks
/// @dev Part of YieldBase Diamond implementation (EIP-2535)
///      Handles KYC Registry integration and verification logic
///      Extracted from YieldBaseFacet to reduce contract size below 24KB limit
contract KYCFacet {
    
    // ============ Events ============
    
    /// @notice Emitted when KYCRegistry contract is linked
    event KYCRegistrySet(address indexed kycRegistry);
    
    // ============ Errors ============
    
    error KYCRegistryNotSet();
    error AddressNotKYCVerified(address account);
    error AddressBlacklisted(address account);
    error UnauthorizedCaller();

    // ============ Modifiers ============

    /// @notice Modifier that allows only the contract owner
    modifier onlyOwner() {
        require(msg.sender == OwnableUpgradeable(address(this)).owner(), "Caller is not the owner");
        _;
    }

    // ============ Core Functions ============

    /// @notice Set the KYCRegistry contract reference for compliance checks
    /// @dev Only owner can set for security. Required for KYC verification
    /// @param kycRegistryAddress Address of the KYCRegistry contract
    function setKYCRegistry(address kycRegistryAddress) external onlyOwner {
        require(kycRegistryAddress != address(0), "Invalid KYCRegistry address");
        
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        agreements.kycRegistry = kycRegistryAddress;
        
        emit KYCRegistrySet(kycRegistryAddress);
    }

    /// @notice Get the KYCRegistry contract address
    /// @return kycRegistryAddress The address of the linked KYCRegistry contract
    function getKYCRegistry() external view returns (address kycRegistryAddress) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        return agreements.kycRegistry;
    }

    /// @notice Check if an address is KYC verified and not blacklisted
    /// @dev Reverts if KYC Registry not set, address not verified, or address blacklisted
    /// @param account Address to verify
    function requireKYCVerified(address account) external view {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        
        if (agreements.kycRegistry == address(0)) {
            revert KYCRegistryNotSet();
        }
        
        KYCRegistry registry = KYCRegistry(agreements.kycRegistry);
        
        if (!registry.isWhitelisted(account)) {
            revert AddressNotKYCVerified(account);
        }
        
        if (registry.isBlacklisted(account)) {
            revert AddressBlacklisted(account);
        }
    }

    /// @notice Check if an address is KYC verified (view-only, no revert)
    /// @param account Address to check
    /// @return isVerified True if address is whitelisted and not blacklisted
    function isKYCVerified(address account) external view returns (bool isVerified) {
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        
        if (agreements.kycRegistry == address(0)) {
            return false;
        }
        
        KYCRegistry registry = KYCRegistry(agreements.kycRegistry);
        return registry.isWhitelisted(account) && !registry.isBlacklisted(account);
    }

    /// @notice Configure KYC Registry on a YieldSharesToken instance
    /// @dev Called during agreement creation to enable KYC on token transfers/minting
    /// @param tokenAddress Address of the YieldSharesToken to configure
    function configureTokenKYC(address tokenAddress) external {
        // Only allow YieldBaseFacet (via Diamond proxy) to call this
        require(msg.sender == address(this), "Only callable via Diamond");
        
        DiamondYieldStorage.AgreementStorage storage agreements = DiamondYieldStorage.getAgreementStorage();
        
        if (agreements.kycRegistry != address(0) && tokenAddress != address(0)) {
            YieldSharesToken(tokenAddress).setKYCRegistry(agreements.kycRegistry);
        }
    }
}

