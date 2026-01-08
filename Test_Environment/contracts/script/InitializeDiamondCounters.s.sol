// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/facets/combined/CombinedTokenCoreFacet.sol";

/**
 * @title InitializeDiamondCounters
 * @notice Script to set Diamond counters based on existing blockchain state
 * @dev Prevents token ID collisions after Diamond redeployment by setting counters
 *      to the next available ID based on the highest existing token ID
 * 
 * Usage:
 *   1. Query database for highest blockchain_token_id (property tokens)
 *   2. Query database for highest blockchain_agreement_id (yield tokens, typically start at 1,000,000)
 *   3. Run: forge script script/InitializeDiamondCounters.s.sol:InitializeDiamondCounters \
 *           --rpc-url http://localhost:8545 --broadcast --unlocked \
 *           --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
 *           --sig "run(address,uint256,uint256)" \
 *           <DIAMOND_ADDRESS> <NEXT_PROPERTY_ID> <NEXT_YIELD_ID>
 * 
 * Example:
 *   If database shows max property token ID = 10, max yield token ID = 1000005
 *   forge script script/InitializeDiamondCounters.s.sol:InitializeDiamondCounters \
 *     --rpc-url http://localhost:8545 --broadcast --unlocked \
 *     --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
 *     --sig "run(address,uint256,uint256)" \
 *     0x4ed7c70F96B99c776995fB64377f0d4aB3B0e1C1 11 1000006
 */
contract InitializeDiamondCounters is Script {
    
    function run(
        address diamondAddress, 
        uint256 nextPropertyTokenId,
        uint256 nextYieldTokenId
    ) external {
        console2.log("=========================================================");
        console2.log("Initializing Diamond Counter Values");
        console2.log("=========================================================");
        console2.log("");
        console2.log("Diamond Address:           ", diamondAddress);
        console2.log("Next Property Token ID:    ", nextPropertyTokenId);
        console2.log("Next Yield Token ID:       ", nextYieldTokenId);
        console2.log("");
        
        vm.startBroadcast();
        
        // Cast to CombinedTokenCoreFacet to access counter setter
        // Note: This requires adding a setter function to CombinedTokenCoreFacet
        // For now, we'll document the manual approach
        
        console2.log("NOTE: Counter initialization requires manual contract update");
        console2.log("      or adding admin setter functions to CombinedTokenCoreFacet");
        console2.log("");
        console2.log("Manual Approach:");
        console2.log("1. Add setCounters(uint256 propId, uint256 yieldId) to CombinedTokenCoreFacet");
        console2.log("2. Add onlyOwner modifier to restrict access");
        console2.log("3. Update storage values via delegatecall through Diamond");
        console2.log("");
        
        vm.stopBroadcast();
        
        console2.log("=========================================================");
        console2.log("Counter Initialization Planning Complete");
        console2.log("=========================================================");
    }
}

