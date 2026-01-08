// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/YieldBase.sol";
import "../src/YieldSharesToken.sol";
import "../src/PropertyNFT.sol";
import "../src/CombinedPropertyYieldToken.sol";
import "../src/GovernanceController.sol";

/// @title Complete Deployment Script with Fixed Ownership
/// @notice Deploys all contracts with correct EOA ownership for linking
contract DeployAll is Script {
    function run() external {
        // Get deployer private key from environment or use Anvil's default
        uint256 deployerPrivateKey = vm.envOr("DEPLOYER_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        
        // Get the actual EOA address from the private key
        address deployer = vm.addr(deployerPrivateKey);
        console2.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Phase 1: Deploy PropertyNFT
        console2.log("=== Deploying PropertyNFT ===");
        PropertyNFT propertyNFTImplementation = new PropertyNFT();
        console2.log("PropertyNFT implementation deployed at:", address(propertyNFTImplementation));

        bytes memory propertyNFTInitData = abi.encodeWithSelector(
            PropertyNFT.initialize.selector,
            deployer, // Use EOA address
            "RWA Property NFT",
            "RWAPROP"
        );

        ERC1967Proxy propertyNFTProxyContract = new ERC1967Proxy(address(propertyNFTImplementation), propertyNFTInitData);
        PropertyNFT propertyNFTProxy = PropertyNFT(address(propertyNFTProxyContract));
        console2.log("PropertyNFT proxy deployed at:", address(propertyNFTProxy));

        // Phase 2: Deploy YieldBase
        console2.log("=== Deploying YieldBase ===");
        YieldBase yieldBaseImplementation = new YieldBase();
        console2.log("YieldBase implementation deployed at:", address(yieldBaseImplementation));

        bytes memory yieldBaseInitData = abi.encodeWithSelector(
            YieldBase.initialize.selector,
            deployer // Use EOA address
        );

        ERC1967Proxy yieldBaseProxyContract = new ERC1967Proxy(address(yieldBaseImplementation), yieldBaseInitData);
        YieldBase yieldBaseProxy = YieldBase(address(yieldBaseProxyContract));
        console2.log("YieldBase proxy deployed at:", address(yieldBaseProxy));

        // Phase 3: Deploy YieldSharesToken
        console2.log("=== Deploying YieldSharesToken ===");
        YieldSharesToken tokenImplementation = new YieldSharesToken();
        console2.log("YieldSharesToken implementation deployed at:", address(tokenImplementation));

        bytes memory tokenInitData = abi.encodeWithSelector(
            YieldSharesToken.initialize.selector,
            deployer, // Use EOA address
            address(yieldBaseProxy),
            "RWA Yield Shares",
            "RWAYIELD"
        );

        ERC1967Proxy tokenProxyContract = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        YieldSharesToken tokenProxy = YieldSharesToken(address(tokenProxyContract));
        console2.log("YieldSharesToken proxy deployed at:", address(tokenProxy));

        // Phase 4: Deploy GovernanceController
        console2.log("=== Deploying GovernanceController ===");
        GovernanceController governanceImplementation = new GovernanceController();
        console2.log("GovernanceController implementation deployed at:", address(governanceImplementation));

        bytes memory governanceInitData = abi.encodeWithSelector(
            GovernanceController.initialize.selector,
            deployer, // Use EOA address
            address(yieldBaseProxy)
        );

        ERC1967Proxy governanceProxyContract = new ERC1967Proxy(address(governanceImplementation), governanceInitData);
        GovernanceController governanceProxy = GovernanceController(payable(address(governanceProxyContract)));
        console2.log("GovernanceController proxy deployed at:", address(governanceProxy));

        // Phase 5: Link contracts together
        console2.log("=== Linking Contracts ===");
        yieldBaseProxy.setPropertyNFT(address(propertyNFTProxy));
        console2.log("YieldBase linked to PropertyNFT");
        
        propertyNFTProxy.setYieldBase(address(yieldBaseProxy));
        console2.log("PropertyNFT linked to YieldBase");
        
        yieldBaseProxy.setGovernanceController(address(governanceProxy));
        console2.log("YieldBase linked to GovernanceController");

        vm.stopBroadcast();

        // Verification
        console2.log("=== Deployment Complete ===");
        console2.log("PropertyNFT proxy:", address(propertyNFTProxy));
        console2.log("YieldBase proxy:", address(yieldBaseProxy));
        console2.log("YieldSharesToken proxy:", address(tokenProxy));
        console2.log("GovernanceController proxy:", address(governanceProxy));
        console2.log("All contracts deployed and linked successfully!");
    }
}

