// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibDiamond} from "../lib/diamond-3-hardhat/contracts/libraries/LibDiamond.sol";
import {IDiamondCut} from "../lib/diamond-3-hardhat/contracts/interfaces/IDiamondCut.sol";

/// @title DiamondCombinedToken
/// @notice Diamond proxy for CombinedPropertyYieldToken with EIP-2535 Diamond Standard
/// @dev Routes function calls to appropriate facets via delegatecall
///      Uses ERC-7201 namespaced storage to prevent collisions
contract DiamondCombinedToken {
    /// @notice Initializes the Diamond with the owner and DiamondCutFacet
    /// @param _contractOwner The address that will own the Diamond
    /// @param _diamondCutFacet The address of the DiamondCutFacet
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        LibDiamond.setContractOwner(_contractOwner);

        // Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        LibDiamond.diamondCut(cut, address(0), "");
    }

    /// @notice Fallback function to route calls to appropriate facets
    /// @dev Uses delegatecall to preserve msg.sender and msg.value
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}
}

