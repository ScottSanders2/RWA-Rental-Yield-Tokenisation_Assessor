// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/KYCRegistry.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployKYCRegistry Script
 * @notice Foundry deployment script for KYCRegistry with UUPS proxy pattern
 * @dev Deploys implementation, proxy, and saves addresses for backend integration
 */
contract DeployKYCRegistry is Script {
    function run() external {
        // Load deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying KYCRegistry with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        KYCRegistry implementation = new KYCRegistry();
        console.log("KYCRegistry implementation deployed at:", address(implementation));

        // Encode initializer data
        bytes memory initData = abi.encodeWithSelector(
            KYCRegistry.initialize.selector,
            deployer // initialOwner
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        console.log("KYCRegistry proxy deployed at:", address(proxy));

        // Verify deployment
        KYCRegistry kycRegistry = KYCRegistry(address(proxy));
        require(kycRegistry.owner() == deployer, "Owner mismatch");
        console.log("KYCRegistry owner verified:", kycRegistry.owner());

        vm.stopBroadcast();

        // Save addresses to JSON for backend integration
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "kycRegistry": "', vm.toString(address(proxy)), '",\n',
            '  "kycRegistryImplementation": "', vm.toString(address(implementation)), '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "network": "', _getNetworkName(), '",\n',
            '  "timestamp": "', vm.toString(block.timestamp), '"\n',
            '}'
        ));

        string memory outputPath = string(abi.encodePacked(
            vm.projectRoot(),
            "/deployments/kyc_registry_",
            _getNetworkName(),
            ".json"
        ));

        vm.writeFile(outputPath, json);
        console.log("\nDeployment info saved to:", outputPath);

        // Print post-deployment instructions
        console.log("\n=== POST-DEPLOYMENT STEPS ===");
        console.log("1. Link KYCRegistry to contracts:");
        console.log("   - yieldBase.setKYCRegistry(%s)", address(proxy));
        console.log("   - yieldSharesToken.setKYCRegistry(%s)", address(proxy));
        console.log("   - combinedToken.setKYCRegistry(%s)", address(proxy));
        console.log("   - governance.setKYCRegistry(%s)", address(proxy));
        console.log("\n2. Set governance controller:");
        console.log("   - kycRegistry.setGovernanceController(<governance_address>)");
        console.log("\n3. Update backend config:");
        console.log("   - Set KYC_REGISTRY_ADDRESS=%s", address(proxy));
        console.log("\n4. Verify on block explorer (if mainnet/testnet):");
        console.log("   - forge verify-contract %s KYCRegistry --watch", address(implementation));
    }

    /**
     * @notice Get network name from chain ID
     * @return name Network name string
     */
    function _getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 1) return "mainnet";
        if (chainId == 5) return "goerli";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 137) return "polygon";
        if (chainId == 80001) return "mumbai";
        if (chainId == 31337) return "anvil";
        
        return string(abi.encodePacked("chain_", vm.toString(chainId)));
    }
}

/**
 * @title DeployKYCRegistryAnvil Script
 * @notice Specialized deployment script for local Anvil testing
 * @dev Uses default Anvil test accounts and whitelists test addresses
 */
contract DeployKYCRegistryAnvil is Script {
    function run() external {
        // Use default Anvil account (0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying to Anvil with address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        KYCRegistry implementation = new KYCRegistry();
        console.log("Implementation:", address(implementation));

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            KYCRegistry.initialize.selector,
            deployer
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        KYCRegistry kycRegistry = KYCRegistry(address(proxy));
        console.log("Proxy:", address(proxy));

        // Whitelist test accounts for development
        address[] memory testAccounts = new address[](5);
        testAccounts[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil account 0
        testAccounts[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil account 1
        testAccounts[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Anvil account 2
        testAccounts[3] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Anvil account 3
        testAccounts[4] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65; // Anvil account 4

        kycRegistry.batchAddToWhitelist(testAccounts);
        console.log("Whitelisted %s test accounts", testAccounts.length);

        vm.stopBroadcast();

        console.log("\nKYC Registry deployed and configured for local testing");
        console.log("KYC_REGISTRY_ADDRESS=%s", address(proxy));
    }
}

