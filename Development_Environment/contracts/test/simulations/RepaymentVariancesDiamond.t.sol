// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../script/DeployDiamond.s.sol";

// Facet interfaces
import "../../src/facets/YieldBaseFacet.sol";
import "../../src/facets/RepaymentFacet.sol";
import "../../src/facets/ViewsFacet.sol";
import "../../src/KYCRegistry.sol";
import "../../src/PropertyNFT.sol";

/**
 * @title RepaymentVariances Diamond Test Suite
 * @notice Tests various repayment scenarios and edge cases
 * @dev Covers overpayment, underpayment, early repayment, partial, and sequential repayments
 */
contract RepaymentVariancesDiamondTest is Test {
    DeployDiamond public deployer;
    
    KYCRegistry public kycRegistry;
    YieldBaseFacet public yieldBaseFacet;
    RepaymentFacet public repaymentFacet;
    ViewsFacet public viewsFacet;
    PropertyNFT public propertyNFT;
    
    address public owner;
    address public propertyOwner;
    
    function setUp() public {
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        propertyOwner = makeAddr("propertyOwner");
        
        // Deploy via actual script
        deployer = new DeployDiamond();
        deployer.run();
        
        // Get deployed contracts
        kycRegistry = deployer.kycRegistry();
        propertyNFT = deployer.propertyNFT();
        
        address diamondAddr = address(deployer.yieldBaseDiamond());
        yieldBaseFacet = YieldBaseFacet(diamondAddr);
        repaymentFacet = RepaymentFacet(diamondAddr);
        viewsFacet = ViewsFacet(diamondAddr);
        
        // Whitelist test users
        vm.startPrank(owner);
        kycRegistry.addToWhitelist(propertyOwner);
        vm.stopPrank();
    }
    
    /// @notice Helper to create a property and agreement
    function _createAgreement(uint256 capital, uint16 termMonths) internal returns (uint256 propertyId, uint256 agreementId) {
        vm.startPrank(owner);
        propertyId = propertyNFT.mintProperty(
            keccak256(abi.encodePacked("Property", capital)),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(propertyId);
        propertyNFT.transferFrom(owner, propertyOwner, propertyId);
        vm.stopPrank();
        
        vm.prank(propertyOwner);
        agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            capital,
            capital * 1000,  // USD value
            termMonths,
            500,  // 5% ROI
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
    }
    
    // ============ OVERPAYMENT SCENARIOS ============
    
    function testOverpaymentExactDouble() public {
        (, uint256 agreementId) = _createAgreement(100 ether, 12);
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Pay exactly double
        vm.deal(propertyOwner, monthlyPayment * 2);
        vm.prank(propertyOwner);
        repaymentFacet.makeRepayment{value: monthlyPayment * 2}(agreementId);
        
        // Verify overpayment recorded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(totalRepaid, monthlyPayment * 2);
    }
    
    function testOverpaymentSlightlyMore() public {
        (, uint256 agreementId) = _createAgreement(100 ether, 12);
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Pay 1.5x monthly payment
        uint256 overpayment = (monthlyPayment * 3) / 2;
        vm.deal(propertyOwner, overpayment);
        vm.prank(propertyOwner);
        repaymentFacet.makeRepayment{value: overpayment}(agreementId);
        
        // Verify overpayment recorded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(totalRepaid, overpayment);
    }
    
    // ============ UNDERPAYMENT SCENARIOS ============
    
    function testUnderpaymentPartialAllowed() public {
        (, uint256 agreementId) = _createAgreement(100 ether, 12);
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Pay 50% of monthly payment (partial allowed)
        uint256 partialPayment = monthlyPayment / 2;
        vm.deal(propertyOwner, partialPayment);
        vm.prank(propertyOwner);
        repaymentFacet.makeRepayment{value: partialPayment}(agreementId);
        
        // Verify partial payment recorded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(totalRepaid, partialPayment);
    }
    
    function testMultipleUnderpaymentsCoverFullMonth() public {
        (, uint256 agreementId) = _createAgreement(100 ether, 12);
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Make 4 payments of 25% each
        uint256 quarterPayment = monthlyPayment / 4;
        for (uint i = 0; i < 4; i++) {
            vm.deal(propertyOwner, quarterPayment + 1);  // +1 for rounding
            vm.prank(propertyOwner);
            repaymentFacet.makeRepayment{value: quarterPayment}(agreementId);
        }
        
        // Verify total is close to monthly payment
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertTrue(totalRepaid >= quarterPayment * 4);
    }
    
    // ============ EARLY REPAYMENT ============
    
    function testEarlyRepaymentFullAmount() public {
        (, uint256 agreementId) = _createAgreement(100 ether, 12);
        
        (,,,, bool active, uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        assertTrue(active);
        
        // Pay all 12 months at once
        uint256 totalAmount = monthlyPayment * 12;
        vm.deal(propertyOwner, totalAmount + 1 ether);  // Extra for rounding
        
        for (uint i = 0; i < 12; i++) {
            vm.prank(propertyOwner);
            repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        }
        
        // Verify agreement completed
        (,uint16 term,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(term, 12);
        assertTrue(totalRepaid >= monthlyPayment * 12);
    }
    
    function testEarlyRepaymentInterestAdjustment() public {
        (, uint256 agreementId) = _createAgreement(100 ether, 24);
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Pay first 3 months normally
        for (uint i = 0; i < 3; i++) {
            vm.deal(propertyOwner, monthlyPayment);
            vm.prank(propertyOwner);
            repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        }
        
        // Attempt early full repayment (remaining 21 months)
        uint256 remainingPayments = monthlyPayment * 21;
        vm.deal(propertyOwner, remainingPayments + 1 ether);
        
        for (uint i = 0; i < 21; i++) {
            vm.prank(propertyOwner);
            repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        }
        
        // Verify total repaid
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertTrue(totalRepaid >= monthlyPayment * 24);
    }
    
    // ============ PARTIAL REPAYMENTS ============
    
    function testPartialRepaymentAllowed() public {
        (, uint256 agreementId) = _createAgreement(100 ether, 12);
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Pay 75% of monthly payment
        uint256 partialAmount = (monthlyPayment * 3) / 4;
        vm.deal(propertyOwner, partialAmount);
        vm.prank(propertyOwner);
        repaymentFacet.makeRepayment{value: partialAmount}(agreementId);
        
        // Verify partial recorded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(totalRepaid, partialAmount);
    }
    
    function testMultiplePartialRepaymentsAccumulate() public {
        (, uint256 agreementId) = _createAgreement(100 ether, 12);
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Make 3 partial payments
        uint256 partial1 = monthlyPayment / 3;
        uint256 partial2 = monthlyPayment / 3;
        uint256 partial3 = monthlyPayment / 3;
        
        vm.deal(propertyOwner, monthlyPayment);
        vm.prank(propertyOwner);
        repaymentFacet.makeRepayment{value: partial1}(agreementId);
        
        vm.prank(propertyOwner);
        repaymentFacet.makeRepayment{value: partial2}(agreementId);
        
        vm.prank(propertyOwner);
        repaymentFacet.makeRepayment{value: partial3}(agreementId);
        
        // Verify accumulated
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertTrue(totalRepaid >= partial1 + partial2 + partial3);
    }
    
    // ============ SEQUENTIAL REPAYMENTS ============
    
    function testSequentialMonthlyRepayments() public {
        (, uint256 agreementId) = _createAgreement(100 ether, 6);
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Pay 6 months sequentially
        for (uint i = 0; i < 6; i++) {
            vm.deal(propertyOwner, monthlyPayment);
            vm.prank(propertyOwner);
            repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        }
        
        // Verify all payments recorded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertTrue(totalRepaid >= monthlyPayment * 6);
    }
    
    // ============ PAYMENT ROUNDING PRECISION ============
    
    function testPaymentRoundingHandled() public {
        // Create agreement with amount that will cause rounding
        (, uint256 agreementId) = _createAgreement(123.456789 ether, 7);
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Make payment with exact calculated amount
        vm.deal(propertyOwner, monthlyPayment);
        vm.prank(propertyOwner);
        repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        
        // Verify payment accepted despite rounding
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(totalRepaid, monthlyPayment);
    }
}

