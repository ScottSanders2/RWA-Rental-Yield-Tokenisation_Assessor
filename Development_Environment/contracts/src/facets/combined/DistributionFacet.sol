// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../../storage/CombinedTokenStorage.sol";
import "../../libraries/CombinedTokenDistribution.sol";
import "../../libraries/YieldCalculations.sol";

/// @title DistributionFacet
/// @notice Facet for repayment distribution to yield token holders
/// @dev Handles standard, partial, and batch repayment distributions
contract DistributionFacet is ERC1155Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using CombinedTokenStorage for CombinedTokenStorage.CombinedTokenStorageLayout;

    // ============ Events ============
    
    event RepaymentDistributed(uint256 indexed yieldTokenId, uint256 amount);
    event PartialYieldRepaymentDistributed(uint256 indexed yieldTokenId, uint256 partialAmount, uint256 fullAmount);
    event YieldAgreementDefaulted(uint256 indexed yieldTokenId, uint256 totalArrears);
    event BatchRepaymentsDistributed(uint256[] yieldTokenIds, uint256[] amounts, uint256 totalDistributed);

    // ============ Custom Errors ============
    
    error InvalidYieldTokenID();
    error YieldAgreementNotActive();
    error YieldAgreementDoesNotExist();
    error InsufficientRepaymentAmount();

    // ============ Repayment Distribution ============

    /// @notice Distribute yield repayment to holders
    /// @param yieldTokenId The yield token ID
    function distributeYieldRepayment(uint256 yieldTokenId) external onlyOwner nonReentrant payable {
        if (!CombinedTokenDistribution.isYieldToken(yieldTokenId)) revert InvalidYieldTokenID();

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        CombinedTokenStorage.YieldAgreementData storage yieldData = layout.yieldAgreementData[yieldTokenId];

        if (!yieldData.isActive) revert YieldAgreementNotActive();
        if (yieldData.upfrontCapital == 0) revert YieldAgreementDoesNotExist();

        address[] memory holders = CombinedTokenStorage.getHolders(layout, yieldTokenId);
        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(
            yieldData.upfrontCapital,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints
        );

        if (msg.value < monthlyPayment) revert InsufficientRepaymentAmount();

        yieldData.totalRepaid += msg.value;
        yieldData.lastRepaymentTimestamp = block.timestamp;

        uint256 tokenTotalSupply = layout.totalSupply[yieldTokenId];
        uint256 totalDistributed = 0;

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 holderBalance = balanceOf(holder, yieldTokenId);
            if (holderBalance > 0) {
                uint256 holderShare = (msg.value * holderBalance) / tokenTotalSupply;
                if (holderShare > 0) {
                    (bool success, ) = payable(holder).call{value: holderShare}("");
                    if (!success) {
                        layout.unclaimedRemainder[holder] += holderShare;
                    } else {
                        totalDistributed += holderShare;
                    }
                }
            }
        }

        emit RepaymentDistributed(yieldTokenId, msg.value);
    }

    /// @notice Distribute partial repayment
    /// @param yieldTokenId The yield token ID
    function distributePartialYieldRepayment(uint256 yieldTokenId) external onlyOwner nonReentrant payable {
        if (!CombinedTokenDistribution.isYieldToken(yieldTokenId)) revert InvalidYieldTokenID();

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        CombinedTokenStorage.YieldAgreementData storage yieldData = layout.yieldAgreementData[yieldTokenId];

        if (!yieldData.isActive) revert YieldAgreementNotActive();
        if (yieldData.upfrontCapital == 0) revert YieldAgreementDoesNotExist();
        if (!yieldData.allowPartialRepayments) revert("Partial repayments not allowed");

        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(
            yieldData.upfrontCapital,
            yieldData.repaymentTermMonths,
            yieldData.annualROIBasisPoints
        );

        yieldData.totalRepaid += msg.value;
        yieldData.lastRepaymentTimestamp = block.timestamp;

        address[] memory holders = CombinedTokenStorage.getHolders(layout, yieldTokenId);
        uint256 tokenTotalSupply = layout.totalSupply[yieldTokenId];

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 holderBalance = balanceOf(holder, yieldTokenId);
            if (holderBalance > 0) {
                uint256 holderShare = (msg.value * holderBalance) / tokenTotalSupply;
                if (holderShare > 0) {
                    (bool success, ) = payable(holder).call{value: holderShare}("");
                    if (!success) {
                        layout.unclaimedRemainder[holder] += holderShare;
                    }
                }
            }
        }

        emit PartialYieldRepaymentDistributed(yieldTokenId, msg.value, monthlyPayment);
    }

    /// @notice Handle yield default
    /// @param yieldTokenId The yield token ID
    function handleYieldDefault(uint256 yieldTokenId) external onlyOwner {
        if (!CombinedTokenDistribution.isYieldToken(yieldTokenId)) revert InvalidYieldTokenID();

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        CombinedTokenStorage.YieldAgreementData storage yieldData = layout.yieldAgreementData[yieldTokenId];

        if (yieldData.upfrontCapital == 0) revert YieldAgreementDoesNotExist();

        yieldData.isInDefault = true;
        yieldData.isActive = false;

        emit YieldAgreementDefaulted(yieldTokenId, yieldData.accumulatedArrears);
    }

    /// @notice Batch distribute repayments
    /// @param yieldTokenIds Array of yield token IDs
    /// @param amounts Array of repayment amounts
    function batchDistributeRepayments(uint256[] memory yieldTokenIds, uint256[] memory amounts) external onlyOwner nonReentrant payable {
        require(yieldTokenIds.length == amounts.length, "Array length mismatch");

        uint256 totalRequired = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalRequired += amounts[i];
        }
        require(msg.value >= totalRequired, "Insufficient total amount");

        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        uint256 totalDistributed = 0;

        for (uint256 i = 0; i < yieldTokenIds.length; i++) {
            uint256 yieldTokenId = yieldTokenIds[i];
            uint256 amount = amounts[i];

            if (!CombinedTokenDistribution.isYieldToken(yieldTokenId)) continue;

            CombinedTokenStorage.YieldAgreementData storage yieldData = layout.yieldAgreementData[yieldTokenId];
            if (!yieldData.isActive || yieldData.upfrontCapital == 0) continue;

            yieldData.totalRepaid += amount;
            yieldData.lastRepaymentTimestamp = block.timestamp;

            address[] memory holders = CombinedTokenStorage.getHolders(layout, yieldTokenId);
            uint256 tokenTotalSupply = layout.totalSupply[yieldTokenId];

            for (uint256 j = 0; j < holders.length; j++) {
                address holder = holders[j];
                uint256 holderBalance = balanceOf(holder, yieldTokenId);
                if (holderBalance > 0) {
                    uint256 holderShare = (amount * holderBalance) / tokenTotalSupply;
                    if (holderShare > 0) {
                        (bool success, ) = payable(holder).call{value: holderShare}("");
                        if (!success) {
                            layout.unclaimedRemainder[holder] += holderShare;
                        } else {
                            totalDistributed += holderShare;
                        }
                    }
                }
            }
        }

        emit BatchRepaymentsDistributed(yieldTokenIds, amounts, totalDistributed);
    }

    /// @notice Claim unclaimed remainder
    function claimUnclaimedRemainder() external nonReentrant {
        CombinedTokenStorage.CombinedTokenStorageLayout storage layout = CombinedTokenStorage.getCombinedTokenStorage();
        uint256 amount = layout.unclaimedRemainder[msg.sender];
        require(amount > 0, "No unclaimed remainder");

        layout.unclaimedRemainder[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }
}

