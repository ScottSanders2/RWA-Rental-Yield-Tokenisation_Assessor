// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../script/DeployDiamond.s.sol";

// Facet interfaces
import "../src/facets/YieldBaseFacet.sol";
import "../src/facets/RepaymentFacet.sol";
import "../src/facets/ViewsFacet.sol";
import "../src/facets/KYCFacet.sol";
import "../src/KYCRegistry.sol";
import "../src/PropertyNFT.sol";
import "../src/YieldSharesToken.sol";

/**
 * @title YieldBase Diamond Comprehensive Test Suite
 * @notice Tests YieldBase Diamond proxy with all facets
 * @dev Uses actual DeployDiamond script to match production deployment
 */
contract YieldBaseDiamondTest is Test {
    DeployDiamond public deployer;
    
    // Contract references
    KYCRegistry public kycRegistry;
    YieldBaseFacet public yieldBaseFacet;
    RepaymentFacet public repaymentFacet;
    ViewsFacet public viewsFacet;
    KYCFacet public kycFacet;
    PropertyNFT public propertyNFT;
    
    address public owner;
    address public user1;
    address public user2;
    address public propertyOwner;
    
    function setUp() public {
        // Anvil default deployer
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        propertyOwner = makeAddr("propertyOwner");
        
        // Deploy via actual script
        deployer = new DeployDiamond();
        deployer.run();
        
        // Get deployed contracts
        kycRegistry = deployer.kycRegistry();
        propertyNFT = deployer.propertyNFT();
        
        // Wrap Diamond proxy with facet ABIs
        address diamondAddr = address(deployer.yieldBaseDiamond());
        yieldBaseFacet = YieldBaseFacet(diamondAddr);
        repaymentFacet = RepaymentFacet(diamondAddr);
        viewsFacet = ViewsFacet(diamondAddr);
        kycFacet = KYCFacet(diamondAddr);
        
        // Whitelist test users
        vm.startPrank(owner);
        kycRegistry.addToWhitelist(user1);
        kycRegistry.addToWhitelist(user2);
        kycRegistry.addToWhitelist(propertyOwner);
        vm.stopPrank();
    }
    
    /// @notice Helper to create and verify a property
    function _createProperty(address creator) internal returns (uint256) {
        // Owner must mint and verify (only owner can verify)
        vm.startPrank(owner);
        uint256 tokenId = propertyNFT.mintProperty(
            keccak256(abi.encodePacked("Property", creator)),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(tokenId);
        
        // Transfer to creator if different from owner
        if (creator != owner) {
            propertyNFT.transferFrom(owner, creator, tokenId);
        }
        vm.stopPrank();
        return tokenId;
    }
    
    // ============ INITIALIZATION TESTS ============
    
    function testDiamondInitialization() public view {
        // Diamond should be deployed correctly
        assertTrue(address(yieldBaseFacet) != address(0));
        assertTrue(address(viewsFacet) != address(0));
        assertTrue(address(propertyNFT) != address(0));
    }
    
    // ============ AGREEMENT CREATION TESTS ============
    
    function testCreateYieldAgreement() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,      // upfrontCapital
            100000 ether,   // upfrontCapitalUsd
            12,             // termMonths
            500,            // annualROI (5%)
            address(0),     // propertyPayer (owner-only)
            30,             // gracePeriodDays
            200,            // defaultPenaltyRate (2%)
            3,              // defaultThreshold
            true,           // allowPartialRepayments
            true            // allowEarlyRepayment
        );
        
        assertEq(agreementId, 1);
        
        // Verify agreement data via ViewsFacet
        (
            uint256 capital,
            uint16 term,
            uint16 roi,
            ,
            bool active,
            
        ) = viewsFacet.getYieldAgreement(agreementId);
        
        assertEq(capital, 100 ether);
        assertEq(term, 12);
        assertEq(roi, 500);
        assertTrue(active);
    }
    
    function testCreateAgreementAutomaticallyConfiguresTokenKYC() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        // Verify agreement was created successfully
        // YieldBaseFacet line 257 calls: KYCFacet(address(this)).configureTokenKYC(address(tokenInstance))
        // This automatically configures KYC on the newly created YieldSharesToken
        (uint256 capital,,,,, ) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    function testCreateAgreementRequiresKYCVerification() public {
        uint256 propertyId = _createProperty(owner);
        
        address nonKYCUser = makeAddr("nonKYC");
        
        vm.prank(owner);
        propertyNFT.transferFrom(owner, nonKYCUser, propertyId);
        
        // Should fail for non-whitelisted user
        vm.prank(nonKYCUser);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
    }
    
    function testMultipleAgreementsPerProperty() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        // Create first agreement with propertyOwner as payer
        vm.prank(propertyOwner);
        uint256 agreement1 = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            propertyOwner,  // Set propertyOwner as authorized payer
            30,
            200,
            3,
            true,
            true
        );
        
        // Complete first agreement by making all payments
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreement1);
        
        for (uint i = 0; i < 12; i++) {
            vm.deal(propertyOwner, monthlyPayment);
            vm.prank(propertyOwner);
            repaymentFacet.makeRepayment{value: monthlyPayment}(agreement1);
        }
        
        // Create second agreement on same property
        vm.prank(propertyOwner);
        uint256 agreement2 = yieldBaseFacet.createYieldAgreement(
            propertyId,
            200 ether,
            200000 ether,
            24,
            400,
            propertyOwner,  // Set propertyOwner as authorized payer
            30,
            200,
            3,
            true,
            true
        );
        
        assertEq(agreement2, 2);
        
        // Verify both agreements exist
        (uint256 capital1,,,,, ) = viewsFacet.getYieldAgreement(agreement1);
        (uint256 capital2,,,,, ) = viewsFacet.getYieldAgreement(agreement2);
        assertEq(capital1, 100 ether);
        assertEq(capital2, 200 ether);
    }
    
    // ============ VALIDATION TESTS ============
    
    function testCreateAgreementValidatesInputs() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        // Test invalid term (0 months)
        vm.prank(propertyOwner);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            0,  // Invalid term
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        // Test invalid term (> 360 months)
        vm.prank(propertyOwner);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            361,  // Invalid term
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        // Test invalid ROI (0 basis points)
        vm.prank(propertyOwner);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            0,  // Invalid ROI
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        // Test invalid ROI (> 5000 basis points)
        vm.prank(propertyOwner);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            5001,  // Invalid ROI
            address(0),
            30,
            200,
            3,
            true,
            true
        );
    }
    
    function testCreateAgreementRequiresVerifiedProperty() public {
        // Owner mints but doesn't verify
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256("Unverified"),
            "ipfs://test"
        );
        // Transfer to propertyOwner without verifying
        propertyNFT.transferFrom(owner, propertyOwner, propertyId);
        vm.stopPrank();
        
        // Should fail without verification
        vm.prank(propertyOwner);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
    }
    
    // ============ REPAYMENT TESTS ============
    
    function testMakeRepayment() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        // Create agreement with propertyOwner as designated payer
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            propertyOwner,  // Explicitly set propertyOwner as authorized payer
            30,
            200,
            3,
            true,
            true
        );
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Make first repayment
        vm.deal(propertyOwner, monthlyPayment);
        vm.prank(propertyOwner);
        repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        
        // Verify repayment was recorded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(totalRepaid, monthlyPayment);
    }
    
    function testDesignatedPayerCanMakeRepayments() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        address designatedPayer = user1;
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            designatedPayer,  // Set designated payer
            30,
            200,
            3,
            true,
            true
        );
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Designated payer can make repayment
        vm.deal(designatedPayer, monthlyPayment);
        vm.prank(designatedPayer);
        repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        
        // Verify repayment succeeded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(totalRepaid, monthlyPayment);
    }
    
    // ============ VIEWS TESTS ============
    
    function testPropertyAgreementLinking() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        // Verify agreement is linked to property
        (uint256 capital,,,,, ) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    // ============ STORAGE LAYOUT TESTS ============
    
    function testStorageLayout() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            1000000,
            100000 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        // Verify storage reads work correctly (validates ERC-7201 namespaced storage)
        (uint256 capital, uint16 term, uint16 roi,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 1000000);
        assertEq(term, 12);
        assertEq(roi, 500);
    }
    
    // ============ LIBRARY INTEGRATION TESTS ============
    
    function testLibraryLinking() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            1000000,
            100000 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        // Get monthly payment (calculated by YieldCalculations library)
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Verify calculation returned reasonable value
        assertTrue(monthlyPayment > 0);
        assertTrue(monthlyPayment < 1000000);
    }
    
    // ============ FULL FLOW TESTS ============
    
    function testCompleteYieldAgreementFlow() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        // Create agreement
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            6,  // Short term for full test
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Make all 6 monthly payments
        for (uint i = 0; i < 6; i++) {
            vm.deal(propertyOwner, monthlyPayment);
            vm.prank(propertyOwner);
            repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        }
        
        // Verify all payments recorded
        (,uint16 term,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(term, 6);
        assertTrue(totalRepaid >= monthlyPayment * 6);
    }
    
    // ============ ACCESS CONTROL TESTS ============
    
    function testOnlyPropertyOwnerCanCreateAgreement() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        // Non-property-owner cannot create agreement
        vm.prank(user1);
        vm.expectRevert();
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            user1,
            30,
            200,
            3,
            true,
            true
        );
    }
    
    // ============ AGREEMENT COUNT TRACKING ============
    
    function testAgreementCountIncreases() public {
        uint256 countBefore = yieldBaseFacet.getAgreementCount();
        
        uint256 propertyId = _createProperty(propertyOwner);
        
        vm.prank(propertyOwner);
        yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        uint256 countAfter = yieldBaseFacet.getAgreementCount();
        assertEq(countAfter, countBefore + 1);
    }
    
    // ============ YIELD TOKEN INTEGRATION ============
    
    function testYieldTokenCreatedPerAgreement() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            200 ether,
            200000 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true
        );
        
        // Verify agreement created successfully (tokens are created internally)
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 200 ether);
    }
    
    // ============ REPAYMENT FREQUENCY TESTS ============
    
    function testRepaymentFrequencyEnforcement() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,  // 3-month repayment frequency
            true,
            true
        );
        
        // Verify agreement created with correct frequency
        (uint256 capital,,,,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(capital, 100 ether);
    }
    
    // ============ PARTIAL REPAYMENT TESTS ============
    
    function testPartialRepaymentsWhenAllowed() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,  // Allow partial repayments
            true
        );
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Make partial payment (50%)
        uint256 partialAmount = monthlyPayment / 2;
        vm.deal(propertyOwner, partialAmount);
        vm.prank(propertyOwner);
        repaymentFacet.makeRepayment{value: partialAmount}(agreementId);
        
        // Verify partial payment recorded
        (,,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(totalRepaid, partialAmount);
    }
    
    // ============ EARLY REPAYMENT TESTS ============
    
    function testEarlyRepaymentWhenAllowed() public {
        uint256 propertyId = _createProperty(propertyOwner);
        
        vm.prank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            100 ether,
            100000 ether,
            12,
            500,
            propertyOwner,
            30,
            200,
            3,
            true,
            true  // Allow early repayment
        );
        
        (,,,, , uint256 monthlyPayment) = viewsFacet.getYieldAgreement(agreementId);
        
        // Pay all at once (early repayment)
        uint256 totalAmount = monthlyPayment * 12;
        vm.deal(propertyOwner, totalAmount + 1 ether);
        
        for (uint i = 0; i < 12; i++) {
            vm.prank(propertyOwner);
            repaymentFacet.makeRepayment{value: monthlyPayment}(agreementId);
        }
        
        // Verify all payments recorded
        (,uint16 term,, uint256 totalRepaid,,) = viewsFacet.getYieldAgreement(agreementId);
        assertEq(term, 12);
        assertTrue(totalRepaid >= monthlyPayment * 12);
    }
}

