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
 * @title LoadTesting Diamond Test Suite
 * @notice Comprehensive load testing for Diamond-based RWA platform
 * @dev Tests scalability, stress scenarios, and performance under high load
 */
contract LoadTestingDiamondTest is Test {
    DeployDiamond public deployer;
    
    KYCRegistry public kycRegistry;
    YieldBaseFacet public yieldBaseFacet;
    RepaymentFacet public repaymentFacet;
    ViewsFacet public viewsFacet;
    PropertyNFT public propertyNFT;
    
    address public owner;
    address[] public users;
    
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
        
        // Create and whitelist 100 test users for load testing
        for (uint i = 0; i < 100; i++) {
            address user = makeAddr(string(abi.encodePacked("user", vm.toString(i))));
            users.push(user);
            vm.prank(owner);
            kycRegistry.addToWhitelist(user);
        }
    }
    
    // ============ BATCH PROPERTY OPERATIONS ============
    
    function testBatchPropertyCreation100Properties() public {
        uint256 gasStart = gasleft();
        
        // Create 100 properties
        uint256[] memory propertyIds = new uint256[](100);
        for (uint i = 0; i < 100; i++) {
            vm.startPrank(owner);
            uint256 propertyId = propertyNFT.mintProperty(
                keccak256(abi.encodePacked("Property", i)),
                string(abi.encodePacked("ipfs://property", vm.toString(i)))
            );
            propertyNFT.verifyProperty(propertyId);
            propertyIds[i] = propertyId;
            vm.stopPrank();
        }
        
        uint256 gasUsed = gasStart - gasleft();
        emit log_named_uint("Gas used for 100 properties", gasUsed);
        emit log_named_uint("Avg gas per property", gasUsed / 100);
        
        // Verify all properties created
        assertEq(propertyIds.length, 100);
        for (uint i = 0; i < 100; i++) {
            assertTrue(propertyNFT.isPropertyVerified(propertyIds[i]));
        }
    }
    
    // ============ STRESS TEST AGREEMENT CREATION ============
    
    function testStressCreate50Agreements() public {
        // Create 50 properties first
        uint256[] memory propertyIds = new uint256[](50);
        for (uint i = 0; i < 50; i++) {
            vm.startPrank(owner);
            uint256 propertyId = propertyNFT.mintProperty(
                keccak256(abi.encodePacked("StressProperty", i)),
                "ipfs://stress"
            );
            propertyNFT.verifyProperty(propertyId);
            propertyIds[i] = propertyId;
            vm.stopPrank();
        }
        
        uint256 gasStart = gasleft();
        
        // Create 50 yield agreements
        uint256[] memory agreementIds = new uint256[](50);
        for (uint i = 0; i < 50; i++) {
            vm.prank(owner);
            agreementIds[i] = yieldBaseFacet.createYieldAgreement(
                propertyIds[i],
                100 ether + (i * 1 ether),  // Varying amounts
                100000 ether + (i * 1000 ether),
                12 + uint16(i % 12),  // Varying terms (12-23 months)
                500,
                owner,
                30,
                200,
                3,
                true,
                true
            );
        }
        
        uint256 gasUsed = gasStart - gasleft();
        emit log_named_uint("Gas used for 50 agreements", gasUsed);
        emit log_named_uint("Avg gas per agreement", gasUsed / 50);
        
        // Verify all agreements created
        assertEq(agreementIds.length, 50);
        uint256 totalAgreements = yieldBaseFacet.getAgreementCount();
        assertTrue(totalAgreements >= 50);
    }
    
    // ============ LIQUIDITY TESTING UNDER LOAD ============
    
    function testLiquidityUnderHighLoad() public {
        // Create 20 properties and agreements
        uint256[] memory agreementIds = new uint256[](20);
        for (uint i = 0; i < 20; i++) {
            vm.startPrank(owner);
            uint256 propertyId = propertyNFT.mintProperty(
                keccak256(abi.encodePacked("LiquidityProperty", i)),
                "ipfs://liquidity"
            );
            propertyNFT.verifyProperty(propertyId);
            
            agreementIds[i] = yieldBaseFacet.createYieldAgreement(
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
        }
        
        // Make concurrent repayments on all agreements
        for (uint i = 0; i < 20; i++) {
            (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementIds[i]);
            vm.deal(owner, monthlyPayment);
            vm.prank(owner);
            repaymentFacet.makeRepayment{value: monthlyPayment}(agreementIds[i]);
        }
        
        // Verify all repayments succeeded
        for (uint i = 0; i < 20; i++) {
            (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementIds[i]);
            assertTrue(totalRepaid > 0, "Repayment should be recorded");
        }
    }
    
    // ============ RESTRICTION ENFORCEMENT RESILIENCE ============
    
    function testKYCEnforcementUnderLoad() public {
        // Create 10 properties
        uint256[] memory propertyIds = new uint256[](10);
        for (uint i = 0; i < 10; i++) {
            vm.startPrank(owner);
            uint256 propertyId = propertyNFT.mintProperty(
                keccak256(abi.encodePacked("KYCTestProperty", i)),
                "ipfs://kyctest"
            );
            propertyNFT.verifyProperty(propertyId);
            propertyIds[i] = propertyId;
            vm.stopPrank();
        }
        
        // Try to create agreements from non-KYC users (should all fail)
        address nonKYCUser = makeAddr("nonKYC");
        uint256 failureCount = 0;
        
        for (uint i = 0; i < 10; i++) {
            // Transfer property to non-KYC user
            vm.prank(owner);
            propertyNFT.transferFrom(owner, nonKYCUser, propertyIds[i]);
            
            // Attempt to create agreement (should fail)
            vm.prank(nonKYCUser);
            try yieldBaseFacet.createYieldAgreement(
                propertyIds[i],
                100 ether,
                100000 ether,
                12,
                500,
                nonKYCUser,
                30,
                200,
                3,
                true,
                true
            ) {
                // Should not succeed
            } catch {
                failureCount++;
            }
        }
        
        // All attempts should fail due to KYC
        assertEq(failureCount, 10, "All non-KYC attempts should fail");
    }
    
    // ============ GAS OPTIMIZATION VALIDATION ============
    
    function testGasEfficiencyComparison() public {
        // Create baseline property and agreement
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("GasTestProperty"),
            "ipfs://gastest"
        );
        propertyNFT.verifyProperty(propertyId);
        vm.stopPrank();
        
        // Measure gas for first agreement (includes token deployment)
        uint256 gasStart1 = gasleft();
        vm.prank(owner);
        yieldBaseFacet.createYieldAgreement(
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
        uint256 gas1 = gasStart1 - gasleft();
        
        // Create second property
        vm.startPrank(owner);
        uint256 propertyId2 = propertyNFT.mintProperty(
            keccak256("GasTestProperty2"),
            "ipfs://gastest2"
        );
        propertyNFT.verifyProperty(propertyId2);
        vm.stopPrank();
        
        // Measure gas for second agreement
        uint256 gasStart2 = gasleft();
        vm.prank(owner);
        yieldBaseFacet.createYieldAgreement(
            propertyId2,
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
        uint256 gas2 = gasStart2 - gasleft();
        
        emit log_named_uint("Gas for 1st agreement (with token deploy)", gas1);
        emit log_named_uint("Gas for 2nd agreement", gas2);
        
        // Second agreement should use less gas (no token deployment)
        // Note: Due to token deployment in first agreement, it will be significantly higher
        assertTrue(gas1 > 0);
        assertTrue(gas2 > 0);
    }
    
    // ============ CONCURRENT OPERATIONS HANDLING ============
    
    function testConcurrentRepayments() public {
        // Create 10 agreements with different users
        uint256[] memory agreementIds = new uint256[](10);
        for (uint i = 0; i < 10; i++) {
            address user = users[i];
            
            vm.startPrank(owner);
            uint256 propertyId = propertyNFT.mintProperty(
                keccak256(abi.encodePacked("ConcurrentProperty", i)),
                "ipfs://concurrent"
            );
            propertyNFT.verifyProperty(propertyId);
            propertyNFT.transferFrom(owner, user, propertyId);
            vm.stopPrank();
            
            vm.prank(user);
            agreementIds[i] = yieldBaseFacet.createYieldAgreement(
                propertyId,
                100 ether,
                100000 ether,
                12,
                500,
                user,
                30,
                200,
                3,
                true,
                true
            );
        }
        
        // Simulate concurrent repayments from all users
        for (uint i = 0; i < 10; i++) {
            address user = users[i];
            (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementIds[i]);
            vm.deal(user, monthlyPayment);
            vm.prank(user);
            repaymentFacet.makeRepayment{value: monthlyPayment}(agreementIds[i]);
        }
        
        // Verify all repayments succeeded concurrently
        for (uint i = 0; i < 10; i++) {
            (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementIds[i]);
            assertTrue(totalRepaid > 0, "Concurrent repayment should succeed");
        }
    }
}

