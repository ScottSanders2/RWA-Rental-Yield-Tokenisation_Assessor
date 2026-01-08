// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/KYCRegistry.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title KYCTestHelper
 * @notice Base test contract that provides automatic KYC setup for legacy tests
 * @dev Inherit from this instead of Test to get pre-configured KYC infrastructure
 * 
 * Usage:
 *   contract MyTest is KYCTestHelper {
 *       function setUp() public override {
 *           super.setUp();  // Automatically sets up KYC
 *           // ... your test setup ...
 *       }
 *   }
 */
abstract contract KYCTestHelper is Test {
    // KYC Infrastructure
    KYCRegistry public kycRegistry;
    address public kycOwner;
    
    // Pre-whitelisted test addresses (add your test addresses here)
    address[] public preWhitelistedAddresses;
    
    /**
     * @notice Automatically sets up KYC registry and whitelists common test addresses
     * @dev Call super.setUp() in your test's setUp to enable this
     */
    function setUp() public virtual {
        kycOwner = address(this);
        
        // Deploy KYC Registry
        KYCRegistry kycImpl = new KYCRegistry();
        bytes memory kycInitData = abi.encodeWithSelector(
            KYCRegistry.initialize.selector,
            kycOwner
        );
        ERC1967Proxy kycProxy = new ERC1967Proxy(address(kycImpl), kycInitData);
        kycRegistry = KYCRegistry(address(kycProxy));
        
        // Whitelist common test addresses (override in your test if needed)
        _setupDefaultWhitelist();
    }
    
    /**
     * @notice Whitelists default test addresses
     * @dev Override this in your test to customize the whitelist
     */
    function _setupDefaultWhitelist() internal virtual {
        // Whitelist the test contract itself
        kycRegistry.addToWhitelist(address(this));
        
        // Whitelist common Foundry test addresses
        kycRegistry.addToWhitelist(address(0x1)); // Common test address
        kycRegistry.addToWhitelist(address(0x2));
        kycRegistry.addToWhitelist(address(0x3));
        kycRegistry.addToWhitelist(address(0xBEEF)); // Common test address
        kycRegistry.addToWhitelist(address(0xCAFE));
        
        // Add any pre-configured addresses
        for (uint256 i = 0; i < preWhitelistedAddresses.length; i++) {
            kycRegistry.addToWhitelist(preWhitelistedAddresses[i]);
        }
    }
    
    /**
     * @notice Helper to whitelist an address (for use in tests)
     */
    function whitelistAddress(address addr) public {
        kycRegistry.addToWhitelist(addr);
    }
    
    /**
     * @notice Helper to whitelist multiple addresses at once
     */
    function whitelistAddresses(address[] memory addresses) public {
        for (uint256 i = 0; i < addresses.length; i++) {
            kycRegistry.addToWhitelist(addresses[i]);
        }
    }
    
    /**
     * @notice Helper to blacklist an address (for negative tests)
     */
    function blacklistAddress(address addr) public {
        kycRegistry.addToBlacklist(addr);
    }
    
    /**
     * @notice Configure contracts with KYC registry (call after deploying your contracts)
     * @param yieldBase YieldBase contract instance
     */
    function linkKYCToYieldBase(address yieldBase) public {
        (bool success, ) = yieldBase.call(
            abi.encodeWithSignature("setKYCRegistry(address)", address(kycRegistry))
        );
        require(success, "Failed to link KYC to YieldBase");
    }
    
    /**
     * @notice Configure YieldSharesToken with KYC registry
     */
    function linkKYCToToken(address token) public {
        (bool success, ) = token.call(
            abi.encodeWithSignature("setKYCRegistry(address)", address(kycRegistry))
        );
        require(success, "Failed to link KYC to token");
    }
    
    /**
     * @notice Configure CombinedPropertyYieldToken with KYC registry
     */
    function linkKYCToCombinedToken(address combinedToken) public {
        (bool success, ) = combinedToken.call(
            abi.encodeWithSignature("setKYCRegistry(address)", address(kycRegistry))
        );
        require(success, "Failed to link KYC to combined token");
    }
    
    /**
     * @notice One-stop helper to link KYC to all common contracts
     */
    function linkKYCToAllContracts(
        address yieldBase,
        address propertyToken,
        address[] memory shareTokens
    ) public {
        if (yieldBase != address(0)) {
            linkKYCToYieldBase(yieldBase);
        }
        if (propertyToken != address(0)) {
            linkKYCToCombinedToken(propertyToken);
        }
        for (uint256 i = 0; i < shareTokens.length; i++) {
            if (shareTokens[i] != address(0)) {
                linkKYCToToken(shareTokens[i]);
            }
        }
    }
}

