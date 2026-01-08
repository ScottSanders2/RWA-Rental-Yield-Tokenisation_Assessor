// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

/// @title Bytecode Size Analyzer
/// @notice Analyzes and compares bytecode sizes of different contract approaches
/// @dev Run with: forge script script/BytecodeSizeAnalyzer.s.sol
contract BytecodeSizeAnalyzer is Script {
    function run() external view {
        console2.log("=== Contract Bytecode Size Analysis ===");
        console2.log("ERC-721 + ERC-20 vs ERC-1155 Approaches");
        console2.log("");

        // Note: This script would ideally parse the output of `forge build --sizes`
        // For now, it provides instructions on how to analyze sizes manually

        console2.log("To analyze bytecode sizes, run:");
        console2.log("forge build --sizes");
        console2.log("");

        console2.log("Expected output format:");
        console2.log("Contract: PropertyNFT");
        console2.log("Size: XXXX bytes");
        console2.log("Contract: YieldBase");
        console2.log("Size: XXXX bytes");
        console2.log("Contract: YieldSharesToken");
        console2.log("Size: XXXX bytes");
        console2.log("Contract: CombinedPropertyYieldToken");
        console2.log("Size: XXXX bytes");
        console2.log("");

        console2.log("Key metrics to compare:");
        console2.log("- Total deployment size for ERC-721+ERC-20 approach");
        console2.log("- Total deployment size for ERC-1155 approach");
        console2.log("- Individual contract sizes");
        console2.log("- Proxy contract sizes (if applicable)");
        console2.log("");

        console2.log("Analysis complete. Run 'forge build --sizes' to get actual measurements.");
    }
}
