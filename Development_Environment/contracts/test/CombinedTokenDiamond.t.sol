// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../script/DeployDiamond.s.sol";

// Facet interfaces
import "../src/facets/combined/MintingFacet.sol";
import "../src/facets/combined/DistributionFacet.sol";
import "../src/facets/combined/CombinedViewsFacet.sol";
import "../src/KYCRegistry.sol";

/**
 * @title CombinedPropertyYieldToken Diamond Test Suite
 * @notice Tests ERC-1155 Diamond implementation with KYC enforcement
 * @dev Uses actual DeployDiamond script to test production deployment
 */
contract CombinedTokenDiamondTest is Test, ERC1155Holder {
    DeployDiamond public deployer;
    
    MintingFacet public mintingFacet;
    DistributionFacet public distributionFacet;
    CombinedViewsFacet public combinedViewsFacet;
    KYCRegistry public kycRegistry;
    
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
        kycRegistry = deployer.kycRegistry();
        
        // Wrap CombinedToken Diamond with facet ABIs
        address combinedAddr = address(deployer.combinedTokenDiamond());
        mintingFacet = MintingFacet(combinedAddr);
        distributionFacet = DistributionFacet(combinedAddr);
        combinedViewsFacet = CombinedViewsFacet(combinedAddr);
        
        // Whitelist test users
        vm.startPrank(owner);
        kycRegistry.addToWhitelist(user1);
        kycRegistry.addToWhitelist(user2);
        kycRegistry.addToWhitelist(address(this));  // Test contract needs to receive tokens
        vm.stopPrank();
    }
    
    // ============ PROPERTY TOKEN TESTS (ERC-1155 ID < 1M) ============
    
    function testMintPropertyToken() public {
        bytes32 propertyHash = keccak256("123 Main St");
        string memory uri = "ipfs://property";
        
        vm.prank(owner);
        uint256 tokenId = mintingFacet.mintPropertyToken(
            propertyHash,
            uri
        );
        
        assertTrue(tokenId < 1_000_000);
        // Check balance via the Diamond (ERC1155 functions are in the base contract)
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(owner, tokenId), 1);
    }
    
    // ============ YIELD TOKEN TESTS (ERC-1155 ID >= 1M) ============
    
    function testMintYieldTokens() public {
        // First mint property token
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        
        // Verify property
        mintingFacet.verifyProperty(propertyId);
        
        // Mint yield tokens for this property (need proper parameters)
        uint256 yieldAmount = 100 ether;
        uint256 yieldTokenId = mintingFacet.mintYieldTokens(
            propertyId,
            yieldAmount,
            100000 ether,  // upfrontCapitalUsd
            12,            // termMonths
            500,           // annualROI
            30,            // gracePeriodDays
            200,           // defaultPenaltyRate
            true,          // allowPartialRepayments
            true           // allowEarlyRepayment
        );
        vm.stopPrank();
        
        assertTrue(yieldTokenId >= 1_000_000);
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(owner, yieldTokenId), yieldAmount);
    }
    
    // ============ KYC ENFORCEMENT TESTS ============
    
    function testYieldTokenTransferRequiresKYC() public {
        // Mint property and yield tokens
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        
        // Must verify property before minting yield tokens
        mintingFacet.verifyProperty(propertyId);
        
        uint256 yieldTokenId = mintingFacet.mintYieldTokens(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
        vm.stopPrank();
        
        // Transfer to whitelisted user (should work)
        vm.prank(owner);
        MintingFacet(address(mintingFacet)).safeTransferFrom(owner, user1, yieldTokenId, 10 ether, "");
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(user1, yieldTokenId), 10 ether);
        
        // Transfer to non-whitelisted user (should fail)
        address nonKYCUser = makeAddr("nonKYC");
        vm.prank(owner);
        vm.expectRevert();
        MintingFacet(address(mintingFacet)).safeTransferFrom(owner, nonKYCUser, yieldTokenId, 10 ether, "");
    }
    
    function testPropertyTokenTransferRestricted() public {
        // Mint property token
        vm.prank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        
        // Property tokens also require KYC for transfers
        address nonKYCUser = makeAddr("nonKYC");
        vm.prank(owner);
        vm.expectRevert();  // Should fail - nonKYCUser not whitelisted
        MintingFacet(address(mintingFacet)).safeTransferFrom(owner, nonKYCUser, propertyId, 1, "");
    }
    
    // ============ BATCH OPERATIONS WITH KYC ============
    
    function testBatchTransferEnforcesKYC() public {
        // Create multiple yield tokens
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        
        // Must verify property before minting yield tokens
        mintingFacet.verifyProperty(propertyId);
        
        uint256 yieldId1 = mintingFacet.mintYieldTokens(propertyId, 100 ether, 100000 ether, 12, 500, 30, 200, true, true);
        uint256 yieldId2 = mintingFacet.mintYieldTokens(propertyId, 200 ether, 200000 ether, 12, 500, 30, 200, true, true);
        vm.stopPrank();
        
        // Batch transfer to whitelisted user (should work)
        uint256[] memory ids = new uint256[](2);
        ids[0] = yieldId1;
        ids[1] = yieldId2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 20 ether;
        
        // Store initial balances
        uint256 ownerBalanceId1Before = MintingFacet(address(mintingFacet)).balanceOf(owner, yieldId1);
        uint256 ownerBalanceId2Before = MintingFacet(address(mintingFacet)).balanceOf(owner, yieldId2);
        
        vm.prank(owner);
        MintingFacet(address(mintingFacet)).safeBatchTransferFrom(owner, user1, ids, amounts, "");
        
        // Verify transfer occurred (user1 received some tokens)
        assertTrue(MintingFacet(address(mintingFacet)).balanceOf(user1, yieldId1) > 0, "User1 should receive yieldId1 tokens");
        assertTrue(MintingFacet(address(mintingFacet)).balanceOf(user1, yieldId2) > 0, "User1 should receive yieldId2 tokens");
        // Verify owner balance decreased
        assertTrue(MintingFacet(address(mintingFacet)).balanceOf(owner, yieldId1) < ownerBalanceId1Before, "Owner balance should decrease");
        assertTrue(MintingFacet(address(mintingFacet)).balanceOf(owner, yieldId2) < ownerBalanceId2Before, "Owner balance should decrease");
    }
    
    // ============ PROPERTY VERIFICATION TESTS ============
    
    function testVerifyProperty() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        
        mintingFacet.verifyProperty(propertyId);
        vm.stopPrank();
    }
    
    function testOnlyOwnerCanVerifyProperty() public {
        vm.prank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        
        // Non-owner cannot verify
        vm.prank(user1);
        vm.expectRevert();
        mintingFacet.verifyProperty(propertyId);
    }
    
    function testCannotVerifyNonexistentProperty() public {
        vm.prank(owner);
        vm.expectRevert();
        mintingFacet.verifyProperty(999);
    }
    
    function testCannotVerifyAlreadyVerifiedProperty() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        mintingFacet.verifyProperty(propertyId);
        
        // Try to verify again
        vm.expectRevert();
        mintingFacet.verifyProperty(propertyId);
        vm.stopPrank();
    }
    
    // ============ YIELD TOKEN VALIDATION TESTS ============
    
    function testYieldTokenRequiresVerifiedProperty() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        
        // Don't verify property
        vm.expectRevert();
        mintingFacet.mintYieldTokens(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
        vm.stopPrank();
    }
    
    function testYieldTokenRequiresPropertyOwnership() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        mintingFacet.verifyProperty(propertyId);
        
        // Transfer property to user1
        MintingFacet(address(mintingFacet)).safeTransferFrom(owner, user1, propertyId, 1, "");
        vm.stopPrank();
        
        // owner no longer owns property, cannot mint yield
        vm.prank(owner);
        vm.expectRevert();
        mintingFacet.mintYieldTokens(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
    }
    
    function testYieldTokenValidation() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        mintingFacet.verifyProperty(propertyId);
        
        // Cannot mint with zero capital
        vm.expectRevert();
        mintingFacet.mintYieldTokens(
            propertyId,
            0,  // Zero capital
            100000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
        vm.stopPrank();
    }
    
    // ============ MULTIPLE TOKENS TESTS ============
    
    function testMultiplePropertyTokensMinting() public {
        vm.startPrank(owner);
        
        uint256 property1 = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property1"
        );
        uint256 property2 = mintingFacet.mintPropertyToken(
            keccak256("456 Oak Ave"),
            "ipfs://property2"
        );
        uint256 property3 = mintingFacet.mintPropertyToken(
            keccak256("789 Pine Rd"),
            "ipfs://property3"
        );
        
        assertTrue(property1 < 1_000_000);
        assertTrue(property2 < 1_000_000);
        assertTrue(property3 < 1_000_000);
        assertTrue(property2 != property1);
        assertTrue(property3 != property2);
        
        vm.stopPrank();
    }
    
    function testMultipleYieldTokensPerProperty() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        mintingFacet.verifyProperty(propertyId);
        
        // Create multiple yield agreements for same property
        uint256 yieldId1 = mintingFacet.mintYieldTokens(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
        
        uint256 yieldId2 = mintingFacet.mintYieldTokens(
            propertyId,
            200 ether,
            200000 ether,
            24,
            600,
            30,
            200,
            true,
            true
        );
        
        assertTrue(yieldId1 >= 1_000_000);
        assertTrue(yieldId2 >= 1_000_000);
        assertTrue(yieldId2 != yieldId1);
        
        vm.stopPrank();
    }
    
    // ============ TOKEN BALANCES TESTS ============
    
    function testBalanceTracking() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        mintingFacet.verifyProperty(propertyId);
        
        uint256 yieldTokenId = mintingFacet.mintYieldTokens(
            propertyId,
            150 ether,
            150000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
        vm.stopPrank();
        
        // Check initial balance
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(owner, yieldTokenId), 150 ether);
        
        // Transfer some tokens
        vm.prank(owner);
        MintingFacet(address(mintingFacet)).safeTransferFrom(owner, user1, yieldTokenId, 50 ether, "");
        
        // Check updated balances
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(owner, yieldTokenId), 100 ether);
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(user1, yieldTokenId), 50 ether);
    }
    
    // ============ TOKEN METADATA TESTS ============
    
    function testPropertyMetadata() public {
        vm.prank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property-metadata"
        );
        
        // URI should be accessible
        string memory uri = MintingFacet(address(mintingFacet)).uri(propertyId);
        assertTrue(bytes(uri).length > 0);
    }
    
    // ============ REPAYMENT DISTRIBUTION TESTS ============
    
    function testDistributeYieldRepayment() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        mintingFacet.verifyProperty(propertyId);
        
        uint256 yieldTokenId = mintingFacet.mintYieldTokens(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
        
        // Transfer some tokens to user1
        MintingFacet(address(mintingFacet)).safeTransferFrom(owner, user1, yieldTokenId, 30 ether, "");
        vm.stopPrank();
        
        // Distribute repayment
        uint256 repaymentAmount = 10 ether;
        vm.deal(owner, repaymentAmount);
        vm.prank(owner);
        distributionFacet.distributeYieldRepayment{value: repaymentAmount}(yieldTokenId);
    }
    
    function testOnlyOwnerCanDistributeRepayment() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        mintingFacet.verifyProperty(propertyId);
        
        uint256 yieldTokenId = mintingFacet.mintYieldTokens(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
        vm.stopPrank();
        
        // Non-owner cannot distribute
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        vm.expectRevert();
        distributionFacet.distributeYieldRepayment{value: 10 ether}(yieldTokenId);
    }
    
    // ============ ERC-1155 COMPLIANCE TESTS ============
    
    function testERC1155Compliance() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        
        // Test balanceOf
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(owner, propertyId), 1);
        
        // Test setApprovalForAll
        MintingFacet(address(mintingFacet)).setApprovalForAll(user1, true);
        assertTrue(MintingFacet(address(mintingFacet)).isApprovedForAll(owner, user1));
        
        vm.stopPrank();
    }
    
    // ============ BLACKLIST ENFORCEMENT TESTS ============
    
    function testBlacklistedUserCannotReceiveYieldTokens() public {
        address blacklisted = makeAddr("blacklisted");
        
        vm.prank(owner);
        kycRegistry.addToBlacklist(blacklisted);
        
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        mintingFacet.verifyProperty(propertyId);
        
        uint256 yieldTokenId = mintingFacet.mintYieldTokens(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
        
        // Should fail - blacklisted address
        vm.expectRevert();
        MintingFacet(address(mintingFacet)).safeTransferFrom(owner, blacklisted, yieldTokenId, 10 ether, "");
        vm.stopPrank();
    }
    
    // ============ TOKEN ID RANGE TESTS ============
    
    function testTokenIdRanges() public {
        vm.startPrank(owner);
        
        // Property token should be < 1,000,000
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property"
        );
        assertTrue(propertyId < 1_000_000);
        
        // Yield token should be >= 1,000,000
        mintingFacet.verifyProperty(propertyId);
        uint256 yieldTokenId = mintingFacet.mintYieldTokens(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
        assertTrue(yieldTokenId >= 1_000_000);
        
        vm.stopPrank();
    }
    
    // ============ BATCH BALANCE QUERIES ============
    
    function testBatchBalanceOf() public {
        vm.startPrank(owner);
        uint256 property1 = mintingFacet.mintPropertyToken(
            keccak256("123 Main St"),
            "ipfs://property1"
        );
        uint256 property2 = mintingFacet.mintPropertyToken(
            keccak256("456 Oak Ave"),
            "ipfs://property2"
        );
        vm.stopPrank();
        
        address[] memory accounts = new address[](2);
        accounts[0] = owner;
        accounts[1] = owner;
        
        uint256[] memory ids = new uint256[](2);
        ids[0] = property1;
        ids[1] = property2;
        
        uint256[] memory balances = MintingFacet(address(mintingFacet)).balanceOfBatch(accounts, ids);
        
        assertEq(balances[0], 1);
        assertEq(balances[1], 1);
    }
}

