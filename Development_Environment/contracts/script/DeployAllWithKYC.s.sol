// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/YieldBase.sol";
import "../src/YieldSharesToken.sol";
import "../src/PropertyNFT.sol";
import "../src/CombinedPropertyYieldToken.sol";
import "../src/GovernanceController.sol";
import "../src/KYCRegistry.sol";

/// @title Complete Deployment Script with KYC Integration
/// @notice Deploys all contracts including KYC Registry and links them together
contract DeployAllWithKYC is Script {
    function run() external {
        // Get deployer private key from environment or use Anvil's default
        uint256 deployerPrivateKey = vm.envOr("DEPLOYER_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        // Get the actual EOA address from the private key
        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Phase 1: Deploy KYC Registry
        console2.log("=== Deploying KYC Registry ===");
        KYCRegistry kycImplementation = new KYCRegistry();
        console2.log("KYCRegistry implementation deployed at:", address(kycImplementation));

        bytes memory kycInitData = abi.encodeWithSelector(
            KYCRegistry.initialize.selector,
            deployer
        );

        ERC1967Proxy kycProxyContract = new ERC1967Proxy(address(kycImplementation), kycInitData);
        KYCRegistry kycProxy = KYCRegistry(address(kycProxyContract));
        console2.log("KYCRegistry proxy deployed at:", address(kycProxy));

        // Whitelist test accounts for development
        address[] memory testAccounts = new address[](5);
        testAccounts[0] = deployer;
        testAccounts[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil account 1
        testAccounts[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Anvil account 2
        testAccounts[3] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Anvil account 3
        testAccounts[4] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // Anvil account 4
        
        for (uint256 i = 0; i < testAccounts.length; i++) {
            kycProxy.addToWhitelist(testAccounts[i]);
        }
        console2.log("Whitelisted 5 test accounts for development");

        // Phase 2: Deploy PropertyNFT
        console2.log("=== Deploying PropertyNFT ===");
        PropertyNFT propertyNFTImplementation = new PropertyNFT();
        console2.log("PropertyNFT implementation deployed at:", address(propertyNFTImplementation));

        bytes memory propertyNFTInitData = abi.encodeWithSelector(
            PropertyNFT.initialize.selector,
            deployer,
            "RWA Property NFT",
            "RWAPROP"
        );

        ERC1967Proxy propertyNFTProxyContract = new ERC1967Proxy(address(propertyNFTImplementation), propertyNFTInitData);
        PropertyNFT propertyNFTProxy = PropertyNFT(address(propertyNFTProxyContract));
        console2.log("PropertyNFT proxy deployed at:", address(propertyNFTProxy));

        // Phase 3: Deploy YieldBase
        console2.log("=== Deploying YieldBase ===");
        YieldBase yieldBaseImplementation = new YieldBase();
        console2.log("YieldBase implementation deployed at:", address(yieldBaseImplementation));

        bytes memory yieldBaseInitData = abi.encodeWithSelector(
            YieldBase.initialize.selector,
            deployer
        );

        ERC1967Proxy yieldBaseProxyContract = new ERC1967Proxy(address(yieldBaseImplementation), yieldBaseInitData);
        YieldBase yieldBaseProxy = YieldBase(payable(address(yieldBaseProxyContract)));
        console2.log("YieldBase proxy deployed at:", address(yieldBaseProxy));

        // Phase 4: Deploy YieldSharesToken (template)
        console2.log("=== Deploying YieldSharesToken ===");
        YieldSharesToken tokenImplementation = new YieldSharesToken();
        console2.log("YieldSharesToken implementation deployed at:", address(tokenImplementation));

        bytes memory tokenInitData = abi.encodeWithSelector(
            YieldSharesToken.initialize.selector,
            deployer,
            address(yieldBaseProxy),
            "RWA Yield Shares",
            "RWAYIELD"
        );

        ERC1967Proxy tokenProxyContract = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        YieldSharesToken tokenProxy = YieldSharesToken(address(tokenProxyContract));
        console2.log("YieldSharesToken proxy deployed at:", address(tokenProxy));

        // Phase 5: Deploy GovernanceController
        console2.log("=== Deploying GovernanceController ===");
        GovernanceController governanceImplementation = new GovernanceController();
        console2.log("GovernanceController implementation deployed at:", address(governanceImplementation));

        bytes memory governanceInitData = abi.encodeWithSelector(
            GovernanceController.initialize.selector,
            deployer,
            address(yieldBaseProxy)
        );

        ERC1967Proxy governanceProxyContract = new ERC1967Proxy(address(governanceImplementation), governanceInitData);
        GovernanceController governanceProxy = GovernanceController(payable(address(governanceProxyContract)));
        console2.log("GovernanceController proxy deployed at:", address(governanceProxy));

        // Phase 6: Deploy CombinedPropertyYieldToken
        console2.log("=== Deploying CombinedPropertyYieldToken ===");
        CombinedPropertyYieldToken combinedTokenImplementation = new CombinedPropertyYieldToken();
        console2.log("CombinedPropertyYieldToken implementation deployed at:", address(combinedTokenImplementation));

        bytes memory combinedTokenInitData = abi.encodeWithSelector(
            CombinedPropertyYieldToken.initialize.selector,
            deployer,
            address(yieldBaseProxy)
        );

        ERC1967Proxy combinedTokenProxyContract = new ERC1967Proxy(address(combinedTokenImplementation), combinedTokenInitData);
        CombinedPropertyYieldToken combinedTokenProxy = CombinedPropertyYieldToken(address(combinedTokenProxyContract));
        console2.log("CombinedPropertyYieldToken proxy deployed at:", address(combinedTokenProxy));

        // Phase 7: Link contracts together
        console2.log("=== Linking Contracts ===");
        
        // Link YieldBase
        yieldBaseProxy.setPropertyNFT(address(propertyNFTProxy));
        console2.log("[OK] YieldBase linked to PropertyNFT");
        
        yieldBaseProxy.setKYCRegistry(address(kycProxy));
        console2.log("[OK] YieldBase linked to KYCRegistry");
        
        yieldBaseProxy.setGovernanceController(address(governanceProxy));
        console2.log("[OK] YieldBase linked to GovernanceController");
        
        // Link PropertyNFT
        propertyNFTProxy.setYieldBase(address(yieldBaseProxy));
        console2.log("[OK] PropertyNFT linked to YieldBase");
        
        // Link YieldSharesToken to KYC
        tokenProxy.setKYCRegistry(address(kycProxy));
        console2.log("[OK] YieldSharesToken linked to KYCRegistry");
        
        // Link CombinedPropertyYieldToken to KYC
        combinedTokenProxy.setKYCRegistry(address(kycProxy));
        console2.log("[OK] CombinedPropertyYieldToken linked to KYCRegistry");
        
        // Link GovernanceController to KYC
        governanceProxy.setKYCRegistry(address(kycProxy));
        console2.log("[OK] GovernanceController linked to KYCRegistry");

        vm.stopBroadcast();

        // Final Summary
        console2.log("\n=== Deployment Complete ===");
        console2.log("KYCRegistry proxy:              ", address(kycProxy));
        console2.log("PropertyNFT proxy:              ", address(propertyNFTProxy));
        console2.log("YieldBase proxy:                ", address(yieldBaseProxy));
        console2.log("YieldSharesToken proxy:         ", address(tokenProxy));
        console2.log("GovernanceController proxy:     ", address(governanceProxy));
        console2.log("CombinedPropertyYieldToken proxy:", address(combinedTokenProxy));
        console2.log("\nAll contracts deployed and linked successfully!");
        console2.log("5 test accounts whitelisted in KYCRegistry");
        
        // Output for backend configuration
        console2.log("\n=== Backend Environment Variables ===");
        console2.log("KYC_REGISTRY_ADDRESS=", address(kycProxy));
        console2.log("YIELD_BASE_ADDRESS=", address(yieldBaseProxy));
        console2.log("PROPERTY_NFT_ADDRESS=", address(propertyNFTProxy));
        console2.log("GOVERNANCE_CONTROLLER_ADDRESS=", address(governanceProxy));
    }
}

