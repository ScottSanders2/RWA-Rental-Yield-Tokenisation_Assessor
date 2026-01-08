// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title ComputeStorageSlot
 * @notice Script to compute ERC-7201 storage slot for governance storage
 * @dev Computes: keccak256(abi.encode(uint256(keccak256("rwa.storage.Governance")) - 1)) & ~bytes32(uint256(0xff))
 */
contract ComputeStorageSlot is Script {
    function run() public view {
        // Step 1: Compute keccak256("rwa.storage.Governance")
        bytes32 innerHash = keccak256("rwa.storage.Governance");
        console.log("Step 1 - keccak256('rwa.storage.Governance'):");
        console.logBytes32(innerHash);
        
        // Step 2: Convert to uint256 and subtract 1
        uint256 innerHashUint = uint256(innerHash);
        uint256 subtracted = innerHashUint - 1;
        console.log("\nStep 2 - uint256(innerHash) - 1:");
        console.logBytes32(bytes32(subtracted));
        
        // Step 3: Encode and hash
        bytes32 outerHash = keccak256(abi.encode(subtracted));
        console.log("\nStep 3 - keccak256(abi.encode(subtracted)):");
        console.logBytes32(outerHash);
        
        // Step 4: Apply mask (~0xff clears last byte)
        bytes32 finalSlot = outerHash & ~bytes32(uint256(0xff));
        console.log("\nStep 4 - Apply mask (& ~bytes32(uint256(0xff))):");
        console.logBytes32(finalSlot);
        
        console.log("\n========================================");
        console.log("GOVERNANCE_STORAGE_LOCATION:");
        console.logBytes32(finalSlot);
        console.log("========================================");
    }
}

