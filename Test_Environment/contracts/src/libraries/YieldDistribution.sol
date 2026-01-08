// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./YieldCalculations.sol";

/// @title Yield Distribution Library
/// @notice Pure functions for autonomous yield distribution to ERC-20 token holders
/// @dev Library functions are deployed once and linked at deployment time, reducing main contract bytecode size
/// This library handles the complex distribution logic to keep YieldSharesToken under 24KB limit
/// Uses YieldCalculations.calculateProRataDistribution for consistent mathematical operations
library YieldDistribution {
    /// @dev Struct to return distribution results for batch processing
    struct DistributionResult {
        address shareholder;
        uint256 amount;
    }

    /// @notice Distributes repayment amount to shareholders based on their token holdings
    /// @dev SINGLE AGREEMENT MODEL: Simplified to work with single agreement per token instance.
    ///     Iterates through shareholder array and calculates pro-rata distribution for each.
    ///     Uses YieldCalculations.calculateProRataDistribution for consistency with yield calculations.
    /// @param shareholders Array of shareholder addresses for the agreement
    /// @param shareholderShares Mapping of shares held by each address
    /// @param totalShares Total shares outstanding for this agreement
    /// @param repaymentAmount Total amount to distribute
    /// @return results Array of DistributionResult structs containing address and amount for each shareholder
    function distributeRepayment(
        address[] memory shareholders,
        mapping(address => uint256) storage shareholderShares,
        uint256 totalShares,
        uint256 repaymentAmount
    ) internal view returns (DistributionResult[] memory results) {
        // Division by zero guard
        require(repaymentAmount == 0 || totalShares > 0, "No shareholders for distribution");

        uint256 shareholderCount = shareholders.length;
        results = new DistributionResult[](shareholderCount);

        for (uint256 i = 0; i < shareholderCount; i++) {
            address shareholder = shareholders[i];
            uint256 shareholderBalance = shareholderShares[shareholder];

            uint256 distributionAmount = YieldCalculations.calculateProRataDistribution(
                repaymentAmount,
                shareholderBalance,
                totalShares
            );

            results[i] = DistributionResult({
                shareholder: shareholder,
                amount: distributionAmount
            });
        }

        return results;
    }

    /// @notice Calculates the token amount to mint for a given capital contribution
    /// @dev Uses 1:1 ratio (1 token = 1 wei of capital) with 18 decimals for fractional ownership
    /// @param capitalAmount The amount of capital contributed
    /// @return The number of tokens to mint (with 18 decimals)
    function calculateSharesForCapital(uint256 capitalAmount) internal pure returns (uint256) {
        return capitalAmount;
    }

    /// @notice Validates shareholder count limits to prevent excessive gas costs
    /// @dev Enforces reasonable limits on shareholder arrays to maintain gas efficiency
    /// @param currentCount Current number of shareholders
    /// @param maxShareholders Maximum allowed shareholders per agreement
    /// @return True if within limits, false if exceeded
    function validateShareholderLimit(uint256 currentCount, uint256 maxShareholders) internal pure returns (bool) {
        return currentCount <= maxShareholders;
    }

    /// @notice Aggregates total shares held by a list of shareholders
    /// @dev Used for reporting and validation purposes
    /// @param shareholders Array of shareholder addresses
    /// @param shares Storage mapping of shares held by each address
    /// @return total Total shares held by all provided shareholders
    function aggregateShareholderBalances(
        address[] memory shareholders,
        mapping(address => uint256) storage shares
    ) internal view returns (uint256 total) {
        uint256 shareholderCount = shareholders.length;
        for (uint256 i = 0; i < shareholderCount; i++) {
            total += shares[shareholders[i]];
        }
        return total;
    }

    /// @notice Distributes partial repayment amount to shareholders based on their token holdings
    /// @dev Calculates percentage of full payment and distributes proportionally to each shareholder
    /// @param shareholders Array of shareholder addresses for the agreement
    /// @param shareholderShares Mapping of shares held by each address
    /// @param totalShares Total shares outstanding for this agreement
    /// @param partialAmount The partial repayment amount received
    /// @param fullMonthlyPayment The standard full monthly payment amount
    /// @return results Array of DistributionResult structs with proportional partial amounts
    function distributePartialRepayment(
        address[] memory shareholders,
        mapping(address => uint256) storage shareholderShares,
        uint256 totalShares,
        uint256 partialAmount,
        uint256 fullMonthlyPayment
    ) internal view returns (DistributionResult[] memory results) {
        // Division by zero guard
        require(partialAmount == 0 || totalShares > 0, "No shareholders for distribution");

        uint256 shareholderCount = shareholders.length;
        results = new DistributionResult[](shareholderCount);

        // Calculate the percentage of full payment this partial represents
        uint256 paymentPercentage = fullMonthlyPayment > 0 ? (partialAmount * 1e18) / fullMonthlyPayment : 0;

        for (uint256 i = 0; i < shareholderCount; i++) {
            address shareholder = shareholders[i];
            uint256 shareholderBalance = shareholderShares[shareholder];

            // Calculate shareholder's portion of the partial amount
            uint256 distributionAmount = YieldCalculations.calculateProRataDistribution(
                partialAmount,
                shareholderBalance,
                totalShares
            );

            results[i] = DistributionResult({
                shareholder: shareholder,
                amount: distributionAmount
            });
        }

        return results;
    }

    /// @notice Validates that pooled contributions sum to required upfront capital
    /// @dev Checks contribution array lengths and validates total matches required amount
    /// @param contributors Array of contributor addresses
    /// @param amounts Array of capital amounts contributed by each address
    /// @param totalRequired The total upfront capital required for the agreement
    /// @return isValid True if contributions are valid, false otherwise
    /// @return totalAccumulated The total amount accumulated from all contributions
    function accumulatePooledContributions(
        address[] memory contributors,
        uint256[] memory amounts,
        uint256 totalRequired
    ) internal pure returns (bool isValid, uint256 totalAccumulated) {
        require(contributors.length == amounts.length, "Array length mismatch");

        uint256 contributorCount = contributors.length;
        for (uint256 i = 0; i < contributorCount; i++) {
            require(amounts[i] > 0, "Zero contribution not allowed");
            totalAccumulated += amounts[i];
        }

        isValid = (totalAccumulated >= totalRequired);
        return (isValid, totalAccumulated);
    }

    /// @notice Calculates token shares to mint for each contributor based on capital contribution
    /// @dev Pro-rata calculation: each contributor gets shares proportional to their contribution
    /// @param contributors Array of contributor addresses
    /// @param contributions Array of capital amounts contributed
    /// @param totalCapital The total capital pooled for the agreement
    /// @return shareAmounts Array of token amounts to mint for each contributor
    function calculateContributorShares(
        address[] memory contributors,
        uint256[] memory contributions,
        uint256 totalCapital
    ) internal pure returns (uint256[] memory shareAmounts) {
        require(contributors.length == contributions.length, "Array length mismatch");
        require(totalCapital > 0, "Total capital cannot be zero");

        uint256 contributorCount = contributors.length;
        shareAmounts = new uint256[](contributorCount);

        for (uint256 i = 0; i < contributorCount; i++) {
            // Calculate shares proportional to contribution
            shareAmounts[i] = YieldCalculations.calculateProRataDistribution(
                totalCapital, // Total tokens to mint (1:1 with capital)
                contributions[i],
                totalCapital
            );
        }

        return shareAmounts;
    }

    /// @notice Validates pooled contributions meet required capital within tolerance
    /// @dev Allows small rounding differences when pooling from multiple investors
    /// @param totalContributions The total amount contributed
    /// @param requiredCapital The required upfront capital amount
    /// @param tolerance The allowed tolerance in wei (e.g., 1e15 for 0.001 ETH)
    /// @return True if within acceptable range
    function validatePooledCapital(
        uint256 totalContributions,
        uint256 requiredCapital,
        uint256 tolerance
    ) internal pure returns (bool) {
        if (totalContributions >= requiredCapital) {
            return (totalContributions - requiredCapital) <= tolerance;
        } else {
            return (requiredCapital - totalContributions) <= tolerance;
        }
    }
}
