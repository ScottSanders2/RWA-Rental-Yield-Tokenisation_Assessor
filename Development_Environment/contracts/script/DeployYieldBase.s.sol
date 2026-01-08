// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/YieldBase.sol";
import "../src/YieldSharesToken.sol";
import "../src/PropertyNFT.sol";
import "../src/CombinedPropertyYieldToken.sol";
import "../src/GovernanceController.sol";

/// @title PropertyNFT + YieldBase + YieldSharesToken + GovernanceController Deployment Script
/// @notice Automates three-phase deployment of all contracts with UUPS proxy pattern to Anvil
/// @dev Uses Foundry's Script contract for transaction broadcasting and logging
/// Deploys PropertyNFT, YieldBase, YieldSharesToken and links them all together
contract DeployYieldBase is Script {
    /// @notice Deploys PropertyNFT, YieldBase and YieldSharesToken implementations and proxies, then links them
    /// @dev Run with: forge script script/DeployYieldBase.s.sol --rpc-url http://localhost:8545 --broadcast
    function run() external {
        // Get deployer private key from environment or use Anvil's default
        uint256 deployerPrivateKey = vm.envOr("DEPLOYER_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));

        vm.startBroadcast(deployerPrivateKey);

        // Phase 1: Deploy PropertyNFT
        console2.log("=== Deploying PropertyNFT ===");

        // Deploy PropertyNFT implementation contract
        PropertyNFT propertyNFTImplementation = new PropertyNFT();
        console2.log("PropertyNFT implementation deployed at:", address(propertyNFTImplementation));

        // Encode PropertyNFT initialization data
        bytes memory propertyNFTInitData = abi.encodeWithSelector(
            PropertyNFT.initialize.selector,
            msg.sender, // initialOwner
            "RWA Property NFT", // name
            "RWAPROP" // symbol
        );

        // Deploy PropertyNFT proxy
        ERC1967Proxy propertyNFTProxyContract = new ERC1967Proxy(address(propertyNFTImplementation), propertyNFTInitData);
        PropertyNFT propertyNFTProxy = PropertyNFT(address(propertyNFTProxyContract));
        console2.log("PropertyNFT proxy deployed at:", address(propertyNFTProxy));

        // Phase 2: Deploy YieldBase
        console2.log("=== Deploying YieldBase ===");

        // Deploy YieldBase implementation contract
        YieldBase yieldBaseImplementation = new YieldBase();
        console2.log("YieldBase implementation deployed at:", address(yieldBaseImplementation));

        // Encode YieldBase initialization data
        bytes memory yieldBaseInitData = abi.encodeWithSelector(
            YieldBase.initialize.selector,
            msg.sender // Use transaction sender as initial owner
        );

        // Deploy YieldBase proxy
        ERC1967Proxy yieldBaseProxyContract = new ERC1967Proxy(address(yieldBaseImplementation), yieldBaseInitData);
        YieldBase yieldBaseProxy = YieldBase(address(yieldBaseProxyContract));
        console2.log("YieldBase proxy deployed at:", address(yieldBaseProxy));

        // Phase 3: Deploy YieldSharesToken
        console2.log("=== Deploying YieldSharesToken ===");

        // Deploy YieldSharesToken implementation contract
        YieldSharesToken tokenImplementation = new YieldSharesToken();
        console2.log("YieldSharesToken implementation deployed at:", address(tokenImplementation));

        // Encode token initialization data
        bytes memory tokenInitData = abi.encodeWithSelector(
            YieldSharesToken.initialize.selector,
            msg.sender, // initialOwner
            address(yieldBaseProxy), // yieldBaseAddress
            "RWA Yield Shares", // name
            "RWAYIELD" // symbol
        );

        // Deploy token proxy
        ERC1967Proxy tokenProxyContract = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        YieldSharesToken tokenProxy = YieldSharesToken(address(tokenProxyContract));
        console2.log("YieldSharesToken proxy deployed at:", address(tokenProxy));

        // Phase 4: Deploy GovernanceController
        console2.log("=== Deploying GovernanceController ===");

        // Deploy GovernanceController implementation contract
        GovernanceController governanceImplementation = new GovernanceController();
        console2.log("GovernanceController implementation deployed at:", address(governanceImplementation));

        // Encode governance initialization data
        bytes memory governanceInitData = abi.encodeWithSelector(
            GovernanceController.initialize.selector,
            msg.sender, // initialOwner
            address(yieldBaseProxy) // yieldBaseAddress
        );

        // Deploy governance proxy
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
        console2.log("=== Deployment Verification ===");
        console2.log("PropertyNFT proxy owner:", propertyNFTProxy.owner());
        console2.log("PropertyNFT name:", propertyNFTProxy.name());
        console2.log("PropertyNFT symbol:", propertyNFTProxy.symbol());
        console2.log("PropertyNFT implementation:", _getImplementationAddress(address(propertyNFTProxy)));
        console2.log("YieldBase proxy owner:", yieldBaseProxy.owner());
        console2.log("YieldBase PropertyNFT reference:", address(yieldBaseProxy.propertyNFT()));
        console2.log("YieldBase implementation:", _getImplementationAddress(address(yieldBaseProxy)));
        console2.log("YieldSharesToken name:", tokenProxy.name());
        console2.log("YieldSharesToken symbol:", tokenProxy.symbol());
        console2.log("YieldSharesToken owner:", tokenProxy.owner());
        console2.log("YieldSharesToken implementation:", _getImplementationAddress(address(tokenProxy)));
        console2.log("YieldBase creates tokens per agreement");
        console2.log("Token YieldBase reference: set during agreement creation");
        console2.log("GovernanceController owner:", governanceProxy.owner());
        console2.log("GovernanceController YieldBase reference:", address(governanceProxy.yieldBase()));
        console2.log("GovernanceController implementation:", _getImplementationAddress(address(governanceProxy)));
        console2.log("YieldBase GovernanceController reference:", yieldBaseProxy.governanceController());

        console2.log("=== Example Usage ===");
        console2.log("1. Mint property NFT: propertyNFT.mintProperty(propertyHash, metadataURI)");
        console2.log("2. Verify property: propertyNFT.verifyProperty(tokenId)");
        console2.log("3. Create yield agreement: yieldBase.createYieldAgreement(propertyTokenId, capital, term, roi, payer)");
        console2.log("4. Make repayments: yieldBase.makeRepayment(agreementId) (payable)");
        console2.log("5. Create governance proposal: governance.createProposal(agreementId, proposalType, targetValue, description)");
        console2.log("6. Cast vote: governance.castVote(proposalId, support)");
        console2.log("7. Execute proposal: governance.executeProposal(proposalId)");

        console2.log("=== Deployment Complete ===");
        console2.log("PropertyNFT proxy:", address(propertyNFTProxy));
        console2.log("YieldBase proxy:", address(yieldBaseProxy));
        console2.log("YieldSharesToken proxy:", address(tokenProxy));
        console2.log("GovernanceController proxy:", address(governanceProxy));
    }

    /// @dev Helper function to get implementation address from proxy
    /// @param proxyAddress The address of the deployed proxy
    /// @return The implementation address
    function _getImplementationAddress(address proxyAddress) internal view returns (address) {
        // ERC1967 implementation slot
        bytes32 slot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        return address(uint160(uint256(vm.load(proxyAddress, slot))));
    }
}
