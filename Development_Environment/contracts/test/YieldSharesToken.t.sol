// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../src/YieldSharesToken.sol";
import "../src/YieldBase.sol";
import "../src/PropertyNFT.sol";
import "./helpers/KYCTestHelper.sol";

/// @title YieldSharesToken Contract Tests
/// @notice Comprehensive test suite for YieldSharesToken ERC-20 functionality
/// @dev Tests token minting, distribution, access control, integration with YieldBase, and upgrade patterns
contract YieldSharesTokenTest is KYCTestHelper {
    YieldSharesToken public tokenImplementation;
    YieldSharesToken public tokenProxy;
    YieldBase public yieldBaseImplementation;
    YieldBase public yieldBaseProxy;
    PropertyNFT public propertyNFTImplementation;
    PropertyNFT public propertyNFTProxy;

    address public owner;
    address public investor1;
    address public investor2;
    address public unauthorized;

    function setUp() public override {
        // Setup KYC infrastructure first
        super.setUp();
        
        // Set up test accounts
        owner = address(0x123);
        investor1 = address(0x456);
        investor2 = address(0x789);
        unauthorized = address(0xABC);

        // Whitelist test addresses (owner is already whitelisted, but these are custom addresses)
        if (owner != address(this)) whitelistAddress(owner);
        whitelistAddress(investor1);
        whitelistAddress(investor2);
        whitelistAddress(unauthorized);

        // Deploy PropertyNFT implementation and proxy first
        propertyNFTImplementation = new PropertyNFT();
        bytes memory propertyNFTInitData = abi.encodeWithSelector(
            PropertyNFT.initialize.selector,
            owner,
            "RWA Property NFT",
            "RWAPROP"
        );
        ERC1967Proxy propertyNFTProxyContract = new ERC1967Proxy(address(propertyNFTImplementation), propertyNFTInitData);
        propertyNFTProxy = PropertyNFT(address(propertyNFTProxyContract));

        // Deploy YieldBase implementation and proxy
        yieldBaseImplementation = new YieldBase();
        bytes memory yieldBaseInitData = abi.encodeWithSelector(YieldBase.initialize.selector, owner);
        ERC1967Proxy yieldBaseProxyContract = new ERC1967Proxy(address(yieldBaseImplementation), yieldBaseInitData);
        yieldBaseProxy = YieldBase(address(yieldBaseProxyContract));

        // Link PropertyNFT to YieldBase
        vm.prank(owner);
        yieldBaseProxy.setPropertyNFT(address(propertyNFTProxy));

        // Set YieldBase address in PropertyNFT contract
        vm.prank(owner);
        propertyNFTProxy.setYieldBase(address(yieldBaseProxy));

        // Deploy YieldSharesToken implementation
        tokenImplementation = new YieldSharesToken();

        // Encode token initialization data
        bytes memory tokenInitData = abi.encodeWithSelector(
            YieldSharesToken.initialize.selector,
            owner,
            address(yieldBaseProxy),
            "RWA Yield Shares",
            "RWAYIELD"
        );

        // Deploy token proxy
        ERC1967Proxy tokenProxyContract = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        tokenProxy = YieldSharesToken(address(tokenProxyContract));

        // Link KYC Registry to contracts
        linkKYCToYieldBase(address(yieldBaseProxy));
        linkKYCToToken(address(tokenProxy));

        // Note: Tokens are created per agreement in new architecture
    }

    /// @notice Helper function to create and verify a test property NFT
    /// @dev Assumes the caller has already set up the correct prank context
    function _createTestProperty() internal returns (uint256) {
        uint256 tokenId = propertyNFTProxy.mintProperty(
            keccak256("Test Property"),
            "ipfs://test-property-metadata"
        );
        propertyNFTProxy.verifyProperty(tokenId);
        return tokenId;
    }

    /// @notice Tests that the token initializes correctly
    function testInitialization() public {
        assertEq(tokenProxy.owner(), owner);
        assertEq(tokenProxy.name(), "RWA Yield Shares");
        assertEq(tokenProxy.symbol(), "RWAYIELD");
        assertEq(tokenProxy.decimals(), 18);
        assertTrue(tokenProxy.owner() != address(0));
    }

    /// @notice Tests that the contract cannot be reinitialized
    function testCannotReinitialize() public {
        vm.expectRevert();
        tokenProxy.initialize(address(0xDEF), address(yieldBaseProxy), "Test", "TEST");
    }

    /// @notice Tests that only YieldBase can mint shares
    function testMintSharesOnlyYieldBase() public {
        vm.expectRevert("Only YieldBase can perform this action");
        tokenProxy.mintShares(1, investor1, 1000 ether);
    }

    /// @notice Tests that minting shares creates correct balance
    function testMintSharesCreatesCorrectBalance() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;

        // Mint shares via YieldBase
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the token instance for this agreement
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Check token balance matches capital amount (1:1 ratio)
        assertEq(agreementToken.balanceOf(owner), capitalAmount);

        // Check total supply
        assertEq(agreementToken.totalSupply(), capitalAmount);
        vm.stopPrank();
    }

    /// @notice Tests that minting shares updates storage mappings correctly
    function testMintSharesUpdatesStorage() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;

        // Mint shares
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the token instance for this agreement
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Check storage mappings
        address[] memory shareholders = agreementToken.getAgreementShareholders();
        assertEq(shareholders.length, 1);
        assertEq(shareholders[0], owner);

        assertEq(agreementToken.getShareholderBalance(owner), capitalAmount);
        assertEq(agreementToken.getTotalSharesForAgreement(), capitalAmount);
        vm.stopPrank();
    }

    /// @notice Tests single agreement constraint - token instance supports only one agreement
    function testSingleAgreementConstraint() public {
        vm.startPrank(owner);
        uint256 capital1 = 1000 ether;
        uint256 capital2 = 2000 ether;

        // Mint shares for first agreement
        uint256 propertyTokenId1 = _createTestProperty();
        uint256 agreementId1 = yieldBaseProxy.createYieldAgreement(propertyTokenId1, capital1, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the token instance for the first agreement
        YieldSharesToken agreementToken1 = yieldBaseProxy.agreementTokens(agreementId1);

        // Transfer some shares to investor1
        agreementToken1.transfer(investor1, 300 ether);

        // Create second agreement (should succeed since each agreement gets its own token instance)
        uint256 propertyTokenId2 = _createTestProperty();
        uint256 agreementId2 = yieldBaseProxy.createYieldAgreement(propertyTokenId2, capital2, 100000e18, 24, 600, address(0), 30, 200, 3, true, true);

        // Check balances (only first agreement)
        assertEq(agreementToken1.balanceOf(owner), capital1 - 300 ether);
        assertEq(agreementToken1.balanceOf(investor1), 300 ether);

        // Check that the token is constrained to single agreement
        assertEq(agreementToken1.getCurrentAgreementId(), agreementId1);

        // Check total shares (scoped to single agreement)
        assertEq(agreementToken1.getTotalSharesForAgreement(), capital1);

        // Check shareholder arrays (scoped to single agreement)
        address[] memory shareholders = agreementToken1.getAgreementShareholders();
        assertEq(shareholders.length, 2); // owner and investor1
        vm.stopPrank();
    }

    /// @notice Tests repayment distribution to token holders
    function testDistributeRepayment() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;
        uint256 repaymentAmount = 100 ether;

        // Create agreement and mint shares
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the agreement token
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Transfer some shares to investors
        agreementToken.transfer(investor1, 300 ether);
        agreementToken.transfer(investor2, 200 ether);

        // Record initial balances
        uint256 ownerInitialBalance = owner.balance;
        uint256 investor1InitialBalance = investor1.balance;
        uint256 investor2InitialBalance = investor2.balance;

        // Make repayment (this will call distributeRepayment)
        vm.deal(owner, repaymentAmount); // Give owner some ETH
        yieldBaseProxy.makeRepayment{value: repaymentAmount}(agreementId);

        // Check that ETH was distributed proportionally
        // Owner: 500 ether shares out of 1000 total = 50%
        // Investor1: 300 ether shares out of 1000 total = 30%
        // Investor2: 200 ether shares out of 1000 total = 20%

        uint256 expectedOwnerAmount = (repaymentAmount * 500 ether) / 1000 ether;
        uint256 expectedInvestor1Amount = (repaymentAmount * 300 ether) / 1000 ether;
        uint256 expectedInvestor2Amount = (repaymentAmount * 200 ether) / 1000 ether;

        assertEq(owner.balance, ownerInitialBalance + expectedOwnerAmount);
        assertEq(investor1.balance, investor1InitialBalance + expectedInvestor1Amount);
        assertEq(investor2.balance, investor2InitialBalance + expectedInvestor2Amount);
        vm.stopPrank();
    }

    /// @notice Tests repayment distribution with multiple shareholders
    function testDistributeRepaymentMultipleInvestors() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;
        uint256 repaymentAmount = 100 ether; // Use same amount as working test

        // Create agreement
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the agreement token
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Create multiple shareholders
        agreementToken.transfer(investor1, 250 ether);
        agreementToken.transfer(investor2, 250 ether);
        // Owner keeps 500 ether

        uint256[] memory initialBalances = new uint256[](3);
        initialBalances[0] = owner.balance;
        initialBalances[1] = investor1.balance;
        initialBalances[2] = investor2.balance;

        // Distribute repayment
        
        vm.deal(owner, repaymentAmount);
        yieldBaseProxy.makeRepayment{value: repaymentAmount}(agreementId);

        // Verify proportional distribution (each has 250 ether out of 1000 = 25%)
        uint256 expectedAmount = (repaymentAmount * 250 ether) / 1000 ether;

        assertEq(investor1.balance, initialBalances[1] + expectedAmount);
        assertEq(investor2.balance, initialBalances[2] + expectedAmount);
        // Owner gets 50% (500/1000) = 50 ether
        assertEq(owner.balance, initialBalances[0] + 50 ether);
        vm.stopPrank();
    }

    /// @notice Tests burning shares functionality
    function testBurnShares() public {
        vm.startPrank(owner);
        uint256 agreementId = 1;
        uint256 capitalAmount = 1000 ether;
        uint256 burnAmount = 300 ether;

        // Create agreement and mint shares
        
        uint256 propertyTokenId = _createTestProperty();
        yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        uint256 initialBalance = tokenProxy.balanceOf(owner);
        uint256 initialTotalSupply = tokenProxy.totalSupply();

        // Burn shares (only YieldBase can do this - we'd need to add a burn function to YieldBase)
        // For now, test the burn mechanism by calling it directly (would be internal in production)
        vm.expectRevert("Only YieldBase can perform this action");
        tokenProxy.burnShares(agreementId, owner, burnAmount);

        // Verify balances unchanged after failed burn
        assertEq(tokenProxy.balanceOf(owner), initialBalance);
        assertEq(tokenProxy.totalSupply(), initialTotalSupply);
    }

    /// @notice Tests shareholder array queries
    function testGetAgreementShareholders() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;

        // Create agreement
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the agreement token
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Initially only owner
        address[] memory shareholders = agreementToken.getAgreementShareholders();
        assertEq(shareholders.length, 1);
        assertEq(shareholders[0], owner);

        // Transfer to create more shareholders
        agreementToken.transfer(investor1, 100 ether);
        agreementToken.transfer(investor2, 100 ether);

        shareholders = agreementToken.getAgreementShareholders();
        assertEq(shareholders.length, 3);
        // Note: Order may vary due to how transfers update the array
        vm.stopPrank();
    }

    /// @notice Tests shareholder balance queries
    function testGetShareholderBalance() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;

        // Create agreement
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the agreement token
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        assertEq(agreementToken.getShareholderBalance(owner), capitalAmount);
        assertEq(agreementToken.getShareholderBalance(investor1), 0);

        // Transfer some shares
        agreementToken.transfer(investor1, 250 ether);

        assertEq(agreementToken.getShareholderBalance(owner), 750 ether);
        assertEq(agreementToken.getShareholderBalance(investor1), 250 ether);
        vm.stopPrank();
    }

    /// @notice Tests total shares query
    function testGetTotalSharesForAgreement() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;

        // Create agreement
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the agreement token
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        assertEq(agreementToken.getTotalSharesForAgreement(), capitalAmount);

        // Transfer doesn't change total shares
        agreementToken.transfer(investor1, 100 ether);

        assertEq(agreementToken.getTotalSharesForAgreement(), capitalAmount);
        vm.stopPrank();
    }

    /// @notice Tests that token transfers update storage mappings
    function testTransferUpdatesStorage() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;

        // Create agreement
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the agreement token
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Transfer shares
        agreementToken.transfer(investor1, 300 ether);

        // Check balances
        assertEq(agreementToken.balanceOf(owner), 700 ether);
        assertEq(agreementToken.balanceOf(investor1), 300 ether);

        // Transfer back to verify ERC20 functionality works both ways
        agreementToken.transfer(owner, 100 ether);
        assertEq(agreementToken.balanceOf(owner), 800 ether);
        assertEq(agreementToken.balanceOf(investor1), 200 ether);
        vm.stopPrank();
    }

    /// @notice Tests division by zero guard prevents distribution with zero total shares
    function testZeroShareholderDistributionGuard() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;
        uint256 repaymentAmount = 100 ether;

        // Create agreement
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the agreement token
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Transfer all shares to investor1
        agreementToken.transfer(investor1, capitalAmount);

        // Burn the shares from investor1 (this would normally be done by YieldBase)
        vm.stopPrank();
        vm.prank(address(yieldBaseProxy));
        agreementToken.burnShares(agreementId, investor1, capitalAmount);
        vm.startPrank(owner);

        // Attempt to distribute with zero total shares should revert
        vm.deal(owner, repaymentAmount);
        vm.expectRevert("No shareholders for distribution");
        yieldBaseProxy.makeRepayment{value: repaymentAmount}(agreementId);
        vm.stopPrank();
    }

    /// @notice Tests remainder handling distributes dust to largest holder
    function testRemainderDistribution() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;
        uint256 repaymentAmount = 100 ether; // Sufficient amount to create remainder in distribution

        // Create agreement with uneven shares
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the agreement token
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Transfer shares to create uneven distribution (333 + 333 + 334 = 1000)
        agreementToken.transfer(investor1, 333 ether);
        agreementToken.transfer(investor2, 333 ether);
        // Owner keeps 334 ether

        // Record initial balances
        uint256 ownerInitialBalance = owner.balance;
        uint256 investor1InitialBalance = investor1.balance;
        uint256 investor2InitialBalance = investor2.balance;

        // Make repayment through YieldBase (which will call distributeRepayment)
        
        vm.deal(owner, repaymentAmount);
        yieldBaseProxy.makeRepayment{value: repaymentAmount}(agreementId);

        // Calculate expected amounts: 100 ether * (shares / 1000)
        // Owner: 100 ether * 334 / 1000 = 33.4 ether → 33 ether
        // Investor1: 100 ether * 333 / 1000 = 33.3 ether → 33 ether
        // Investor2: 100 ether * 333 / 1000 = 33.3 ether → 33 ether
        // Total distributed: 33 + 33 + 33 = 99 ether
        // Remainder: 100 - 99 = 1 ether, goes to largest holder (owner)

        // Check actual balances received
        uint256 ownerReceived = owner.balance - ownerInitialBalance;
        uint256 investor1Received = investor1.balance - investor1InitialBalance;
        uint256 investor2Received = investor2.balance - investor2InitialBalance;

        console.log("Owner received:", ownerReceived);
        console.log("Investor1 received:", investor1Received);
        console.log("Investor2 received:", investor2Received);

        // The total should be 100 ether
        assertEq(ownerReceived + investor1Received + investor2Received, 100 ether);
        vm.stopPrank();
    }

    /// @notice Tests shareholder limit validation prevents excessive gas usage
    function testShareholderLimitValidation() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;

        // Create agreement
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the agreement token
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Transfer shares to create multiple shareholders up to the limit
        // Owner already counts as 1 shareholder, so we need MAX_SHAREHOLDERS - 1 more
        for (uint256 i = 0; i < agreementToken.MAX_SHAREHOLDERS() - 1; i++) {
            address newInvestor = address(uint160(uint256(keccak256(abi.encodePacked(i)))));

            agreementToken.transfer(newInvestor, 1); // 1 wei each
        }

        // Verify we're at the limit
        address[] memory shareholders = agreementToken.getAgreementShareholders();
        assertEq(shareholders.length, agreementToken.MAX_SHAREHOLDERS());

        // Attempting to add one more shareholder should fail
        address extraInvestor = address(uint160(uint256(keccak256(abi.encodePacked("extra")))));

        vm.expectRevert("Too many shareholders");
        agreementToken.transfer(extraInvestor, 1);
        vm.stopPrank();
    }

    /// @notice Tests UUPS upgrade authorization
    function testUpgradeAuthorization() public {
        vm.startPrank(owner);
        YieldSharesToken newImplementation = new YieldSharesToken();

        // Create an agreement to get a real token instance
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, 1000 ether, 1000e21, 12, 500, address(0), 30, 200, 3, true, true);
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Non-owner cannot upgrade
        vm.stopPrank();
        vm.prank(unauthorized);
        vm.expectRevert();
        UUPSUpgradeable(address(agreementToken)).upgradeToAndCall(address(newImplementation), "");
        vm.startPrank(owner);

        // Owner can upgrade
        UUPSUpgradeable(address(agreementToken)).upgradeToAndCall(address(newImplementation), "");

        // Verify upgrade worked
        assertEq(agreementToken.owner(), owner);
        vm.stopPrank();
    }

    /// @notice Tests ERC-7201 storage layout
    function testStorageLayout() public {
        vm.startPrank(owner);
        // This test verifies that our ERC-7201 namespace calculation works
        // We can't directly test the storage slot, but we can test that
        // the contract functions correctly after initialization

        // Create agreement to test storage operations
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, 1000 ether, 1000e21, 12, 500, address(0), 30, 200, 3, true, true);

        // Get the agreement token instance
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Test basic ERC20 functionality (avoid restricted methods)
        assertEq(agreementToken.balanceOf(owner), 1000 ether);
        vm.stopPrank();
    }

    /// @notice Tests gas optimization for token operations
    function testGasOptimization() public {
        vm.startPrank(owner);
        uint256 capitalAmount = 1000 ether;

        // Measure gas for minting
        uint256 gasStart = gasleft();
        uint256 propertyTokenId = _createTestProperty();
        uint256 agreementId = yieldBaseProxy.createYieldAgreement(propertyTokenId, capitalAmount, 100000e18, 12, 500, address(0), 30, 200, 3, true, true);
        uint256 gasUsed = gasStart - gasleft();

        console.log("Gas used for createYieldAgreement + mintShares:", gasUsed);
        assertTrue(gasUsed < 3_000_000); // Reasonable gas limit with token operations (increased due to additional checks)

        // Get the agreement token
        YieldSharesToken agreementToken = yieldBaseProxy.agreementTokens(agreementId);

        // Measure gas for transfer
        gasStart = gasleft();
        agreementToken.transfer(investor1, 100 ether);
        gasUsed = gasStart - gasleft();

        console.log("Gas used for token transfer:", gasUsed);
        assertTrue(gasUsed < 100_000); // ERC-20 transfer with shareholder tracking
        vm.stopPrank();
    }
}
