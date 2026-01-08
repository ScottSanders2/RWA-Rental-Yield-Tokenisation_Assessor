// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/DeployDiamond.s.sol";

// Contract imports
import "../src/PropertyNFT.sol";
import "../src/KYCRegistry.sol";
import "../src/facets/YieldBaseFacet.sol";
import "../src/facets/ViewsFacet.sol";

/**
 * @title PropertyNFT Diamond Integration Test Suite
 * @notice Tests PropertyNFT integration with YieldBase Diamond
 * @dev Uses actual DeployDiamond script to test production deployment pattern
 */
contract PropertyNFTDiamondTest is Test {
    DeployDiamond public deployer;
    
    PropertyNFT public propertyNFT;
    KYCRegistry public kycRegistry;
    YieldBaseFacet public yieldBaseFacet;
    ViewsFacet public viewsFacet;
    
    address public owner;
    address public user1;
    address public user2;
    
    function setUp() public {
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy via actual script
        deployer = new DeployDiamond();
        deployer.run();
        
        // Get deployed contracts
        propertyNFT = deployer.propertyNFT();
        kycRegistry = deployer.kycRegistry();
        
        address diamondAddr = address(deployer.yieldBaseDiamond());
        yieldBaseFacet = YieldBaseFacet(diamondAddr);
        viewsFacet = ViewsFacet(diamondAddr);
        
        // Whitelist test users
        vm.startPrank(owner);
        kycRegistry.addToWhitelist(user1);
        kycRegistry.addToWhitelist(user2);
        vm.stopPrank();
    }
    
    // ============ PROPERTY MINTING TESTS ============
    
    function testMintProperty() public {
        vm.prank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://property-metadata"
        );
        
        assertEq(tokenId, 1);
        assertEq(propertyNFT.ownerOf(tokenId), owner);
        assertFalse(propertyNFT.isPropertyVerified(tokenId));
    }
    
    function testVerifyProperty() public {
        vm.startPrank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://property-metadata"
        );
        
        propertyNFT.verifyProperty(tokenId);
        assertTrue(propertyNFT.isPropertyVerified(tokenId));
        vm.stopPrank();
    }
    
    function testOnlyOwnerCanVerifyProperty() public {
        vm.prank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://property-metadata"
        );
        
        // Non-owner cannot verify
        vm.prank(user1);
        vm.expectRevert();
        propertyNFT.verifyProperty(tokenId);
    }
    
    // ============ YIELD AGREEMENT LINKING TESTS ============
    
    function testPropertyLinksToYieldAgreement() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(propertyId);
        vm.stopPrank();
        
        // Create yield agreement
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
        
        // Verify agreement was created
        (uint256 capital,,,,, ) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    function testCannotCreateAgreementOnUnverifiedProperty() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        // Don't verify
        
        // Should fail
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
        vm.stopPrank();
    }
    
    function testPropertyOwnershipRequiredForAgreement() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(propertyId);
        vm.stopPrank();
        
        // Non-owner cannot create agreement
        vm.prank(user1);
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
    
    // ============ INITIALIZATION TESTS ============
    
    function testCannotReinitialize() public {
        vm.expectRevert();
        propertyNFT.initialize(address(this), "Test", "TEST");
    }
    
    // ============ MINTING VALIDATION TESTS ============
    
    function testMintPropertyValidation() public {
        vm.startPrank(owner);
        
        // Cannot mint with zero address hash
        vm.expectRevert("Property address hash cannot be zero");
        propertyNFT.mintProperty(bytes32(0), "ipfs://test");
        
        // Cannot mint with empty metadata URI
        vm.expectRevert("Metadata URI cannot be empty");
        propertyNFT.mintProperty(keccak256("123 Main St"), "");
        
        vm.stopPrank();
    }
    
    function testOnlyOwnerCanMintProperty() public {
        vm.prank(user1);
        vm.expectRevert();
        propertyNFT.mintProperty(keccak256("123 Main St"), "ipfs://test");
    }
    
    // ============ TOKEN URI TESTS ============
    
    function testTokenURIRetrieval() public {
        vm.prank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://property-metadata"
        );
        
        assertEq(propertyNFT.tokenURI(tokenId), "ipfs://property-metadata");
    }
    
    function testTokenURINonexistent() public {
        vm.expectRevert("Property does not exist");
        propertyNFT.tokenURI(999);
    }
    
    // ============ MULTIPLE PROPERTIES TESTS ============
    
    function testMultiplePropertiesMinting() public {
        vm.startPrank(owner);
        
        uint256 tokenId1 = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://property1"
        );
        uint256 tokenId2 = propertyNFT.mintProperty(
            keccak256("456 Oak Ave"),
            "ipfs://property2"
        );
        uint256 tokenId3 = propertyNFT.mintProperty(
            keccak256("789 Pine Rd"),
            "ipfs://property3"
        );
        
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(tokenId3, 3);
        
        assertEq(propertyNFT.ownerOf(tokenId1), owner);
        assertEq(propertyNFT.ownerOf(tokenId2), owner);
        assertEq(propertyNFT.ownerOf(tokenId3), owner);
        
        vm.stopPrank();
    }
    
    // ============ PROPERTY DATA RETRIEVAL TESTS ============
    
    function testGetPropertyData() public {
        vm.startPrank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://property-metadata"
        );
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
        
        PropertyStorage.PropertyData memory data = propertyNFT.getPropertyData(tokenId);
        
        assertEq(data.propertyAddressHash, keccak256("123 Main St"));
        assertEq(data.metadataURI, "ipfs://property-metadata");
        assertTrue(data.isVerified);
        assertEq(data.verifierAddress, owner);
        assertEq(data.verificationTimestamp, block.timestamp);
    }
    
    // ============ VERIFICATION WORKFLOW TESTS ============
    
    function testCannotVerifyNonexistentProperty() public {
        vm.prank(owner);
        vm.expectRevert("Property does not exist");
        propertyNFT.verifyProperty(999);
    }
    
    function testCannotVerifyAlreadyVerifiedProperty() public {
        vm.startPrank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(tokenId);
        
        // Try to verify again
        vm.expectRevert("Property already verified");
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
    }
    
    function testVerificationTimestamp() public {
        vm.startPrank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        
        // Advance time
        vm.warp(block.timestamp + 100);
        
        propertyNFT.verifyProperty(tokenId);
        
        PropertyStorage.PropertyData memory data = propertyNFT.getPropertyData(tokenId);
        assertEq(data.verificationTimestamp, block.timestamp);
        vm.stopPrank();
    }
    
    // ============ TRANSFER TESTS ============
    
    function testTransferProperty() public {
        vm.startPrank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        
        propertyNFT.transferFrom(owner, user1, tokenId);
        
        assertEq(propertyNFT.ownerOf(tokenId), user1);
        vm.stopPrank();
    }
    
    function testSafeTransferProperty() public {
        vm.startPrank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        
        propertyNFT.safeTransferFrom(owner, user1, tokenId);
        
        assertEq(propertyNFT.ownerOf(tokenId), user1);
        vm.stopPrank();
    }
    
    // ============ YIELDBASE LINKING TESTS ============
    
    function testSetYieldBase() public {
        address newYieldBase = address(deployer.yieldBaseDiamond());
        
        vm.prank(owner);
        propertyNFT.setYieldBase(newYieldBase);
        
        assertEq(propertyNFT.yieldBase(), newYieldBase);
    }
    
    function testOnlyOwnerCanSetYieldBase() public {
        address newYieldBase = makeAddr("newYieldBase");
        
        vm.prank(user1);
        vm.expectRevert();
        propertyNFT.setYieldBase(newYieldBase);
    }
    
    function testSetYieldBaseValidation() public {
        vm.prank(owner);
        vm.expectRevert("Invalid YieldBase address");
        propertyNFT.setYieldBase(address(0));
    }
    
    // ============ LINK TO YIELD AGREEMENT TESTS ============
    
    function testLinkToYieldAgreementOnlyByYieldBase() public {
        vm.startPrank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(tokenId);
        vm.stopPrank();
        
        // Non-YieldBase cannot link
        vm.prank(user1);
        vm.expectRevert("Caller is not the configured YieldBase contract");
        propertyNFT.linkToYieldAgreement(tokenId, 1);
    }
    
    function testLinkValidation() public {
        vm.prank(address(deployer.yieldBaseDiamond()));
        
        // Cannot link nonexistent property
        vm.expectRevert("Property does not exist");
        propertyNFT.linkToYieldAgreement(999, 1);
    }
    
    // ============ ERC-721 COMPLIANCE TESTS ============
    
    function testERC721Compliance() public {
        vm.startPrank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );
        
        // Test balanceOf
        assertEq(propertyNFT.balanceOf(owner), 1);
        
        // Test ownerOf
        assertEq(propertyNFT.ownerOf(tokenId), owner);
        
        // Test approve
        propertyNFT.approve(user1, tokenId);
        assertEq(propertyNFT.getApproved(tokenId), user1);
        
        vm.stopPrank();
    }
}

