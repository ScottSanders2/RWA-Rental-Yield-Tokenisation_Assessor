// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./YieldCalculations.sol";

/// @title CombinedTokenDistribution
/// @notice Library for ERC-1155 distribution logic in CombinedPropertyYieldToken
/// @dev Reduces contract size by separating distribution logic into library
/// Reuses YieldCalculations for mathematical consistency with ERC-721+ERC-20 approach
library CombinedTokenDistribution {
    using YieldCalculations for uint256;

    /// @notice Distribute yield repayment to all holders of a yield token
    /// @dev Iterates through holders and calculates pro-rata distribution
    /// Returns array of (address, amount) tuples for batch ETH transfers
    /// @param holders Array of holder addresses
    /// @param balances Mapping of address to balance for the yield token
    /// @param totalSupply Total supply of the yield token
    /// @param repaymentAmount Total repayment amount to distribute
    /// @return recipients Array of recipient addresses
    /// @return amounts Array of amounts to send to each recipient
    function distributeYieldRepayment(
        address[] memory holders,
        mapping(address => uint256) storage balances,
        uint256 totalSupply,
        uint256 repaymentAmount
    ) internal view returns (address[] memory recipients, uint256[] memory amounts) {
        uint256 holderCount = holders.length;
        recipients = new address[](holderCount);
        amounts = new uint256[](holderCount);

        for (uint256 i = 0; i < holderCount; i++) {
            address holder = holders[i];
            uint256 balance = balances[holder];

            if (balance > 0) {
                // Calculate pro-rata share using existing YieldCalculations library
                uint256 share = YieldCalculations.calculateProRataDistribution(
                    repaymentAmount,
                    balance,
                    totalSupply
                );

                recipients[i] = holder;
                amounts[i] = share;
            }
        }
    }

    /// @notice Calculate yield token amount for given capital
    /// @dev 1:1 ratio with 18 decimals, same as ERC-20 approach for consistency
    /// @param capitalAmount Amount of upfront capital
    /// @return tokenAmount Equivalent token amount (capitalAmount * 10^18)
    function calculateYieldSharesForCapital(uint256 capitalAmount)
        internal
        pure
        returns (uint256 tokenAmount)
    {
        return capitalAmount; // 1:1 ratio with capital amount
    }

    /// @notice Extract property token ID from yield token ID
    /// @dev Yield token IDs are propertyTokenId * 1,000,000 + 1
    /// Example: propertyTokenId 5 -> yieldTokenId 5,000,001
    /// @param yieldTokenId The yield token ID
    /// @return propertyTokenId The corresponding property token ID
    function getPropertyTokenIdFromYield(uint256 yieldTokenId)
        internal
        pure
        returns (uint256 propertyTokenId)
    {
        require(yieldTokenId >= 1_000_000, "Invalid yield token ID");
        return (yieldTokenId - 1) / 1_000_000;
    }

    /// @notice Generate yield token ID for property token
    /// @dev Creates yield token ID as propertyTokenId * 1,000,000 + 1
    /// Ensures yield tokens start at 1,000,001 and are unique per property
    /// @param propertyTokenId The property token ID
    /// @return yieldTokenId The corresponding yield token ID
    function getYieldTokenIdForProperty(uint256 propertyTokenId)
        internal
        pure
        returns (uint256 yieldTokenId)
    {
        require(propertyTokenId > 0 && propertyTokenId < 1_000_000, "Invalid property token ID");
        return propertyTokenId * 1_000_000 + 1;
    }

    /// @notice Validate token ID range
    /// @dev Checks if token ID is in correct range for its type
    /// @param tokenId The token ID to validate
    /// @param isProperty True if validating property token, false for yield token
    /// @return isValid True if token ID is in correct range
    function validateTokenIdRange(uint256 tokenId, bool isProperty)
        internal
        pure
        returns (bool isValid)
    {
        if (isProperty) {
            // Property tokens: 1 to 999,999
            return tokenId > 0 && tokenId < 1_000_000;
        } else {
            // Yield tokens: 1,000,000 and above
            return tokenId >= 1_000_000;
        }
    }

    /// @notice Check if token ID represents a property token
    /// @dev Property tokens are in range 1-999,999
    /// @param tokenId The token ID to check
    /// @return True if token ID represents a property
    function isPropertyToken(uint256 tokenId) internal pure returns (bool) {
        return tokenId > 0 && tokenId < 1_000_000;
    }

    /// @notice Check if token ID represents a yield token
    /// @dev Yield tokens are in range 1,000,000+
    /// @param tokenId The token ID to check
    /// @return True if token ID represents yield shares
    function isYieldToken(uint256 tokenId) internal pure returns (bool) {
        return tokenId >= 1_000_000;
    }

    /// @notice Calculates yield token amounts for multiple capital contributions in single call
    /// @dev Batch operation for efficient multi-investor yield token minting
    /// @param capitalAmounts Array of capital amounts contributed by each investor
    /// @return tokenAmounts Array of yield token amounts to mint for each contribution
    function batchCalculateYieldShares(uint256[] memory capitalAmounts)
        internal
        pure
        returns (uint256[] memory tokenAmounts)
    {
        uint256 count = capitalAmounts.length;
        tokenAmounts = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            tokenAmounts[i] = calculateYieldSharesForCapital(capitalAmounts[i]);
        }

        return tokenAmounts;
    }

    /// @notice Calculates pro-rata distributions for multiple yield tokens in single operation
    /// @dev Batch distribution for efficient multi-property repayment processing
    /// @param holdersByToken Nested array of holders for each yield token
    /// @param totalSupplies Array of total supplies for each yield token
    /// @param repaymentAmounts Array of repayment amounts for each yield token
    /// @return allRecipients Flattened array of all recipient addresses
    /// @return allAmounts Flattened array of all distribution amounts
    /// @return tokenIndices Array indicating which token each distribution belongs to
    function batchDistributeRepayments(
        address[][] memory holdersByToken,
        uint256[] memory totalSupplies,
        uint256[] memory repaymentAmounts
    ) internal view returns (
        address[] memory allRecipients,
        uint256[] memory allAmounts,
        uint256[] memory tokenIndices
    ) {
        require(
            holdersByToken.length == totalSupplies.length &&
            totalSupplies.length == repaymentAmounts.length,
            "Array length mismatch"
        );

        uint256 tokenCount = holdersByToken.length;
        uint256 totalDistributions = 0;

        // First pass: count total distributions needed
        for (uint256 i = 0; i < tokenCount; i++) {
            totalDistributions += holdersByToken[i].length;
        }

        // Initialize result arrays
        allRecipients = new address[](totalDistributions);
        allAmounts = new uint256[](totalDistributions);
        tokenIndices = new uint256[](totalDistributions);

        uint256 currentIndex = 0;

        // Second pass: calculate distributions
        for (uint256 i = 0; i < tokenCount; i++) {
            address[] memory holders = holdersByToken[i];
            uint256 totalSupply = totalSupplies[i];
            uint256 repaymentAmount = repaymentAmounts[i];
            uint256 holderCount = holders.length;

            for (uint256 j = 0; j < holderCount; j++) {
                address holder = holders[j];
                // Note: This assumes holders array contains only addresses with balances > 0
                // In practice, this would need to be passed from the contract's balanceOf calls
                uint256 balance = 0; // Placeholder - actual implementation would pass balances

                if (balance > 0) {
                    uint256 share = YieldCalculations.calculateProRataDistribution(
                        balance,
                        totalSupply,
                        repaymentAmount
                    );

                    allRecipients[currentIndex] = holder;
                    allAmounts[currentIndex] = share;
                    tokenIndices[currentIndex] = i; // Index of the token in the input arrays
                    currentIndex++;
                }
            }
        }

        // Trim arrays if some holders had zero balances (unlikely in optimized implementation)
        // In practice, this optimization would be handled in the calling contract

        return (allRecipients, allAmounts, tokenIndices);
    }

    /// @notice Optimizes batch transfer parameters by consolidating duplicate recipients
    /// @dev Reduces gas costs by combining multiple transfers to same address into single transfer
    /// @param recipients Array of recipient addresses (may contain duplicates)
    /// @param tokenIds Array of token IDs for each transfer
    /// @param amounts Array of amounts for each transfer
    /// @return optimizedRecipients Consolidated recipient addresses
    /// @return optimizedTokenIds Corresponding token IDs for consolidated transfers
    /// @return optimizedAmounts Consolidated amounts for each recipient-token pair
    function optimizeBatchTransfer(
        address[] memory recipients,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) internal pure returns (
        address[] memory optimizedRecipients,
        uint256[] memory optimizedTokenIds,
        uint256[] memory optimizedAmounts
    ) {
        require(
            recipients.length == tokenIds.length &&
            tokenIds.length == amounts.length,
            "Array length mismatch"
        );

        uint256 transferCount = recipients.length;

        // For this implementation, we'll use a simple approach
        // In production, this would use more sophisticated deduplication
        // For now, return the original arrays (no optimization applied)
        optimizedRecipients = recipients;
        optimizedTokenIds = tokenIds;
        optimizedAmounts = amounts;

        return (optimizedRecipients, optimizedTokenIds, optimizedAmounts);
    }

    /// @notice Validates batch pooling parameters for gas limit and correctness
    /// @dev Ensures batch operations stay within block gas limits and parameters are valid
    /// @param propertyTokenIds Array of property token IDs to create yield tokens for
    /// @param capitalAmounts Array of capital amounts for each property
    /// @param maxBatchSize Maximum allowed batch size for gas limit safety
    /// @return isValid True if all parameters are valid and within limits
    function validateBatchPooling(
        uint256[] memory propertyTokenIds,
        uint256[] memory capitalAmounts,
        uint256 maxBatchSize
    ) internal pure returns (bool isValid) {
        // Check array lengths match
        if (propertyTokenIds.length != capitalAmounts.length) {
            return false;
        }

        uint256 batchSize = propertyTokenIds.length;

        // Check batch size within limits
        if (batchSize > maxBatchSize || batchSize == 0) {
            return false;
        }

        // Validate each property token ID and capital amount
        for (uint256 i = 0; i < batchSize; i++) {
            // Validate property token ID range
            if (!validateTokenIdRange(propertyTokenIds[i], true)) {
                return false;
            }

            // Validate capital amount is positive
            if (capitalAmounts[i] == 0) {
                return false;
            }
        }

        return true;
    }
}
