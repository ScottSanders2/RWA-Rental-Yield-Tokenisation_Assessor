// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/facets/YieldBaseFacet.sol";
import "../../src/facets/RepaymentFacet.sol";
import "../../src/facets/ViewsFacet.sol";
import "../../src/YieldSharesToken.sol";
import "../../src/PropertyNFT.sol";
import "../../src/KYCRegistry.sol";

/**
 * @title YieldInvariantHandler
 * @notice Handler contract for invariant testing that encapsulates valid state transitions
 * @dev Used by Foundry's invariant testing engine to drive randomized sequences
 */
contract YieldInvariantHandler is Test {
    YieldBaseFacet public yieldBaseFacet;
    RepaymentFacet public repaymentFacet;
    ViewsFacet public viewsFacet;
    PropertyNFT public propertyNFT;
    KYCRegistry public kycRegistry;

    address public owner;
    address public propertyOwner;
    address public investor1;
    address public investor2;

    // Track created agreements and properties for random selection
    uint256[] public agreementIds;
    uint256[] public propertyIds;
    
    // Ghost variables for tracking state
    mapping(uint256 => uint256) public ghost_totalSupply;
    mapping(uint256 => mapping(address => uint256)) public ghost_balances;
    mapping(uint256 => uint256) public ghost_repaymentsMade;
    mapping(uint256 => uint256) public ghost_missedPayments;
    
    // Constants for state transitions
    uint256 public constant MIN_UPFRONT_CAPITAL = 10_000 ether;
    uint256 public constant MAX_UPFRONT_CAPITAL = 1_000_000 ether;
    uint256 public constant MIN_ROI_BPS = 100; // 1%
    uint256 public constant MAX_ROI_BPS = 2000; // 20%
    uint256 public constant MIN_TERM_MONTHS = 6;
    uint256 public constant MAX_TERM_MONTHS = 36;

    constructor(
        YieldBaseFacet _yieldBaseFacet,
        RepaymentFacet _repaymentFacet,
        ViewsFacet _viewsFacet,
        PropertyNFT _propertyNFT,
        KYCRegistry _kycRegistry,
        address _owner,
        address _propertyOwner,
        address _investor1,
        address _investor2
    ) {
        yieldBaseFacet = _yieldBaseFacet;
        repaymentFacet = _repaymentFacet;
        viewsFacet = _viewsFacet;
        propertyNFT = _propertyNFT;
        kycRegistry = _kycRegistry;
        owner = _owner;
        propertyOwner = _propertyOwner;
        investor1 = _investor1;
        investor2 = _investor2;
    }

    /**
     * @notice Create a new property and agreement
     * @dev Valid state transition: empty -> property registered -> agreement created
     */
    function createAgreement(uint256 seed) public {
        // Bound parameters using seed
        uint256 upfrontCapital = bound(
            uint256(keccak256(abi.encodePacked(seed, "capital"))),
            MIN_UPFRONT_CAPITAL,
            MAX_UPFRONT_CAPITAL
        );
        uint16 roiBps = uint16(bound(
            uint256(keccak256(abi.encodePacked(seed, "roi"))),
            MIN_ROI_BPS,
            MAX_ROI_BPS
        ));
        uint16 termMonths = uint16(bound(
            uint256(keccak256(abi.encodePacked(seed, "term"))),
            MIN_TERM_MONTHS,
            MAX_TERM_MONTHS
        ));

        // Create property
        vm.startPrank(owner);
        uint256 propertyId = propertyNFT.mintProperty(
            keccak256(abi.encodePacked("Property", block.timestamp, seed)),
            "ipfs://test"
        );
        propertyNFT.verifyProperty(propertyId);
        propertyNFT.transferFrom(owner, propertyOwner, propertyId);
        vm.stopPrank();

        propertyIds.push(propertyId);

        // Create agreement
        vm.startPrank(propertyOwner);
        uint256 agreementId = yieldBaseFacet.createYieldAgreement(
            propertyId,
            upfrontCapital,
            upfrontCapital,
            termMonths,
            roiBps,
            address(0),
            30, // grace period
            200, // penalty rate
            3, // default threshold
            true, // allow partial
            true // allow early
        );
        vm.stopPrank();

        agreementIds.push(agreementId);
        
        // Initialize ghost variables
        address tokenAddress = viewsFacet.getAgreementToken(agreementId);
        YieldSharesToken yieldToken = YieldSharesToken(tokenAddress);
        ghost_totalSupply[agreementId] = yieldToken.totalSupply();
        ghost_balances[agreementId][propertyOwner] = yieldToken.balanceOf(propertyOwner);
    }

    /**
     * @notice Make a repayment on an existing agreement
     * @dev Valid state transition: agreement active -> repayment made
     */
    function makeRepayment(uint256 agreementIndex) public {
        if (agreementIds.length == 0) return;
        
        uint256 agreementId = agreementIds[agreementIndex % agreementIds.length];
        
        // Get agreement details
        (uint256 capital, , uint16 roiBps, , , ) = viewsFacet.getYieldAgreement(agreementId);
        
        // Calculate a reasonable repayment amount
        uint256 repaymentAmount = capital / 12; // Approximate monthly payment
        
        vm.deal(propertyOwner, repaymentAmount + 1 ether);
        
        vm.startPrank(propertyOwner);
        try repaymentFacet.makeRepayment{value: repaymentAmount}(agreementId) {
            ghost_repaymentsMade[agreementId]++;
        } catch {
            // Repayment might fail for valid reasons (already completed, etc.)
        }
        vm.stopPrank();
    }

    /**
     * @notice Make a partial repayment
     * @dev Valid state transition: agreement active -> partial repayment made
     */
    function makePartialRepayment(uint256 agreementIndex, uint256 amountSeed) public {
        if (agreementIds.length == 0) return;
        
        uint256 agreementId = agreementIds[agreementIndex % agreementIds.length];
        
        // Get agreement details
        (uint256 capital, , , , , ) = viewsFacet.getYieldAgreement(agreementId);
        
        // Bound partial amount to reasonable range
        uint256 partialAmount = bound(amountSeed, 1 ether, capital / 2);
        
        vm.deal(propertyOwner, partialAmount + 1 ether);
        
        vm.startPrank(propertyOwner);
        try repaymentFacet.makePartialRepayment{value: partialAmount}(agreementId) {
            ghost_repaymentsMade[agreementId]++;
        } catch {
            // Partial repayment might fail if not allowed
        }
        vm.stopPrank();
    }

    /**
     * @notice Transfer shares between investors
     * @dev Valid state transition: investor holds shares -> transfers to another whitelisted investor
     */
    function transferShares(uint256 agreementIndex, uint256 amountSeed, bool toInvestor2) public {
        if (agreementIds.length == 0) return;
        
        uint256 agreementId = agreementIds[agreementIndex % agreementIds.length];
        
        address tokenAddress = viewsFacet.getAgreementToken(agreementId);
        YieldSharesToken yieldToken = YieldSharesToken(tokenAddress);
        
        address from = toInvestor2 ? investor1 : investor2;
        address to = toInvestor2 ? investor2 : investor1;
        
        uint256 balance = yieldToken.balanceOf(from);
        if (balance == 0) return;
        
        uint256 transferAmount = bound(amountSeed, 1, balance);
        
        vm.prank(from);
        try yieldToken.transfer(to, transferAmount) {
            // Update ghost variables
            ghost_balances[agreementId][from] = yieldToken.balanceOf(from);
            ghost_balances[agreementId][to] = yieldToken.balanceOf(to);
        } catch {
            // Transfer might fail due to restrictions
        }
    }

    /**
     * @notice Advance time to simulate missed payments
     * @dev Valid state transition: time passes -> grace period -> default
     */
    function advanceTime(uint256 daysToAdvance) public {
        // Bound to reasonable range (0-60 days)
        daysToAdvance = bound(daysToAdvance, 1, 60);
        vm.warp(block.timestamp + (daysToAdvance * 1 days));
        
        // Track potential missed payments for all agreements
        for (uint256 i = 0; i < agreementIds.length; i++) {
            uint256 agreementId = agreementIds[i];
            // If no repayment was made and time advanced significantly, it's a potential missed payment
            if (daysToAdvance >= 30 && ghost_repaymentsMade[agreementId] < (block.timestamp / 30 days)) {
                ghost_missedPayments[agreementId]++;
            }
        }
    }

    /**
     * @notice Fund an agreement with an investor
     * @dev Valid state transition: agreement created -> investor funds
     */
    function fundAgreement(uint256 agreementIndex, uint256 amountSeed, bool useInvestor2) public {
        if (agreementIds.length == 0) return;
        
        uint256 agreementId = agreementIds[agreementIndex % agreementIds.length];
        
        // Get agreement details
        (uint256 capital, , , , , ) = viewsFacet.getYieldAgreement(agreementId);
        
        // Bound investment to reasonable range
        uint256 investmentAmount = bound(amountSeed, 1 ether, capital);
        
        address investor = useInvestor2 ? investor2 : investor1;
        address tokenAddress = viewsFacet.getAgreementToken(agreementId);
        YieldSharesToken yieldToken = YieldSharesToken(tokenAddress);
        
        // Simulate YieldBase calling mintShares (in real system, would be via investment flow)
        address diamondAddr = address(yieldBaseFacet);
        vm.prank(diamondAddr);
        try yieldToken.mintShares(agreementId, investor, investmentAmount) {
            // Update ghost variables
            ghost_totalSupply[agreementId] = yieldToken.totalSupply();
            ghost_balances[agreementId][investor] = yieldToken.balanceOf(investor);
        } catch {
            // Minting might fail for valid reasons
        }
    }

    /**
     * @notice Simulate a governance vote (placeholder for when governance is implemented)
     * @dev Valid state transition: proposal created -> vote cast
     */
    function castGovernanceVote(uint256 agreementIndex, bool voteFor) public {
        if (agreementIds.length == 0) return;
        
        // Placeholder for governance voting logic
        // When governance is fully implemented, this will cast votes on proposals
        // For now, this is a no-op that serves as a potential future state transition
    }

    /**
     * @notice Get the number of agreements created
     */
    function getAgreementCount() public view returns (uint256) {
        return agreementIds.length;
    }

    /**
     * @notice Get the number of properties created
     */
    function getPropertyCount() public view returns (uint256) {
        return propertyIds.length;
    }
}

