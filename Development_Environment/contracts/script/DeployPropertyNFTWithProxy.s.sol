// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PropertyNFT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployPropertyNFTWithProxy
 * @notice Deployment script for PropertyNFT with UUPS proxy pattern
 * @dev Deploys:
 *  1. PropertyNFT implementation (logic contract)
 *  2. ERC1967Proxy pointing to implementation
 *  3. Initializes via proxy
 */
contract DeployPropertyNFTWithProxy is Script {
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=============================================");
        console.log("DEPLOYING PROPERTYNFT WITH UUPS PROXY");
        console.log("=============================================");
        console.log("Deployer Address:", deployer);
        console.log("Network: Polygon Amoy Testnet");
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy PropertyNFT implementation
        console.log("Step 1: Deploying PropertyNFT implementation...");
        PropertyNFT implementation = new PropertyNFT();
        console.log("  Implementation deployed at:", address(implementation));
        console.log("");

        // Step 2: Encode initialize call
        console.log("Step 2: Encoding initialize calldata...");
        bytes memory initData = abi.encodeWithSelector(
            PropertyNFT.initialize.selector,
            deployer,              // initialOwner
            "RWA Property NFT",    // name
            "RWAPROP"              // symbol
        );
        console.log("  Calldata encoded (length:", initData.length, "bytes)");
        console.log("");

        // Step 3: Deploy ERC1967Proxy
        console.log("Step 3: Deploying ERC1967Proxy...");
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        console.log("  Proxy deployed at:", address(proxy));
        console.log("");

        // Step 4: Verify deployment
        console.log("Step 4: Verifying deployment...");
        PropertyNFT propertyNFT = PropertyNFT(address(proxy));
        
        string memory name = propertyNFT.name();
        string memory symbol = propertyNFT.symbol();
        address owner = propertyNFT.owner();
        
        console.log("  Name:", name);
        console.log("  Symbol:", symbol);
        console.log("  Owner:", owner);
        console.log("");

        vm.stopBroadcast();

        // Final summary
        console.log("=============================================");
        console.log("DEPLOYMENT COMPLETE");
        console.log("=============================================");
        console.log("");
        console.log("ADDRESSES TO RECORD:");
        console.log("---------------------------------------------");
        console.log("PropertyNFT Implementation:", address(implementation));
        console.log("PropertyNFT Proxy (MAIN)  :", address(proxy));
        console.log("---------------------------------------------");
        console.log("");
        console.log("USE THE PROXY ADDRESS FOR ALL INTERACTIONS!");
        console.log("=============================================");
    }
}

