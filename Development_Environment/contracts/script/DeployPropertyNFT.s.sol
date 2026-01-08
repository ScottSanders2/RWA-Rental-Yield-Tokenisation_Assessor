// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PropertyNFT.sol";

/**
 * @title DeployPropertyNFT
 * @notice Deployment script for PropertyNFT contract with proper initialization
 */
contract DeployPropertyNFT is Script {
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying PropertyNFT...");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy PropertyNFT (upgradeable proxy pattern)
        PropertyNFT propertyNFT = new PropertyNFT();
        console.log("PropertyNFT deployed at:", address(propertyNFT));

        // Initialize the contract
        propertyNFT.initialize(
            deployer,              // initialOwner
            "RWA Property Token",  // name
            "RWAPROP"              // symbol
        );
        console.log("PropertyNFT initialized");
        console.log("Owner:", propertyNFT.owner());

        vm.stopBroadcast();

        // Output deployment address
        console.log("");
        console.log("=================================");
        console.log("DEPLOYMENT COMPLETE");
        console.log("=================================");
        console.log("PropertyNFT:", address(propertyNFT));
        console.log("Owner:", propertyNFT.owner());
        console.log("=================================");
    }
}

