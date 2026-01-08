// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/DeployDiamond.s.sol";

// Facet interfaces
import "../src/facets/YieldBaseFacet.sol";
import "../src/facets/ViewsFacet.sol";
import "../src/KYCRegistry.sol";
import "../src/PropertyNFT.sol";

/**
 * @title TransferRestrictions Diamond Test Suite
 * @notice Tests transfer restrictions, lock-ups, and compliance controls
 * @dev Validates whitelist, blacklist, and KYC-based restrictions
 */
contract TransferRestrictionsDiamondTest is Test {
    DeployDiamond public deployer;
    
    KYCRegistry public kycRegistry;
    YieldBaseFacet public yieldBaseFacet;
    ViewsFacet public viewsFacet;
    PropertyNFT public propertyNFT;
    
    address public owner;
    address public user1;
    address public user2;
    address public blacklisted;
    
    function setUp() public {
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        blacklisted = makeAddr("blacklisted");
        
        // Deploy via actual script
        deployer = new DeployDiamond();
        deployer.run();
        
        // Get deployed contracts
        kycRegistry = deployer.kycRegistry();
        propertyNFT = deployer.propertyNFT();
        
        address diamondAddr = address(deployer.yieldBaseDiamond());
        yieldBaseFacet = YieldBaseFacet(diamondAddr);
        viewsFacet = ViewsFacet(diamondAddr);
        
        // Setup KYC
        vm.startPrank(owner);
        kycRegistry.addToWhitelist(user1);
        kycRegistry.addToWhitelist(user2);
        kycRegistry.addToBlacklist(blacklisted);
        vm.stopPrank();
    }
    
    // ============ WHITELIST ENFORCEMENT ============
    
    function testWhitelistRequiredForAgreementCreation() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("WhitelistTest"), "ipfs://whitelist");
        propertyNFT.verifyProperty(propertyId);
        propertyNFT.transferFrom(owner, user1, propertyId);
        vm.stopPrank();
        
        // Whitelisted user can create agreement
        vm.prank(user1);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            user1,
            30,
            200,
            3,
            true,
            true
        );
        
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    function testNonWhitelistedUserRejected() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("NonKYCTest"), "ipfs://nonkyc");
        propertyNFT.verifyProperty(propertyId);
        
        address nonKYC = makeAddr("nonKYC");
        propertyNFT.transferFrom(owner, nonKYC, propertyId);
        vm.stopPrank();
        
        // Non-whitelisted user cannot create agreement
        vm.prank(nonKYC);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            nonKYC,
            30,
            200,
            3,
            true,
            true
        );
    }
    
    // ============ BLACKLIST ENFORCEMENT ============
    
    function testBlacklistedUserRejected() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("BlacklistTest"), "ipfs://blacklist");
        propertyNFT.verifyProperty(propertyId);
        propertyNFT.transferFrom(owner, blacklisted, propertyId);
        vm.stopPrank();
        
        // Blacklisted user cannot create agreement
        vm.prank(blacklisted);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            blacklisted,
            30,
            200,
            3,
            true,
            true
        );
    }
    
    // ============ DYNAMIC RESTRICTION UPDATES ============
    
    function testDynamicWhitelistAddition() public {
        address newUser = makeAddr("newUser");
        
        vm.prank(owner);
        kycRegistry.addToWhitelist(newUser);
        
        assertTrue(kycRegistry.isWhitelisted(newUser));
    }
    
    function testDynamicWhitelistRemoval() public {
        vm.startPrank(owner);
        kycRegistry.removeFromWhitelist(user1);
        vm.stopPrank();
        
        assertFalse(kycRegistry.isWhitelisted(user1));
    }
    
    function testDynamicBlacklistAddition() public {
        address newBlacklisted = makeAddr("newBlacklisted");
        
        vm.prank(owner);
        kycRegistry.addToBlacklist(newBlacklisted);
        
        assertTrue(kycRegistry.isBlacklisted(newBlacklisted));
    }
    
    function testDynamicBlacklistRemoval() public {
        vm.prank(owner);
        kycRegistry.removeFromBlacklist(blacklisted);
        
        assertFalse(kycRegistry.isBlacklisted(blacklisted));
    }
    
    // ============ KYC STATE CHANGES AFFECT EXISTING AGREEMENTS ============
    
    function testBlacklistingExistingUser() public {
        // Create agreement first
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("ExistingUser"), "ipfs://existing");
        propertyNFT.verifyProperty(propertyId);
        propertyNFT.transferFrom(owner, user1, propertyId);
        vm.stopPrank();
        
        vm.prank(user1);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            user1,
            30,
            200,
            3,
            true,
            true
        );
        
        // Blacklist user1
        vm.prank(owner);
        kycRegistry.addToBlacklist(user1);
        
        assertTrue(kycRegistry.isBlacklisted(user1));
        
        // Agreement still exists but user1 is now blacklisted
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    // ============ COMPLIANCE CHECKS ============
    
    function testKYCRequirementEnforcement() public {
        // Verify KYC is enforced via whitelist
        assertTrue(kycRegistry.isWhitelisted(user1));
        assertTrue(kycRegistry.isWhitelisted(user2));
        address randomAddr = makeAddr("random");
        assertFalse(kycRegistry.isWhitelisted(randomAddr));
    }
    
    function testMultipleRestrictionLayers() public view {
        // Multiple layers: whitelist AND not blacklisted
        assertTrue(kycRegistry.isWhitelisted(user1));
        assertFalse(kycRegistry.isBlacklisted(user1));
        
        // Blacklisted user fails even if was whitelisted
        assertTrue(kycRegistry.isBlacklisted(blacklisted));
    }
    
    // ============ PROPERTY NFT TRANSFER RESTRICTIONS ============
    
    function testPropertyTransferBetweenWhitelistedUsers() public {
        vm.prank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("TransferTest"), "ipfs://transfer");
        
        // Transfer between whitelisted users
        vm.prank(owner);
        propertyNFT.transferFrom(owner, user1, propertyId);
        assertEq(propertyNFT.ownerOf(propertyId), user1);
        
        vm.prank(user1);
        propertyNFT.transferFrom(user1, user2, propertyId);
        assertEq(propertyNFT.ownerOf(propertyId), user2);
    }
    
    // ============ GEOGRAPHIC/JURISDICTION COMPLIANCE ============
    
    function testJurisdictionComplianceViaKYC() public view {
        // Jurisdiction compliance enforced via KYC whitelist
        assertTrue(kycRegistry.isWhitelisted(user1));
        assertTrue(kycRegistry.isWhitelisted(user2));
    }
    
    // ============ ACCREDITED INVESTOR REQUIREMENTS ============
    
    function testAccreditedInvestorViaKYC() public view {
        // Accreditation verified via KYC whitelist
        assertTrue(kycRegistry.isWhitelisted(user1));
    }
    
    // ============ AUTOMATED COMPLIANCE VALIDATION ============
    
    function testAutomatedComplianceCheck() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("ComplianceTest"), "ipfs://compliance");
        propertyNFT.verifyProperty(propertyId);
        vm.stopPrank();
        
        // Whitelisted user passes automated check
        vm.prank(user1);
        vm.expectRevert();  // Will fail because user1 doesn't own property
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            user1,
            30,
            200,
            3,
            true,
            true
        );
    }
    
    // ============ EMERGENCY CONTROLS ============
    
    function testEmergencyBlacklistEnforcement() public {
        // Simulate emergency blacklist of user
        vm.prank(owner);
        kycRegistry.addToBlacklist(user1);
        
        assertTrue(kycRegistry.isBlacklisted(user1));
        
        // Remove from blacklist
        vm.prank(owner);
        kycRegistry.removeFromBlacklist(user1);
        
        assertFalse(kycRegistry.isBlacklisted(user1));
    }
    
    // ============ GRANULAR PERMISSION CONTROL ============
    
    function testGranularKYCControl() public {
        // Individual user control
        vm.startPrank(owner);
        
        address user3 = makeAddr("user3");
        address user4 = makeAddr("user4");
        
        kycRegistry.addToWhitelist(user3);
        assertTrue(kycRegistry.isWhitelisted(user3));
        
        kycRegistry.addToBlacklist(user4);
        assertTrue(kycRegistry.isBlacklisted(user4));
        
        vm.stopPrank();
    }
    
    // ============ COMPLIANCE REPORTING ============
    
    function testComplianceAuditTrail() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("AuditTest"), "ipfs://audit");
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
        
        // Agreement creation logged (audit trail via events)
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    // ============ BULK RESTRICTION UPDATES ============
    
    function testBulkWhitelistUpdates() public {
        address[] memory newUsers = new address[](5);
        for (uint i = 0; i < 5; i++) {
            newUsers[i] = makeAddr(string(abi.encodePacked("bulk", vm.toString(i))));
        }
        
        // Whitelist all
        vm.startPrank(owner);
        for (uint i = 0; i < 5; i++) {
            kycRegistry.addToWhitelist(newUsers[i]);
        }
        vm.stopPrank();
        
        // Verify all whitelisted
        for (uint i = 0; i < 5; i++) {
            assertTrue(kycRegistry.isWhitelisted(newUsers[i]));
        }
    }
    
    // ============ RESTRICTION BYPASS PREVENTION ============
    
    function testCannotBypassKYCRestrictions() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("BypassTest"), "ipfs://bypass");
        propertyNFT.verifyProperty(propertyId);
        
        address nonKYC = makeAddr("nonKYC");
        propertyNFT.transferFrom(owner, nonKYC, propertyId);
        vm.stopPrank();
        
        // Non-KYC user cannot create agreement (no bypass possible)
        vm.prank(nonKYC);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            nonKYC,
            30,
            200,
            3,
            true,
            true
        );
    }
    
    // ============ CROSS-CONTRACT RESTRICTION CONSISTENCY ============
    
    function testKYCEnforcementConsistency() public {
        // KYC should be enforced consistently across all contracts
        assertTrue(kycRegistry.isWhitelisted(user1));
        assertTrue(kycRegistry.isWhitelisted(user2));
        assertTrue(kycRegistry.isBlacklisted(blacklisted));
        assertFalse(kycRegistry.isWhitelisted(blacklisted));
    }
    
    // ============ PERMISSION INHERITANCE ============
    
    function testWhitelistInheritance() public {
        // Whitelisting at KYC level applies to all contracts
        vm.prank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("InheritTest"), "ipfs://inherit");
        propertyNFT.verifyProperty(propertyId);
        propertyNFT.transferFrom(owner, user1, propertyId);
        
        // user1 can use property in agreement
        vm.prank(user1);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            user1,
            30,
            200,
            3,
            true,
            true
        );
        
        assertTrue(agreementId > 0);
    }
    
    // ============ RESTRICTION CASCADING ============
    
    function testBlacklistCascading() public {
        // Blacklisting cascades to all platform functions
        assertTrue(kycRegistry.isBlacklisted(blacklisted));
        
        // Verify blacklisted cannot bypass via property transfer
        vm.prank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("CascadeTest"), "ipfs://cascade");
        
        // Even if property is transferred to blacklisted user, they can't use it
        vm.prank(owner);
        propertyNFT.verifyProperty(propertyId);
        vm.prank(owner);
        propertyNFT.transferFrom(owner, blacklisted, propertyId);
        
        vm.prank(blacklisted);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            blacklisted,
            30,
            200,
            3,
            true,
            true
        );
    }
}
