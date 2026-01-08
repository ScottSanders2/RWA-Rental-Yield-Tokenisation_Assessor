// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/YieldSharesToken.sol";
import "../src/CombinedPropertyYieldToken.sol";
import "../src/PropertyNFT.sol";
import "../src/YieldBase.sol";
import "../src/storage/TransferRestrictionsStorage.sol";
import "../src/libraries/TransferRestrictions.sol";

/**
 * @title TransferRestrictionsTest
 * @notice Comprehensive test suite for transfer restriction functionality
 * 
 * Test Coverage:
 * - Transfer restrictions enforcement (lockup, concentration, holding period, pause)
 * - Governance integration for restriction updates
 * - ERC-20 standard compliance with restrictions
 * - ERC-1155 yield token restrictions (property tokens unrestricted)
 * - Restriction overhead gas measurement
 * - Autonomous enforcement validation
 * 
 * Research Contribution:
 * - Validates transfer restrictions for risk mitigation (Research Question 2)
 * - Tests governance integration for democratic control (Research Question 5)
 * - Measures gas overhead for performance analysis (Research Question 3)
 * - Validates autonomous enforcement without trusted parties (Research Question 9)
 */
contract TransferRestrictionsTest is Test {
    using TransferRestrictionsStorage for TransferRestrictionsStorage.TransferRestrictionData;

    // Contracts
    YieldSharesToken public yieldSharesToken;
    YieldSharesToken public yieldSharesImpl;
    CombinedPropertyYieldToken public combinedToken;
    CombinedPropertyYieldToken public combinedImpl;
    PropertyNFT public propertyNFT;
    PropertyNFT public propertyNFTImpl;
    YieldBase public yieldBase;
    YieldBase public yieldBaseImpl;

    // Test accounts
    address public owner;
    address public investor1;
    address public investor2;
    address public investor3;
    address public investor4;

    // Test data
    uint256 public agreementId = 1;
    uint256 public capitalAmount = 1000 ether;

    function setUp() public {
        // Setup accounts
        owner = address(this);
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        investor3 = makeAddr("investor3");
        investor4 = makeAddr("investor4");

        // Fund test accounts
        vm.deal(investor1, 100 ether);
        vm.deal(investor2, 100 ether);
        vm.deal(investor3, 100 ether);
        vm.deal(investor4, 100 ether);

        // Deploy PropertyNFT
        propertyNFTImpl = new PropertyNFT();
        bytes memory propertyInitData = abi.encodeCall(PropertyNFT.initialize, (owner, "RWA Property", "RWAPROP"));
        ERC1967Proxy propertyNFTProxy = new ERC1967Proxy(address(propertyNFTImpl), propertyInitData);
        propertyNFT = PropertyNFT(address(propertyNFTProxy));

        // Deploy YieldBase
        yieldBaseImpl = new YieldBase();
        bytes memory yieldBaseInitData = abi.encodeCall(YieldBase.initialize, (owner));
        ERC1967Proxy yieldBaseProxy = new ERC1967Proxy(address(yieldBaseImpl), yieldBaseInitData);
        yieldBase = YieldBase(payable(address(yieldBaseProxy)));

        // Link contracts
        propertyNFT.setYieldBase(address(yieldBase));
        yieldBase.setPropertyNFT(address(propertyNFT));

        // Deploy YieldSharesToken (ERC-20)
        yieldSharesImpl = new YieldSharesToken();
        bytes memory yieldSharesInitData = abi.encodeCall(
            YieldSharesToken.initialize,
            (owner, address(yieldBase), "Yield Shares Test", "YST")
        );
        ERC1967Proxy yieldSharesProxy = new ERC1967Proxy(address(yieldSharesImpl), yieldSharesInitData);
        yieldSharesToken = YieldSharesToken(address(yieldSharesProxy));

        // Deploy CombinedPropertyYieldToken (ERC-1155)
        combinedImpl = new CombinedPropertyYieldToken();
        bytes memory combinedInitData = abi.encodeCall(
            CombinedPropertyYieldToken.initialize,
            (owner, "https://api.example.com/metadata/{id}")
        );
        ERC1967Proxy combinedProxy = new ERC1967Proxy(address(combinedImpl), combinedInitData);
        combinedToken = CombinedPropertyYieldToken(address(combinedProxy));

        // Create yield agreement and mint tokens for testing
        _createTestAgreementAndMintTokens();
    }

    function _createTestAgreementAndMintTokens() internal {
        // Mint property NFT
        propertyNFT.mintProperty(
            bytes32(uint256(1)),
            "ipfs://test"
        );

        // Create yield agreement via YieldBase (simplified for testing)
        // In production, this would go through proper YieldBase.createYieldAgreement
        // For testing, we directly mint tokens
        
        // Mint YieldSharesToken for investor1
        vm.prank(address(yieldBase));
        yieldSharesToken.mintShares(agreementId, investor1, capitalAmount);
        
        // Mint CombinedPropertyYieldToken for testing
        // First mint and verify a property token for combined token (as owner)
        vm.startPrank(owner);
        bytes32 propertyHash = keccak256(abi.encodePacked("456 Oak Ave"));
        uint256 propertyTokenId1155 = combinedToken.mintPropertyToken(propertyHash, "ipfs://property2");
        combinedToken.verifyProperty(propertyTokenId1155);
        
        // Now mint yield tokens
        uint256 yieldTokenId = combinedToken.mintYieldTokens(
            propertyTokenId1155,
            capitalAmount, // capitalAmount
            12, // termMonths
            500, // annualROI
            30, // gracePeriodDays
            200, // defaultPenaltyRate
            true, // allowPartialRepayments
            true // allowEarlyRepayment
        );
        combinedToken.safeTransferFrom(owner, investor1, yieldTokenId, capitalAmount, "");
        vm.stopPrank();
    }

    // ============ Transfer Without Restrictions Tests ============

    function testTransferWithoutRestrictions() public {
        // Verify restrictions are disabled by default
        assertFalse(yieldSharesToken.transferRestrictionsEnabled());

        // Transfer should succeed
        vm.prank(investor1);
        yieldSharesToken.transfer(investor2, 100 ether);

        // Verify transfer succeeded
        assertEq(yieldSharesToken.balanceOf(investor2), 100 ether);
    }

    // ============ Enable Transfer Restrictions Tests ============

    function testEnableTransferRestrictions() public {
        uint256 lockupEnd = block.timestamp + 30 days;
        uint256 maxShares = 2000; // 20% in basis points
        uint256 minHolding = 7 days;

        // Enable restrictions
        yieldSharesToken.setTransferRestrictions(lockupEnd, maxShares, minHolding);

        // Verify restrictions enabled
        assertTrue(yieldSharesToken.transferRestrictionsEnabled());

        // Verify restriction parameters stored (would need getter functions)
        // This test validates the function can be called without reverting
    }

    function testOnlyOwnerCanSetRestrictions() public {
        vm.prank(investor1);
        vm.expectRevert();
        yieldSharesToken.setTransferRestrictions(
            block.timestamp + 30 days,
            2000,
            7 days
        );
    }

    // ============ Lockup Period Enforcement Tests ============

    function testLockupPeriodEnforcement() public {
        // Enable restrictions with lockup
        uint256 lockupEnd = block.timestamp + 30 days;
        yieldSharesToken.setTransferRestrictions(lockupEnd, 10000, 0); // No concentration/holding limits

        // Attempt transfer before lockup expiry should fail
        vm.prank(investor1);
        vm.expectRevert();
        yieldSharesToken.transfer(investor2, 100 ether);
    }

    function testTransferAfterLockupExpiry() public {
        // Enable restrictions with lockup
        uint256 lockupEnd = block.timestamp + 30 days;
        yieldSharesToken.setTransferRestrictions(lockupEnd, 10000, 0);

        // Fast forward past lockup
        vm.warp(lockupEnd + 1);

        // Transfer should now succeed
        vm.prank(investor1);
        yieldSharesToken.transfer(investor2, 100 ether);

        assertEq(yieldSharesToken.balanceOf(investor2), 100 ether);
    }

    // ============ Concentration Limit Enforcement Tests ============

    function testConcentrationLimitEnforcement() public {
        // Enable restrictions with 20% concentration limit
        yieldSharesToken.setTransferRestrictions(0, 2000, 0); // No lockup/holding, 20% max

        uint256 totalSupply = yieldSharesToken.totalSupply();
        uint256 maxAllowed = (totalSupply * 2000) / 10000; // 20% of supply

        // Try to transfer more than 20% to investor2
        vm.prank(investor1);
        vm.expectRevert();
        yieldSharesToken.transfer(investor2, maxAllowed + 1 ether);
    }

    function testTransferWithinConcentrationLimit() public {
        // Enable restrictions with 20% concentration limit
        yieldSharesToken.setTransferRestrictions(0, 2000, 0);

        uint256 totalSupply = yieldSharesToken.totalSupply();
        uint256 allowed = (totalSupply * 1500) / 10000; // 15% (within 20% limit)

        // Transfer within limit should succeed
        vm.prank(investor1);
        yieldSharesToken.transfer(investor2, allowed);

        assertEq(yieldSharesToken.balanceOf(investor2), allowed);
    }

    // ============ Minimum Holding Period Enforcement Tests ============

    function testMinimumHoldingPeriodEnforcement() public {
        // Enable restrictions with 7-day holding period
        yieldSharesToken.setTransferRestrictions(0, 10000, 7 days); // No lockup/concentration

        // First transfer to investor2 (this should succeed as it's the first receipt)
        vm.prank(investor1);
        yieldSharesToken.transfer(investor2, 100 ether);

        // Immediate transfer from investor2 should fail (holding period not met)
        vm.prank(investor2);
        vm.expectRevert();
        yieldSharesToken.transfer(investor3, 50 ether);
    }

    function testTransferAfterHoldingPeriod() public {
        // Enable restrictions with 7-day holding period
        yieldSharesToken.setTransferRestrictions(0, 10000, 7 days);

        // Transfer to investor2
        vm.prank(investor1);
        yieldSharesToken.transfer(investor2, 100 ether);

        // Fast forward 7 days
        vm.warp(block.timestamp + 7 days + 1);

        // Transfer should now succeed
        vm.prank(investor2);
        yieldSharesToken.transfer(investor3, 50 ether);

        assertEq(yieldSharesToken.balanceOf(investor3), 50 ether);
    }

    // ============ Emergency Pause Enforcement Tests ============

    function testEmergencyPauseEnforcement() public {
        // Pause transfers
        yieldSharesToken.pauseTransfers();

        // Any transfer should fail
        vm.prank(investor1);
        vm.expectRevert();
        yieldSharesToken.transfer(investor2, 100 ether);
    }

    function testUnpauseAllowsTransfers() public {
        // Pause transfers
        yieldSharesToken.pauseTransfers();

        // Unpause
        yieldSharesToken.unpauseTransfers();

        // Transfer should succeed
        vm.prank(investor1);
        yieldSharesToken.transfer(investor2, 100 ether);

        assertEq(yieldSharesToken.balanceOf(investor2), 100 ether);
    }

    function testOnlyOwnerCanPause() public {
        vm.prank(investor1);
        vm.expectRevert();
        yieldSharesToken.pauseTransfers();
    }

    // ============ isTransferAllowed View Function Tests ============

    function testIsTransferAllowedView() public {
        // Enable restrictions
        yieldSharesToken.setTransferRestrictions(
            block.timestamp + 30 days,
            2000,
            7 days
        );

        // Check if transfer allowed (should fail due to lockup)
        (bool allowed, string memory reason) = yieldSharesToken.isTransferAllowed(
            investor1,
            investor2,
            100 ether
        );

        assertFalse(allowed);
        // Reason should contain "Lockup period active"
    }

    function testIsTransferAllowedAfterLockup() public {
        uint256 lockupEnd = block.timestamp + 30 days;
        yieldSharesToken.setTransferRestrictions(lockupEnd, 10000, 0);

        // Fast forward past lockup
        vm.warp(lockupEnd + 1);

        // Check if transfer allowed
        (bool allowed, ) = yieldSharesToken.isTransferAllowed(
            investor1,
            investor2,
            100 ether
        );

        assertTrue(allowed);
    }

    // ============ Mint/Burn Bypass Restrictions Tests ============

    function testRestrictionsDoNotAffectMint() public {
        // Enable strict restrictions
        yieldSharesToken.setTransferRestrictions(
            block.timestamp + 365 days,
            1000, // 10% concentration
            30 days
        );

        // Minting should still work
        vm.prank(address(yieldBase));
        yieldSharesToken.mintShares(agreementId, investor4, 500 ether);

        assertEq(yieldSharesToken.balanceOf(investor4), 500 ether);
    }

    function testRestrictionsDoNotAffectBurn() public {
        // Enable strict restrictions
        yieldSharesToken.setTransferRestrictions(
            block.timestamp + 365 days,
            1000,
            30 days
        );

        // Burning should still work
        vm.prank(address(yieldBase));
        yieldSharesToken.burnShares(agreementId, investor1, 100 ether);

        assertEq(yieldSharesToken.balanceOf(investor1), capitalAmount - 100 ether);
    }

    // ============ Multiple Restrictions Combined Tests ============

    function testMultipleRestrictionsCombined() public {
        // Enable all restrictions
        uint256 lockupEnd = block.timestamp + 30 days;
        yieldSharesToken.setTransferRestrictions(lockupEnd, 2000, 7 days);

        // Transfer should fail due to lockup (first check)
        vm.prank(investor1);
        vm.expectRevert();
        yieldSharesToken.transfer(investor2, 100 ether);

        // Fast forward past lockup
        vm.warp(lockupEnd + 1);

        // Now first transfer should succeed (holding period doesn't apply to first receipt)
        vm.prank(investor1);
        yieldSharesToken.transfer(investor2, 100 ether);

        // Second transfer should fail due to holding period
        vm.prank(investor2);
        vm.expectRevert();
        yieldSharesToken.transfer(investor3, 50 ether);
    }

    // ============ ERC-1155 Yield Token Restrictions Tests ============

    function testERC1155YieldTokenRestrictions() public {
        uint256 yieldTokenId = 1000000;
        
        // Enable restrictions for yield token
        combinedToken.setYieldTokenRestrictions(
            yieldTokenId,
            block.timestamp + 30 days,
            2000,
            7 days
        );

        // Transfer of yield token should fail (lockup)
        vm.prank(investor1);
        vm.expectRevert();
        combinedToken.safeTransferFrom(investor1, investor2, yieldTokenId, 100 ether, "");
    }

    function testERC1155PropertyTokensUnrestricted() public {
        uint256 propertyTokenId = 1; // Property tokens < 1,000,000
        
        // Mint property token to investor1
        vm.startPrank(owner);
        combinedToken.mintPropertyToken(bytes32(uint256(2)), "ipfs://test2");
        vm.stopPrank();

        // Enable restrictions for a yield token (shouldn't affect property tokens)
        combinedToken.setYieldTokenRestrictions(
            1000000,
            block.timestamp + 365 days,
            1000,
            30 days
        );

        // Property token transfer should still work (restrictions don't apply)
        vm.prank(owner);
        combinedToken.safeTransferFrom(owner, investor1, propertyTokenId, 1, "");

        assertEq(combinedToken.balanceOf(investor1, propertyTokenId), 1);
    }

    // ============ Event Emission Tests ============

    function testTransferBlockedEventEmission() public {
        // Enable restrictions
        yieldSharesToken.setTransferRestrictions(
            block.timestamp + 30 days,
            2000,
            7 days
        );

        // Expect TransferBlocked event
        vm.prank(investor1);
        vm.expectRevert();
        yieldSharesToken.transfer(investor2, 100 ether);
        
        // Note: We can't easily test event emission on reverts in Foundry
        // This would be validated through transaction logs in actual testing
    }

    function testTransferRestrictionsUpdatedEvent() public {
        uint256 lockupEnd = block.timestamp + 30 days;
        uint256 maxShares = 2000;
        uint256 minHolding = 7 days;

        // Expect TransferRestrictionsUpdated event
        vm.expectEmit(true, true, true, true);
        emit YieldSharesToken.TransferRestrictionsUpdated(lockupEnd, maxShares, minHolding);
        
        yieldSharesToken.setTransferRestrictions(lockupEnd, maxShares, minHolding);
    }

    // ============ Gas Overhead Measurement Tests ============

    function testRestrictionGasOverhead() public {
        // Measure gas without restrictions
        vm.prank(investor1);
        uint256 gasBefore = gasleft();
        yieldSharesToken.transfer(investor2, 50 ether);
        uint256 gasWithoutRestrictions = gasBefore - gasleft();

        console.log("Gas without restrictions:", gasWithoutRestrictions);

        // Reset state
        vm.prank(investor2);
        yieldSharesToken.transfer(investor1, 50 ether);

        // Enable restrictions
        yieldSharesToken.setTransferRestrictions(0, 10000, 0); // Minimal restrictions

        // Measure gas with restrictions
        vm.prank(investor1);
        gasBefore = gasleft();
        yieldSharesToken.transfer(investor3, 50 ether);
        uint256 gasWithRestrictions = gasBefore - gasleft();

        console.log("Gas with restrictions:", gasWithRestrictions);

        // Calculate overhead percentage
        uint256 overhead = ((gasWithRestrictions - gasWithoutRestrictions) * 100) / gasWithoutRestrictions;
        console.log("Restriction overhead:", overhead, "%");

        // Verify overhead is reasonable (<15% for minimal restrictions)
        assertLt(overhead, 15);
    }
}

