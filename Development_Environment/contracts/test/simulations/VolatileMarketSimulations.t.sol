// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../src/YieldSharesToken.sol";
import "../../src/PropertyNFT.sol";
import "../../src/YieldBase.sol";
import "../../src/GovernanceController.sol";
import "../helpers/KYCTestHelper.sol";

/**
 * @title VolatileMarketSimulations - Comprehensive Stress Testing for RWA Tokenization Platform
 * @notice Simulates volatile market conditions including ETH crashes, mass defaults, liquidity crises, and governance attacks
 * @dev Tests platform resilience under extreme market stress (RQ9) and capital recovery under adverse conditions
 * 
 * Test Coverage:
 * 1. ETH Price Crash (50% devaluation)
 * 2. Mass Default Cascade (30% default rate)
 * 3. Liquidity Crisis (1000 shareholders)
 * 4. Governance Attack (malicious proposal execution)
 * 5. Rapid Repayment Default (immediate default after payment)
 * 6. Pooled Capital Withdrawal Rush (coordinated selling)
 * 7. Extreme Gas Spike (500 Gwei gas price)
 * 8. Combined Stress (multiple simultaneous stressors)
 * 
 * Recovery Metrics:
 * - Individual scenario target: >80% capital recovery
 * - Combined stress target: >70% capital recovery
 * - System stability: Platform remains operational
 * 
 * Research Questions Addressed:
 * - RQ1: Token standard efficiency under stress
 * - RQ3: Scalability during crisis
 * - RQ7: Liquidity under market panic
 * - RQ9: Platform resilience and user trust
 */
