// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/// @title Contract Flattening Script
/// @notice Provides Foundry-based contract flattening for Remix IDE deployment preparation
/// @dev This script serves as an alternative to Hardhat flattening, offering redundancy
///      for contract deployment preparation. Uses vm.ffi() to execute shell commands.
///      NOTE: ffi = true should only be enabled for this script in foundry.toml, not globally
contract FlattenContracts is Script {
    /// @notice Main script execution function
    /// @dev Flattens all key contracts using forge flatten command
    function run() external {
        // Flatten YieldBase contract
        flattenContract("src/YieldBase.sol", "flattened/YieldBase_flat.sol");

        // Flatten YieldSharesToken contract
        flattenContract("src/YieldSharesToken.sol", "flattened/YieldSharesToken_flat.sol");

        // Flatten PropertyNFT contract
        flattenContract("src/PropertyNFT.sol", "flattened/PropertyNFT_flat.sol");

        // Flatten CombinedPropertyYieldToken contract
        flattenContract("src/CombinedPropertyYieldToken.sol", "flattened/CombinedPropertyYieldToken_flat.sol");

        // Flatten GovernanceController contract
        flattenContract("src/GovernanceController.sol", "flattened/GovernanceController_flat.sol");

        console2.log("All contracts flattened successfully!");
        console2.log("Flattened files are ready for Remix IDE deployment on Polygon Amoy testnet.");
        console2.log("Alternative: Use Hardhat with 'npm run flatten:all' for more robust flattening");
    }

    /// @notice Helper function to flatten a single contract
    /// @param sourcePath Path to the source contract file
    /// @param outputPath Path for the flattened output file
    function flattenContract(string memory sourcePath, string memory outputPath) internal {
        string[] memory cmd = new string[](5);
        cmd[0] = "forge";
        cmd[1] = "flatten";
        cmd[2] = sourcePath;
        cmd[3] = "-o";
        cmd[4] = outputPath;
        vm.ffi(cmd);
        console2.log(string.concat("Flattened ", sourcePath, " to ", outputPath));
    }
}