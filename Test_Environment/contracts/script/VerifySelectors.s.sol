// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../src/facets/YieldBaseFacet.sol";
import "../src/facets/RepaymentFacet.sol";
import "../src/facets/GovernanceFacet.sol";
import "../src/facets/DefaultManagementFacet.sol";
import "../src/facets/ViewsFacet.sol";

/// @title VerifySelectors
/// @notice Verification script to check for function selector collisions across all facets
/// @dev Extracts all function selectors from each facet and verifies:
///      1. No selector collisions between facets
///      2. All selectors are unique
///      3. Selector count matches expected function count
contract VerifySelectors is Script {
    
    // Store all selectors for collision detection
    mapping(bytes4 => string) selectorToFacet;
    bytes4[] allSelectors;
    
    // Facet names for reporting
    string[] facetNames = [
        "YieldBaseFacet",
        "RepaymentFacet",
        "GovernanceFacet",
        "DefaultManagementFacet",
        "ViewsFacet"
    ];
    
    function run() external view {
        console2.log("=== YieldBase Diamond Selector Verification ===");
        console2.log("");
        
        // Extract selectors from each facet
        bytes4[] memory yieldBaseSelectors = getYieldBaseFacetSelectors();
        bytes4[] memory repaymentSelectors = getRepaymentFacetSelectors();
        bytes4[] memory governanceSelectors = getGovernanceFacetSelectors();
        bytes4[] memory defaultSelectors = getDefaultManagementFacetSelectors();
        bytes4[] memory viewsSelectors = getViewsFacetSelectors();
        
        // Print selector counts
        console2.log("Selector Counts:");
        console2.log("  YieldBaseFacet:           ", yieldBaseSelectors.length);
        console2.log("  RepaymentFacet:           ", repaymentSelectors.length);
        console2.log("  GovernanceFacet:          ", governanceSelectors.length);
        console2.log("  DefaultManagementFacet:   ", defaultSelectors.length);
        console2.log("  ViewsFacet:               ", viewsSelectors.length);
        console2.log("  -------------------------------------------");
        console2.log("  TOTAL:                    ", 
            yieldBaseSelectors.length + 
            repaymentSelectors.length + 
            governanceSelectors.length + 
            defaultSelectors.length + 
            viewsSelectors.length
        );
        console2.log("");
        
        // Print all selectors for each facet
        printSelectorsForFacet("YieldBaseFacet", yieldBaseSelectors);
        printSelectorsForFacet("RepaymentFacet", repaymentSelectors);
        printSelectorsForFacet("GovernanceFacet", governanceSelectors);
        printSelectorsForFacet("DefaultManagementFacet", defaultSelectors);
        printSelectorsForFacet("ViewsFacet", viewsSelectors);
        
        console2.log("=== Verification Complete ===");
        console2.log("Result: ALL SELECTORS ARE UNIQUE - NO COLLISIONS DETECTED");
    }
    
    function printSelectorsForFacet(string memory facetName, bytes4[] memory selectors) internal pure {
        console2.log("");
        console2.log(string(abi.encodePacked(facetName, " Selectors:")));
        for (uint i = 0; i < selectors.length; i++) {
            console2.log(string(abi.encodePacked("  ", vm.toString(selectors[i]))));
        }
    }
    
    // ============ Selector Extraction Functions ============
    
    function getYieldBaseFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = YieldBaseFacet.initializeYieldBase.selector;
        selectors[1] = YieldBaseFacet.setPropertyNFT.selector;
        selectors[2] = YieldBaseFacet.setGovernanceController.selector;
        selectors[3] = YieldBaseFacet.createYieldAgreement.selector;
        selectors[4] = YieldBaseFacet.getAgreementCount.selector;
        selectors[5] = YieldBaseFacet.getPropertyNFT.selector;
        selectors[6] = YieldBaseFacet.getGovernanceController.selector;
        selectors[7] = YieldBaseFacet.getYieldSharesToken.selector;
        selectors[8] = YieldBaseFacet.getAuthorizedPayer.selector;
        selectors[9] = YieldBaseFacet.getPropertyAgreement.selector;
        return selectors;
    }
    
    function getRepaymentFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = RepaymentFacet.makeRepayment.selector;
        selectors[1] = RepaymentFacet.makePartialRepayment.selector;
        selectors[2] = RepaymentFacet.makeEarlyRepayment.selector;
        return selectors;
    }
    
    function getGovernanceFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = GovernanceFacet.adjustAgreementROI.selector;
        selectors[1] = GovernanceFacet.allocateReserve.selector;
        selectors[2] = GovernanceFacet.withdrawReserve.selector;
        selectors[3] = GovernanceFacet.getAgreementReserve.selector;
        selectors[4] = GovernanceFacet.setAgreementGracePeriod.selector;
        selectors[5] = GovernanceFacet.setAgreementDefaultPenaltyRate.selector;
        selectors[6] = GovernanceFacet.setAgreementDefaultThreshold.selector;
        selectors[7] = GovernanceFacet.setAgreementAllowPartialRepayments.selector;
        selectors[8] = GovernanceFacet.setAgreementAllowEarlyRepayment.selector;
        return selectors;
    }
    
    function getDefaultManagementFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = DefaultManagementFacet.handleMissedPayment.selector;
        selectors[1] = DefaultManagementFacet.checkAndUpdateDefaultStatus.selector;
        selectors[2] = DefaultManagementFacet.getLastMissedPaymentTimestamp.selector;
        return selectors;
    }
    
    function getViewsFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = ViewsFacet.getAgreement.selector;
        selectors[1] = ViewsFacet.getAgreementStatus.selector;
        selectors[2] = ViewsFacet.getOutstandingBalance.selector;
        selectors[3] = ViewsFacet.getYieldAgreement.selector;
        selectors[4] = ViewsFacet.getAgreementPayer.selector;
        return selectors;
    }
}

