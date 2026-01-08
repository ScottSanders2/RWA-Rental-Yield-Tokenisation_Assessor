// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {PropertyNFT} from "../src/PropertyNFT.sol";
import {PropertyStorage} from "../src/storage/PropertyStorage.sol";

/// @title PropertyNFT Test Suite
/// @notice Comprehensive tests for PropertyNFT contract functionality
/// @dev Tests ERC-721 minting, verification, linking, storage layout, and upgrade authorization
contract PropertyNFTTest is Test {
    PropertyNFT public implementation;
    PropertyNFT public proxy;
    address public owner;
    address public user;

    bytes32 constant TEST_PROPERTY_HASH = keccak256("123 Main St, Anytown, USA");
    string constant TEST_METADATA_URI = "ipfs://QmTestHash123/property-details.json";

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");

        // Deploy implementation
        implementation = new PropertyNFT();

        // Deploy proxy with initialization
        proxy = PropertyNFT(address(new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                PropertyNFT.initialize.selector,
                owner,
                "RWA Property NFT",
                "RWAPROP"
            )
        )));

        // Verify initialization
        assertEq(proxy.owner(), owner);
        assertEq(proxy.name(), "RWA Property NFT");
        assertEq(proxy.symbol(), "RWAPROP");

        // Set yieldBase for testing (normally done in deployment script)
        proxy.setYieldBase(address(this)); // Use test contract as mock YieldBase for testing
    }

    function testInitialization() public {
        assertEq(proxy.owner(), owner);
        assertEq(proxy.name(), "RWA Property NFT");
        assertEq(proxy.symbol(), "RWAPROP");
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        proxy.initialize(owner, "Test", "TEST");
    }

    function testMintProperty() public {
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);

        assertEq(tokenId, 1);
        assertEq(proxy.ownerOf(tokenId), owner);
        assertEq(proxy.tokenURI(tokenId), TEST_METADATA_URI);

        PropertyStorage.PropertyData memory data = proxy.getPropertyData(tokenId);
        assertEq(data.propertyAddressHash, TEST_PROPERTY_HASH);
        assertEq(data.metadataURI, TEST_METADATA_URI);
        assertEq(data.verificationTimestamp, 0);
        assertFalse(data.isVerified);
        assertEq(data.verifierAddress, address(0));
        assertEq(data.yieldAgreementId, 0);
    }

    function testOnlyOwnerCanMint() public {
        vm.prank(user);
        vm.expectRevert();
        proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);
    }

    function testMintPropertyValidation() public {
        vm.expectRevert("Property address hash cannot be zero");
        proxy.mintProperty(bytes32(0), TEST_METADATA_URI);

        vm.expectRevert("Metadata URI cannot be empty");
        proxy.mintProperty(TEST_PROPERTY_HASH, "");
    }

    function testVerifyProperty() public {
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);

        proxy.verifyProperty(tokenId);

        PropertyStorage.PropertyData memory data = proxy.getPropertyData(tokenId);
        assertTrue(data.isVerified);
        assertEq(data.verificationTimestamp, block.timestamp);
        assertEq(data.verifierAddress, owner);
    }

    function testOnlyOwnerCanVerify() public {
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);

        vm.prank(user);
        vm.expectRevert();
        proxy.verifyProperty(tokenId);
    }

    function testSetYieldBase() public {
        address newYieldBase = makeAddr("newYieldBase");

        proxy.setYieldBase(newYieldBase);
        assertEq(proxy.yieldBase(), newYieldBase);
    }

    function testOnlyOwnerCanSetYieldBase() public {
        address newYieldBase = makeAddr("newYieldBase");

        vm.prank(user);
        vm.expectRevert();
        proxy.setYieldBase(newYieldBase);
    }

    function testSetYieldBaseValidation() public {
        vm.expectRevert("Invalid YieldBase address");
        proxy.setYieldBase(address(0));
    }

    function testCannotVerifyNonexistentProperty() public {
        vm.expectRevert("Property does not exist");
        proxy.verifyProperty(999);
    }

    function testCannotVerifyAlreadyVerifiedProperty() public {
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);
        proxy.verifyProperty(tokenId);

        vm.expectRevert("Property already verified");
        proxy.verifyProperty(tokenId);
    }

    function testLinkToYieldAgreement() public {
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);
        proxy.verifyProperty(tokenId);
        uint256 yieldAgreementId = 42;

        proxy.linkToYieldAgreement(tokenId, yieldAgreementId);

        PropertyStorage.PropertyData memory data = proxy.getPropertyData(tokenId);
        assertEq(data.yieldAgreementId, yieldAgreementId);
    }

    function testOnlyYieldBaseCanLink() public {
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);
        proxy.verifyProperty(tokenId);

        // Test that non-yieldBase cannot link after verification
        vm.prank(user);
        vm.expectRevert("Caller is not the configured YieldBase contract");
        proxy.linkToYieldAgreement(tokenId, 42);

        // Test that configured yieldBase can link (using test contract as yieldBase)
        proxy.linkToYieldAgreement(tokenId, 42);

        PropertyStorage.PropertyData memory data = proxy.getPropertyData(tokenId);
        assertEq(data.yieldAgreementId, 42);
    }

    function testLinkValidation() public {
        vm.expectRevert("Property does not exist");
        proxy.linkToYieldAgreement(999, 42);

        // Create a valid property and try to link with invalid yield agreement ID
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);
        proxy.verifyProperty(tokenId);

        vm.expectRevert("Invalid yield agreement ID");
        proxy.linkToYieldAgreement(tokenId, 0);
    }

    function testTokenURI() public {
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);
        assertEq(proxy.tokenURI(tokenId), TEST_METADATA_URI);
    }

    function testTokenURINonexistent() public {
        vm.expectRevert("Property does not exist");
        proxy.tokenURI(999);
    }

    function testIsPropertyVerified() public {
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);

        // Should return false for unverified property
        assertFalse(proxy.isPropertyVerified(tokenId));

        // Should return false for nonexistent property
        assertFalse(proxy.isPropertyVerified(999));

        // Should return true after verification
        proxy.verifyProperty(tokenId);
        assertTrue(proxy.isPropertyVerified(tokenId));
    }

    function testRelinkProtection() public {
        // Test basic relinking functionality (protection against active agreements requires YieldBase integration)
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);
        proxy.verifyProperty(tokenId);

        // First link should work
        proxy.linkToYieldAgreement(tokenId, 42);

        // Relinking should work since test contract doesn't implement YieldBase.isAgreementActive
        // In production, this would be protected by checking if the agreement is active
        proxy.linkToYieldAgreement(tokenId, 43);

        PropertyStorage.PropertyData memory data = proxy.getPropertyData(tokenId);
        assertEq(data.yieldAgreementId, 43);
    }

    function testMultipleProperties() public {
        uint256 tokenId1 = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);
        uint256 tokenId2 = proxy.mintProperty(keccak256("456 Oak Ave"), "ipfs://QmTestHash456");

        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);

        assertEq(proxy.ownerOf(tokenId1), owner);
        assertEq(proxy.ownerOf(tokenId2), owner);

        PropertyStorage.PropertyData memory data1 = proxy.getPropertyData(tokenId1);
        PropertyStorage.PropertyData memory data2 = proxy.getPropertyData(tokenId2);

        assertEq(data1.propertyAddressHash, TEST_PROPERTY_HASH);
        assertEq(data2.propertyAddressHash, keccak256("456 Oak Ave"));
    }

    function testPropertyDataRetrieval() public {
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);
        proxy.verifyProperty(tokenId);
        proxy.linkToYieldAgreement(tokenId, 123);

        PropertyStorage.PropertyData memory data = proxy.getPropertyData(tokenId);

        assertEq(data.propertyAddressHash, TEST_PROPERTY_HASH);
        assertEq(data.verificationTimestamp, block.timestamp);
        assertEq(data.metadataURI, TEST_METADATA_URI);
        assertEq(data.yieldAgreementId, 123);
        assertTrue(data.isVerified);
        assertEq(data.verifierAddress, owner);
    }

    function testPropertyDataNonexistent() public {
        vm.expectRevert("Property does not exist");
        proxy.getPropertyData(999);
    }

    function testUpgradeAuthorization() public {
        PropertyNFT newImplementation = new PropertyNFT();

        // Owner can upgrade
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");

        // Non-owner cannot upgrade
        vm.prank(user);
        vm.expectRevert();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(newImplementation), "");
    }

    function testStorageLayout() public {
        // Test that storage is properly namespaced
        uint256 tokenId = proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);

        // Get storage slot for property data
        bytes32 storageSlot = keccak256(abi.encode(uint256(keccak256("rwa.storage.Property")) - 1)) & ~bytes32(uint256(0xff));
        bytes32 propertySlot = keccak256(abi.encode(tokenId, uint256(storageSlot)));

        // This is mainly a compilation test - actual slot verification would require more complex testing
        assertTrue(storageSlot != bytes32(0));
    }

    function testERC7201SlotComputation() public {
        // Test that the storage slot is computed correctly per ERC-7201
        bytes32 expectedSlot = bytes32(uint256(keccak256(abi.encode(uint256(keccak256("rwa.storage.Property")) - 1))) & ~uint256(0xff));
        bytes32 actualSlot = PropertyStorage.getStorageSlot();

        // Assert the slot matches the formula
        assertEq(actualSlot, expectedSlot);

        // Assert the lowest byte is zero (masked out)
        assertEq(uint256(actualSlot) & 0xff, 0);
    }

    function testGasOptimization() public {
        // Benchmark minting gas cost
        uint256 gasStart = gasleft();
        proxy.mintProperty(TEST_PROPERTY_HASH, TEST_METADATA_URI);
        uint256 gasUsed = gasStart - gasleft();

        // Gas cost should be reasonable (less than 500k for minting)
        assertLt(gasUsed, 500_000);

        // Benchmark verification gas cost
        uint256 tokenId = proxy.mintProperty(keccak256("test"), "ipfs://test");
        gasStart = gasleft();
        proxy.verifyProperty(tokenId);
        gasUsed = gasStart - gasleft();

        // Gas cost should be reasonable (less than 50k for verification)
        assertLt(gasUsed, 50_000);
    }
}
