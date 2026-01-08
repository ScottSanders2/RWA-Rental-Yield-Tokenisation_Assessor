// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/DeployDiamond.s.sol";

// Facet interfaces
import "../src/facets/YieldBaseFacet.sol";
import "../src/facets/RepaymentFacet.sol";
import "../src/facets/ViewsFacet.sol";
import "../src/KYCRegistry.sol";
import "../src/PropertyNFT.sol";

/**
 * @title AnalyticsAccuracy Diamond Test Suite
 * @notice Tests event emission accuracy and data consistency
 * @dev Validates analytics data for Graph Node integration
 */
contract AnalyticsAccuracyDiamondTest is Test {
    DeployDiamond public deployer;
    
    KYCRegistry public kycRegistry;
    YieldBaseFacet public yieldBaseFacet;
    RepaymentFacet public repaymentFacet;
    ViewsFacet public viewsFacet;
    PropertyNFT public propertyNFT;
    
    address public owner;
    address public user;
    
    // Events to verify
    event PropertyMinted(uint256 indexed tokenId, address indexed owner, bytes32 propertyAddressHash);
    event PropertyVerified(uint256 indexed tokenId);
    
    function setUp() public {
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        user = makeAddr("user");
        
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
        
        // Whitelist user
        vm.prank(owner);
        kycRegistry.addToWhitelist(user);
    }
    
    // ============ EVENT EMISSION ACCURACY ============
    
    function testPropertyMintedEventEmission() public {
        bytes32 propertyHash = keccak256("AnalyticsProperty");
        
        vm.expectEmit(true, true, false, true);
        emit PropertyMinted(1, owner, propertyHash);
        
        vm.prank(owner);
        propertyNFT.mintProperty(propertyHash, "ipfs://analytics");
    }
    
    function testPropertyVerifiedEventEmission() public {
        vm.prank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("VerifyTest"),
            "ipfs://verify"
        );
        
        vm.expectEmit(true, false, false, false);
        emit PropertyVerified(propertyId);
        
        vm.prank(owner);
        propertyNFT.verifyProperty(propertyId);
    }
    
    // ============ DATA CONSISTENCY VALIDATION ============
    
    function testAgreementDataConsistency() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("ConsistencyTest"),
            "ipfs://consistency"
        );
        propertyNFT.verifyProperty(propertyId);
        
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            owner,
            30,
            200,
            3,
            true,
            true
        );
        vm.stopPrank();
        
        // Verify data consistency
        (uint256 capital, uint16 term, uint16 roi,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether, "Capital mismatch");
        assertEq(term, 12, "Term mismatch");
        assertEq(roi, 500, "ROI mismatch");
    }
    
    // ============ GRAPH NODE INTEGRATION VALIDATION ============
    
    function testGraphNodeDataFormat() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("GraphTest"),
            "ipfs://graph"
        );
        propertyNFT.verifyProperty(propertyId);
        
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            200 ether,
            200000 ether,
            18,
            400,
            owner,
            30,
            200,
            3,
            true,
            true
        );
        vm.stopPrank();
        
        // Verify agreement exists (Graph Node would index this)
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertTrue(capital > 0, "Agreement should exist for Graph Node");
    }
    
    // ============ QUERY RESULT ACCURACY ============
    
    function testQueryResultAccuracy() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("QueryTest"),
            "ipfs://query"
        );
        propertyNFT.verifyProperty(propertyId);
        
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            150 ether,
            150000 ether,
            24,
            600,
            owner,
            30,
            200,
            3,
            true,
            true
        );
        vm.stopPrank();
        
        // Query and verify accuracy
        (
            uint256 capital,
            uint16 term,
            uint16 roi,
            uint256 totalRepaid,
            bool active,
            uint256 monthlyPayment
        ) = viewsFacet.getYieldAgreement(agreementId);
        
        assertEq(capital, 150 ether);
        assertEq(term, 24);
        assertEq(roi, 600);
        assertEq(totalRepaid, 0);
        assertTrue(active);
        assertTrue(monthlyPayment > 0);
    }
    
    // ============ REPAYMENT EVENT ACCURACY ============
    
    function testRepaymentEventAccuracy() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("RepaymentEvent"),
            "ipfs://repayment"
        );
        propertyNFT.verifyProperty(propertyId);
        
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            owner,
            30,
            200,
            3,
            true,
            true
        );
        vm.stopPrank();
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Make repayment and verify
        vm.deal(owner, monthlyPayment);
        vm.prank(owner);
        repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        
        // Verify repayment recorded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(totalRepaid, monthlyPayment, "Repayment not recorded accurately");
    }
}

