// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PropertyNFT} from "../src/PropertyNFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract FixPropertyNFT is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy NEW PropertyNFT implementation
        PropertyNFT propertyNFTImpl = new PropertyNFT();
        console2.log("New PropertyNFT implementation:", address(propertyNFTImpl));
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            PropertyNFT.initialize.selector,
            deployer, // initialOwner
            "RWA Property NFT",
            "RWAPROP"
        );
        
        // Deploy NEW proxy with initialization
        ERC1967Proxy propertyNFTProxy = new ERC1967Proxy(
            address(propertyNFTImpl),
            initData
        );
        
        PropertyNFT propertyNFT = PropertyNFT(address(propertyNFTProxy));
        
        console2.log("New PropertyNFT proxy:", address(propertyNFT));
        console2.log("Owner:", propertyNFT.owner());
        console2.log("Name:", propertyNFT.name());
        console2.log("Symbol:", propertyNFT.symbol());
        
        vm.stopBroadcast();
    }
}
