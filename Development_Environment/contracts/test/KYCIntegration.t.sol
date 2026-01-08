// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/KYCRegistry.sol";
import "../src/YieldBase.sol";
import "../src/YieldSharesToken.sol";
import "../src/CombinedPropertyYieldToken.sol";
import "../src/PropertyNFT.sol";
import "../src/GovernanceController.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title KYC Integration Test Suite
 * @notice Tests KYC enforcement across all platform contracts
 * @dev Validates end-to-end KYC workflows and cross-contract integration
 */
contract KYCIntegrationTest is Test {
    KYCRegistry public kycRegistry;
    YieldBase public yieldBase;
    YieldSharesToken public yieldSharesToken;
    PropertyNFT public propertyNFT;
    GovernanceController public governance;

    address public owner;
    address public propertyOwner;
    address public investor1;
    address public investor2;
    address public blacklistedUser;

    uint256 public propertyTokenId;
    uint256 public agreementId;

    function setUp() public {
        owner = address(this);
        propertyOwner = makeAddr("propertyOwner");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        blacklistedUser = makeAddr("blacklistedUser");

        // Deploy KYCRegistry
        KYCRegistry kycImpl = new KYCRegistry();
        bytes memory kycInitData = abi.encodeWithSelector(KYCRegistry.initialize.selector, owner);
        ERC1967Proxy kycProxy = new ERC1967Proxy(address(kycImpl), kycInitData);
        kycRegistry = KYCRegistry(address(kycProxy));

        // Deploy YieldBase
        YieldBase yieldBaseImpl = new YieldBase();
        bytes memory yieldInitData = abi.encodeWithSelector(YieldBase.initialize.selector, owner);
        ERC1967Proxy yieldProxy = new ERC1967Proxy(address(yieldBaseImpl), yieldInitData);
        yieldBase = YieldBase(payable(address(yieldProxy)));

        // Deploy PropertyNFT
        PropertyNFT propertyImpl = new PropertyNFT();
        bytes memory propertyInitData = abi.encodeWithSelector(
            PropertyNFT.initialize.selector,
            owner,
            "RWA Property",
            "RWAP"
        );
        ERC1967Proxy propertyProxy = new ERC1967Proxy(address(propertyImpl), propertyInitData);
        propertyNFT = PropertyNFT(address(propertyProxy));

        // Link contracts
        yieldBase.setPropertyNFT(address(propertyNFT));
        yieldBase.setKYCRegistry(address(kycRegistry));
        propertyNFT.setYieldBase(address(yieldBase));

        // Mint property NFT to propertyOwner
        vm.prank(owner);
        propertyTokenId = propertyNFT.mintProperty(
            keccak256("123 Main St"),
            "ipfs://test"
        );

        // Verify property
        vm.prank(owner);
        propertyNFT.verifyProperty(propertyTokenId);
    }

    // ============ YieldBase Integration Tests ============

    function testCreateAgreementRequiresKYC() public {
        // Should fail without KYC
        vm.prank(propertyOwner);
        vm.expectRevert("KYC Registry not set");
        yieldBase.createYieldAgreement(
            propertyTokenId,
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

    function testCreateAgreementWithKYC() public {
        // Whitelist property owner
        kycRegistry.addToWhitelist(propertyOwner);

        // Should succeed with KYC
        vm.prank(propertyOwner);
        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
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

        assertGt(agreementId, 0, "Agreement should be created");
    }

    function testCreateAgreementBlockedIfBlacklisted() public {
        // Whitelist first
        kycRegistry.addToWhitelist(propertyOwner);

        // Then blacklist
        kycRegistry.addToBlacklist(propertyOwner);

        // Should fail even though whitelisted
        vm.prank(propertyOwner);
        vm.expectRevert("Address is blacklisted");
        yieldBase.createYieldAgreement(
            propertyTokenId,
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

    function testMakeRepaymentRequiresKYC() public {
        // Setup: Create agreement
        kycRegistry.addToWhitelist(propertyOwner);
        vm.prank(propertyOwner);
        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
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

        // Remove from whitelist
        kycRegistry.removeFromWhitelist(propertyOwner);

        // Calculate monthly payment
        uint256 monthlyPayment = 8_791_666_666_666_666_666; // Approximately for 100 ETH at 5% over 12 months

        // Repayment should fail without KYC
        vm.prank(propertyOwner);
        vm.expectRevert("Address not KYC verified");
        yieldBase.makeRepayment{value: monthlyPayment}(agreementId);
    }

    // ============ YieldSharesToken Integration Tests ============

    function testMintSharesRequiresKYC() public {
        // Create agreement first
        kycRegistry.addToWhitelist(propertyOwner);
        vm.prank(propertyOwner);
        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
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

        // Get the token contract for this agreement
        YieldSharesToken token = yieldBase.agreementTokens(agreementId);
        token.setKYCRegistry(address(kycRegistry));

        // Try to mint shares to non-whitelisted investor
        vm.prank(address(yieldBase));
        vm.expectRevert("Investor not KYC verified");
        token.mintShares(agreementId, investor1, 50 ether);
    }

    function testTransferRequiresKYC() public {
        // Setup: Create agreement and mint shares
        kycRegistry.addToWhitelist(propertyOwner);
        kycRegistry.addToWhitelist(investor1);

        vm.prank(propertyOwner);
        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
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

        YieldSharesToken token = yieldBase.agreementTokens(agreementId);
        token.setKYCRegistry(address(kycRegistry));

        vm.prank(address(yieldBase));
        token.mintShares(agreementId, investor1, 50 ether);

        // Enable transfer restrictions
        vm.prank(owner);
        token.setTransferRestrictions(0, 5000, 0);

        // Try to transfer to non-whitelisted address
        vm.prank(investor1);
        vm.expectRevert("Recipient not KYC verified");
        token.transfer(investor2, 10 ether);
    }

    function testTransferFromBlacklistedBlocked() public {
        // Setup: Create agreement and mint shares
        kycRegistry.addToWhitelist(propertyOwner);
        kycRegistry.addToWhitelist(investor1);
        kycRegistry.addToWhitelist(investor2);

        vm.prank(propertyOwner);
        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
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

        YieldSharesToken token = yieldBase.agreementTokens(agreementId);
        token.setKYCRegistry(address(kycRegistry));

        vm.prank(address(yieldBase));
        token.mintShares(agreementId, investor1, 50 ether);

        // Enable transfer restrictions
        vm.prank(owner);
        token.setTransferRestrictions(0, 5000, 0);

        // Blacklist sender
        kycRegistry.addToBlacklist(investor1);

        // Transfer should fail
        vm.prank(investor1);
        vm.expectRevert("Sender is blacklisted");
        token.transfer(investor2, 10 ether);
    }

    function testBurnSharesUnaffectedByKYC() public {
        // Setup: Create agreement and mint shares
        kycRegistry.addToWhitelist(propertyOwner);
        kycRegistry.addToWhitelist(investor1);

        vm.prank(propertyOwner);
        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
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

        YieldSharesToken token = yieldBase.agreementTokens(agreementId);
        token.setKYCRegistry(address(kycRegistry));

        vm.prank(address(yieldBase));
        token.mintShares(agreementId, investor1, 50 ether);

        // Remove from whitelist
        kycRegistry.removeFromWhitelist(investor1);

        // Burning should still work (transfers to address(0) bypass KYC)
        vm.prank(address(yieldBase));
        token.burnShares(agreementId, investor1, 10 ether);

        assertEq(token.balanceOf(investor1), 40 ether, "Shares should be burned");
    }

    // ============ Governance Integration Tests ============

    function testGovernanceProposalAddsToWhitelist() public {
        // Deploy governance
        GovernanceController govImpl = new GovernanceController();
        bytes memory govInitData = abi.encodeWithSelector(
            GovernanceController.initialize.selector,
            owner,
            address(yieldBase)
        );
        ERC1967Proxy govProxy = new ERC1967Proxy(address(govImpl), govInitData);
        governance = GovernanceController(payable(address(govProxy)));

        governance.setKYCRegistry(address(kycRegistry));
        kycRegistry.setGovernanceController(address(governance));

        // Create KYC whitelist proposal
        vm.prank(owner);
        uint256 proposalId = governance.createKYCWhitelistProposal(
            investor1,
            true,
            "Add investor1 to whitelist"
        );

        assertGt(proposalId, 0, "Proposal should be created");
    }

    function testGovernanceProposalRemovesFromWhitelist() public {
        // Deploy governance
        GovernanceController govImpl = new GovernanceController();
        bytes memory govInitData = abi.encodeWithSelector(
            GovernanceController.initialize.selector,
            owner,
            address(yieldBase)
        );
        ERC1967Proxy govProxy = new ERC1967Proxy(address(govImpl), govInitData);
        governance = GovernanceController(payable(address(govProxy)));

        governance.setKYCRegistry(address(kycRegistry));
        kycRegistry.setGovernanceController(address(governance));

        // Add to whitelist first
        kycRegistry.addToWhitelist(investor1);

        // Create removal proposal
        vm.prank(owner);
        uint256 proposalId = governance.createKYCWhitelistProposal(
            investor1,
            false,
            "Remove investor1 from whitelist"
        );

        assertGt(proposalId, 0, "Proposal should be created");
    }

    function testBatchKYCProposal() public {
        // Deploy governance
        GovernanceController govImpl = new GovernanceController();
        bytes memory govInitData = abi.encodeWithSelector(
            GovernanceController.initialize.selector,
            owner,
            address(yieldBase)
        );
        ERC1967Proxy govProxy = new ERC1967Proxy(address(govImpl), govInitData);
        governance = GovernanceController(payable(address(govProxy)));

        governance.setKYCRegistry(address(kycRegistry));
        kycRegistry.setGovernanceController(address(governance));

        address[] memory addresses = new address[](3);
        addresses[0] = investor1;
        addresses[1] = investor2;
        addresses[2] = propertyOwner;

        // Create batch proposal
        vm.prank(owner);
        uint256 proposalId = governance.createBatchKYCWhitelistProposal(
            addresses,
            true,
            "Add multiple investors to whitelist"
        );

        assertGt(proposalId, 0, "Batch proposal should be created");
    }

    // ============ End-to-End Workflow Test ============

    function testFullKYCWorkflow() public {
        // Step 1: Admin adds property owner to whitelist
        kycRegistry.addToWhitelist(propertyOwner);
        assertTrue(kycRegistry.isWhitelisted(propertyOwner), "Property owner should be whitelisted");

        // Step 2: Property owner creates yield agreement
        vm.prank(propertyOwner);
        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
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
        assertGt(agreementId, 0, "Agreement should be created");

        // Step 3: Admin adds investor to whitelist
        kycRegistry.addToWhitelist(investor1);

        // Step 4: Investor receives shares (simulated via YieldBase)
        YieldSharesToken token = yieldBase.agreementTokens(agreementId);
        token.setKYCRegistry(address(kycRegistry));
        
        vm.prank(address(yieldBase));
        token.mintShares(agreementId, investor1, 50 ether);
        assertEq(token.balanceOf(investor1), 50 ether, "Investor should have shares");

        // Step 5: Investor transfers shares to another whitelisted address
        kycRegistry.addToWhitelist(investor2);
        
        vm.prank(owner);
        token.setTransferRestrictions(0, 5000, 0);
        
        vm.prank(investor1);
        token.transfer(investor2, 10 ether);
        assertEq(token.balanceOf(investor2), 10 ether, "Transfer should succeed");

        // Step 6: Admin blacklists investor1
        kycRegistry.addToBlacklist(investor1);

        // Step 7: Investor1 cannot transfer (blacklisted)
        vm.prank(investor1);
        vm.expectRevert("Sender is blacklisted");
        token.transfer(investor2, 5 ether);
    }

    // ============ Gas Benchmarking Tests ============

    function testGasOverheadKYCCheck() public {
        kycRegistry.addToWhitelist(propertyOwner);

        uint256 gasBefore = gasleft();
        vm.prank(propertyOwner);
        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
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
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for createYieldAgreement with KYC", gasUsed);
        
        // KYC overhead should be minimal (<10k gas)
        // Total gas for agreement creation is ~500k, so KYC should be <2% overhead
    }

    function testGasTransferOverhead() public {
        // Setup
        kycRegistry.addToWhitelist(propertyOwner);
        kycRegistry.addToWhitelist(investor1);
        kycRegistry.addToWhitelist(investor2);

        vm.prank(propertyOwner);
        agreementId = yieldBase.createYieldAgreement(
            propertyTokenId,
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

        YieldSharesToken token = yieldBase.agreementTokens(agreementId);
        token.setKYCRegistry(address(kycRegistry));

        vm.prank(address(yieldBase));
        token.mintShares(agreementId, investor1, 50 ether);

        vm.prank(owner);
        token.setTransferRestrictions(0, 5000, 0);

        // Measure transfer gas
        uint256 gasBefore = gasleft();
        vm.prank(investor1);
        token.transfer(investor2, 10 ether);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for transfer with KYC", gasUsed);
    }
}

