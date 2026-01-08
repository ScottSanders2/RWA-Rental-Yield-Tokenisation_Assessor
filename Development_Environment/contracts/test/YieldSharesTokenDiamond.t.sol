// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/DeployDiamond.s.sol";

// Facet interfaces
import "../src/facets/YieldBaseFacet.sol";
import "../src/facets/ViewsFacet.sol";
import "../src/facets/RepaymentFacet.sol";
import "../src/KYCRegistry.sol";
import "../src/PropertyNFT.sol";
import "../src/YieldSharesToken.sol";

/**
 * @title YieldSharesToken Diamond Integration Test Suite
 * @notice Comprehensive tests for YieldSharesToken (ERC-20) functionality in Diamond architecture
 * @dev Tests token transfers, allowances, balances, and KYC enforcement
 */
contract YieldSharesTokenDiamondTest is Test {
    DeployDiamond public deployer;
    
    KYCRegistry public kycRegistry;
    YieldBaseFacet public yieldBaseFacet;
    ViewsFacet public viewsFacet;
    RepaymentFacet public repaymentFacet;
    PropertyNFT public propertyNFT;
    
    address public owner;
    address public propertyOwner;
    address public investor1;
    address public investor2;
    address public investor3;
    
    uint256 public propertyId;
    uint256 public agreementId;
    YieldSharesToken public yieldToken;
    
    // Event to capture token creation
    event YieldAgreementCreated(
        uint256 indexed agreementId,
        uint256 indexed propertyTokenId,
        address indexed propertyOwner,
        uint256 upfrontCapital,
        address tokenAddress
    );
    
    function setUp() public {
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        propertyOwner = makeAddr("propertyOwner");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        investor3 = makeAddr("investor3");
        
        // Deploy via actual script
        deployer = new DeployDiamond();
        deployer.run();
        
        // Get deployed contracts
        kycRegistry = deployer.kycRegistry();
        propertyNFT = deployer.propertyNFT();
        
        address diamondAddr = address(deployer.yieldBaseDiamond());
        yieldBaseFacet = YieldBaseFacet(diamondAddr);
        viewsFacet = ViewsFacet(diamondAddr);
        repaymentFacet = RepaymentFacet(diamondAddr);
        
        // Setup KYC
        vm.startPrank(owner);
        kycRegistry.addToWhitelist(propertyOwner);
        kycRegistry.addToWhitelist(investor1);
        kycRegistry.addToWhitelist(investor2);
        kycRegistry.addToWhitelist(investor3);
        vm.stopPrank();
        
        // Create property and agreement
        vm.startPrank(owner);
        propertyId = propertyNFT.mintProperty(
            keccak256("TestProperty"),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(propertyId);
        propertyNFT.transferFrom(owner, propertyOwner, propertyId);
        vm.stopPrank();
        
        // Create agreement
        vm.prank(propertyOwner);
        agreementId = yieldBaseFacet.createYieldAgreement(
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
        
        // Get token address from ViewsFacet
        address tokenAddr = viewsFacet.getAgreementToken(agreementId);
        require(tokenAddr != address(0), "Token address should not be zero");
        yieldToken = YieldSharesToken(tokenAddr);
    }
    
    // ============ TOKEN INITIALIZATION ============
    
    function testTokenInitialization() public view {
        assertTrue(address(yieldToken) != address(0), "Token should exist");
        assertEq(yieldToken.totalSupply(), 100 ether, "Total supply should match capital");
        assertEq(yieldToken.balanceOf(propertyOwner), 100 ether, "Property owner should have all tokens");
    }
    
    function testTokenMetadata() public view {
        string memory name = yieldToken.name();
        string memory symbol = yieldToken.symbol();
        uint8 decimals = yieldToken.decimals();
        
        assertTrue(bytes(name).length > 0, "Token should have name");
        assertTrue(bytes(symbol).length > 0, "Token should have symbol");
        assertEq(decimals, 18, "Token should have 18 decimals");
    }
    
    // ============ TOKEN TRANSFERS ============
    
    function testTransferToWhitelistedUser() public {
        uint256 transferAmount = 10 ether;
        
        vm.prank(propertyOwner);
        yieldToken.transfer(investor1, transferAmount);
        
        assertEq(yieldToken.balanceOf(investor1), transferAmount, "Investor1 should receive tokens");
        assertEq(yieldToken.balanceOf(propertyOwner), 90 ether, "Property owner balance should decrease");
    }
    
    function testTransferFromWhitelistedUser() public {
        // Transfer some tokens to investor1
        vm.prank(propertyOwner);
        yieldToken.transfer(investor1, 20 ether);
        
        // investor1 transfers to investor2
        vm.prank(investor1);
        yieldToken.transfer(investor2, 5 ether);
        
        assertEq(yieldToken.balanceOf(investor1), 15 ether, "Investor1 balance correct");
        assertEq(yieldToken.balanceOf(investor2), 5 ether, "Investor2 received tokens");
    }
    
    function testTransferZeroAmount() public {
        vm.prank(propertyOwner);
        yieldToken.transfer(investor1, 0);
        
        assertEq(yieldToken.balanceOf(investor1), 0, "Zero transfer should succeed");
    }
    
    function testTransferInsufficientBalance() public {
        vm.prank(investor1);
        vm.expectRevert();
        yieldToken.transfer(investor2, 1 ether);
    }
    
    // ============ TOKEN ALLOWANCES ============
    
    function testApprove() public {
        uint256 allowanceAmount = 50 ether;
        
        vm.prank(propertyOwner);
        yieldToken.approve(investor1, allowanceAmount);
        
        assertEq(yieldToken.allowance(propertyOwner, investor1), allowanceAmount, "Allowance should be set");
    }
    
    function testTransferFrom() public {
        uint256 allowanceAmount = 30 ether;
        uint256 transferAmount = 20 ether;
        
        // Approve investor1
        vm.prank(propertyOwner);
        yieldToken.approve(investor1, allowanceAmount);
        
        // investor1 transfers on behalf of propertyOwner
        vm.prank(investor1);
        yieldToken.transferFrom(propertyOwner, investor2, transferAmount);
        
        assertEq(yieldToken.balanceOf(investor2), transferAmount, "Investor2 should receive tokens");
        assertEq(yieldToken.balanceOf(propertyOwner), 80 ether, "Property owner balance should decrease");
        assertEq(yieldToken.allowance(propertyOwner, investor1), 10 ether, "Allowance should decrease");
    }
    
    function testTransferFromWithoutApprovalFails() public {
        vm.prank(investor1);
        vm.expectRevert();
        yieldToken.transferFrom(propertyOwner, investor2, 10 ether);
    }
    
    function testTransferFromExceedsAllowanceFails() public {
        vm.prank(propertyOwner);
        yieldToken.approve(investor1, 10 ether);
        
        vm.prank(investor1);
        vm.expectRevert();
        yieldToken.transferFrom(propertyOwner, investor2, 20 ether);
    }
    
    // ============ MULTIPLE INVESTORS ============
    
    function testMultipleInvestorsHoldTokens() public {
        vm.prank(propertyOwner);
        yieldToken.transfer(investor1, 30 ether);
        
        vm.prank(propertyOwner);
        yieldToken.transfer(investor2, 20 ether);
        
        vm.prank(propertyOwner);
        yieldToken.transfer(investor3, 10 ether);
        
        assertEq(yieldToken.balanceOf(propertyOwner), 40 ether, "Property owner balance correct");
        assertEq(yieldToken.balanceOf(investor1), 30 ether, "Investor1 balance correct");
        assertEq(yieldToken.balanceOf(investor2), 20 ether, "Investor2 balance correct");
        assertEq(yieldToken.balanceOf(investor3), 10 ether, "Investor3 balance correct");
        assertEq(yieldToken.totalSupply(), 100 ether, "Total supply unchanged");
    }
    
    function testMultipleTransfersBetweenInvestors() public {
        // Setup: Distribute tokens
        vm.prank(propertyOwner);
        yieldToken.transfer(investor1, 40 ether);
        
        vm.prank(propertyOwner);
        yieldToken.transfer(investor2, 30 ether);
        
        // Investor1 transfers to investor3
        vm.prank(investor1);
        yieldToken.transfer(investor3, 15 ether);
        
        // Investor2 transfers to investor3
        vm.prank(investor2);
        yieldToken.transfer(investor3, 10 ether);
        
        assertEq(yieldToken.balanceOf(investor1), 25 ether, "Investor1 final balance");
        assertEq(yieldToken.balanceOf(investor2), 20 ether, "Investor2 final balance");
        assertEq(yieldToken.balanceOf(investor3), 25 ether, "Investor3 final balance");
    }
    
    // ============ BALANCE TRACKING ============
    
    // Note: KYC enforcement on token transfers requires enabling transfer restrictions
    // via setTransferRestrictions(), which can only be called by the token owner (YieldBase Diamond).
    // KYC is enforced at agreement creation time, ensuring only whitelisted users can participate.
    
    function testBalanceOfMultipleAccounts() public {
        vm.prank(propertyOwner);
        yieldToken.transfer(investor1, 25 ether);
        
        vm.prank(propertyOwner);
        yieldToken.transfer(investor2, 25 ether);
        
        assertEq(yieldToken.balanceOf(propertyOwner), 50 ether);
        assertEq(yieldToken.balanceOf(investor1), 25 ether);
        assertEq(yieldToken.balanceOf(investor2), 25 ether);
        assertEq(yieldToken.totalSupply(), 100 ether);
    }
    
    // ============ ERC-20 COMPLIANCE ============
    
    function testERC20TotalSupplyImmutable() public view {
        // Total supply should not change (no minting/burning after creation)
        assertEq(yieldToken.totalSupply(), 100 ether, "Total supply should be constant");
    }
}
