// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PropertyNFT} from "../src/PropertyNFT.sol";

/**
 * @title InitializePropertyNFTCounter
 * @notice Script to set PropertyNFT counter based on existing blockchain state
 * @dev Prevents token ID collisions after contract redeployment by setting counter
 *      to the next available ID based on the highest existing token ID
 * 
 * Usage:
 *   1. Query database for highest blockchain_token_id WHERE token_standard = 'ERC721'
 *   2. Run: forge script script/InitializePropertyNFTCounter.s.sol:InitializePropertyNFTCounter \
 *           --rpc-url http://localhost:8545 --broadcast --unlocked \
 *           --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
 *           --sig "run(uint256)" <NEXT_TOKEN_ID>
 * 
 * Example:
 *   If database shows max ERC-721 token ID = 2
 *   forge script script/InitializePropertyNFTCounter.s.sol:InitializePropertyNFTCounter \
 *     --rpc-url http://localhost:8545 --broadcast --unlocked \
 *     --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
 *     --sig "run(uint256)" 3
 */
contract InitializePropertyNFTCounter is Script {
    function run(address propertyNFTAddress, uint256 nextTokenId) external {
        console.log("=== Initializing PropertyNFT Counter ===");
        console.log("PropertyNFT address:", propertyNFTAddress);
        console.log("Setting next token ID to:", nextTokenId);

        vm.startBroadcast();

        PropertyNFT propertyNFT = PropertyNFT(propertyNFTAddress);
        propertyNFT.setTokenCounter(nextTokenId);

        console.log("[SUCCESS] PropertyNFT counter initialized successfully");
        console.log("Current counter value:", propertyNFT.getTokenCounter());

        vm.stopBroadcast();
    }
}

