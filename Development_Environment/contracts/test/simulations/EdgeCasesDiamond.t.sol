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
 * @title EdgeCases Diamond Test Suite
 * @notice Tests boundary conditions, extreme values, and edge cases
 * @dev Validates contract behavior at limits and unusual scenarios
 */
contract EdgeCasesDiamondTest is Test {
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
    
    /// @notice Helper to create property
    function _createProperty() internal returns (uint256) {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256(abi.encodePacked("TestProperty", block.timestamp)),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(propertyId);
        propertyNFT.transferFrom(owner, propertyOwner, propertyId);
        vm.stopPrank();
        return propertyId;
    }
    
    // ============ BOUNDARY CONDITIONS - MIN/MAX VALUES ============
    
    function testMinimumTermBoundary() public {
        uint256 propertyId = _createProperty();
        
        // Test minimum term (1 month)
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            1,  // Minimum term
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        (,uint16 term,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(term, 1);
    }
    
    function testMaximumTermBoundary() public {
        uint256 propertyId = _createProperty();
        
        // Test maximum term (360 months = 30 years)
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            360,  // Maximum term
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        (,uint16 term,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(term, 360);
    }
    
    // ============ ZERO AMOUNTS VALIDATION ============
    
    function testZeroCapitalRejected() public {
        uint256 propertyId = _createProperty();
        
        // Attempt to create agreement with zero capital
        vm.prank(propertyOwner);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            0,  // Zero capital
            100000 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
    }
    
    function testZeroRepaymentRejected() public {
        uint256 propertyId = _createProperty();
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        // Attempt zero repayment
        vm.prank(propertyOwner);
        vm.expectRevert();
        repaymentFacet.makeRepayment{value: 0}(agreementId);
    }
    
    // ============ MAXIMUM uint256 VALUES ============
    
    function testVeryLargeCapitalAmount() public {
        uint256 propertyId = _createProperty();
        
        // Test with very large (but reasonable) capital
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            1_000_000 ether,  // 1 million ETH
            1_000_000_000_000 ether,  // 1 trillion USD
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 1_000_000 ether);
    }
    
    // ============ STATE TRANSITION EDGE CASES ============
    
    function testAgreementIDOverflowPrevention() public {
        // Create multiple agreements to test ID increment
        uint256[] memory ids = new uint256[](10);
        
        for (uint i = 0; i < 10; i++) {
            uint256 propertyId = _createProperty();
            
            vm.prank(propertyOwner);
            ids[i] = yieldBaseFacet.createYieldAgreement(
                propertyId,
                100 ether,
                100000 ether,
                12,
                500,
                propertyOwner,
                30,
                200,
                3,
                true,
                true
            );
        }
        
        // Verify IDs increment properly
        for (uint i = 1; i < 10; i++) {
            assertTrue(ids[i] > ids[i-1]);
        }
    }
    
    function testPropertyIDEdgeCases() public {
        // Create multiple properties to test ID handling
        uint256[] memory propertyIds = new uint256[](5);
        
        for (uint i = 0; i < 5; i++) {
            vm.startPrank(owner);
            propertyIds[i] = propertyNFT.mintProperty(
                keccak256(abi.encodePacked("EdgeProperty", i)),
                string(abi.encodePacked("ipfs://edge", vm.toString(i)))
            );
            propertyNFT.verifyProperty(propertyIds[i]);
            vm.stopPrank();
        }
        
        // Verify sequential IDs
        for (uint i = 1; i < 5; i++) {
            assertEq(propertyIds[i], propertyIds[i-1] + 1);
        }
    }
    
    // ============ ROI BOUNDARY TESTING ============
    
    function testMinimumROIBoundary() public {
        uint256 propertyId = _createProperty();
        
        // Test minimum ROI (1 basis point = 0.01%)
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            1,  // 0.01% ROI (minimum)
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        (,,uint16 roi,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(roi, 1);
    }
    
    function testMaximumROIBoundary() public {
        uint256 propertyId = _createProperty();
        
        // Test maximum ROI (5000 basis points = 50%)
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            5000,  // 50% ROI (maximum)
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        (,,uint16 roi,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(roi, 5000);
    }
    
    // ============ GRACE PERIOD EDGE CASES ============
    
    function testZeroGracePeriod() public {
        uint256 propertyId = _createProperty();
        
        // Create agreement with no grace period
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            propertyOwner,
            0,  // No grace period
            200,
            3,
            true,
            true
        );
        
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    function testMaximumGracePeriod() public {
        uint256 propertyId = _createProperty();
        
        // Create agreement with very long grace period
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            propertyOwner,
            365,  // 1 year grace period
            200,
            3,
            true,
            true
        );
        
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    // ============ CAPITAL BOUNDARY TESTING ============
    
    function testMinimumCapitalAmount() public {
        uint256 propertyId = _createProperty();
        
        // Test with 1 wei capital
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            1,  // 1 wei
            1000,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 1);
    }
    
    // ============ TIMESTAMP MANIPULATION RESISTANCE ============
    
    function testTimestampHandlingEdgeCases() public {
        uint256 propertyId = _createProperty();
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        // Warp to far future
        vm.warp(block.timestamp + 365 days * 10);  // 10 years
        
        // Verify agreement still queryable
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
}

