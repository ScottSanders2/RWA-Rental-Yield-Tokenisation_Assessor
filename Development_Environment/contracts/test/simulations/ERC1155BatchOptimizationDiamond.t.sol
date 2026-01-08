// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../../script/DeployDiamond.s.sol";

// Facet interfaces
import "../../src/facets/combined/MintingFacet.sol";
import "../../src/facets/combined/CombinedViewsFacet.sol";
import "../../src/KYCRegistry.sol";

/**
 * @title ERC1155BatchOptimization Diamond Test Suite
 * @notice Tests batch operation efficiency for ERC-1155 tokens
 * @dev Validates gas optimization and batch transfer performance
 */
contract ERC1155BatchOptimizationDiamondTest is Test, ERC1155Holder {
    DeployDiamond public deployer;
    
    MintingFacet public mintingFacet;
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
        
        // Wrap CombinedToken Diamond
        address combinedAddr = address(deployer.combinedTokenDiamond());
        mintingFacet = MintingFacet(combinedAddr);
        combinedViewsFacet = CombinedViewsFacet(combinedAddr);
        
        // Whitelist test users
        vm.startPrank(owner);
        kycRegistry.addToWhitelist(user1);
        kycRegistry.addToWhitelist(user2);
        kycRegistry.addToWhitelist(address(this));
        vm.stopPrank();
    }
    
    // ============ BATCH TRANSFER OPTIMIZATION ============
    
    function testBatchTransferVsSingleTransfers() public {
        // Create 5 yield tokens
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("BatchTestProperty"),
            "ipfs://batch"
        );
        mintingFacet.verifyProperty(propertyId);
        
        uint256[] memory yieldIds = new uint256[](5);
        for (uint i = 0; i < 5; i++) {
            yieldIds[i] = mintingFacet.mintYieldTokens(
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
        vm.stopPrank();
        
        // Measure gas for single transfers
        uint256 gasStart1 = gasleft();
        for (uint i = 0; i < 5; i++) {
            vm.prank(owner);
            MintingFacet(address(mintingFacet)).safeTransferFrom(
                owner,
                user1,
                yieldIds[i],
                10 ether,
                ""
            );
        }
        uint256 gasSingle = gasStart1 - gasleft();
        
        // Measure gas for batch transfer
        uint256[] memory amounts = new uint256[](5);
        for (uint i = 0; i < 5; i++) {
            amounts[i] = 10 ether;
        }
        
        uint256 gasStart2 = gasleft();
        vm.prank(owner);
        MintingFacet(address(mintingFacet)).safeBatchTransferFrom(
            owner,
            user2,
            yieldIds,
            amounts,
            ""
        );
        uint256 gasBatch = gasStart2 - gasleft();
        
        emit log_named_uint("Gas for 5 single transfers", gasSingle);
        emit log_named_uint("Gas for 1 batch transfer", gasBatch);
        
        // Batch should be more efficient
        assertTrue(gasBatch < gasSingle);
    }
    
    // ============ GAS EFFICIENCY COMPARISON ============
    
    function testBatchMintingEfficiency() public {
        // Create property
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("MintEfficiency"),
            "ipfs://efficiency"
        );
        mintingFacet.verifyProperty(propertyId);
        vm.stopPrank();
        
        // Measure gas for creating 10 yield tokens
        uint256 gasStart = gasleft();
        vm.startPrank(owner);
        for (uint i = 0; i < 10; i++) {
            mintingFacet.mintYieldTokens(
                propertyId,
                50 ether,
                50000 ether,
                12,
                500,
                30,
                200,
                true,
                true
            );
        }
        vm.stopPrank();
        uint256 gasUsed = gasStart - gasleft();
        
        emit log_named_uint("Gas for 10 yield token mints", gasUsed);
        emit log_named_uint("Avg gas per mint", gasUsed / 10);
        
        assertTrue(gasUsed > 0);
    }
    
    // ============ LARGE BATCH OPERATIONS ============
    
    function testLargeBatchOperation20Tokens() public {
        // Create property and 20 yield tokens
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("LargeBatch"),
            "ipfs://large"
        );
        mintingFacet.verifyProperty(propertyId);
        
        uint256[] memory yieldIds = new uint256[](20);
        for (uint i = 0; i < 20; i++) {
            yieldIds[i] = mintingFacet.mintYieldTokens(
                propertyId,
                25 ether,
                25000 ether,
                12,
                500,
                30,
                200,
                true,
                true
            );
        }
        vm.stopPrank();
        
        // Batch transfer all 20
        uint256[] memory amounts = new uint256[](20);
        for (uint i = 0; i < 20; i++) {
            amounts[i] = 5 ether;
        }
        
        uint256 gasStart = gasleft();
        vm.prank(owner);
        MintingFacet(address(mintingFacet)).safeBatchTransferFrom(
            owner,
            user1,
            yieldIds,
            amounts,
            ""
        );
        uint256 gasUsed = gasStart - gasleft();
        
        emit log_named_uint("Gas for batch transfer of 20 tokens", gasUsed);
        
        // Verify all transferred
        for (uint i = 0; i < 20; i++) {
            assertEq(MintingFacet(address(mintingFacet)).balanceOf(user1, yieldIds[i]), 5 ether);
        }
    }
    
    // ============ MIXED PROPERTY/YIELD BATCH OPERATIONS ============
    
    function testMixedTokenBatchTransfer() public {
        vm.startPrank(owner);
        
        // Create 2 properties and 2 yield tokens
        uint256 propId1 = mintingFacet.mintPropertyToken(
            keccak256("MixedProp1"),
            "ipfs://mixed1"
        );
        
        uint256 propId2 = mintingFacet.mintPropertyToken(
            keccak256("MixedProp2"),
            "ipfs://mixed2"
        );
        
        mintingFacet.verifyProperty(propId1);
        
        uint256 yieldId1 = mintingFacet.mintYieldTokens(
            propId1,
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
            propId1,
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
        
        // Batch transfer mixed types
        uint256[] memory ids = new uint256[](3);
        ids[0] = propId2;      // Property token
        ids[1] = yieldId1;     // Yield token
        ids[2] = yieldId2;     // Yield token
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;        // Property (single NFT)
        amounts[1] = 10 ether; // Yield shares
        amounts[2] = 15 ether; // Yield shares
        
        vm.prank(owner);
        MintingFacet(address(mintingFacet)).safeBatchTransferFrom(
            owner,
            user1,
            ids,
            amounts,
            ""
        );
        
        // Verify mixed batch succeeded
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(user1, propId2), 1);
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(user1, yieldId1), 10 ether);
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(user1, yieldId2), 15 ether);
    }
    
    // ============ BATCH OPERATION ROLLBACK ON SINGLE FAILURE ============
    
    function testBatchTransferRollbackOnFailure() public {
        // Create yield tokens
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("RollbackTest"),
            "ipfs://rollback"
        );
        mintingFacet.verifyProperty(propertyId);
        
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
        
        // Attempt batch transfer to non-KYC user (should fail entirely)
        address nonKYCUser = makeAddr("nonKYC");
        
        uint256[] memory ids = new uint256[](2);
        ids[0] = yieldId1;
        ids[1] = yieldId2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 10 ether;
        amounts[1] = 10 ether;
        
        vm.prank(owner);
        vm.expectRevert();  // Entire batch should fail
        MintingFacet(address(mintingFacet)).safeBatchTransferFrom(
            owner,
            nonKYCUser,
            ids,
            amounts,
            ""
        );
        
        // Verify no partial transfer occurred
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(nonKYCUser, yieldId1), 0);
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(nonKYCUser, yieldId2), 0);
    }
    
    // ============ BATCH APPROVAL OPERATIONS ============
    
    function testBatchApprovalForAll() public {
        // Create yield tokens
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("ApprovalTest"),
            "ipfs://approval"
        );
        mintingFacet.verifyProperty(propertyId);
        
        uint256 yieldId = mintingFacet.mintYieldTokens(
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
        
        // Set approval for all
        MintingFacet(address(mintingFacet)).setApprovalForAll(user2, true);
        vm.stopPrank();
        
        // Verify user2 can transfer on behalf of owner
        vm.prank(user2);
        MintingFacet(address(mintingFacet)).safeTransferFrom(
            owner,
            user1,
            yieldId,
            10 ether,
            ""
        );
        
        // Verify transfer succeeded
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(user1, yieldId), 10 ether);
    }
    
    // ============ GAS COMPARISON: BATCH VS SEQUENTIAL ============
    
    function testGasComparisonBatchVsSequential() public {
        // Create property and tokens
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("GasComparison"),
            "ipfs://gas"
        );
        mintingFacet.verifyProperty(propertyId);
        
        uint256[] memory yieldIds = new uint256[](10);
        for (uint i = 0; i < 10; i++) {
            yieldIds[i] = mintingFacet.mintYieldTokens(
                propertyId,
                50 ether,
                50000 ether,
                12,
                500,
                30,
                200,
                true,
                true
            );
        }
        vm.stopPrank();
        
        // Sequential transfers
        uint256 gasSequential = gasleft();
        for (uint i = 0; i < 10; i++) {
            vm.prank(owner);
            MintingFacet(address(mintingFacet)).safeTransferFrom(
                owner,
                user1,
                yieldIds[i],
                5 ether,
                ""
            );
        }
        gasSequential = gasSequential - gasleft();
        
        // Batch transfer (need to create new tokens for user1 to transfer)
        uint256[] memory amounts = new uint256[](10);
        for (uint i = 0; i < 10; i++) {
            amounts[i] = 5 ether;
        }
        
        uint256 gasBatch = gasleft();
        vm.prank(owner);
        MintingFacet(address(mintingFacet)).safeBatchTransferFrom(
            owner,
            user2,
            yieldIds,
            amounts,
            ""
        );
        gasBatch = gasBatch - gasleft();
        
        emit log_named_uint("Gas for 10 sequential transfers", gasSequential);
        emit log_named_uint("Gas for 1 batch transfer (10 tokens)", gasBatch);
        uint256 savings = gasSequential > gasBatch ? gasSequential - gasBatch : 0;
        emit log_named_uint("Gas savings (batch vs sequential)", savings);
        
        // Batch should save gas
        assertTrue(gasBatch < gasSequential, "Batch should be more efficient");
    }
    
    // ============ MAXIMUM BATCH SIZE HANDLING ============
    
    function testMaximumBatchSize() public {
        // Create property
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("MaxBatch"),
            "ipfs://maxbatch"
        );
        mintingFacet.verifyProperty(propertyId);
        
        // Create 50 yield tokens (stress test)
        uint256[] memory yieldIds = new uint256[](50);
        for (uint i = 0; i < 50; i++) {
            yieldIds[i] = mintingFacet.mintYieldTokens(
                propertyId,
                20 ether,
                20000 ether,
                12,
                500,
                30,
                200,
                true,
                true
            );
        }
        vm.stopPrank();
        
        // Batch transfer all 50
        uint256[] memory amounts = new uint256[](50);
        for (uint i = 0; i < 50; i++) {
            amounts[i] = 2 ether;
        }
        
        vm.prank(owner);
        MintingFacet(address(mintingFacet)).safeBatchTransferFrom(
            owner,
            user1,
            yieldIds,
            amounts,
            ""
        );
        
        // Verify large batch succeeded
        for (uint i = 0; i < 50; i++) {
            assertEq(MintingFacet(address(mintingFacet)).balanceOf(user1, yieldIds[i]), 2 ether);
        }
    }
}

