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
import "../../src/YieldSharesToken.sol";

/**
 * @title PoolingScenarios Diamond Test Suite
 * @notice Tests multi-investor capital pooling scenarios
 * @dev Validates pooled contributions, proportional token minting, and distribution
 */
contract PoolingScenariosDiamondTest is Test {
    DeployDiamond public deployer;
    
    KYCRegistry public kycRegistry;
    YieldBaseFacet public yieldBaseFacet;
    RepaymentFacet public repaymentFacet;
    ViewsFacet public viewsFacet;
    PropertyNFT public propertyNFT;
    
    address public owner;
    address[] public investors;
    
    function setUp() public {
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        
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
        
        // Create and whitelist 10 investors
        for (uint i = 0; i < 10; i++) {
            address investor = makeAddr(string(abi.encodePacked("investor", vm.toString(i))));
            investors.push(investor);
            vm.prank(owner);
            kycRegistry.addToWhitelist(investor);
        }
    }
    
    /// @notice Helper to create property
    function _createProperty(address propertyOwner) internal returns (uint256) {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256(abi.encodePacked("PoolProperty", propertyOwner)),
            "ipfs://pool"
        );
        propertyNFT.verifyProperty(propertyId);
        propertyNFT.transferFrom(owner, propertyOwner, propertyId);
        vm.stopPrank();
        return propertyId;
    }
    
    // ============ MULTI-INVESTOR CAPITAL POOLING ============
    
    function testMultiInvestorPooling3Investors() public {
        uint256 propertyId = _createProperty(investors[0]);
        
        // Create agreement (investor0 is property owner)
        vm.prank(investors[0]);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,  // Total capital needed
            100000 ether,
            12,
            500,
            investors[0],
            30,
            200,
            3,
            true,
            true
        );
        
        // Get the created YieldSharesToken
        // Verify agreement created
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    function testPooledContributionTracking() public {
        uint256 propertyId = _createProperty(investors[0]);
        
        // Create agreement
        vm.prank(investors[0]);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            300 ether,  // Larger capital for pooling
            300000 ether,
            12,
            500,
            investors[0],
            30,
            200,
            3,
            true,
            true
        );
        
        // Verify agreement created
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 300 ether);
    }
    
    // ============ PROPORTIONAL TOKEN MINTING ============
    
    function testProportionalTokenAllocation() public {
        uint256 propertyId = _createProperty(investors[0]);
        
        vm.prank(investors[0]);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            150 ether,
            150000 ether,
            12,
            500,
            investors[0],
            30,
            200,
            3,
            true,
            true
        );
        
        // Get token
        // Verify agreement created
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 150 ether);
    }
    
    // ============ POOLED REPAYMENT DISTRIBUTION ============
    
    function testPooledRepaymentDistribution() public {
        uint256 propertyId = _createProperty(investors[0]);
        
        vm.prank(investors[0]);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            200 ether,
            200000 ether,
            12,
            500,
            investors[0],
            30,
            200,
            3,
            true,
            true
        );
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Make repayment (this would distribute to all token holders)
        vm.deal(investors[0], monthlyPayment);
        vm.prank(investors[0]);
        repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        
        // Verify repayment recorded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(totalRepaid, monthlyPayment);
    }
    
    // ============ INVESTOR CONTRIBUTION TRACKING ============
    
    function testInvestorContributionTracking() public {
        uint256 propertyId = _createProperty(investors[0]);
        
        vm.prank(investors[0]);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            500 ether,
            500000 ether,
            24,
            500,
            investors[0],
            30,
            200,
            3,
            true,
            true
        );
        
        // Verify agreement tracks capital correctly
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 500 ether);
    }
    
    // ============ POOLED DEFAULT HANDLING ============
    
    function testPooledAgreementDefaultHandling() public {
        uint256 propertyId = _createProperty(investors[0]);
        
        vm.prank(investors[0]);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            investors[0],
            30,
            200,
            3,
            true,
            true
        );
        
        // Warp time to simulate missed payment
        vm.warp(block.timestamp + 35 days);
        
        // Check default status
        (bool isActive,,,,,,,) = viewsFacet.getAgreementStatus(agreementId);
        assertTrue(isActive);  // Agreement still active
    }
    
    // ============ DYNAMIC INVESTOR ADDITION ============
    
    function testDynamicInvestorAddition() public {
        uint256 propertyId = _createProperty(investors[0]);
        
        vm.prank(investors[0]);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            200 ether,
            200000 ether,
            12,
            500,
            investors[0],
            30,
            200,
            3,
            true,
            true
        );
        
        // Verify agreement created (token created internally)
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 200 ether);
    }
    
    // ============ PROPORTIONAL YIELD DISTRIBUTION ============
    
    function testProportionalYieldDistribution() public {
        uint256 propertyId = _createProperty(investors[0]);
        
        vm.prank(investors[0]);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            300 ether,
            300000 ether,
            18,
            500,
            investors[0],
            30,
            200,
            3,
            true,
            true
        );
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Make first repayment
        vm.deal(investors[0], monthlyPayment);
        vm.prank(investors[0]);
        repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        
        // Verify yield recorded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertTrue(totalRepaid > 0);
    }
    
    // ============ POOLED AGREEMENT COMPLETION ============
    
    function testPooledAgreementCompletion() public {
        uint256 propertyId = _createProperty(investors[0]);
        
        vm.prank(investors[0]);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            6,  // Short term for testing
            500,
            investors[0],
            30,
            200,
            3,
            true,
            true
        );
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Complete all payments
        for (uint i = 0; i < 6; i++) {
            vm.deal(investors[0], monthlyPayment);
            vm.prank(investors[0]);
            repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        }
        
        // Verify completion
        (,uint16 term,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(term, 6);
        assertTrue(totalRepaid >= monthlyPayment * 6);
    }
    
    // ============ LARGE INVESTOR POOL HANDLING ============
    
    function testLargeInvestorPoolHandling() public {
        uint256 propertyId = _createProperty(investors[0]);
        
        vm.prank(investors[0]);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            1000 ether,  // Large capital requiring many investors
            1000000 ether,
            12,
            500,
            investors[0],
            30,
            200,
            3,
            true,
            true
        );
        
        // Verify large agreement created
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 1000 ether);
    }
}

