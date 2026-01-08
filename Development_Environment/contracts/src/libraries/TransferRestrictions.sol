// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../storage/TransferRestrictionsStorage.sol";

/**
 * @title TransferRestrictions
 * @notice Library for transfer restriction validation logic
 * @dev Pure and view functions to reduce contract bytecode size and maintain 24KB limit.
 * Provides modular validation for lockup periods, concentration limits, minimum holding
 * periods, whitelist/blacklist, and emergency pause controls.
 *
 * Design Pattern:
 * - Pure functions for gas optimization and testability
 * - Aggregate validation function returns (bool, string) for detailed error messages
 * - Integration with _update hook for autonomous enforcement
 * - No state modifications (validation only)
 *
 * Usage:
 * - Called from YieldSharesToken._update() and CombinedPropertyYieldToken._beforeTokenTransfer()
 * - Validates restrictions before allowing transfer to proceed
 * - Returns reason string for frontend display and error messages
 */
library TransferRestrictions {
    using TransferRestrictionsStorage for TransferRestrictionsStorage.TransferRestrictionData;

    /**
     * @notice Validate lockup period has expired
     * @param lockupEndTimestamp Timestamp when lockup ends (0 = no lockup)
     * @return allowed True if lockup expired or not set
     */
    function validateLockupPeriod(uint256 lockupEndTimestamp) internal view returns (bool allowed) {
        if (lockupEndTimestamp == 0) {
            return true; // No lockup set
        }
        return block.timestamp >= lockupEndTimestamp;
    }

    /**
     * @notice Validate concentration limit not exceeded
     * @param recipientBalance Current balance of recipient
     * @param transferAmount Amount being transferred
     * @param totalSupply Total token supply
     * @param maxSharesPerInvestor Maximum shares per investor in basis points (e.g., 2000 = 20%)
     * @return allowed True if concentration limit not exceeded
     */
    function validateConcentrationLimit(
        uint256 recipientBalance,
        uint256 transferAmount,
        uint256 totalSupply,
        uint256 maxSharesPerInvestor
    ) internal pure returns (bool allowed) {
        if (maxSharesPerInvestor == 0 || totalSupply == 0) {
            return true; // No concentration limit set or supply is zero
        }
        
        // Calculate new balance percentage in basis points (10000 = 100%)
        uint256 newBalance = recipientBalance + transferAmount;
        uint256 newBalancePercentage = (newBalance * 10000) / totalSupply;
        
        return newBalancePercentage <= maxSharesPerInvestor;
    }

    /**
     * @notice Validate minimum holding period has elapsed
     * @param lastTransferTimestamp Timestamp of last transfer for sender
     * @param minHoldingPeriod Minimum holding period in seconds (0 = no requirement)
     * @return allowed True if holding period met or not set
     */
    function validateHoldingPeriod(
        uint256 lastTransferTimestamp,
        uint256 minHoldingPeriod
    ) internal view returns (bool allowed) {
        if (minHoldingPeriod == 0 || lastTransferTimestamp == 0) {
            return true; // No holding period set or first transfer
        }
        return block.timestamp >= lastTransferTimestamp + minHoldingPeriod;
    }

    /**
     * @notice Validate address is whitelisted (if whitelist enabled)
     * @param account Address to check
     * @param whitelist Mapping of whitelisted addresses
     * @param whitelistEnabled Whether whitelist is active
     * @return allowed True if address whitelisted or whitelist disabled
     */
    function validateWhitelist(
        address account,
        mapping(address => bool) storage whitelist,
        bool whitelistEnabled
    ) internal view returns (bool allowed) {
        if (!whitelistEnabled) {
            return true; // Whitelist disabled
        }
        return whitelist[account];
    }

    /**
     * @notice Validate address is not blacklisted (if blacklist enabled)
     * @param account Address to check
     * @param blacklist Mapping of blacklisted addresses
     * @param blacklistEnabled Whether blacklist is active
     * @return allowed True if address not blacklisted or blacklist disabled
     */
    function validateBlacklist(
        address account,
        mapping(address => bool) storage blacklist,
        bool blacklistEnabled
    ) internal view returns (bool allowed) {
        if (!blacklistEnabled) {
            return true; // Blacklist disabled
        }
        return !blacklist[account]; // Allow if NOT blacklisted
    }

    /**
     * @notice Validate transfers are not paused
     * @param isTransferPaused Pause flag from storage
     * @return allowed True if transfers not paused
     */
    function validateTransferNotPaused(bool isTransferPaused) internal pure returns (bool allowed) {
        return !isTransferPaused;
    }

    /**
     * @notice Aggregate validation of all transfer restrictions
     * @param from Sender address
     * @param to Recipient address
     * @param amount Transfer amount
     * @param recipientBalance Current balance of recipient
     * @param totalSupply Total token supply
     * @param restrictions Storage pointer to restriction data
     * @return allowed True if all restrictions pass
     * @return reason Human-readable reason for restriction violation (empty if allowed)
     */
    function validateAllRestrictions(
        address from,
        address to,
        uint256 amount,
        uint256 recipientBalance,
        uint256 totalSupply,
        TransferRestrictionsStorage.TransferRestrictionData storage restrictions
    ) internal view returns (bool allowed, string memory reason) {
        // Check 1: Transfer not paused
        if (!validateTransferNotPaused(restrictions.isTransferPaused)) {
            return (false, "Transfers paused by owner or governance");
        }

        // Check 2: Lockup period expired
        if (!validateLockupPeriod(restrictions.lockupEndTimestamp)) {
            return (false, string(abi.encodePacked(
                "Lockup period active until timestamp ",
                _uint2str(restrictions.lockupEndTimestamp)
            )));
        }

        // Check 3: Sender holding period met
        if (!validateHoldingPeriod(restrictions.lastTransferTimestamp[from], restrictions.minHoldingPeriod)) {
            uint256 requiredTime = restrictions.lastTransferTimestamp[from] + restrictions.minHoldingPeriod;
            return (false, string(abi.encodePacked(
                "Minimum holding period not met. Can transfer after timestamp ",
                _uint2str(requiredTime)
            )));
        }

        // Check 4: Recipient concentration limit
        if (!validateConcentrationLimit(recipientBalance, amount, totalSupply, restrictions.maxSharesPerInvestor)) {
            return (false, string(abi.encodePacked(
                "Concentration limit exceeded. Max allowed: ",
                _uint2str(restrictions.maxSharesPerInvestor / 100),
                "%"
            )));
        }

        // Check 5: Recipient whitelist (if enabled)
        if (!validateWhitelist(to, restrictions.whitelistedAddresses, restrictions.whitelistEnabled)) {
            return (false, "Recipient not whitelisted");
        }

        // Check 6: Recipient not blacklisted (if enabled)
        if (!validateBlacklist(to, restrictions.blacklistedAddresses, restrictions.blacklistEnabled)) {
            return (false, "Recipient is blacklisted");
        }

        // Check 7: Sender not blacklisted (if enabled)
        if (!validateBlacklist(from, restrictions.blacklistedAddresses, restrictions.blacklistEnabled)) {
            return (false, "Sender is blacklisted");
        }

        // All checks passed
        return (true, "");
    }

    /**
     * @notice Convert uint256 to string (helper for error messages)
     * @param _i Number to convert
     * @return _uintAsString String representation
     */
    function _uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}

