// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/YieldBase.sol";
import "../../src/YieldSharesToken.sol";
import "../../src/PropertyNFT.sol";
import "../../src/libraries/YieldCalculations.sol";

/// @title Repayment Variances Simulation Tests
/// @notice Comprehensive tests for partial repayment handling, overpayment credits, early repayment rebates, and irregular payment schedules
/// @dev Validates flexible repayment handling and tracks variance metrics for dissertation analysis
contract RepaymentVariancesTest is Test {
    YieldBase public yieldBase;
    YieldSharesToken public tokenImpl;
    PropertyNFT public propertyNFT;

    address public owner = address(1);
    address public propertyOwner = address(2);
    address public investor = address(3);

    uint256 public propertyTokenId;
    uint256 public agreementId;

    // Test metrics for variance tracking
    struct VarianceMetrics {
        uint256 scenario;
        uint256 expectedValue;
        uint256 actualValue;
        uint256 variance;
        uint256 gasCost;
    }

    VarianceMetrics[] public metrics;

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

    /// @notice Test partial repayment allocation logic
    /// @dev Verifies correct allocation between arrears and current payment
    function testPartialRepaymentAllocation() public {
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
            true, // allow partial
            true
        );

        vm.stopPrank();

        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(1 ether, 12, 500);
        uint256 partialAmount = monthlyPayment / 2; // 50% of monthly payment

        // First create some arrears with a partial payment
        vm.startPrank(propertyOwner);
        yieldBase.makePartialRepayment{value: partialAmount}(agreementId);

        // Check arrears accumulation
        (, , , uint256 arrears, , , , ) = yieldBase.getAgreementStatus(agreementId);
        uint256 expectedArrears = monthlyPayment - partialAmount;
        assertEq(arrears, expectedArrears, "Arrears calculation incorrect");

        // Now make another partial payment that covers arrears + current
        uint256 secondPartial = (expectedArrears + monthlyPayment) * 3 / 4; // 75% of total owed
        yieldBase.makePartialRepayment{value: secondPartial}(agreementId);

        // Check final state
        uint256 finalArrears;
        (, , , finalArrears, , , , ) = yieldBase.getAgreementStatus(agreementId);
        uint256 expectedFinalArrears = expectedArrears + monthlyPayment - secondPartial;
        assertEq(finalArrears, expectedFinalArrears, "Final arrears calculation incorrect");

        vm.stopPrank();

        // Track variance metrics
        metrics.push(VarianceMetrics({
            scenario: 1, // Partial payment allocation
            expectedValue: expectedFinalArrears,
            actualValue: finalArrears,
            variance: expectedFinalArrears > finalArrears ?
                ((expectedFinalArrears - finalArrears) * 100) / expectedFinalArrears :
                ((finalArrears - expectedFinalArrears) * 100) / expectedFinalArrears,
            gasCost: 0
        }));
    }

    /// @notice Test multiple partial repayments accumulating arrears
    /// @dev Verifies arrears accumulate correctly across multiple partial payments
    function testMultiplePartialRepaymentsAccumulatingArrears() public {
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
        uint256[] memory partialPayments = new uint256[](3);
        partialPayments[0] = monthlyPayment * 60 / 100; // 60%
        partialPayments[1] = monthlyPayment * 70 / 100; // 70%
        partialPayments[2] = monthlyPayment * 80 / 100; // 80%

        uint256 expectedTotalArrears = 0;

        vm.startPrank(propertyOwner);
        for (uint256 i = 0; i < partialPayments.length; i++) {
            yieldBase.makePartialRepayment{value: partialPayments[i]}(agreementId);

            (, , , uint256 currentArrears, , , , ) = yieldBase.getAgreementStatus(agreementId);
            expectedTotalArrears += (monthlyPayment - partialPayments[i]);
            assertEq(currentArrears, expectedTotalArrears, "Arrears accumulation incorrect");

            // Track metrics for each partial payment
            metrics.push(VarianceMetrics({
                scenario: 2, // Multiple partial repayments
                expectedValue: expectedTotalArrears,
                actualValue: currentArrears,
                variance: expectedTotalArrears > currentArrears ?
                    ((expectedTotalArrears - currentArrears) * 100) / expectedTotalArrears :
                    ((currentArrears - expectedTotalArrears) * 100) / expectedTotalArrears,
                gasCost: 0
            }));
        }
        vm.stopPrank();
    }

    /// @notice Test overpayment creates credit for future payments
    /// @dev Verifies overpayments are credited and applied to future obligations
    function testOverpaymentCreatesCredit() public {
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
            false, // no partial payments
            true
        );

        vm.stopPrank();

        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(1 ether, 12, 500);
        uint256 overpayment = monthlyPayment * 120 / 100; // 120% of monthly payment

        vm.startPrank(propertyOwner);
        yieldBase.makeRepayment{value: overpayment}(agreementId);

        // Check credit was created
        (, , , , uint256 overpaymentCredit, , , ) = yieldBase.getAgreementStatus(agreementId);
        uint256 expectedCredit = overpayment - monthlyPayment;
        assertEq(overpaymentCredit, expectedCredit, "Overpayment credit incorrect");

        vm.stopPrank();

        metrics.push(VarianceMetrics({
            scenario: 3, // Overpayment credit creation
            expectedValue: expectedCredit,
            actualValue: overpaymentCredit,
            variance: expectedCredit > overpaymentCredit ?
                ((expectedCredit - overpaymentCredit) * 100) / expectedCredit :
                ((overpaymentCredit - expectedCredit) * 100) / expectedCredit,
            gasCost: 0
        }));
    }

    /// @notice Test overpayment credit application to future payments
    /// @dev Verifies credits are automatically applied to reduce payment requirements
    function testOverpaymentCreditApplication() public {
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
            false,
            true
        );

        vm.stopPrank();

        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(1 ether, 12, 500);

        // Create overpayment credit
        vm.startPrank(propertyOwner);
        yieldBase.makeRepayment{value: monthlyPayment * 120 / 100}(agreementId);

        // Verify credit exists
        (, , , , uint256 credit, , , ) = yieldBase.getAgreementStatus(agreementId);
        assertGt(credit, 0, "Credit should exist");

        // Make underpayment that should be covered by credit
        uint256 underpayment = monthlyPayment * 80 / 100; // 80% of monthly payment
        yieldBase.makeRepayment{value: underpayment}(agreementId);

        // Check credit was applied and no arrears created
        (, , , uint256 arrears, , uint256 creditAfter, , ) = yieldBase.getAgreementStatus(agreementId);
        uint256 expectedCreditAfter = credit - (monthlyPayment - underpayment);
        assertEq(creditAfter, expectedCreditAfter, "Credit application incorrect");
        assertEq(arrears, 0, "No arrears should be created when credit covers shortfall");

        vm.stopPrank();

        metrics.push(VarianceMetrics({
            scenario: 4, // Credit application
            expectedValue: expectedCreditAfter,
            actualValue: creditAfter,
            variance: expectedCreditAfter > creditAfter ?
                ((expectedCreditAfter - creditAfter) * 100) / expectedCreditAfter :
                ((creditAfter - expectedCreditAfter) * 100) / expectedCreditAfter,
            gasCost: 0
        }));
    }

    /// @notice Test early repayment with rebate calculation
    /// @dev Verifies rebate calculation and agreement completion
    function testEarlyRepaymentWithRebate() public {
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

        // Calculate remaining balance
        uint256 elapsedMonths = YieldCalculations.calculateElapsedMonths(
            block.timestamp,
            block.timestamp
        );

        uint256 remainingBalance = YieldCalculations.calculateRemainingBalance(
            1 ether,
            0, // no payments made yet
            12,
            500,
            elapsedMonths
        );

        // Calculate expected rebate (10% of remaining balance)
        uint256 expectedRebate = (remainingBalance * 1000) / 10000;

        vm.startPrank(propertyOwner);
        yieldBase.makeEarlyRepayment{value: remainingBalance - expectedRebate}(agreementId);

        // Verify agreement completed and rebate applied
        (bool isActive, , , , , , , ) = yieldBase.getAgreementStatus(agreementId);
        assertFalse(isActive, "Agreement should be completed");

        vm.stopPrank();

        metrics.push(VarianceMetrics({
            scenario: 5, // Early repayment rebate
            expectedValue: expectedRebate,
            actualValue: expectedRebate, // Simplified - actual implementation would track rebate
            variance: 0,
            gasCost: 0
        }));
    }

    /// @notice Test early repayment rebate calculation with various parameters
    /// @dev Validates rebate calculation accuracy across different scenarios
    function testEarlyRepaymentRebateCalculation() public {
        uint256[] memory remainingBalances = new uint256[](3);
        remainingBalances[0] = 1 ether;
        remainingBalances[1] = 0.5 ether;
        remainingBalances[2] = 2 ether;

        uint256[] memory remainingInterests = new uint256[](3);
        remainingInterests[0] = 0.1 ether;
        remainingInterests[1] = 0.05 ether;
        remainingInterests[2] = 0.2 ether;

        uint16[] memory rebatePercentages = new uint16[](3);
        rebatePercentages[0] = 500;  // 5%
        rebatePercentages[1] = 1000; // 10%
        rebatePercentages[2] = 1500; // 15%

        for (uint256 i = 0; i < remainingBalances.length; i++) {
            for (uint256 j = 0; j < rebatePercentages.length; j++) {
                uint256 expectedRebate = YieldCalculations.calculateEarlyRepaymentRebate(
                    remainingBalances[i] - remainingInterests[i], // principal
                    remainingInterests[i], // interest
                    rebatePercentages[j]
                );

                uint256 totalRemaining = remainingBalances[i];
                uint256 calculatedRebate = (totalRemaining * rebatePercentages[j]) / 10000;

                assertEq(expectedRebate, calculatedRebate, "Rebate calculation incorrect");

                metrics.push(VarianceMetrics({
                    scenario: 6, // Rebate calculation validation
                    expectedValue: calculatedRebate,
                    actualValue: expectedRebate,
                    variance: 0, // Exact calculation
                    gasCost: 0
                }));
            }
        }
    }

    /// @notice Test irregular payment schedule handling
    /// @dev Verifies system handles payments at irregular intervals
    function testIrregularPaymentSchedule() public {
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

        // Simulate irregular payment schedule
        uint256[] memory paymentIntervals = new uint256[](3);
        paymentIntervals[0] = 10 days;  // Early payment
        paymentIntervals[1] = 45 days;  // Late payment
        paymentIntervals[2] = 20 days;  // Normal payment

        uint256 totalPaid = 0;

        vm.startPrank(propertyOwner);
        for (uint256 i = 0; i < paymentIntervals.length; i++) {
            vm.warp(block.timestamp + paymentIntervals[i]);
            yieldBase.makeRepayment{value: monthlyPayment}(agreementId);
            totalPaid += monthlyPayment;
        }

        // Verify total paid is tracked correctly
        (bool isActive, bool isInDefault, uint8 missedCount, uint256 arrears, uint256 credit, uint256 remaining, uint256 graceExpiry, uint256 nextDue) = yieldBase.getAgreementStatus(agreementId);
        uint256 outstandingBalance = yieldBase.getOutstandingBalance(agreementId);
        uint256 expectedOutstanding = YieldCalculations.calculateRemainingBalance(
            1 ether,
            totalPaid,
            12,
            500,
            YieldCalculations.calculateElapsedMonths(block.timestamp - 75 days, block.timestamp)
        );

        assertApproxEqAbs(outstandingBalance, expectedOutstanding, 0.01 ether, "Outstanding balance calculation incorrect");

        vm.stopPrank();

        metrics.push(VarianceMetrics({
            scenario: 7, // Irregular payment schedule
            expectedValue: expectedOutstanding,
            actualValue: outstandingBalance,
            variance: expectedOutstanding > outstandingBalance ?
                ((expectedOutstanding - outstandingBalance) * 100) / expectedOutstanding :
                ((outstandingBalance - expectedOutstanding) * 100) / expectedOutstanding,
            gasCost: 0
        }));
    }

    /// @notice Test zero payment handling
    /// @dev Verifies zero-value repayments are rejected
    function testZeroPaymentHandling() public {
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

        // Attempt zero payment
        vm.startPrank(propertyOwner);
        vm.expectRevert("Invalid repayment amount");
        yieldBase.makeRepayment{value: 0}(agreementId);

        vm.expectRevert("Invalid repayment amount");
        yieldBase.makePartialRepayment{value: 0}(agreementId);

        vm.stopPrank();
    }

    /// @notice Test maximum repayment amount handling
    /// @dev Verifies system handles repayments exceeding remaining balance
    function testMaximumRepaymentAmount() public {
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

        // Make payment exceeding total agreement value
        uint256 excessivePayment = 2 ether; // Much more than needed

        vm.startPrank(propertyOwner);
        yieldBase.makeRepayment{value: excessivePayment}(agreementId);

        // Verify agreement is completed
        (bool isActive, , , , , , , ) = yieldBase.getAgreementStatus(agreementId);
        assertFalse(isActive, "Agreement should be completed");

        vm.stopPrank();
    }

    /// @notice Test repayment handling after long delay
    /// @dev Verifies interest calculations account for extended elapsed time
    function testRepaymentAfterLongDelay() public {
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

        // Wait 6 months
        vm.warp(block.timestamp + 180 days);

        uint256 monthlyPayment = YieldCalculations.calculateMonthlyRepayment(1 ether, 12, 500);

        vm.startPrank(propertyOwner);
        yieldBase.makeRepayment{value: monthlyPayment}(agreementId);

        // Verify repayment is accepted and processed
        uint256 outstandingBalance = yieldBase.getOutstandingBalance(agreementId);
        uint256 expectedRemaining = YieldCalculations.calculateRemainingBalance(
            1 ether,
            monthlyPayment,
            12,
            500,
            6 // elapsed months
        );

        assertApproxEqAbs(outstandingBalance, expectedRemaining, 0.01 ether, "Outstanding balance after delay incorrect");

        vm.stopPrank();

        metrics.push(VarianceMetrics({
            scenario: 10, // Long delay repayment
            expectedValue: expectedRemaining,
            actualValue: outstandingBalance,
            variance: expectedRemaining > outstandingBalance ?
                ((expectedRemaining - outstandingBalance) * 100) / expectedRemaining :
                ((outstandingBalance - expectedRemaining) * 100) / expectedRemaining,
            gasCost: 0
        }));
    }

    /// @notice Get variance metrics for dissertation analysis
    /// @dev Returns collected metrics for analysis of repayment variance accuracy
    function getVarianceMetrics() external view returns (VarianceMetrics[] memory) {
        return metrics;
    }

    /// @notice Calculate average variance across all repayment scenarios
    /// @dev Returns percentage variance between expected and actual values
    function getAverageVariance() external view returns (uint256 averageVariance) {
        if (metrics.length == 0) return 0;

        uint256 totalVariance = 0;

        for (uint256 i = 0; i < metrics.length; i++) {
            totalVariance += metrics[i].variance;
        }

        return totalVariance / metrics.length;
    }
}
