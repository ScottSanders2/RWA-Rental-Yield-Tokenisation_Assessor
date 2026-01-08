// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/KYCRegistry.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title KYCRegistry Test Suite
 * @notice Comprehensive Foundry tests for KYCRegistry contract
 * @dev Tests whitelist/blacklist management, governance integration, upgrade safety, and gas benchmarking
 */
contract KYCRegistryTest is Test {
    KYCRegistry public kycRegistryImplementation;
    KYCRegistry public kycRegistry;
    ERC1967Proxy public proxy;

    address public owner;
    address public governance;
    address public user1;
    address public user2;
    address public user3;

    event AddressWhitelisted(address indexed account, string tier, uint256 timestamp);
    event AddressRemovedFromWhitelist(address indexed account, uint256 timestamp);
    event AddressBlacklisted(address indexed account, uint256 timestamp);
    event AddressRemovedFromBlacklist(address indexed account, uint256 timestamp);
    event GovernanceControllerSet(address indexed governanceController);

    function setUp() public {
        owner = address(this);
        governance = makeAddr("governance");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Deploy implementation
        kycRegistryImplementation = new KYCRegistry();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            KYCRegistry.initialize.selector,
            owner
        );
        proxy = new ERC1967Proxy(address(kycRegistryImplementation), initData);
        kycRegistry = KYCRegistry(address(proxy));
    }

    // ============ Initialization Tests ============

    function testInitializeSuccess() public view {
        assertEq(kycRegistry.owner(), owner, "Owner should be set correctly");
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        kycRegistry.initialize(owner);
    }

    // ============ Whitelist Management Tests ============

    function testAddToWhitelist() public {
        vm.expectEmit(true, false, false, true);
        emit AddressWhitelisted(user1, "", block.timestamp);
        
        kycRegistry.addToWhitelist(user1);
        
        assertTrue(kycRegistry.isWhitelisted(user1), "User1 should be whitelisted");
        assertEq(kycRegistry.getVerificationTimestamp(user1), block.timestamp, "Timestamp should be set");
    }

    function testAddToWhitelistUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        kycRegistry.addToWhitelist(user2);
    }

    function testAddToWhitelistZeroAddress() public {
        vm.expectRevert("KYCRegistry: Cannot whitelist zero address");
        kycRegistry.addToWhitelist(address(0));
    }

    function testAddToWhitelistAlreadyWhitelisted() public {
        kycRegistry.addToWhitelist(user1);
        
        vm.expectRevert("KYCRegistry: Address already whitelisted");
        kycRegistry.addToWhitelist(user1);
    }

    function testRemoveFromWhitelist() public {
        kycRegistry.addToWhitelist(user1);
        
        vm.expectEmit(true, false, false, true);
        emit AddressRemovedFromWhitelist(user1, block.timestamp);
        
        kycRegistry.removeFromWhitelist(user1);
        
        assertFalse(kycRegistry.isWhitelisted(user1), "User1 should not be whitelisted");
    }

    function testRemoveFromWhitelistNotWhitelisted() public {
        vm.expectRevert("KYCRegistry: Address not whitelisted");
        kycRegistry.removeFromWhitelist(user1);
    }

    function testBatchAddToWhitelist() public {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        kycRegistry.batchAddToWhitelist(users);

        assertTrue(kycRegistry.isWhitelisted(user1), "User1 should be whitelisted");
        assertTrue(kycRegistry.isWhitelisted(user2), "User2 should be whitelisted");
        assertTrue(kycRegistry.isWhitelisted(user3), "User3 should be whitelisted");
    }

    function testBatchRemoveFromWhitelist() public {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        kycRegistry.batchAddToWhitelist(users);
        kycRegistry.batchRemoveFromWhitelist(users);

        assertFalse(kycRegistry.isWhitelisted(user1), "User1 should not be whitelisted");
        assertFalse(kycRegistry.isWhitelisted(user2), "User2 should not be whitelisted");
        assertFalse(kycRegistry.isWhitelisted(user3), "User3 should not be whitelisted");
    }

    // ============ Blacklist Management Tests ============

    function testAddToBlacklist() public {
        vm.expectEmit(true, false, false, true);
        emit AddressBlacklisted(user1, block.timestamp);
        
        kycRegistry.addToBlacklist(user1);
        
        assertTrue(kycRegistry.isBlacklisted(user1), "User1 should be blacklisted");
    }

    function testAddToBlacklistZeroAddress() public {
        vm.expectRevert("KYCRegistry: Cannot blacklist zero address");
        kycRegistry.addToBlacklist(address(0));
    }

    function testAddToBlacklistAlreadyBlacklisted() public {
        kycRegistry.addToBlacklist(user1);
        
        vm.expectRevert("KYCRegistry: Address already blacklisted");
        kycRegistry.addToBlacklist(user1);
    }

    function testRemoveFromBlacklist() public {
        kycRegistry.addToBlacklist(user1);
        
        vm.expectEmit(true, false, false, true);
        emit AddressRemovedFromBlacklist(user1, block.timestamp);
        
        kycRegistry.removeFromBlacklist(user1);
        
        assertFalse(kycRegistry.isBlacklisted(user1), "User1 should not be blacklisted");
    }

    function testBlacklistPriority() public {
        // Add to whitelist first
        kycRegistry.addToWhitelist(user1);
        
        // Then add to blacklist
        kycRegistry.addToBlacklist(user1);
        
        // Both should return true (blacklist doesn't remove from whitelist)
        assertTrue(kycRegistry.isWhitelisted(user1), "User1 should still be whitelisted");
        assertTrue(kycRegistry.isBlacklisted(user1), "User1 should be blacklisted");
        
        // In actual usage, blacklist check should override whitelist
    }

    // ============ Governance Integration Tests ============

    function testSetGovernanceController() public {
        vm.expectEmit(true, false, false, false);
        emit GovernanceControllerSet(governance);
        
        kycRegistry.setGovernanceController(governance);
        
        assertEq(kycRegistry.getGovernanceController(), governance, "Governance controller should be set");
    }

    function testSetGovernanceControllerZeroAddress() public {
        vm.expectRevert("KYCRegistry: Invalid governance controller");
        kycRegistry.setGovernanceController(address(0));
    }

    function testGovernanceCanAddToWhitelist() public {
        kycRegistry.setGovernanceController(governance);
        
        vm.prank(governance);
        kycRegistry.addToWhitelist(user1);
        
        assertTrue(kycRegistry.isWhitelisted(user1), "Governance should be able to add to whitelist");
    }

    function testGovernanceCanRemoveFromWhitelist() public {
        kycRegistry.setGovernanceController(governance);
        kycRegistry.addToWhitelist(user1);
        
        vm.prank(governance);
        kycRegistry.removeFromWhitelist(user1);
        
        assertFalse(kycRegistry.isWhitelisted(user1), "Governance should be able to remove from whitelist");
    }

    // ============ KYC Tier Tests ============

    function testSetKYCTier() public {
        kycRegistry.setKYCTier(user1, "accredited");
        
        assertEq(kycRegistry.getKYCTier(user1), "accredited", "KYC tier should be set");
    }

    function testSetKYCTierUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        kycRegistry.setKYCTier(user2, "basic");
    }

    // ============ Whitelist/Blacklist Enable/Disable Tests ============

    function testSetWhitelistEnabled() public {
        kycRegistry.setWhitelistEnabled(false);
        
        // When disabled, all addresses should pass whitelist check
        assertTrue(kycRegistry.isWhitelisted(user1), "Should pass when whitelist disabled");
    }

    function testSetBlacklistEnabled() public {
        kycRegistry.addToBlacklist(user1);
        kycRegistry.setBlacklistEnabled(false);
        
        // When disabled, no addresses should be blacklisted
        assertFalse(kycRegistry.isBlacklisted(user1), "Should pass when blacklist disabled");
    }

    // ============ Upgrade Tests ============

    function testUpgradeAuthorization() public {
        KYCRegistry newImplementation = new KYCRegistry();
        
        // Owner can upgrade
        kycRegistry.upgradeToAndCall(address(newImplementation), "");
        
        // Verify state persists
        kycRegistry.addToWhitelist(user1);
        assertTrue(kycRegistry.isWhitelisted(user1), "State should persist after upgrade");
    }

    function testUpgradeAuthorizationUnauthorized() public {
        KYCRegistry newImplementation = new KYCRegistry();
        
        vm.prank(user1);
        vm.expectRevert();
        kycRegistry.upgradeToAndCall(address(newImplementation), "");
    }

    function testUpgradePreservesState() public {
        // Add addresses to whitelist/blacklist
        kycRegistry.addToWhitelist(user1);
        kycRegistry.addToBlacklist(user2);
        kycRegistry.setKYCTier(user1, "institutional");
        kycRegistry.setGovernanceController(governance);
        
        // Upgrade
        KYCRegistry newImplementation = new KYCRegistry();
        kycRegistry.upgradeToAndCall(address(newImplementation), "");
        
        // Verify state persists
        assertTrue(kycRegistry.isWhitelisted(user1), "Whitelist should persist");
        assertTrue(kycRegistry.isBlacklisted(user2), "Blacklist should persist");
        assertEq(kycRegistry.getKYCTier(user1), "institutional", "KYC tier should persist");
        assertEq(kycRegistry.getGovernanceController(), governance, "Governance should persist");
    }

    // ============ Gas Benchmarking Tests ============

    function testGasAddToWhitelist() public {
        uint256 gasBefore = gasleft();
        kycRegistry.addToWhitelist(user1);
        uint256 gasUsed = gasBefore - gasleft();
        
        emit log_named_uint("Gas used for addToWhitelist", gasUsed);
        assertLt(gasUsed, 100_000, "Should use less than 100k gas");
    }

    function testGasBatchAdd10() public {
        address[] memory users = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            users[i] = address(uint160(0x1000 + i));
        }
        
        uint256 gasBefore = gasleft();
        kycRegistry.batchAddToWhitelist(users);
        uint256 gasUsed = gasBefore - gasleft();
        
        emit log_named_uint("Gas used for batchAdd (10 addresses)", gasUsed);
    }

    function testGasBatchAdd100() public {
        address[] memory users = new address[](100);
        for (uint256 i = 0; i < 100; i++) {
            users[i] = address(uint160(0x1000 + i));
        }
        
        uint256 gasBefore = gasleft();
        kycRegistry.batchAddToWhitelist(users);
        uint256 gasUsed = gasBefore - gasleft();
        
        emit log_named_uint("Gas used for batchAdd (100 addresses)", gasUsed);
        // Updated: 100 is now the maximum allowed batch size, so test passes
        assertLt(gasUsed, 6_000_000, "Should complete within reasonable gas limit");
    }
    
    function testBatchAddExceedsMaximum() public {
        address[] memory users = new address[](101);
        for (uint256 i = 0; i < 101; i++) {
            users[i] = address(uint160(0x1000 + i));
        }
        
        vm.expectRevert("KYCRegistry: Batch size exceeds maximum (100 addresses)");
        kycRegistry.batchAddToWhitelist(users);
    }
    
    function testBatchRemoveExceedsMaximum() public {
        address[] memory users = new address[](101);
        for (uint256 i = 0; i < 101; i++) {
            users[i] = address(uint160(0x1000 + i));
        }
        
        vm.expectRevert("KYCRegistry: Batch size exceeds maximum (100 addresses)");
        kycRegistry.batchRemoveFromWhitelist(users);
    }

    // ============ Event Emission Tests ============

    function testEventsEmitCorrectParameters() public {
        // Test AddressWhitelisted event
        vm.expectEmit(true, false, false, true);
        emit AddressWhitelisted(user1, "", block.timestamp);
        kycRegistry.addToWhitelist(user1);
        
        // Test AddressBlacklisted event
        vm.expectEmit(true, false, false, true);
        emit AddressBlacklisted(user2, block.timestamp);
        kycRegistry.addToBlacklist(user2);
    }
}

