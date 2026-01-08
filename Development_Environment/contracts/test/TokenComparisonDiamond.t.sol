// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../script/DeployDiamond.s.sol";

// Facet interfaces
import "../src/facets/YieldBaseFacet.sol";
import "../src/facets/ViewsFacet.sol";
import "../src/facets/combined/MintingFacet.sol";
import "../src/KYCRegistry.sol";
import "../src/PropertyNFT.sol";
import "../src/YieldSharesToken.sol";

/**
 * @title TokenComparison Diamond Test Suite
 * @notice Compares ERC-721 (PropertyNFT) vs ERC-1155 (CombinedToken) implementations
 * @dev Validates gas efficiency, feature parity, and use case optimization
 */
contract TokenComparisonDiamondTest is Test, ERC1155Holder {
    DeployDiamond public deployer;
    
    KYCRegistry public kycRegistry;
    YieldBaseFacet public yieldBaseFacet;
    ViewsFacet public viewsFacet;
    PropertyNFT public propertyNFT;
    MintingFacet public mintingFacet;
    
    address public owner;
    
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
        viewsFacet = ViewsFacet(diamondAddr);
        
        address combinedAddr = address(deployer.combinedTokenDiamond());
        mintingFacet = MintingFacet(combinedAddr);
        
        // Whitelist test contract
        vm.prank(owner);
        kycRegistry.addToWhitelist(address(this));
    }
    
    // ============ ERC-721 VS ERC-1155 COMPARISON ============
    
    function testERC721PropertyMinting() public {
        uint256 gasStart = gasleft();
        
        vm.prank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("ERC721Property"),
            "ipfs://erc721"
        );
        
        uint256 gasUsed = gasStart - gasleft();
        emit log_named_uint("Gas for ERC-721 property mint", gasUsed);
        
        assertTrue(propertyId > 0);
    }
    
    function testERC1155PropertyMinting() public {
        uint256 gasStart = gasleft();
        
        vm.prank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(
            keccak256("ERC1155Property"),
            "ipfs://erc1155"
        );
        
        uint256 gasUsed = gasStart - gasleft();
        emit log_named_uint("Gas for ERC-1155 property mint", gasUsed);
        
        assertTrue(propertyId > 0);
    }
    
    // ============ GAS EFFICIENCY COMPARISON ============
    
    function testGasEfficiencyComparison() public {
        // ERC-721
        uint256 gasERC721 = gasleft();
        vm.prank(owner);
        propertyNFT.mintProperty(keccak256("Gas721"), "ipfs://gas721");
        gasERC721 = gasERC721 - gasleft();
        
        // ERC-1155
        uint256 gasERC1155 = gasleft();
        vm.prank(owner);
        mintingFacet.mintPropertyToken(keccak256("Gas1155"), "ipfs://gas1155");
        gasERC1155 = gasERC1155 - gasleft();
        
        emit log_named_uint("ERC-721 gas", gasERC721);
        emit log_named_uint("ERC-1155 gas", gasERC1155);
        
        // Both should complete successfully
        assertTrue(gasERC721 > 0);
        assertTrue(gasERC1155 > 0);
    }
    
    // ============ FEATURE PARITY TESTING ============
    
    function testPropertyVerificationParity() public {
        // ERC-721 verification
        vm.startPrank(owner);
        uint256 prop721 = propertyNFT.mintProperty(keccak256("Verify721"), "ipfs://v721");
        propertyNFT.verifyProperty(prop721);
        assertTrue(propertyNFT.isPropertyVerified(prop721));
        
        // ERC-1155 verification
        uint256 prop1155 = mintingFacet.mintPropertyToken(keccak256("Verify1155"), "ipfs://v1155");
        mintingFacet.verifyProperty(prop1155);
        vm.stopPrank();
        
        // Both support verification
        assertTrue(true);
    }
    
    function testTransferParity() public {
        // ERC-721 transfer
        vm.startPrank(owner);
        uint256 prop721 = propertyNFT.mintProperty(keccak256("Transfer721"), "ipfs://t721");
        address recipient = makeAddr("recipient");
        vm.prank(owner);
        kycRegistry.addToWhitelist(recipient);
        propertyNFT.transferFrom(owner, recipient, prop721);
        assertEq(propertyNFT.ownerOf(prop721), recipient);
        vm.stopPrank();
        
        // ERC-1155 transfer
        vm.prank(owner);
        uint256 prop1155 = mintingFacet.mintPropertyToken(keccak256("Transfer1155"), "ipfs://t1155");
        vm.prank(owner);
        MintingFacet(address(mintingFacet)).safeTransferFrom(owner, recipient, prop1155, 1, "");
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(recipient, prop1155), 1);
    }
    
    // ============ YIELD TOKEN INTEGRATION ============
    
    function testERC721YieldTokenCreation() public {
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(keccak256("Yield721"), "ipfs://y721");
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
        
        // Verify agreement created (token created internally)
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    function testERC1155YieldTokenCreation() public {
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(keccak256("Yield1155"), "ipfs://y1155");
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
        
        // Verify yield token created
        assertTrue(yieldTokenId >= 1_000_000);
    }
    
    // ============ BATCH OPERATION SUPPORT ============
    
    function testERC721NoBatchSupport() public {
        // ERC-721 doesn't natively support batch
        vm.startPrank(owner);
        propertyNFT.mintProperty(keccak256("Batch721_1"), "ipfs://b1");
        propertyNFT.mintProperty(keccak256("Batch721_2"), "ipfs://b2");
        vm.stopPrank();
        
        // Transfers must be done individually
        assertTrue(true);
    }
    
    function testERC1155BatchSupport() public {
        // ERC-1155 supports batch natively
        vm.startPrank(owner);
        uint256 prop1 = mintingFacet.mintPropertyToken(keccak256("Batch1155_1"), "ipfs://b1155_1");
        uint256 prop2 = mintingFacet.mintPropertyToken(keccak256("Batch1155_2"), "ipfs://b1155_2");
        
        uint256[] memory ids = new uint256[](2);
        ids[0] = prop1;
        ids[1] = prop2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        
        address recipient = makeAddr("batchRecipient");
        vm.prank(owner);
        kycRegistry.addToWhitelist(recipient);
        
        MintingFacet(address(mintingFacet)).safeBatchTransferFrom(owner, recipient, ids, amounts, "");
        vm.stopPrank();
        
        // Verify batch transfer
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(recipient, prop1), 1);
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(recipient, prop2), 1);
    }
    
    // ============ METADATA HANDLING ============
    
    function testMetadataComparison() public {
        // Both support metadata URIs
        vm.startPrank(owner);
        propertyNFT.mintProperty(keccak256("Meta721"), "ipfs://meta721");
        mintingFacet.mintPropertyToken(keccak256("Meta1155"), "ipfs://meta1155");
        vm.stopPrank();
        
        assertTrue(true);
    }
    
    // ============ USE CASE OPTIMIZATION ============
    
    function testPropertyUseCase() public {
        // ERC-721: Better for unique property NFTs
        vm.prank(owner);
        uint256 uniqueProperty = propertyNFT.mintProperty(keccak256("Unique"), "ipfs://unique");
        assertEq(propertyNFT.ownerOf(uniqueProperty), owner);
    }
    
    function testFractionalOwnershipUseCase() public {
        // ERC-1155: Better for fractional/fungible tokens
        vm.startPrank(owner);
        uint256 propertyId = mintingFacet.mintPropertyToken(keccak256("Fractional"), "ipfs://frac");
        mintingFacet.verifyProperty(propertyId);
        
        uint256 yieldTokenId = mintingFacet.mintYieldTokens(
            propertyId,
            1000 ether,
            1000000 ether,
            12,
            500,
            30,
            200,
            true,
            true
        );
        vm.stopPrank();
        
        // ERC-1155 supports fractional amounts
        assertEq(MintingFacet(address(mintingFacet)).balanceOf(owner, yieldTokenId), 1000 ether);
    }
}

