// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "../../storage/CombinedTokenStorage.sol";
import "../../libraries/CombinedTokenDistribution.sol";

/// @title CombinedViewsFacet
/// @notice Facet for all view functions in CombinedPropertyYieldToken Diamond
/// @dev Provides read-only access to property metadata, yield data, and token information
contract CombinedViewsFacet {
    using CombinedTokenStorage for CombinedTokenStorage.CombinedTokenStorageLayout;

    // ============ Custom Errors ============
    
    error InvalidPropertyTokenID();
    error InvalidYieldTokenID();

    // ============ Property Views ============

    /// @notice Get property metadata
    /// @param tokenId The property token ID
    /// @return PropertyMetadata struct
    function getPropertyMetadata(uint256 tokenId)
        external
        view
        returns (CombinedTokenStorage.PropertyMetadata memory)
    {
        if (!CombinedTokenDistribution.isPropertyToken(tokenId)) {
            revert InvalidPropertyTokenID();
        }
        
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        return layout.propertyMetadata[tokenId];
    }

    // ============ Yield Views ============

    /// @notice Get yield agreement data
    /// @param tokenId The yield token ID
    /// @return YieldAgreementData struct
    function getYieldAgreementData(uint256 tokenId)
        external
        view
        returns (CombinedTokenStorage.YieldAgreementData memory)
    {
        if (!CombinedTokenDistribution.isYieldToken(tokenId)) {
            revert InvalidYieldTokenID();
        }
        
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        return layout.yieldAgreementData[tokenId];
    }

    /// @notice Get pooled contribution data for a yield token
    /// @param yieldTokenId The yield token ID
    /// @return totalPooledCapital Total capital contributed
    /// @return contributorAddresses List of contributor addresses
    function getPooledContributionData(uint256 yieldTokenId)
        external
        view
        returns (uint256 totalPooledCapital, address[] memory contributorAddresses)
    {
        if (!CombinedTokenDistribution.isYieldToken(yieldTokenId)) {
            revert InvalidYieldTokenID();
        }
        
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        CombinedTokenStorage.PooledContributionData storage pooledData = 
            layout.yieldPooledContributions[yieldTokenId];
        
        return (pooledData.totalPooledCapital, pooledData.contributorAddresses);
    }

    /// @notice Get contributor's balance in a pooled yield agreement
    /// @param yieldTokenId The yield token ID
    /// @param contributor The contributor address
    /// @return contribution The contributor's capital contribution
    function getContributorBalance(uint256 yieldTokenId, address contributor)
        external
        view
        returns (uint256 contribution)
    {
        if (!CombinedTokenDistribution.isYieldToken(yieldTokenId)) {
            revert InvalidYieldTokenID();
        }
        
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        return layout.yieldPooledContributions[yieldTokenId].contributorBalances[contributor];
    }

    // ============ Token Mapping Views ============

    /// @notice Get yield token ID for a property token
    /// @param propertyTokenId The property token ID
    /// @return yieldTokenId The associated yield token ID (0 if none)
    function getYieldTokenForProperty(uint256 propertyTokenId)
        external
        view
        returns (uint256 yieldTokenId)
    {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        return layout.propertyToYieldMapping[propertyTokenId];
    }

    /// @notice Get property token ID for a yield token
    /// @param yieldTokenId The yield token ID
    /// @return propertyTokenId The associated property token ID
    function getPropertyTokenForYield(uint256 yieldTokenId)
        external
        view
        returns (uint256 propertyTokenId)
    {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        return layout.yieldToPropertyMapping[yieldTokenId];
    }

    // ============ Unclaimed Remainder Views ============

    /// @notice Get unclaimed remainder balance for an address
    /// @param holder The holder address
    /// @return amount The unclaimed remainder amount
    function getUnclaimedRemainder(address holder) external view returns (uint256 amount) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        return layout.unclaimedRemainder[holder];
    }

    // ============ Counter Views ============

    /// @notice Get the current property token ID counter
    /// @return counter The current property token ID counter
    function getPropertyTokenIdCounter() external view returns (uint256 counter) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        return layout.propertyTokenIdCounter;
    }

    /// @notice Get the current yield token ID counter
    /// @return counter The current yield token ID counter
    function getYieldTokenIdCounter() external view returns (uint256 counter) {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = 
            CombinedTokenStorage.getCombinedTokenStorage();
        
        return layout.yieldTokenIdCounter;
    }
}

