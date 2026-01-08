// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/YieldBase.sol";
import "../../src/YieldSharesToken.sol";
import "../../src/PropertyNFT.sol";
import "../../src/libraries/YieldCalculations.sol";

/// @title Default Scenarios Simulation Tests
/// @notice Comprehensive tests for autonomous default detection, grace period enforcement, penalty calculations, and default status tracking
/// @dev Validates default handling mechanisms and tracks variance metrics for dissertation analysis
contract DefaultScenariosTest is Test {
    YieldBase public yieldBase;
    YieldSharesToken public tokenImpl;
    PropertyNFT public propertyNFT;

    address public owner = address(1);
    address public propertyOwner = address(2);
    address public investor = address(3);

    uint256 public propertyTokenId;
    uint256 public agreementId;

    // Test metrics for variance tracking
    struct DefaultMetrics {
        uint256 expectedPenalty;
        uint256 actualPenalty;
        uint256 gracePeriodAccuracy;
        uint256 defaultThresholdTiming;
        uint256 gasCost;
    }

    DefaultMetrics[] public metrics;

    function setUp() public {
        // Deploy PropertyNFT with proxy
        PropertyNFT propertyNFTImpl = new PropertyNFT();
        propertyNFT = PropertyNFT(address(new ERC1967Proxy(
            address(propertyNFTImpl),
            abi.encodeWithSelector(
                PropertyNFT.initialize.selector,
                owner,
                "PropertyNFT",
                "PNFT"
            )
        )));

        // Deploy YieldBase with proxy
        YieldBase yieldBaseImpl = new YieldBase();
        yieldBase = YieldBase(address(new ERC1967Proxy(
            address(yieldBaseImpl),
            abi.encodeWithSelector(
                YieldBase.initialize.selector,
                owner
            )
        )));

        vm.prank(owner);
        yieldBase.setPropertyNFT(address(propertyNFT));

        // Setup property
        vm.prank(owner);
        propertyTokenId = propertyNFT.mintProperty(keccak256("test property"), "ipfs://test");

        vm.prank(owner);
        propertyNFT.verifyProperty(propertyTokenId);

        // Transfer property to property owner
        vm.prank(owner);
        propertyNFT.transferFrom(owner, propertyOwner, propertyTokenId);
    }

    /// @notice Test single missed payment within grace period
    /// @dev Verifies agreement remains current when payment is missed but within grace period
    function testSingleMissedPaymentWithinGracePeriod() public {
        vm.startPrank(propertyOwner);

        // Create agreement with 30-day grace period
        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
            1 ether,        // upfront capital
            12,             // term months
            500,            // 5% annual ROI
            propertyOwner,  // payer
            30,             // grace period days
            200,            // 2% penalty rate
            3,              // default threshold
            true,           // allow partial
            true            // allow early
        );

        vm.stopPrank();

        // Fast forward 15 days (within grace period)
        vm.warp(block.timestamp + 15 days);

        // Handle missed payment
        vm.prank(owner);
        uint256 gasStart = gasleft();
        yieldBase.handleMissedPayment(agreementId);
        uint256 gasCost = gasStart - gasleft();

        // Verify agreement is NOT in default
        (bool isActive, bool isInDefault, uint8 missedCount, , , , , ) = yieldBase.getAgreementStatus(agreementId);
        assertTrue(isActive, "Agreement should remain active");
        assertFalse(isInDefault, "Agreement should not be in default");
        assertEq(missedCount, 1, "Missed payment count should be 1");

        // Track metrics
        metrics.push(DefaultMetrics({
            expectedPenalty: 0,
            actualPenalty: 0,
            gracePeriodAccuracy: 15,
            defaultThresholdTiming: 0,
            gasCost: gasCost
        }));
    }

    /// @notice Test single missed payment after grace period expiry
    /// @dev Verifies penalty calculation and arrears accumulation after grace period
    function testSingleMissedPaymentAfterGracePeriod() public {
        vm.startPrank(propertyOwner);

        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
            1 ether,
            12,
            500,
            propertyOwner,
            30,
            200, // 2% penalty
            3,
            true,
            true
        );

        vm.stopPrank();

        // Fast forward 35 days (after grace period)
        vm.warp(block.timestamp + 35 days);

        // Handle missed payment
        vm.prank(owner);
        uint256 gasStart = gasleft();
        yieldBase.handleMissedPayment(agreementId);
        uint256 gasCost = gasStart - gasleft();

        // Calculate expected penalty
        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(1 ether, 12, 500);
        uint256 expectedPenalty = YieldCalculations.calculateDefaultPenalty(monthlyPayment, 200, 1);

        // Verify penalty was applied
        (, , uint8 missedCount, uint256 arrears, , , , ) = yieldBase.getAgreementStatus(agreementId);
        assertEq(missedCount, 1, "Missed payment count should be 1");
        assertEq(arrears, expectedPenalty, "Arrears should equal penalty amount");

        // Track metrics
        metrics.push(DefaultMetrics({
            expectedPenalty: expectedPenalty,
            actualPenalty: arrears,
            gracePeriodAccuracy: 35,
            defaultThresholdTiming: 0,
            gasCost: gasCost
        }));
    }

    /// @notice Test multiple missed payments reaching default threshold
    /// @dev Verifies default declaration after 3 consecutive missed payments
    function testMultipleMissedPaymentsReachingDefaultThreshold() public {
        vm.startPrank(propertyOwner);

        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
            1 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );

        vm.stopPrank();

        uint256 totalExpectedPenalty = 0;
        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(1 ether, 12, 500);

        // Simulate 3 missed payments
        for (uint8 i = 1; i <= 3; i++) {
            vm.warp(block.timestamp + 35 days); // After grace period each time

            vm.prank(owner);
            uint256 gasStart = gasleft();
            yieldBase.handleMissedPayment(agreementId);
            uint256 gasCost = gasStart - gasleft();

            uint256 penalty = YieldCalculations.calculateDefaultPenalty(monthlyPayment, 200, i);
            totalExpectedPenalty += penalty;

            (, bool isInDefault, uint8 missedCount, uint256 arrears, , , , ) = yieldBase.getAgreementStatus(agreementId);

            if (i < 3) {
                assertFalse(isInDefault, "Should not be in default before threshold");
                assertEq(missedCount, i, "Missed payment count incorrect");
                assertEq(arrears, totalExpectedPenalty, "Cumulative arrears incorrect");
            } else {
                // Third missed payment should trigger default
                assertTrue(isInDefault, "Should be in default at threshold");
                assertEq(missedCount, 3, "Missed payment count should be 3");
                assertEq(arrears, totalExpectedPenalty, "Final arrears should be cumulative");

                // Track final metrics
                metrics.push(DefaultMetrics({
                    expectedPenalty: totalExpectedPenalty,
                    actualPenalty: arrears,
                    gracePeriodAccuracy: 35,
                    defaultThresholdTiming: 3,
                    gasCost: gasCost
                }));
            }
        }
    }

    /// @notice Test default penalty calculation with various parameters
    /// @dev Validates penalty calculation accuracy across different scenarios
    function testDefaultPenaltyCalculation() public {
        uint256 monthlyPayment = 0.1 ether; // 0.1 ETH monthly payment

        // Test different penalty rates and missed payment counts
        uint16[] memory penaltyRates = new uint16[](3);
        penaltyRates[0] = 100;  // 1%
        penaltyRates[1] = 200;  // 2%
        penaltyRates[2] = 500;  // 5%

        uint8[] memory missedCounts = new uint8[](3);
        missedCounts[0] = 1;
        missedCounts[1] = 3;
        missedCounts[2] = 6;

        for (uint256 i = 0; i < penaltyRates.length; i++) {
            for (uint256 j = 0; j < missedCounts.length; j++) {
                uint256 expectedPenalty = YieldCalculations.calculateDefaultPenalty(
                    monthlyPayment,
                    penaltyRates[i],
                    missedCounts[j]
                );

                uint256 actualPenalty = (monthlyPayment * penaltyRates[i] * missedCounts[j]) / 10000;

                assertEq(expectedPenalty, actualPenalty, "Penalty calculation incorrect");

                metrics.push(DefaultMetrics({
                    expectedPenalty: expectedPenalty,
                    actualPenalty: actualPenalty,
                    gracePeriodAccuracy: 0,
                    defaultThresholdTiming: 0,
                    gasCost: 0
                }));
            }
        }
    }

    /// @notice Test grace period expiry calculation
    /// @dev Validates grace period timestamp calculations
    function testGracePeriodExpiryCalculation() public {
        uint256 baseTimestamp = block.timestamp;
        uint16[] memory gracePeriods = new uint16[](3);
        gracePeriods[0] = 7;
        gracePeriods[1] = 30;
        gracePeriods[2] = 60;

        for (uint256 i = 0; i < gracePeriods.length; i++) {
            uint256 expiry = YieldCalculations.calculateGracePeriodExpiry(baseTimestamp, gracePeriods[i]);
            uint256 expectedExpiry = baseTimestamp + (gracePeriods[i] * 1 days);

            assertEq(expiry, expectedExpiry, "Grace period expiry calculation incorrect");

            metrics.push(DefaultMetrics({
                expectedPenalty: 0,
                actualPenalty: 0,
                gracePeriodAccuracy: expiry - baseTimestamp,
                defaultThresholdTiming: 0,
                gasCost: 0
            }));
        }
    }

    /// @notice Test recovery from near-default status
    /// @dev Verifies payment resets missed payment counter and clears near-default status
    function testRecoveryFromNearDefault() public {
        vm.startPrank(propertyOwner);

        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
            1 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );

        vm.stopPrank();

        // Simulate 2 missed payments
        for (uint8 i = 0; i < 2; i++) {
            vm.warp(block.timestamp + 35 days);
            vm.prank(owner);
            yieldBase.handleMissedPayment(agreementId);
        }

        // Verify near-default state
        (, bool isInDefault, uint8 missedCount, , , , , ) = yieldBase.getAgreementStatus(agreementId);
        assertFalse(isInDefault, "Should not be in default yet");
        assertEq(missedCount, 2, "Should have 2 missed payments");

        // Make a payment
        vm.warp(block.timestamp + 5 days);
        vm.prank(propertyOwner);
        yieldBase.makeRepayment{value: 0.1 ether}(agreementId);

        // Verify recovery
        (, isInDefault, missedCount, , , , , ) = yieldBase.getAgreementStatus(agreementId);
        assertFalse(isInDefault, "Should not be in default after payment");
        assertEq(missedCount, 0, "Missed payment counter should be reset");
    }

    /// @notice Test default with accumulated arrears from partial payments
    /// @dev Verifies default calculation includes both arrears and penalties
    function testDefaultWithAccumulatedArrears() public {
        vm.startPrank(propertyOwner);

        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
            1 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );

        vm.stopPrank();

        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(1 ether, 12, 500);

        // Make partial payments to accumulate arrears
        vm.startPrank(propertyOwner);
        yieldBase.makePartialRepayment{value: monthlyPayment / 2}(agreementId);
        yieldBase.makePartialRepayment{value: monthlyPayment / 4}(agreementId);

        // Check accumulated arrears
        (, , , uint256 arrears, , , , ) = yieldBase.getAgreementStatus(agreementId);
        uint256 expectedArrears = (monthlyPayment / 2) + (monthlyPayment / 4) + (monthlyPayment / 4);
        assertEq(arrears, expectedArrears, "Arrears accumulation incorrect");

        vm.stopPrank();

        // Now miss a payment and trigger default
        vm.warp(block.timestamp + 35 days);
        vm.prank(owner);
        yieldBase.handleMissedPayment(agreementId);

        // Verify default includes both arrears and penalties
        uint256 penalty = YieldCalculations.calculateDefaultPenalty(monthlyPayment, 200, 1);
        (, bool isInDefault, , uint256 finalArrears, , , , ) = yieldBase.getAgreementStatus(agreementId);
        assertTrue(isInDefault, "Should be in default");
        assertEq(finalArrears, expectedArrears + penalty, "Final arrears should include penalty");
    }

    /// @notice Test that defaulted agreements prevent new repayments
    /// @dev Verifies defaulted agreements cannot accept further repayments
    function testDefaultPreventsNewRepayments() public {
        vm.startPrank(propertyOwner);

        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
            1 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );

        vm.stopPrank();

        // Force default by simulating 3 missed payments quickly
        for (uint8 i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 35 days);
            vm.prank(owner);
            yieldBase.handleMissedPayment(agreementId);
        }

        // Verify defaulted
        (, bool isInDefault, , , , , , ) = yieldBase.getAgreementStatus(agreementId);
        assertTrue(isInDefault, "Agreement should be defaulted");

        // Attempt repayment (should revert)
        vm.startPrank(propertyOwner);
        vm.expectRevert("Cannot make repayments on defaulted agreement");
        yieldBase.makeRepayment{value: 0.1 ether}(agreementId);

        vm.expectRevert("Cannot make repayments on defaulted agreement");
        yieldBase.makePartialRepayment{value: 0.05 ether}(agreementId);

        vm.stopPrank();
    }

    /// @notice Get variance metrics for dissertation analysis
    /// @dev Returns collected metrics for analysis of default handling accuracy
    function getDefaultMetrics() external view returns (DefaultMetrics[] memory) {
        return metrics;
    }

    /// @notice Calculate average variance in penalty calculations
    /// @dev Returns percentage variance between expected and actual penalties
    function getPenaltyVariance() external view returns (uint256 averageVariance) {
        if (metrics.length == 0) return 0;

        uint256 totalVariance = 0;
        uint256 count = 0;

        for (uint256 i = 0; i < metrics.length; i++) {
            if (metrics[i].expectedPenalty > 0) {
                uint256 variance = metrics[i].expectedPenalty > metrics[i].actualPenalty
                    ? ((metrics[i].expectedPenalty - metrics[i].actualPenalty) * 100) / metrics[i].expectedPenalty
                    : ((metrics[i].actualPenalty - metrics[i].expectedPenalty) * 100) / metrics[i].expectedPenalty;
                totalVariance += variance;
                count++;
            }
        }

        return count > 0 ? totalVariance / count : 0;
    }
}