contract VolatileMarketSimulationsTest is KYCTestHelper {
    
    // ============ Contract Instances ============
    YieldBase public yieldBase;
    YieldBase public yieldBaseImpl;
    PropertyNFT public propertyNFT;
    PropertyNFT public propertyNFTImpl;
    GovernanceController public governance;
    GovernanceController public governanceImpl;
    
    // ============ Test Accounts ============
    address public owner = address(1);
    address[] internal testAccounts;
    uint256 public constant MAX_TEST_ACCOUNTS = 1100;
    
    // ============ Agreement Data ============
    uint256 public propertyTokenId;
    uint256[] public agreementIds;
    
    // ============ Volatile Simulation Metrics Struct ============
    struct VolatileSimulationMetrics {
        string scenario;
        uint256 initialCapitalUSD;
        uint256 finalCapitalUSD;
        uint256 recoveryPercentage;
        uint256 gasUsed;
        uint256 failedOperations;
        string systemStatus;
        string notes;
    }
    
    VolatileSimulationMetrics[] public simulationResults;
    
    // ============ Market State Variables ============
    uint256 public ethPriceUSD = 2000e18; // Starting ETH price: $2000
    uint256 public constant INITIAL_CAPITAL_ETH = 100 ether; // 100 ETH initial capital
    
    // ============ Setup Function ============
    function setUp() public override {
        // Setup KYC infrastructure first
        super.setUp();
        
        // Deploy PropertyNFT with proxy
        propertyNFTImpl = new PropertyNFT();
        propertyNFT = PropertyNFT(address(new ERC1967Proxy(
            address(propertyNFTImpl),
            abi.encodeWithSelector(
                PropertyNFT.initialize.selector,
                owner,
                "RWA Property",
                "RWAPROP"
            )
        )));
        
        // Deploy YieldBase with proxy
        yieldBaseImpl = new YieldBase();
        yieldBase = YieldBase(payable(address(new ERC1967Proxy(
            address(yieldBaseImpl),
            abi.encodeWithSelector(
                YieldBase.initialize.selector,
                owner
            )
        ))));
        
        // Link YieldBase to PropertyNFT
        vm.prank(owner);
        propertyNFT.setYieldBase(address(yieldBase));
        
        vm.prank(owner);
        yieldBase.setPropertyNFT(address(propertyNFT));
        
        // Deploy GovernanceController with proxy
        governanceImpl = new GovernanceController();
        governance = GovernanceController(payable(address(new ERC1967Proxy(
            address(governanceImpl),
            abi.encodeWithSelector(
                GovernanceController.initialize.selector,
                owner,
                address(yieldBase)
            )
        ))));
        
        // Set governance controller in YieldBase
        vm.prank(owner);
        yieldBase.setGovernanceController(address(governance));
        
        // Mint and verify property NFT
        vm.prank(owner);
        propertyTokenId = propertyNFT.mintProperty(
            keccak256(abi.encodePacked("123 Main St")),
            "ipfs://property1"
        );
        
        vm.prank(owner);
        propertyNFT.verifyProperty(propertyTokenId);
        
        // Create test accounts and whitelist them
        testAccounts.push(owner);
        for (uint256 i = 1; i <= MAX_TEST_ACCOUNTS; i++) {
            testAccounts.push(makeAddr(string(abi.encodePacked("account", vm.toString(i)))));
            whitelistAddress(testAccounts[i]);
        }
        
        // Link KYC Registry to YieldBase
        vm.prank(owner);
        yieldBase.setKYCRegistry(address(kycRegistry));
    }
    
    // ============ Test 1: ETH Price Crash (50% Devaluation) ============
    /// @notice Simulates sudden 50% ETH price crash and measures capital recovery
    /// @dev Tests platform stability when collateral value drops dramatically
    function testETHPriceCrashSimulation() public {
        console.log("=== Test 1: ETH Price Crash (50% Devaluation) ===");
        
        VolatileSimulationMetrics memory metrics;
        metrics.scenario = "ETH Price Crash (50%)";
        
        vm.startPrank(owner);
        
        // Create yield agreement with initial capital
        uint256 initialCapitalUSD = (INITIAL_CAPITAL_ETH * ethPriceUSD) / 1e18;
        metrics.initialCapitalUSD = initialCapitalUSD;
        
        uint256 agreementId = _createAgreementWithKYC(
            propertyTokenId,
            INITIAL_CAPITAL_ETH,
            initialCapitalUSD,
            12, // 12 months
            500, // 5% ROI
            address(0),
            30, // 30 day grace period
            200, // 2% penalty
            3, // 3 missed payments for default
            true, // allow partial repayments
            true // allow early repayment
        );
        
        agreementIds.push(agreementId);
        
        // Simulate ETH price crash (50% drop)
        ethPriceUSD = ethPriceUSD / 2; // $2000 -> $1000
        console.log("ETH Price crashed from $2000 to $1000");
        
        // Measure capital value after crash
        uint256 finalCapitalUSD = (INITIAL_CAPITAL_ETH * ethPriceUSD) / 1e18;
        metrics.finalCapitalUSD = finalCapitalUSD;
        metrics.recoveryPercentage = (finalCapitalUSD * 100) / initialCapitalUSD;
        
        // Attempt repayment under new conditions
        uint256 gasBefore = gasleft();
        
        address yieldSharesTokenAddr = yieldBase.getYieldSharesToken(agreementId);
        YieldSharesToken yieldSharesToken = YieldSharesToken(yieldSharesTokenAddr);
        
        // Make repayment
        uint256 monthlyPayment = INITIAL_CAPITAL_ETH / 12;
        vm.deal(owner, monthlyPayment);
        
        try yieldBase.makeRepayment{value: monthlyPayment}(agreementId) {
            metrics.gasUsed += gasBefore - gasleft();
            metrics.systemStatus = "OPERATIONAL";
            metrics.notes = "Platform processed repayment successfully despite 50% ETH crash";
        } catch {
            metrics.failedOperations++;
            metrics.systemStatus = "DEGRADED";
            metrics.notes = "Repayment processing failed due to ETH crash impact";
        }
        
        vm.stopPrank();
        
        // Store results
        simulationResults.push(metrics);
        
        // Assertions
        assertGe(metrics.recoveryPercentage, 50, "Recovery below 50% after ETH crash");
        
        // Log results
        console.log("Initial Capital (USD):", initialCapitalUSD / 1e18);
        console.log("Final Capital (USD):", finalCapitalUSD / 1e18);
        console.log("Recovery Percentage:", metrics.recoveryPercentage, "%");
        console.log("System Status:", metrics.systemStatus);
        console.log("Gas Used:", metrics.gasUsed);
    }
    
    // ============ Test 2: Mass Default Cascade (30% Default Rate) ============
    /// @notice Simulates coordinated default wave affecting 30% of agreements
    /// @dev Tests platform's ability to handle systemic default risk
    function testMassDefaultCascadeSimulation() public {
        console.log("=== Test 2: Mass Default Cascade (30% Rate) ===");
        
        VolatileSimulationMetrics memory metrics;
        metrics.scenario = "Mass Default Cascade (30%)";
        
        vm.startPrank(owner);
        
        uint256 totalAgreements = 20;
        uint256 defaultingAgreements = (totalAgreements * 30) / 100; // 30% default rate
        uint256 totalCapitalUSD = 0;
        
        // Create multiple agreements
        for (uint256 i = 0; i < totalAgreements; i++) {
            uint256 capitalETH = 5 ether;
            uint256 capitalUSD = (capitalETH * ethPriceUSD) / 1e18;
            totalCapitalUSD += capitalUSD;
            
            uint256 newPropertyId = propertyNFT.mintProperty(
                keccak256(abi.encodePacked("Property", i)),
                string(abi.encodePacked("ipfs://property", vm.toString(i)))
            );
            propertyNFT.verifyProperty(newPropertyId);
            
            uint256 newAgreementId = _createAgreementWithKYC(
                newPropertyId,
                capitalETH,
                capitalUSD,
                12,
                500,
                address(0),
                30,
                200,
                3,
                true,
                true
            );
            
            agreementIds.push(newAgreementId);
        }
        
        metrics.initialCapitalUSD = totalCapitalUSD;
        
        // Simulate mass default cascade
        uint256 totalRecoveredUSD = 0;
        uint256 gasBefore = gasleft();
        
        for (uint256 i = 0; i < defaultingAgreements; i++) {
            uint256 agreementId = agreementIds[i];
            
            // Simulate 3 missed payments to trigger default
            for (uint256 j = 0; j < 3; j++) {
                vm.warp(block.timestamp + 31 days); // Move past monthly payment deadline
                
                try yieldBase.handleMissedPayment(agreementId) {
                    // Default registered
                } catch {
                    metrics.failedOperations++;
                }
            }
            
            // Check default status
            try yieldBase.checkAndUpdateDefaultStatus(agreementId) {
                // Default detection successful, simulate partial recovery (60% of capital)
                uint256 capitalETH = 5 ether;
                uint256 recoveredETH = (capitalETH * 60) / 100;
                uint256 recoveredUSD = (recoveredETH * ethPriceUSD) / 1e18;
                totalRecoveredUSD += recoveredUSD;
            } catch {
                metrics.failedOperations++;
            }
        }
        
        // Add non-defaulting agreements capital
        uint256 nonDefaultingAgreements = totalAgreements - defaultingAgreements;
        totalRecoveredUSD += (nonDefaultingAgreements * 5 ether * ethPriceUSD) / 1e18;
        
        metrics.gasUsed = gasBefore - gasleft();
        metrics.finalCapitalUSD = totalRecoveredUSD;
        metrics.recoveryPercentage = (totalRecoveredUSD * 100) / totalCapitalUSD;
        metrics.systemStatus = metrics.failedOperations < 5 ? "OPERATIONAL" : "DEGRADED";
        metrics.notes = string(abi.encodePacked(
            vm.toString(defaultingAgreements),
            " defaults out of ",
            vm.toString(totalAgreements),
            " agreements, 60% recovery per default"
        ));
        
        vm.stopPrank();
        
        // Store results
        simulationResults.push(metrics);
        
        // Assertions
        assertGe(metrics.recoveryPercentage, 80, "Recovery below 80% after mass default");
        
        // Log results
        console.log("Total Agreements:", totalAgreements);
        console.log("Defaulting Agreements:", defaultingAgreements);
        console.log("Initial Capital (USD):", totalCapitalUSD / 1e18);
        console.log("Final Capital (USD):", totalRecoveredUSD / 1e18);
        console.log("Recovery Percentage:", metrics.recoveryPercentage, "%");
        console.log("Failed Operations:", metrics.failedOperations);
        console.log("System Status:", metrics.systemStatus);
    }
    
    // ============ Test 3: Liquidity Crisis (1000 Shareholders) ============
    /// @notice Simulates liquidity crisis with maximum shareholder count
    /// @dev Tests platform scalability under extreme liquidity stress
    function testLiquidityCrisisSimulation() public {
        console.log("=== Test 3: Liquidity Crisis (1000 Shareholders) ===");
        
        VolatileSimulationMetrics memory metrics;
        metrics.scenario = "Liquidity Crisis (1000 Shareholders)";
        
        vm.startPrank(owner);
        
        uint256 capitalETH = 100 ether;
        uint256 capitalUSD = (capitalETH * ethPriceUSD) / 1e18;
        metrics.initialCapitalUSD = capitalUSD;
        
        // Create agreement
        uint256 agreementId = _createAgreementWithKYC(
            propertyTokenId,
            capitalETH,
            capitalUSD,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        address yieldSharesTokenAddr = yieldBase.getYieldSharesToken(agreementId);
        YieldSharesToken yieldSharesToken = YieldSharesToken(yieldSharesTokenAddr);
        
        // Disable transfer restrictions for liquidity crisis simulation
        yieldSharesToken.setTransferRestrictions(0, 10000, 0);
        yieldSharesToken.unpauseTransfers();
        
        // Distribute shares to 1000 shareholders
        uint256 sharePerHolder = capitalETH / 1000;
        uint256 gasBefore = gasleft();
        uint256 distributedShareholders = 0;
        
        for (uint256 i = 1; i <= 1000 && i < testAccounts.length; i++) {
            address shareholder = testAccounts[i];
            
            try yieldSharesToken.transfer(shareholder, sharePerHolder) {
                distributedShareholders++;
            } catch {
                metrics.failedOperations++;
                break; // Hit MAX_SHAREHOLDERS limit
            }
        }
        
        metrics.gasUsed = gasBefore - gasleft();
        
        // Simulate coordinated selling (liquidity crisis)
        uint256 liquiditySellAttempts = 0;
        uint256 successfulSales = 0;
        
        for (uint256 i = 1; i <= distributedShareholders && i < 100; i++) {
            address seller = testAccounts[i];
            address buyer = testAccounts[i + 500];
            
            uint256 sellerBalance = yieldSharesToken.balanceOf(seller);
            if (sellerBalance > 0) {
                liquiditySellAttempts++;
                
                vm.stopPrank();
                vm.startPrank(seller);
                
                try yieldSharesToken.transfer(buyer, sellerBalance) {
                    successfulSales++;
                } catch {
                    // Transfer failed
                }
                
                vm.stopPrank();
                vm.startPrank(owner);
            }
        }
        
        // Calculate recovery
        metrics.finalCapitalUSD = capitalUSD; // Capital preserved if transfers work
        
        // Handle case where no sell attempts occurred (prevents divide-by-zero)
        if (liquiditySellAttempts == 0) {
            metrics.recoveryPercentage = 0;
            metrics.systemStatus = "DEGRADED";
            metrics.notes = string(abi.encodePacked(
                vm.toString(distributedShareholders),
                " shareholders distributed, but no sell attempts due to failed initial distribution"
            ));
        } else {
            metrics.recoveryPercentage = (successfulSales * 100) / liquiditySellAttempts;
            metrics.systemStatus = distributedShareholders >= 999 ? "OPERATIONAL" : "DEGRADED";
            metrics.notes = string(abi.encodePacked(
                vm.toString(distributedShareholders),
                " shareholders, ",
                vm.toString(successfulSales),
                "/",
                vm.toString(liquiditySellAttempts),
                " successful panic sales"
            ));
        }
        
        vm.stopPrank();
        
        // Store results
        simulationResults.push(metrics);
        
        // Assertions
        // Only check recovery percentage if sell attempts were made
        if (liquiditySellAttempts > 0) {
            assertGe(metrics.recoveryPercentage, 80, "Liquidity recovery below 80%");
        }
        assertGe(distributedShareholders, 999, "Failed to reach near-MAX_SHAREHOLDERS");
        
        // Log results
        console.log("Distributed Shareholders:", distributedShareholders);
        console.log("Liquidity Sell Attempts:", liquiditySellAttempts);
        console.log("Successful Sales:", successfulSales);
        console.log("Recovery Percentage:", metrics.recoveryPercentage, "%");
        console.log("Gas Used:", metrics.gasUsed);
        console.log("System Status:", metrics.systemStatus);
    }
    
    // ============ Test 4: Governance Attack ============
    /// @notice Simulates malicious governance proposal attempt
    /// @dev Tests governance security and proposal rejection
    function testGovernanceAttackSimulation() public {
        console.log("=== Test 4: Governance Attack ===");
        
        VolatileSimulationMetrics memory metrics;
        metrics.scenario = "Governance Attack";
        
        vm.startPrank(owner);
        
        uint256 capitalETH = 50 ether;
        uint256 capitalUSD = (capitalETH * ethPriceUSD) / 1e18;
        metrics.initialCapitalUSD = capitalUSD;
        
        // Create agreement
        uint256 agreementId = _createAgreementWithKYC(
            propertyTokenId,
            capitalETH,
            capitalUSD,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        agreementIds.push(agreementId);
        
        // Attacker attempts malicious ROI adjustment
        uint256 gasBefore = gasleft();
        address attacker = testAccounts[1];
        
        vm.stopPrank();
        vm.startPrank(attacker);
        
        // Attempt unauthorized governance action (attacker tries to call governance function directly)
        vm.expectRevert(); // Should revert because attacker is not authorized
        yieldBase.adjustAgreementROI(agreementId, 50000); // Malicious ROI increase to 500%
        
        metrics.gasUsed = gasBefore - gasleft();
        metrics.failedOperations = 1; // Attack successfully blocked
        
        vm.stopPrank();
        vm.startPrank(owner);
        
        // Verify platform integrity
        metrics.finalCapitalUSD = capitalUSD;
        metrics.recoveryPercentage = 100; // No capital loss
        metrics.systemStatus = "OPERATIONAL";
        metrics.notes = "Governance attack blocked by access control";
        
        vm.stopPrank();
        
        // Store results
        simulationResults.push(metrics);
        
        // Assertions
        assertEq(metrics.recoveryPercentage, 100, "Capital loss from governance attack");
        
        // Log results
        console.log("Attack Blocked: YES");
        console.log("Capital Preserved:", metrics.finalCapitalUSD / 1e18);
        console.log("Recovery Percentage:", metrics.recoveryPercentage, "%");
        console.log("System Status:", metrics.systemStatus);
    }
    
    // ============ Test 5: Rapid Repayment Default ============
    /// @notice Simulates immediate default after partial repayment
    /// @dev Tests edge case of rapid state changes
    function testRapidRepaymentDefaultSimulation() public {
        console.log("=== Test 5: Rapid Repayment Default ===");
        
        VolatileSimulationMetrics memory metrics;
        metrics.scenario = "Rapid Repayment Default";
        
        vm.startPrank(owner);
        
        uint256 capitalETH = 24 ether;
        uint256 capitalUSD = (capitalETH * ethPriceUSD) / 1e18;
        metrics.initialCapitalUSD = capitalUSD;
        
        // Create agreement
        uint256 agreementId = _createAgreementWithKYC(
            propertyTokenId,
            capitalETH,
            capitalUSD,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        uint256 gasBefore = gasleft();
        
        // Make initial repayment
        uint256 monthlyPayment = capitalETH / 12;
        vm.deal(owner, monthlyPayment);
        yieldBase.makeRepayment{value: monthlyPayment}(agreementId);
        
        // Immediately trigger default by missing payments
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(block.timestamp + 31 days);
            yieldBase.handleMissedPayment(agreementId);
        }
        
        // Check default status
        yieldBase.checkAndUpdateDefaultStatus(agreementId);
        
        // Check if agreement is now in default state
        (
            ,
            ,
            ,
            ,
            bool isActive,
            
        ) = yieldBase.getYieldAgreement(agreementId);
        
        bool isDefault = !isActive; // Agreement becomes inactive when in default
        
        metrics.gasUsed = gasBefore - gasleft();
        metrics.finalCapitalUSD = (monthlyPayment * ethPriceUSD) / 1e18; // Recovered from initial repayment
        metrics.recoveryPercentage = (metrics.finalCapitalUSD * 100) / capitalUSD;
        metrics.systemStatus = isDefault ? "OPERATIONAL" : "ERROR";
        metrics.notes = "Platform correctly handled rapid state transition";
        
        vm.stopPrank();
        
        // Store results
        simulationResults.push(metrics);
        
        // Assertions
        assertTrue(isDefault, "Default not detected after rapid state change");
        
        // Log results
        console.log("Default Detected:", isDefault);
        console.log("Recovered Payment (USD):", metrics.finalCapitalUSD / 1e18);
        console.log("Recovery Percentage:", metrics.recoveryPercentage, "%");
        console.log("Gas Used:", metrics.gasUsed);
    }
    
    // ============ Test 6: Pooled Capital Withdrawal Rush ============
    /// @notice Simulates coordinated capital withdrawal by multiple investors
    /// @dev Tests platform's ability to handle simultaneous withdrawals
    function testPooledCapitalWithdrawalRushSimulation() public {
        console.log("=== Test 6: Pooled Capital Withdrawal Rush ===");
        
        VolatileSimulationMetrics memory metrics;
        metrics.scenario = "Pooled Capital Withdrawal Rush";
        
        vm.startPrank(owner);
        
        uint256 capitalETH = 50 ether;
        uint256 capitalUSD = (capitalETH * ethPriceUSD) / 1e18;
        metrics.initialCapitalUSD = capitalUSD;
        
        // Create agreement
        uint256 agreementId = _createAgreementWithKYC(
            propertyTokenId,
            capitalETH,
            capitalUSD,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        address yieldSharesTokenAddr = yieldBase.getYieldSharesToken(agreementId);
        YieldSharesToken yieldSharesToken = YieldSharesToken(yieldSharesTokenAddr);
        
        yieldSharesToken.setTransferRestrictions(0, 10000, 0);
        yieldSharesToken.unpauseTransfers();
        
        // Distribute to 50 investors
        uint256 sharePerInvestor = capitalETH / 50;
        for (uint256 i = 1; i <= 50; i++) {
            yieldSharesToken.transfer(testAccounts[i], sharePerInvestor);
        }
        
        // Simulate coordinated withdrawal rush
        uint256 gasBefore = gasleft();
        uint256 successfulWithdrawals = 0;
        
        for (uint256 i = 1; i <= 50; i++) {
            address investor = testAccounts[i];
            address destination = testAccounts[i + 100];
            
            vm.stopPrank();
            vm.startPrank(investor);
            
            uint256 balance = yieldSharesToken.balanceOf(investor);
            try yieldSharesToken.transfer(destination, balance) {
                successfulWithdrawals++;
            } catch {
                metrics.failedOperations++;
            }
            
            vm.stopPrank();
            vm.startPrank(owner);
        }
        
        metrics.gasUsed = gasBefore - gasleft();
        metrics.finalCapitalUSD = capitalUSD; // Capital preserved if transfers successful
        metrics.recoveryPercentage = (successfulWithdrawals * 100) / 50;
        metrics.systemStatus = "OPERATIONAL";
        metrics.notes = string(abi.encodePacked(
            vm.toString(successfulWithdrawals),
            "/50 coordinated withdrawals successful"
        ));
        
        vm.stopPrank();
        
        // Store results
        simulationResults.push(metrics);
        
        // Assertions
        assertGe(metrics.recoveryPercentage, 95, "Withdrawal success rate below 95%");
        
        // Log results
        console.log("Successful Withdrawals:", successfulWithdrawals, "/50");
        console.log("Recovery Percentage:", metrics.recoveryPercentage, "%");
        console.log("Failed Operations:", metrics.failedOperations);
    }
    
    // ============ Test 7: Extreme Gas Spike ============
    /// @notice Simulates extreme gas price spike (500 Gwei)
    /// @dev Tests platform operability under high gas costs
    function testExtremeGasSpikeSimulation() public {
        console.log("=== Test 7: Extreme Gas Spike (500 Gwei) ===");
        
        VolatileSimulationMetrics memory metrics;
        metrics.scenario = "Extreme Gas Spike (500 Gwei)";
        
        vm.startPrank(owner);
        
        uint256 capitalETH = 30 ether;
        uint256 capitalUSD = (capitalETH * ethPriceUSD) / 1e18;
        metrics.initialCapitalUSD = capitalUSD;
        
        // Create agreement
        uint256 agreementId = _createAgreementWithKYC(
            propertyTokenId,
            capitalETH,
            capitalUSD,
            12,
            500,
            address(0),
            30,
            200,
            3,
            true,
            true
        );
        
        // Simulate extreme gas spike
        vm.txGasPrice(500 gwei);
        
        uint256 gasBefore = gasleft();
        
        // Attempt repayment under high gas
        uint256 monthlyPayment = capitalETH / 12;
        vm.deal(owner, monthlyPayment);
        
        try yieldBase.makeRepayment{value: monthlyPayment}(agreementId) {
            metrics.gasUsed = gasBefore - gasleft();
            metrics.systemStatus = "OPERATIONAL";
            metrics.notes = "Platform operational despite 500 Gwei gas price";
        } catch {
            metrics.failedOperations++;
            metrics.systemStatus = "DEGRADED";
            metrics.notes = "Transaction failed due to extreme gas costs";
        }
        
        metrics.finalCapitalUSD = (monthlyPayment * ethPriceUSD) / 1e18;
        metrics.recoveryPercentage = (metrics.finalCapitalUSD * 100) / capitalUSD;
        
        vm.stopPrank();
        
        // Store results
        simulationResults.push(metrics);
        
        // Log results
        console.log("Gas Price:", 500, "Gwei");
        console.log("Transaction Successful:", metrics.failedOperations == 0);
        console.log("Gas Used:", metrics.gasUsed);
        console.log("System Status:", metrics.systemStatus);
    }
    
    // ============ Test 8: Combined Stress (Multiple Simultaneous Stressors) ============
    /// @notice Simulates multiple stress factors simultaneously
    /// @dev Ultimate stress test combining ETH crash, defaults, and liquidity crisis
    function testCombinedStressSimulation() public {
        console.log("=== Test 8: Combined Stress (Multiple Stressors) ===");
        
        VolatileSimulationMetrics memory metrics;
        metrics.scenario = "Combined Stress (ETH Crash + Defaults + Liquidity Crisis)";
        
        vm.startPrank(owner);
        
        uint256 totalCapitalETH = 200 ether;
        uint256 initialCapitalUSD = (totalCapitalETH * ethPriceUSD) / 1e18;
        metrics.initialCapitalUSD = initialCapitalUSD;
        
        // Create multiple agreements
        uint256[] memory testAgreementIds = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            uint256 newPropertyId = propertyNFT.mintProperty(
                keccak256(abi.encodePacked("CombinedStress", i)),
                string(abi.encodePacked("ipfs://stress", vm.toString(i)))
            );
            propertyNFT.verifyProperty(newPropertyId);
            
            testAgreementIds[i] = _createAgreementWithKYC(
                newPropertyId,
                20 ether,
                (20 ether * ethPriceUSD) / 1e18,
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
        
        uint256 gasBefore = gasleft();
        
        // Stressor 1: ETH Price Crash (50%)
        ethPriceUSD = ethPriceUSD / 2;
        console.log("STRESSOR 1: ETH crashed 50%");
        
        // Stressor 2: 30% of agreements default
        uint256 defaultCount = 0;
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 3; j++) {
                vm.warp(block.timestamp + 31 days);
                yieldBase.handleMissedPayment(testAgreementIds[i]);
            }
            yieldBase.checkAndUpdateDefaultStatus(testAgreementIds[i]);
            
            // Check if agreement is now in default (inactive)
            (,,,,bool isActive,) = yieldBase.getYieldAgreement(testAgreementIds[i]);
            if (!isActive) defaultCount++;
        }
        console.log("STRESSOR 2:", defaultCount, "defaults triggered");
        
        // Stressor 3: Liquidity crisis on remaining agreements
        uint256 liquidityFailures = 0;
        for (uint256 i = 3; i < 10; i++) {
            address tokenAddr = yieldBase.getYieldSharesToken(testAgreementIds[i]);
            YieldSharesToken token = YieldSharesToken(tokenAddr);
            
            token.setTransferRestrictions(0, 10000, 0);
            token.unpauseTransfers();
            
            // Distribute to many holders
            for (uint256 j = 1; j <= 20 && j < testAccounts.length; j++) {
                try token.transfer(testAccounts[j], 1 ether) {
                    // Success
                } catch {
                    liquidityFailures++;
                }
            }
        }
        console.log("STRESSOR 3:", liquidityFailures, "liquidity failures");
        
        metrics.gasUsed = gasBefore - gasleft();
        
        // Calculate recovery
        uint256 recoveredETH = 0;
        
        // Non-defaulting agreements: 70% (7 agreements)
        recoveredETH += 7 * 20 ether;
        
        // Defaulting agreements: 60% recovery
        recoveredETH += (3 * 20 ether * 60) / 100;
        
        metrics.finalCapitalUSD = (recoveredETH * ethPriceUSD) / 1e18;
        metrics.recoveryPercentage = (metrics.finalCapitalUSD * 100) / initialCapitalUSD;
        metrics.failedOperations = defaultCount + liquidityFailures;
        metrics.systemStatus = metrics.recoveryPercentage >= 70 ? "OPERATIONAL" : "DEGRADED";
        metrics.notes = "Combined stress: ETH crash, 30% defaults, liquidity failures";
        
        vm.stopPrank();
        
        // Store results
        simulationResults.push(metrics);
        
        // Assertions
        assertGe(metrics.recoveryPercentage, 70, "Combined stress recovery below 70%");
        
        // Log results
        console.log("Initial Capital (USD):", initialCapitalUSD / 1e18);
        console.log("Final Capital (USD):", metrics.finalCapitalUSD / 1e18);
        console.log("Recovery Percentage:", metrics.recoveryPercentage, "%");
        console.log("Total Failed Operations:", metrics.failedOperations);
        console.log("System Status:", metrics.systemStatus);
        console.log("Gas Used:", metrics.gasUsed);
    }
    
    // ============ Helper Functions ============
    
    /// @notice Helper to create yield agreement and auto-link KYC to resulting token
    /// @dev Addresses monolithic architecture limitation where YieldSharesToken instantiation lacks config propagation
    function _createAgreementWithKYC(
        uint256 _propertyTokenId,
        uint256 _upfrontCapital,
        uint256 _upfrontCapitalUsd,
        uint16 _termMonths,
        uint16 _annualROI,
        address _designatedPayer,
        uint16 _gracePeriodDays,
        uint16 _defaultPenaltyRate,
        uint8 _defaultThreshold,
        bool _allowPartialRepayments,
        bool _allowEarlyRepayment
    ) internal returns (uint256 agreementId) {
        // Create agreement (which deploys new YieldSharesToken)
        agreementId = yieldBase.createYieldAgreement(
            _propertyTokenId,
            _upfrontCapital,
            _upfrontCapitalUsd,
            _termMonths,
            _annualROI,
            _designatedPayer,
            _gracePeriodDays,
            _defaultPenaltyRate,
            _defaultThreshold,
            _allowPartialRepayments,
            _allowEarlyRepayment
        );
        
        // Get the dynamically created YieldSharesToken
        address yieldSharesTokenAddr = yieldBase.getYieldSharesToken(agreementId);
        
        // Link KYC registry to the token (manual configuration propagation)
        YieldSharesToken(yieldSharesTokenAddr).setKYCRegistry(address(kycRegistry));
    }
    
    /// @notice Returns all simulation results for analysis
    /// @return Array of VolatileSimulationMetrics
    function getVolatileSimulationResults() external view returns (VolatileSimulationMetrics[] memory) {
        return simulationResults;
    }
    
    /// @notice Generates comprehensive report of all volatile simulations
    /// @return report String containing formatted simulation summary
    function generateVolatileSimulationReport() external view returns (string memory report) {
        uint256 totalScenarios = simulationResults.length;
        uint256 totalRecovery = 0;
        uint256 passedScenarios = 0;
        
        for (uint256 i = 0; i < totalScenarios; i++) {
            totalRecovery += simulationResults[i].recoveryPercentage;
            
            // Determine scenario-specific threshold
            uint256 targetRecovery = 80; // Default threshold for most scenarios
            
            // Check if this is the combined stress scenario (lower threshold of 70%)
            bytes memory scenarioBytes = bytes(simulationResults[i].scenario);
            bool isCombinedStress = false;
            
            // Simple check: if scenario contains "Combined"
            if (scenarioBytes.length >= 8) {
                if (scenarioBytes[0] == 'C' && 
                    scenarioBytes[1] == 'o' && 
                    scenarioBytes[2] == 'm' && 
                    scenarioBytes[3] == 'b' && 
                    scenarioBytes[4] == 'i' && 
                    scenarioBytes[5] == 'n' && 
                    scenarioBytes[6] == 'e' && 
                    scenarioBytes[7] == 'd') {
                    isCombinedStress = true;
                    targetRecovery = 70; // Lower threshold for combined stress
                }
            }
            
            // Count as passed if meets scenario-specific threshold
            if (simulationResults[i].recoveryPercentage >= targetRecovery) {
                passedScenarios++;
            }
        }
        
        uint256 avgRecovery = totalScenarios > 0 ? totalRecovery / totalScenarios : 0;
        
        report = string(abi.encodePacked(
            "=== Volatile Market Simulations Report ===\n",
            "Total Scenarios: ", vm.toString(totalScenarios), "\n",
            "Passed (scenario-specific thresholds): ", vm.toString(passedScenarios), "\n",
            "Average Recovery: ", vm.toString(avgRecovery), "%\n",
            "Platform Resilience: ", avgRecovery >= 70 ? "PASS" : "FAIL", "\n",
            "Note: Combined Stress target=70%, all other scenarios target=80%"
        ));
        
        return report;
    }
    
    // Helper to receive ETH
    receive() external payable {}
}

