// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../src/interfaces/IDiamondLoupe.sol";

/**
 * @title ConfigureAmoyDiamonds
 * @notice Post-deployment configuration script for Polygon Amoy testnet
 * @dev Registers facets with Diamond proxies and links all contracts
 * 
 * USAGE:
 * docker exec -e PRIVATE_KEY=0xYOUR_PRIVATE_KEY rwa-dev-foundry bash -c \
 *   "cd /workspace/contracts && forge script script/ConfigureAmoyDiamonds.s.sol:ConfigureAmoyDiamonds \
 *   --rpc-url https://rpc-amoy.polygon.technology/ --broadcast -vvvv"
 */
contract ConfigureAmoyDiamonds is Script {
    
    // ============================================
    // DEPLOYED CONTRACT ADDRESSES (AMOY TESTNET)
    // ============================================
    
    // Diamond Proxies
    address constant DIAMOND_YIELD_BASE = 0xb921e03a44fb126289c9b788Ab1D08731CDDfaFE;
    address constant DIAMOND_COMBINED_TOKEN = 0x27c99b55bd4e1fc801c071a97978adcdd038cd68;
    
    // Standard Facets (shared by both Diamonds)
    address constant DIAMOND_CUT_FACET = 0x616e72a6768afc04f927acbaed97a7679cb0ee34;
    address constant DIAMOND_LOUPE_FACET = 0xfb3fbce3201293568b239bf8fc827c1f4714e811;
    address constant OWNERSHIP_FACET = 0x3714b4a091a0aeb1f13540abcdcd30f134ab4de8;
    
    // YieldBase Facets
    address constant YIELD_BASE_FACET = 0x32737907268795543214cffe84420b4f673ebaa7;
    address constant REPAYMENT_FACET = 0x0337733e2821971b08fa96f9ec9151038d7822fe;
    address constant GOVERNANCE_FACET = 0x8a36960fbbed08cff1f05cbdd593555d04807ec7;
    address constant DEFAULT_MANAGEMENT_FACET = 0x841935479e7907e8e33c547a2ac19af7e555ed02;
    address constant VIEWS_FACET = 0xff09e7c2fb20b1bdcd813fda248dd8bbee3ad155;
    address constant KYC_FACET = 0x7a7d811450f6c5dc0cb60b38a6cd0f345602c0f6;
    
    // CombinedToken Facets
    address constant MINTING_FACET = 0xedfdc6ee6a970038527abb0d572d2e31b548592f;
    address constant COMBINED_TOKEN_CORE_FACET = 0xf7bdb7345e682dfde2e74686dd7e789301cd5b87;
    address constant DISTRIBUTION_FACET = 0x0114867de82fe541cda472d86056d8d0787f8ab4;
    address constant RESTRICTIONS_FACET = 0xd146cdfa6211ae54650f0faf8b221f9442730da7;
    address constant COMBINED_VIEWS_FACET = 0x4ba27ad2bc4641e8204b7a54e3d42e507641922d;
    
    // Supporting Contracts (Proxies)
    address constant PROPERTY_NFT_PROXY = 0x9d883fe441c3fcb5ad4eb173f3374b5461eb0cb0;
    address constant KYC_REGISTRY_PROXY = 0x677695F85Ebfad649C27D69631B3417327159820;
    address constant GOVERNANCE_CONTROLLER_PROXY = 0x04eeA5a94833eF66fDfE2b8Cfadda235c6E9b284;
    
    // ============================================
    // MAIN EXECUTION
    // ============================================
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console2.log("=============================================");
        console2.log("CONFIGURING AMOY DIAMOND CONTRACTS");
        console2.log("=============================================");
        console2.log("Deployer:", deployer);
        console2.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Register YieldBase Facets
        console2.log("STEP 1: Registering YieldBase Facets...");
        _registerYieldBaseFacets();
        console2.log("  YieldBase facets registered!");
        console2.log("");
        
        // Step 2: Register CombinedToken Facets
        console2.log("STEP 2: Registering CombinedToken Facets...");
        _registerCombinedTokenFacets();
        console2.log("  CombinedToken facets registered!");
        console2.log("");
        
        // Step 3: Link KYCRegistry to contracts
        console2.log("STEP 3: Linking KYCRegistry...");
        _linkKYCRegistry();
        console2.log("  KYCRegistry linked!");
        console2.log("");
        
        // Step 4: Link GovernanceController to YieldBase
        console2.log("STEP 4: Linking GovernanceController...");
        _linkGovernanceController();
        console2.log("  GovernanceController linked!");
        console2.log("");
        
        // Step 5: Link CombinedToken to YieldBase
        console2.log("STEP 5: Linking CombinedToken...");
        _linkCombinedToken();
        console2.log("  CombinedToken linked!");
        console2.log("");
        
        vm.stopBroadcast();
        
        console2.log("=============================================");
        console2.log("CONFIGURATION COMPLETE!");
        console2.log("=============================================");
        console2.log("");
        console2.log("Verify by calling on DiamondYieldBase:");
        console2.log("  - facetAddresses() should return 8 addresses");
        console2.log("  - owner() should return deployer");
        console2.log("");
    }
    
    // ============================================
    // STEP 1: REGISTER YIELDBASE FACETS
    // ============================================
    
    function _registerYieldBaseFacets() internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](6);
        
        // Note: DiamondCutFacet is already registered during deployment
        // We register the remaining 6 facets (Loupe, Ownership, and 4 YieldBase facets)
        
        // 1. DiamondLoupeFacet
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: DIAMOND_LOUPE_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getLoupeSelectors()
        });
        
        // 2. OwnershipFacet
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: OWNERSHIP_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getOwnershipSelectors()
        });
        
        // 3. YieldBaseFacet
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: YIELD_BASE_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getYieldBaseSelectors()
        });
        
        // 4. RepaymentFacet
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: REPAYMENT_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getRepaymentSelectors()
        });
        
        // 5. GovernanceFacet
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: GOVERNANCE_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getGovernanceFacetSelectors()
        });
        
        // 6. DefaultManagementFacet
        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: DEFAULT_MANAGEMENT_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getDefaultManagementSelectors()
        });
        
        // Call diamondCut on DiamondYieldBase
        IDiamondCut(DIAMOND_YIELD_BASE).diamondCut(cuts, address(0), "");
        
        // Register ViewsFacet and KYCFacet in a second call (to avoid stack too deep)
        IDiamondCut.FacetCut[] memory cuts2 = new IDiamondCut.FacetCut[](2);
        
        cuts2[0] = IDiamondCut.FacetCut({
            facetAddress: VIEWS_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getViewsSelectors()
        });
        
        cuts2[1] = IDiamondCut.FacetCut({
            facetAddress: KYC_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getKYCFacetSelectors()
        });
        
        IDiamondCut(DIAMOND_YIELD_BASE).diamondCut(cuts2, address(0), "");
    }
    
    // ============================================
    // STEP 2: REGISTER COMBINEDTOKEN FACETS
    // ============================================
    
    function _registerCombinedTokenFacets() internal {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](6);
        
        // 1. DiamondLoupeFacet
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: DIAMOND_LOUPE_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getLoupeSelectors()
        });
        
        // 2. OwnershipFacet
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: OWNERSHIP_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getOwnershipSelectors()
        });
        
        // 3. MintingFacet
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: MINTING_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getMintingSelectors()
        });
        
        // 4. CombinedTokenCoreFacet
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: COMBINED_TOKEN_CORE_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getCombinedTokenCoreSelectors()
        });
        
        // 5. DistributionFacet
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: DISTRIBUTION_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getDistributionSelectors()
        });
        
        // 6. RestrictionsFacet
        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: RESTRICTIONS_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getRestrictionsSelectors()
        });
        
        // Call diamondCut on DiamondCombinedToken
        IDiamondCut(DIAMOND_COMBINED_TOKEN).diamondCut(cuts, address(0), "");
        
        // Register CombinedViewsFacet in a second call
        IDiamondCut.FacetCut[] memory cuts2 = new IDiamondCut.FacetCut[](1);
        
        cuts2[0] = IDiamondCut.FacetCut({
            facetAddress: COMBINED_VIEWS_FACET,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: _getCombinedViewsSelectors()
        });
        
        IDiamondCut(DIAMOND_COMBINED_TOKEN).diamondCut(cuts2, address(0), "");
    }
    
    // ============================================
    // STEP 3: LINK KYC REGISTRY
    // ============================================
    
    function _linkKYCRegistry() internal {
        // Link to DiamondYieldBase (via KYCFacet)
        (bool success1,) = DIAMOND_YIELD_BASE.call(
            abi.encodeWithSignature("setKYCRegistry(address)", KYC_REGISTRY_PROXY)
        );
        require(success1, "Failed to set KYCRegistry on DiamondYieldBase");
        
        // Link to DiamondCombinedToken (via CombinedTokenCoreFacet)
        (bool success2,) = DIAMOND_COMBINED_TOKEN.call(
            abi.encodeWithSignature("setKYCRegistry(address)", KYC_REGISTRY_PROXY)
        );
        require(success2, "Failed to set KYCRegistry on DiamondCombinedToken");
        
        // Link to PropertyNFT
        (bool success3,) = PROPERTY_NFT_PROXY.call(
            abi.encodeWithSignature("setKYCRegistry(address)", KYC_REGISTRY_PROXY)
        );
        require(success3, "Failed to set KYCRegistry on PropertyNFT");
    }
    
    // ============================================
    // STEP 4: LINK GOVERNANCE CONTROLLER
    // ============================================
    
    function _linkGovernanceController() internal {
        (bool success,) = DIAMOND_YIELD_BASE.call(
            abi.encodeWithSignature("setGovernanceController(address)", GOVERNANCE_CONTROLLER_PROXY)
        );
        require(success, "Failed to set GovernanceController on DiamondYieldBase");
    }
    
    // ============================================
    // STEP 5: LINK COMBINED TOKEN
    // ============================================
    
    function _linkCombinedToken() internal {
        (bool success,) = DIAMOND_YIELD_BASE.call(
            abi.encodeWithSignature("setCombinedTokenAddress(address)", DIAMOND_COMBINED_TOKEN)
        );
        require(success, "Failed to set CombinedToken on DiamondYieldBase");
    }
    
    // ============================================
    // FUNCTION SELECTOR HELPERS
    // ============================================
    
    function _getLoupeSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;
        selectors[4] = bytes4(keccak256("supportsInterface(bytes4)"));
        return selectors;
    }
    
    function _getOwnershipSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(keccak256("owner()"));
        selectors[1] = bytes4(keccak256("transferOwnership(address)"));
        return selectors;
    }
    
    function _getYieldBaseSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = bytes4(keccak256("createYieldAgreement(uint256,uint256,uint256,uint16,uint16,address,uint16,uint16,uint8,bool,bool)"));
        selectors[1] = bytes4(keccak256("setPropertyNFT(address)"));
        selectors[2] = bytes4(keccak256("setCombinedTokenAddress(address)"));
        selectors[3] = bytes4(keccak256("setGovernanceController(address)"));
        selectors[4] = bytes4(keccak256("getPropertyNFT()"));
        selectors[5] = bytes4(keccak256("getCombinedTokenAddress()"));
        selectors[6] = bytes4(keccak256("getGovernanceController()"));
        selectors[7] = bytes4(keccak256("getAgreementCount()"));
        return selectors;
    }
    
    function _getRepaymentSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = bytes4(keccak256("makeRepayment(uint256)"));
        selectors[1] = bytes4(keccak256("makePartialRepayment(uint256,uint256)"));
        selectors[2] = bytes4(keccak256("makeEarlyRepayment(uint256)"));
        return selectors;
    }
    
    function _getGovernanceFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = bytes4(keccak256("adjustAgreementROI(uint256,uint16)"));
        selectors[1] = bytes4(keccak256("allocateReserve(uint256)"));
        selectors[2] = bytes4(keccak256("withdrawReserve(uint256,uint256)"));
        selectors[3] = bytes4(keccak256("getAgreementReserve(uint256)"));
        selectors[4] = bytes4(keccak256("setAgreementGracePeriod(uint256,uint16)"));
        selectors[5] = bytes4(keccak256("setAgreementDefaultPenaltyRate(uint256,uint16)"));
        selectors[6] = bytes4(keccak256("setAgreementDefaultThreshold(uint256,uint8)"));
        selectors[7] = bytes4(keccak256("setAgreementAllowPartialRepayments(uint256,bool)"));
        selectors[8] = bytes4(keccak256("setAgreementAllowEarlyRepayment(uint256,bool)"));
        return selectors;
    }
    
    function _getDefaultManagementSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = bytes4(keccak256("handleMissedPayment(uint256)"));
        selectors[1] = bytes4(keccak256("checkAndUpdateDefaultStatus(uint256)"));
        selectors[2] = bytes4(keccak256("getLastMissedPaymentTimestamp(uint256)"));
        return selectors;
    }
    
    function _getViewsSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = bytes4(keccak256("getAgreement(uint256)"));
        selectors[1] = bytes4(keccak256("getAgreementStatus(uint256)"));
        selectors[2] = bytes4(keccak256("getOutstandingBalance(uint256)"));
        selectors[3] = bytes4(keccak256("getYieldAgreement(uint256)"));
        selectors[4] = bytes4(keccak256("getAgreementPayer(uint256)"));
        selectors[5] = bytes4(keccak256("getAgreementToken(uint256)"));
        return selectors;
    }
    
    function _getKYCFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = bytes4(keccak256("setKYCRegistry(address)"));
        selectors[1] = bytes4(keccak256("getKYCRegistry()"));
        selectors[2] = bytes4(keccak256("requireKYCVerified(address)"));
        selectors[3] = bytes4(keccak256("isKYCVerified(address)"));
        selectors[4] = bytes4(keccak256("configureTokenKYC(address)"));
        return selectors;
    }
    
    function _getMintingSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = bytes4(keccak256("mintPropertyTokens(bytes32,string)"));
        selectors[1] = bytes4(keccak256("mintYieldTokens(uint256,uint256,uint256,uint16,address,uint256)"));
        selectors[2] = bytes4(keccak256("batchMintYieldTokens(uint256[],address[][],uint256[][])"));
        selectors[3] = bytes4(keccak256("verifyProperty(uint256)"));
        return selectors;
    }
    
    function _getCombinedTokenCoreSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = bytes4(keccak256("initializeCombinedToken(string,address)"));
        selectors[1] = bytes4(keccak256("setTokenCounters(uint256,uint256)"));
        selectors[2] = bytes4(keccak256("getTokenCounters()"));
        selectors[3] = bytes4(keccak256("setKYCRegistry(address)"));
        selectors[4] = bytes4(keccak256("uri(uint256)"));
        selectors[5] = bytes4(keccak256("totalSupply(uint256)"));
        selectors[6] = bytes4(keccak256("getTokenHolders(uint256)"));
        selectors[7] = bytes4(keccak256("burn(uint256,uint256)"));
        selectors[8] = bytes4(keccak256("safeTransferFrom(address,address,uint256,uint256,bytes)"));
        selectors[9] = bytes4(keccak256("safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)"));
        return selectors;
    }
    
    function _getDistributionSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = bytes4(keccak256("distributeYieldRepayment(uint256)"));
        selectors[1] = bytes4(keccak256("distributePartialYieldRepayment(uint256)"));
        selectors[2] = bytes4(keccak256("handleYieldDefault(uint256)"));
        selectors[3] = bytes4(keccak256("batchDistributeRepayments(uint256[],uint256[])"));
        selectors[4] = bytes4(keccak256("claimUnclaimedRemainder()"));
        return selectors;
    }
    
    function _getRestrictionsSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = bytes4(keccak256("setYieldTokenRestrictions(uint256,uint256,uint256,uint256)"));
        selectors[1] = bytes4(keccak256("pauseYieldTokenTransfers(uint256)"));
        selectors[2] = bytes4(keccak256("unpauseYieldTokenTransfers(uint256)"));
        selectors[3] = bytes4(keccak256("setYieldTokenLockupEndTimestamp(uint256,uint256)"));
        selectors[4] = bytes4(keccak256("setYieldTokenMaxSharesPerInvestor(uint256,uint256)"));
        selectors[5] = bytes4(keccak256("setYieldTokenMinHoldingPeriod(uint256,uint256)"));
        selectors[6] = bytes4(keccak256("checkYieldTokenTransfer(uint256,address,address,uint256)"));
        selectors[7] = bytes4(keccak256("getPropertyTokenIdCounter()"));
        selectors[8] = bytes4(keccak256("getYieldTokenIdCounter()"));
        return selectors;
    }
    
    function _getCombinedViewsSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = bytes4(keccak256("getPropertyMetadata(uint256)"));
        selectors[1] = bytes4(keccak256("getYieldAgreementData(uint256)"));
        selectors[2] = bytes4(keccak256("getPooledContributionData(uint256)"));
        selectors[3] = bytes4(keccak256("getContributorBalance(uint256,address)"));
        selectors[4] = bytes4(keccak256("getYieldTokenForProperty(uint256)"));
        selectors[5] = bytes4(keccak256("getPropertyTokenForYield(uint256)"));
        selectors[6] = bytes4(keccak256("getUnclaimedRemainder(address)"));
        selectors[7] = bytes4(keccak256("getPropertyTokenIdCounter()"));
        selectors[8] = bytes4(keccak256("getYieldTokenIdCounter()"));
        return selectors;
    }
}

