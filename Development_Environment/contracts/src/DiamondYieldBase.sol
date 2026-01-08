// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/******************************************************************************\
* Diamond Proxy for YieldBase
* 
* Based on EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
* Implementation uses mudgen/diamond-3-hardhat library
*
* This Diamond contract serves as a proxy that delegates calls to facets:
* - YieldBaseFacet: Core agreement creation and initialization
* - RepaymentFacet: All repayment operations (standard, partial, early)
* - GovernanceFacet: Governance-controlled operations (ROI, reserves, parameters)
* - DefaultManagementFacet: Default handling and missed payments
* - ViewsFacet: Read-only view functions
* 
* All facets share the same storage via ERC-7201 namespaced storage slots
* defined in DiamondYieldStorage.sol to prevent storage collisions.
\******************************************************************************/

import {LibDiamond} from "../lib/diamond-3-hardhat/contracts/libraries/LibDiamond.sol";
import {IDiamondCut} from "../lib/diamond-3-hardhat/contracts/interfaces/IDiamondCut.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title DiamondYieldBase
/// @notice Diamond proxy contract for the YieldBase system
/// @dev Implements EIP-2535 Diamond Standard for modular contract architecture.
///      Uses LibDiamond for core Diamond functionality (facet management, ownership).
///      All function calls are routed to appropriate facets via delegatecall.
contract DiamondYieldBase {
    
    /// @notice Initializes the Diamond with the owner and DiamondCutFacet
    /// @dev The DiamondCutFacet must be deployed first and its address passed here.
    ///      After construction, additional facets must be added via diamondCut.
    /// @param _contractOwner The address that will own this Diamond
    /// @param _diamondCutFacet The address of the deployed DiamondCutFacet
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

    /// @notice Fallback function that delegates calls to facets
    /// @dev Finds the facet for the function that is called and executes the
    ///      function if a facet is found, returning any value. This is the core
    ///      of the Diamond pattern - all external function calls are routed here.
    ///      Uses assembly for efficient delegatecall execution.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        
        // Get diamond storage
        assembly {
            ds.slot := position
        }
        
        // Get facet from function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "DiamondYieldBase: Function does not exist");
        
        // Execute external function from facet using delegatecall and return any value
        assembly {
            // Copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            
            // Execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            
            // Get any return value
            returndatacopy(0, 0, returndatasize())
            
            // Return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /// @notice Allows the Diamond to receive ETH
    /// @dev Required for repayment functions and reserve allocations that send ETH
    receive() external payable {}
}

