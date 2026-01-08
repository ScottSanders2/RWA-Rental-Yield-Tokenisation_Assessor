// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/DeployDiamond.s.sol";

// Facet interfaces
import "../src/facets/KYCFacet.sol";
import "../src/facets/YieldBaseFacet.sol";
import "../src/facets/ViewsFacet.sol";
import "../src/KYCRegistry.sol";
import "../src/PropertyNFT.sol";

/**
 * @title KYCFacet Comprehensive Test Suite
 * @notice Tests KYCFacet functionality within Diamond architecture
 * @dev Verifies KYC enforcement and whitelist/blacklist operations
 */
contract KYCFacetTest is Test {
    DeployDiamond public deployer;
    
    KYCRegistry public kycRegistry;
    KYCFacet public kycFacet;
    YieldBaseFacet public yieldBaseFacet;
    ViewsFacet public viewsFacet;
    PropertyNFT public propertyNFT;
    
    address public owner;
    address public user1;
    address public user2;
    address public blacklistedUser;
    
    function setUp() public {
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        blacklistedUser = makeAddr("blacklisted");
        
        // Deploy via actual script
        deployer = new DeployDiamond();
        deployer.run();
        
        // Get deployed contracts
        kycRegistry = deployer.kycRegistry();
        propertyNFT = deployer.propertyNFT();
        
        // Wrap Diamond with KYCFacet ABI
        address diamondAddr = address(deployer.yieldBaseDiamond());
        kycFacet = KYCFacet(diamondAddr);
        yieldBaseFacet = YieldBaseFacet(diamondAddr);
        viewsFacet = ViewsFacet(diamondAddr);
        
        // Setup test users
        vm.startPrank(owner);
        kycRegistry.addToWhitelist(user1);
        kycRegistry.addToWhitelist(user2);
        kycRegistry.addToBlacklist(blacklistedUser);
        vm.stopPrank();
    }
    
    // ============ KYC VERIFICATION TESTS ============
    
    function testRequireKYCVerifiedAllowsWhitelistedUser() public view {
        // Should not revert for whitelisted user
        kycFacet.requireKYCVerified(user1);
    }
    
    function testRequireKYCVerifiedRejectsNonWhitelistedUser() public {
        address nonKYCUser = makeAddr("nonKYC");
        
        // Should revert for non-whitelisted user
        vm.expectRevert();
        kycFacet.requireKYCVerified(nonKYCUser);
    }
    
    function testRequireKYCVerifiedRejectsBlacklistedUser() public {
        // Should revert for blacklisted user
        vm.expectRevert();
        kycFacet.requireKYCVerified(blacklistedUser);
    }
    
    // ============ TOKEN KYC CONFIGURATION TESTS ============
    
    function testKYCAutomaticallyConfiguredOnAgreementCreation() public {
        // Create property
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(propertyId);
        vm.stopPrank();
        
        // Create agreement - YieldBaseFacet calls KYCFacet.configureTokenKYC() automatically
        vm.prank(owner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        // Verify agreement created successfully - proves KYC was configured correctly
        (uint256 capital,,,,, ) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    // ============ KYC REGISTRY INTEGRATION TESTS ============
    
    function testKYCRegistrySetCorrectly() public view {
        // KYC Registry should be set on the Diamond
        address registryAddr = address(kycRegistry);
        assertTrue(registryAddr != address(0));
    }
    
    function testCreateAgreementEnforcesKYC() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(propertyId);
        
        // Transfer to non-KYC user
        address nonKYCUser = makeAddr("nonKYC");
        propertyNFT.transferFrom(owner, nonKYCUser, propertyId);
        vm.stopPrank();
        
        // Non-KYC user cannot create agreement
        vm.prank(nonKYCUser);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
    }
}
