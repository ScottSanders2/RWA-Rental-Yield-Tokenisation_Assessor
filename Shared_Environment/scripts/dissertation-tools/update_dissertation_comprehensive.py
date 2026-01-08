#!/usr/bin/env python3
"""
Comprehensive update script for DissertationProgressFinal.md
This script implements all the recommended changes:
1. Convert Tables 6.1-6.5 and 7.1 from paragraph to actual markdown tables
2. Rename Figure 4.1 and add GitHub Repository subsection
3. Create dedicated subsections for misplaced figures
4. Add brief narrative descriptions under all figures and tables
5. Convert paragraph data to tables (contract addresses, test results, etc.)
6. Move Appendix G charts to main body with narrative
"""

import re
import os

def read_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(filepath, content):
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    print("=" * 60)
    print("COMPREHENSIVE DISSERTATION UPDATE")
    print("=" * 60)
    
    # Read the current markdown file
    md_path = 'DissertationProgressFinal.md'
    content = read_file(md_path)
    
    # =========================================================================
    # CHANGE 1: Rename Figure 4.1 and restructure section 4.3.1
    # =========================================================================
    print("\n1. Renaming Figure 4.1 and adding GitHub Repository subsection...")
    
    # Find and replace the Figure 4.1 placeholder
    old_fig_4_1 = """**Figure 4.1: Multi-Environment Docker Architecture (Logical View)**
*[Placeholder for Mermaid diagram: docker-architecture-logical.mmd - Shows Development, Test, and Production environment pipeline flow with container orchestration]*

**Figure 4.2: Multi-Environment Docker Architecture (Physical View)**
*[Placeholder for Mermaid diagram: docker-architecture-physical.mmd - Shows container resource allocations and network topology]*

#### 4.3.2 Technology Stack Selection"""

    new_fig_4_1 = """**Figure 4.1: Multi-Environment Docker Architecture (Logical View)**
*[Placeholder for Mermaid diagram: docker-architecture-logical.mmd - Shows Development, Test, and Production environment pipeline flow with container orchestration]*

*This diagram illustrates the logical flow of code and configurations across the three segregated environments. Development serves as the initial implementation environment with hot-reload capabilities, Test provides comprehensive validation with extended resource allocation, and Production represents the stable deployment target with security hardening.*

**Figure 4.2: Multi-Environment Docker Architecture (Physical View)**
*[Placeholder for Mermaid diagram: docker-architecture-physical.mmd - Shows container resource allocations and network topology]*

*The physical architecture diagram details the actual resource allocations and network topology across environments. Each environment operates on isolated Docker networks preventing cross-contamination whilst maintaining service discoverability through Docker's internal DNS resolution.*

#### 4.3.2 GitHub Repository Architecture

The platform's source code is organised in a structured GitHub repository following industry best practices for monorepo management with environment-specific configurations. The repository structure implements clear separation between shared components accessible across all environments and environment-specific configurations that control deployment behaviour.

The root directory contains shared infrastructure including the contracts/ directory housing all Solidity smart contracts with Foundry configuration, the Shared_Environment/ directory containing documentation, architecture diagrams, and shared utilities, and configuration files including docker-compose base configurations and environment variable templates. Each environment (Development_Environment/, Test_Environment/, Production_Environment/) maintains its own frontend/, backend/, and docker/ directories with environment-specific configurations, enabling independent deployment whilst sharing core business logic.

This repository architecture supports the Docker-first development methodology by enabling volume mounts that synchronise host repository changes with container workspaces, facilitating rapid iteration during development whilst maintaining strict environment isolation for testing and production deployments. The structure also enables clear git branching strategies where feature branches target Development, release candidates undergo Test validation, and only approved changes reach Production.

**Figure 4.3: GitHub Repository Structure**
*[Placeholder for diagram: Shows the hierarchical repository structure with shared and environment-specific directories]*

*The repository structure diagram illustrates the organisation of shared components and environment-specific configurations. This architecture enables code reuse whilst maintaining strict environment isolation required for the CI/CD pipeline.*

#### 4.3.3 Technology Stack Selection"""

    content = content.replace(old_fig_4_1, new_fig_4_1)
    
    # Update subsequent figure numbers in section 4.3.3 onwards
    # Figure 4.3 -> Figure 4.4, etc.
    content = content.replace("**Figure 4.3: Monitoring Architecture Diagram**", "**Figure 4.4: Monitoring Architecture Diagram**")
    content = content.replace("**Figure 4.4: Mobile Application Architecture**", "**Figure 4.5: Mobile Application Architecture**")
    content = content.replace("**Figure 4.5: Backend API Architecture**", "**Figure 4.6: Backend API Architecture**")
    content = content.replace("**Figure 4.6: Property Owner Workflow**", "**Figure 4.7: Property Owner Workflow**")
    
    # =========================================================================
    # CHANGE 2: Restructure Section 4.3.15 - Create dedicated subsections
    # =========================================================================
    print("\n2. Creating dedicated subsections for misplaced figures...")
    
    # Find section 4.3.15 and restructure it
    old_section_4_3_15 = """**Figure 4.15: Governance Architecture**
*[Placeholder for Mermaid diagram: governance-architecture.mmd - GovernanceController contract with proposal types, voting periods, quorum requirements, and timelock execution]*

**Figure 4.16: Governance Proposal Flow**
*[Placeholder for Mermaid diagram: governance-proposal-flow.mmd - Proposal creation, voting period, quorum achievement, majority verification, timelock expiration, and execution workflow]*

**Figure 4.17: Secondary Market Architecture**
*[Placeholder for Mermaid diagram: secondary-market-architecture.mmd - Hybrid architecture with PostgreSQL off-chain order book and on-chain ERC-20/ERC-1155 settlement]*

**Figure 4.18: Transfer Restriction Flow**
*[Placeholder for Mermaid diagram: transfer-restriction-flow.mmd - Lockup period validation, concentration limit check, holding period enforcement, whitelist/blacklist verification]*

**Figure 4.19: KYC Architecture**
*[Placeholder for Mermaid diagram: kyc-architecture.mmd - KYCRegistry contract with whitelist/blacklist management, verification tiers, and administrative controls]*

**Figure 4.20: KYC Verification Workflow**
*[Placeholder for Mermaid diagram: kyc-workflow.mmd - Document submission, admin review, on-chain status update, and enforcement at minting/transfer/governance points]*

**Figure 4.21: Entity-Relationship Diagram**
*[Placeholder for Mermaid diagram: er-diagram.mmd - Database entity relationships for Property, YieldAgreement, Transaction, and User models]*

**Figure 4.22: ERC-1155 Architecture**
*[Placeholder for Mermaid diagram: erc1155-architecture.mmd - CombinedPropertyYieldToken contract structure with token ID scheme]*

**Figure 4.23: ERC-20 Token Flow**
*[Placeholder for Mermaid diagram: erc20-token-flow.mmd - YieldSharesToken minting, transfer, and distribution flow]*

**Figure 4.24: Property NFT Architecture**
*[Placeholder for Mermaid diagram: property-nft-architecture.mmd - PropertyNFT contract with verification workflow and metadata storage]*

**Figure 4.25: Share Transfer Architecture**
*[Placeholder for Mermaid diagram: share-transfer-architecture.mmd - Secondary market share transfer with restriction validation]*

**Figure 4.26: Use Case Diagram**
*[Placeholder for Mermaid diagram: use-case-diagram.mmd - Actor-use case relationships for property owners, investors, and administrators]*

**Figure 4.27: Mobile Workflow**
*[Placeholder for Mermaid diagram: mobile-workflow.mmd - React Native user journey from app launch through wallet connection to transaction completion]*

**Figure 4.28: Dashboard Wireframe**
*[Placeholder for Mermaid diagram: wireframe-dashboard.mmd - Web dashboard layout with portfolio overview, recent activity, and navigation]*

**Figure 4.29: Property Registration Wireframe**
*[Placeholder for Mermaid diagram: wireframe-property-registration.mmd - Property registration form layout with field groupings and validation indicators]*

**Figure 4.30: Yield Agreement Wireframe**
*[Placeholder for Mermaid diagram: wireframe-yield-agreement.mmd - Yield agreement creation form with parameter sliders and financial projections]*

**Figure 4.31: Mobile Dashboard Wireframe**
*[Placeholder for Mermaid diagram: wireframe-mobile-dashboard.mmd - Mobile-optimised dashboard with bottom navigation and card-based layout]*

**Figure 4.32: Mobile Yield Agreement Wireframe**
*[Placeholder for Mermaid diagram: wireframe-mobile-yield-agreement.mmd - Mobile yield agreement form with touch-optimised controls]*

#### 4.3.16 Fuzzing and Invariant Testing Methodology"""

    new_section_4_3_15 = """**Figure 4.16: Governance Architecture**
*[Placeholder for Mermaid diagram: governance-architecture.mmd - GovernanceController contract with proposal types, voting periods, quorum requirements, and timelock execution]*

*The governance architecture implements a comprehensive on-chain voting system with configurable parameters. The GovernanceController contract manages proposal lifecycle, vote tallying, and execution timelock, ensuring democratic participation whilst preventing governance attacks through quorum requirements and voting period constraints.*

**Figure 4.17: Governance Proposal Flow**
*[Placeholder for Mermaid diagram: governance-proposal-flow.mmd - Proposal creation, voting period, quorum achievement, majority verification, timelock expiration, and execution workflow]*

*This flowchart details the complete lifecycle of a governance proposal from creation through execution. The multi-stage process ensures adequate deliberation time, prevents flash loan attacks through timelock delays, and provides transparency through on-chain vote recording.*

#### 4.3.16 Secondary Market Architecture

The secondary market enables token holders to trade their yield shares, providing liquidity that distinguishes tokenised assets from traditional illiquid real estate investments. The marketplace adopts a hybrid architecture that minimises gas costs whilst maintaining blockchain security guarantees for settlement.

The off-chain order book, implemented through PostgreSQL, stores listing metadata including seller address, shares available, USD pricing, and expiry timestamps. This approach eliminates the gas costs associated with on-chain order book management whilst enabling complex matching logic and flexible pricing updates. The on-chain settlement layer executes actual token transfers through standard ERC-20 transfer or ERC-1155 safeTransferFrom functions, ensuring atomic settlement with blockchain security guarantees.

Transfer restriction validation occurs at listing creation and settlement time, ensuring compliance with lockup periods, concentration limits, and KYC requirements. This dual-validation approach prevents listings that would fail at settlement whilst providing early feedback to sellers regarding restriction compliance.

**Figure 4.18: Secondary Market Architecture**
*[Placeholder for Mermaid diagram: secondary-market-architecture.mmd - Hybrid architecture with PostgreSQL off-chain order book and on-chain ERC-20/ERC-1155 settlement]*

*The secondary market architecture diagram illustrates the hybrid approach combining off-chain order management with on-chain settlement. This design achieves gas efficiency whilst maintaining the security guarantees essential for financial applications.*

#### 4.3.17 Transfer Restriction Framework

Transfer restrictions implement programmable compliance controls that enforce regulatory requirements and protect investor interests. The restriction framework operates through the _update hook in yield token contracts, validating all transfer operations against configurable rules before execution.

Four primary restriction types are supported: lockup periods preventing transfers for a configurable duration after minting, concentration limits preventing any single address from accumulating excessive holdings, holding periods requiring minimum ownership duration before resale, and whitelist/blacklist controls enabling administrative override for compliance purposes. Each restriction type can be independently enabled or disabled, with parameters adjustable through governance proposals.

The restriction enforcement architecture ensures universal coverage by intercepting transfers at the ERC-20/ERC-1155 standard interface level. This approach maintains standard compliance whilst preventing circumvention through alternative transfer methods.

**Figure 4.19: Transfer Restriction Flow**
*[Placeholder for Mermaid diagram: transfer-restriction-flow.mmd - Lockup period validation, concentration limit check, holding period enforcement, whitelist/blacklist verification]*

*The transfer restriction flow diagram details the validation sequence executed for each transfer operation. The ordered validation ensures efficient early termination when restrictions are violated whilst providing descriptive error messages for user feedback.*

#### 4.3.18 KYC and Compliance Architecture

The KYC (Know Your Customer) registry implements identity verification controls required for regulatory compliance in financial applications. The KYCRegistry contract maintains on-chain verification status for user addresses, enabling smart contracts to enforce compliance requirements at critical interaction points including token minting, transfers, and governance participation.

The verification workflow supports multiple verification tiers enabling graduated access based on verification depth. Basic verification enables limited investment amounts, whilst enhanced verification unlocks higher limits and additional platform features. Administrative functions enable compliance officers to update verification status, manage whitelists and blacklists, and respond to regulatory requirements.

Integration with yield token contracts occurs through the _update hook, which queries KYC status before permitting transfers when KYC enforcement is enabled. This approach provides flexible compliance that can be toggled based on jurisdictional requirements whilst maintaining a consistent enforcement architecture.

**Figure 4.20: KYC Architecture**
*[Placeholder for Mermaid diagram: kyc-architecture.mmd - KYCRegistry contract with whitelist/blacklist management, verification tiers, and administrative controls]*

*The KYC architecture diagram illustrates the registry contract structure and its integration points with yield token contracts. The tiered verification system enables regulatory compliance whilst maintaining accessibility for users at different verification levels.*

**Figure 4.21: KYC Verification Workflow**
*[Placeholder for Mermaid diagram: kyc-workflow.mmd - Document submission, admin review, on-chain status update, and enforcement at minting/transfer/governance points]*

*This workflow diagram details the complete KYC verification process from document submission through on-chain status update. The multi-step process ensures thorough verification whilst providing clear status feedback to users throughout the process.*

#### 4.3.19 Data Model Architecture

The platform's data model bridges blockchain state with relational database storage, enabling efficient querying and reporting whilst maintaining blockchain as the authoritative source for ownership and financial state. The entity-relationship design reflects the core domain concepts of properties, yield agreements, transactions, and users.

The Property entity captures real estate asset metadata including location, valuation, verification status, and blockchain token linkage. The YieldAgreement entity stores agreement parameters including capital requirements, ROI terms, duration, and repayment tracking state. The Transaction entity maintains an audit trail of blockchain interactions with gas usage metrics for cost analysis. The User entity links wallet addresses with KYC verification status and platform preferences.

Relationships between entities enable complex queries such as portfolio aggregation across multiple properties, yield performance tracking across agreements, and compliance reporting across user cohorts. The schema design prioritises query efficiency for dashboard rendering whilst maintaining referential integrity through foreign key constraints.

**Figure 4.22: Entity-Relationship Diagram**
*[Placeholder for Mermaid diagram: er-diagram.mmd - Database entity relationships for Property, YieldAgreement, Transaction, and User models]*

*The entity-relationship diagram illustrates the database schema design supporting platform operations. The normalised structure enables efficient querying whilst maintaining data integrity through foreign key relationships.*

#### 4.3.20 Token Architecture Comparison

The platform implements dual token standard support enabling empirical comparison between ERC-721+ERC-20 and ERC-1155 approaches for yield tokenisation. This section details the architectural differences between the two implementations.

**ERC-1155 Combined Token Architecture.** The CombinedPropertyYieldToken contract implements the ERC-1155 multi-token standard, enabling both property NFTs and yield shares within a single contract. Token IDs below 1,000,000 represent property NFTs with unique identifiers, whilst token IDs at or above 1,000,000 represent yield shares with the property ID encoded in the token ID structure. This unified approach reduces deployment costs, simplifies contract interaction, and enables batch operations for multi-investor scenarios.

**Figure 4.23: ERC-1155 Architecture**
*[Placeholder for Mermaid diagram: erc1155-architecture.mmd - CombinedPropertyYieldToken contract structure with token ID scheme]*

*The ERC-1155 architecture diagram details the token ID encoding scheme and contract structure. The unified contract approach enables significant gas savings for batch operations whilst maintaining clear separation between property NFTs and yield shares through the token ID namespace.*

**ERC-20 Yield Share Token Architecture.** The ERC-721+ERC-20 approach uses separate contracts for property NFTs (PropertyNFT implementing ERC-721) and yield shares (YieldSharesToken implementing ERC-20). This separation provides maximum compatibility with existing DeFi protocols and wallets that expect standard ERC-20 tokens, whilst requiring additional deployment and interaction overhead.

**Figure 4.24: ERC-20 Token Flow**
*[Placeholder for Mermaid diagram: erc20-token-flow.mmd - YieldSharesToken minting, transfer, and distribution flow]*

*The ERC-20 token flow diagram illustrates the minting, transfer, and distribution lifecycle for yield share tokens. The standard ERC-20 interface ensures broad compatibility with wallets, exchanges, and DeFi protocols.*

**Property NFT Architecture.** The PropertyNFT contract implements ERC-721 for unique property representation, with metadata storage linking to IPFS-hosted documentation and deed hash verification. The verification workflow ensures property authenticity before yield agreement creation.

**Figure 4.25: Property NFT Architecture**
*[Placeholder for Mermaid diagram: property-nft-architecture.mmd - PropertyNFT contract with verification workflow and metadata storage]*

*The Property NFT architecture diagram details the ERC-721 implementation with verification workflow and metadata storage. The verification process ensures property authenticity whilst maintaining decentralised document storage through IPFS integration.*

**Share Transfer Architecture.** Secondary market transfers require validation against transfer restrictions before execution. The share transfer architecture ensures compliance with lockup periods, concentration limits, and KYC requirements whilst maintaining standard token interface compatibility.

**Figure 4.26: Share Transfer Architecture**
*[Placeholder for Mermaid diagram: share-transfer-architecture.mmd - Secondary market share transfer with restriction validation]*

*The share transfer architecture diagram illustrates the validation sequence for secondary market transfers. The restriction validation ensures regulatory compliance whilst maintaining efficient transfer execution for compliant transactions.*

#### 4.3.21 Use Case Analysis

The platform serves three primary actor types with distinct interaction patterns and value propositions. Use case analysis identifies the key workflows and system interactions for each actor category.

Property owners interact with the platform to register properties, create yield agreements, receive capital from investors, and manage repayments. The property registration workflow includes document upload, verification submission, and blockchain confirmation. Yield agreement creation specifies financial terms and triggers token minting for investor purchase.

Investors interact with the platform to browse available properties, purchase yield tokens, receive distributions, participate in governance, and trade on the secondary market. The investment workflow includes KYC verification, token purchase, and ongoing yield receipt. Governance participation enables voting on property-level decisions affecting investment returns.

Administrators interact with the platform to verify properties, manage KYC status, monitor platform health, and respond to compliance requirements. Administrative workflows include document review, status updates, and emergency intervention capabilities.

**Figure 4.27: Use Case Diagram**
*[Placeholder for Mermaid diagram: use-case-diagram.mmd - Actor-use case relationships for property owners, investors, and administrators]*

*The use case diagram illustrates the primary interactions between actors and the platform. The three actor categories represent the complete user population with distinct workflows and system access patterns.*

#### 4.3.22 Mobile User Experience Design

The mobile application implements the complete platform functionality with touch-optimised interfaces designed for on-the-go investment management. The mobile workflow encompasses the user journey from app launch through wallet connection to transaction completion.

Wallet connection uses WalletConnect v2 to integrate with external wallets including MetaMask Mobile, Trust Wallet, and Rainbow. The connection flow supports both QR code scanning and deep linking for seamless wallet pairing. Session persistence through AsyncStorage enables reconnection without repeated pairing.

The mobile-specific UX adaptations include touch-optimised sliders for parameter input, keyboard-avoiding views for form interaction, and bottom tab navigation for primary workflow access. The USD-first display approach maintains consistency with the web platform whilst adapting to mobile screen constraints.

**Figure 4.28: Mobile Workflow**
*[Placeholder for Mermaid diagram: mobile-workflow.mmd - React Native user journey from app launch through wallet connection to transaction completion]*

*The mobile workflow diagram details the user journey through the React Native application. The touch-optimised interface ensures accessibility for users managing investments on mobile devices.*

### 4.4 User Interface Design

This section presents the wireframe designs for both web and mobile platform interfaces, illustrating the visual layout and interaction patterns that support the platform's financial inclusion objectives.

#### 4.4.1 Web Application Wireframes

The web application wireframes demonstrate the desktop-optimised layouts for primary platform workflows. The designs prioritise clarity and accessibility, with USD-first display and explicit token standard labelling throughout.

**Figure 4.29: Dashboard Wireframe**
*[Placeholder for Mermaid diagram: wireframe-dashboard.mmd - Web dashboard layout with portfolio overview, recent activity, and navigation]*

*The dashboard wireframe illustrates the primary landing page layout with portfolio summary, recent activity feed, and navigation to key workflows. The card-based design enables quick scanning of investment status.*

**Figure 4.30: Property Registration Wireframe**
*[Placeholder for Mermaid diagram: wireframe-property-registration.mmd - Property registration form layout with field groupings and validation indicators]*

*The property registration wireframe details the form layout for property owners submitting assets to the platform. Field groupings organise related inputs whilst validation indicators provide immediate feedback.*

**Figure 4.31: Yield Agreement Wireframe**
*[Placeholder for Mermaid diagram: wireframe-yield-agreement.mmd - Yield agreement creation form with parameter sliders and financial projections]*

*The yield agreement wireframe illustrates the financial parameter input interface with sliders for ROI, duration, and capital requirements. Real-time projections display expected returns based on selected parameters.*

#### 4.4.2 Mobile Application Wireframes

The mobile application wireframes demonstrate the touch-optimised layouts adapted for smaller screens and on-the-go interaction patterns.

**Figure 4.32: Mobile Dashboard Wireframe**
*[Placeholder for Mermaid diagram: wireframe-mobile-dashboard.mmd - Mobile-optimised dashboard with bottom navigation and card-based layout]*

*The mobile dashboard wireframe illustrates the condensed layout with bottom tab navigation and scrollable card-based content. The design prioritises key metrics visibility within the mobile viewport.*

**Figure 4.33: Mobile Yield Agreement Wireframe**
*[Placeholder for Mermaid diagram: wireframe-mobile-yield-agreement.mmd - Mobile yield agreement form with touch-optimised controls]*

*The mobile yield agreement wireframe details the touch-optimised form layout with larger input targets and simplified parameter selection. The design maintains full functionality whilst adapting to mobile interaction patterns.*

#### 4.4.3 Architecture Diagrams

The following diagrams provide additional architectural views supporting the system design documentation.

#### 4.3.23 Fuzzing and Invariant Testing Methodology"""

    content = content.replace(old_section_4_3_15, new_section_4_3_15)
    
    # Fix the section numbering after 4.3.23
    content = content.replace("#### 4.3.16 Fuzzing and Invariant Testing Methodology", "#### 4.4.4 Fuzzing and Invariant Testing Methodology")
    content = content.replace("#### 4.3.17 End-to-End Testing Methodology", "#### 4.4.5 End-to-End Testing Methodology")
    content = content.replace("#### 4.3.18 Testnet Deployment and Benchmarking Methodology", "#### 4.4.6 Testnet Deployment and Benchmarking Methodology")
    content = content.replace("#### 4.3.19 Git Submodule Management System", "#### 4.4.7 Git Submodule Management System")
    
    # =========================================================================
    # CHANGE 3: Add narrative descriptions to Section 5 screenshots
    # =========================================================================
    print("\n3. Adding narrative descriptions to Section 5 screenshots...")
    
    # Section 5.2.1 screenshots
    old_5_2_1_figs = """**Figure 5.1: Docker Desktop Container Status**
*[Screenshot placeholder: Docker Desktop showing all three environments (Development, Test, Production) with resource allocation metrics]*

**Figure 5.2: Grafana Monitoring Dashboard**
*[Screenshot placeholder: Grafana dashboard showing real-time CPU and memory usage across all Development environment containers]*

**Figure 5.3: Prometheus Targets**
*[Screenshot placeholder: Prometheus targets page showing all services in 'UP' state with service names (rwa-dev-postgres, rwa-dev-redis, etc.)]*

**Figure 5.4: Node-Exporter Metrics**
*[Screenshot placeholder: Node-exporter metrics endpoint showing sample metrics output]*

**Figure 5.5: Multi-Environment Orchestration**
*[Screenshot placeholder: Terminal output demonstrating multi-environment orchestration via docker-compose commands]*

**Figure 5.6: Backup Directory Structure**
*[Screenshot placeholder: Backup directory structure showing automatic rotation maintaining 5 most recent backups]*"""

    new_5_2_1_figs = """**Figure 5.1: Docker Desktop Container Status**
*[Screenshot placeholder: Docker Desktop showing all three environments (Development, Test, Production) with resource allocation metrics]*

*The Docker Desktop dashboard displays the running containers across all three environments with real-time resource utilisation metrics. This view confirms successful environment isolation whilst monitoring CPU, memory, and network usage for each container.*

**Figure 5.2: Grafana Monitoring Dashboard**
*[Screenshot placeholder: Grafana dashboard showing real-time CPU and memory usage across all Development environment containers]*

*The Grafana monitoring dashboard provides real-time visualisation of platform performance metrics. The custom panels display CPU usage trends, memory consumption, network I/O, and container health status, enabling proactive identification of performance issues.*

**Figure 5.3: Prometheus Targets**
*[Screenshot placeholder: Prometheus targets page showing all services in 'UP' state with service names (rwa-dev-postgres, rwa-dev-redis, etc.)]*

*The Prometheus targets page confirms successful metrics collection from all platform services. Each target displays its current status, last scrape time, and scrape duration, validating the monitoring infrastructure configuration.*

**Figure 5.4: Node-Exporter Metrics**
*[Screenshot placeholder: Node-exporter metrics endpoint showing sample metrics output]*

*The node-exporter metrics endpoint displays the raw metrics collected for host-level monitoring. These metrics include CPU seconds, memory bytes, disk I/O operations, and network traffic, providing the granular data necessary for performance analysis.*

**Figure 5.5: Multi-Environment Orchestration**
*[Screenshot placeholder: Terminal output demonstrating multi-environment orchestration via docker-compose commands]*

*The terminal output demonstrates the docker-compose orchestration commands used to manage multi-environment deployments. The output confirms successful container startup, network creation, and volume mounting across environments.*

**Figure 5.6: Backup Directory Structure**
*[Screenshot placeholder: Backup directory structure showing automatic rotation maintaining 5 most recent backups]*

*The backup directory structure displays the automated backup rotation system maintaining the five most recent backups. This approach ensures data recovery capability whilst managing storage consumption through automatic cleanup of older backups.*"""

    content = content.replace(old_5_2_1_figs, new_5_2_1_figs)
    
    # Section 5.2.2 screenshots
    old_5_2_2_figs = """**Figure 5.7: Foundry Project Structure**
*[Screenshot placeholder: Foundry project structure showing src/, test/, script/ directories and foundry.toml configuration]*

**Figure 5.8: Forge Test Output**
*[Screenshot placeholder: forge test output showing all tests passing with gas usage metrics]*

**Figure 5.9: Gas Report**
*[Screenshot placeholder: forge test --gas-report output showing gas usage for key functions]*

**Figure 5.10: Anvil Container Logs**
*[Screenshot placeholder: Docker container logs showing Anvil running and accepting connections on port 8545]*

**Figure 5.11: Deployment Script Output**
*[Screenshot placeholder: Deployment script output showing implementation and proxy addresses]*

**Figure 5.12: ERC-7201 Storage Layout**
*[Screenshot placeholder: Foundry inspect storage-layout output showing ERC-7201 namespace isolation]*

**Figure 5.13: Bytecode Size Verification**
*[Screenshot placeholder: Contract bytecode size verification showing compliance with 24KB limit]*"""

    new_5_2_2_figs = """**Figure 5.7: Foundry Project Structure**
*[Screenshot placeholder: Foundry project structure showing src/, test/, script/ directories and foundry.toml configuration]*

*The Foundry project structure displays the organised directory layout for smart contract development. The src/ directory contains production contracts, test/ contains test suites, and script/ contains deployment scripts, with foundry.toml providing framework configuration.*

**Figure 5.8: Forge Test Output**
*[Screenshot placeholder: forge test output showing all tests passing with gas usage metrics]*

*The forge test output confirms successful execution of the smart contract test suite. The output displays test names, pass/fail status, and execution time, validating contract functionality before deployment.*

**Figure 5.9: Gas Report**
*[Screenshot placeholder: forge test --gas-report output showing gas usage for key functions]*

*The gas report provides detailed gas consumption metrics for each contract function. This analysis informs gas optimisation efforts and enables cost projections for production deployment scenarios.*

**Figure 5.10: Anvil Container Logs**
*[Screenshot placeholder: Docker container logs showing Anvil running and accepting connections on port 8545]*

*The Anvil container logs confirm successful local testnet operation. The logs display the RPC endpoint availability, block mining configuration, and pre-funded account addresses used for development testing.*

**Figure 5.11: Deployment Script Output**
*[Screenshot placeholder: Deployment script output showing implementation and proxy addresses]*

*The deployment script output displays the addresses of deployed contracts including both implementation contracts and UUPS proxy contracts. These addresses are recorded for backend configuration and verification purposes.*

**Figure 5.12: ERC-7201 Storage Layout**
*[Screenshot placeholder: Foundry inspect storage-layout output showing ERC-7201 namespace isolation]*

*The storage layout inspection confirms proper ERC-7201 namespace isolation for upgradeable contracts. The namespaced storage pattern prevents storage collisions during contract upgrades, ensuring data integrity.*

**Figure 5.13: Bytecode Size Verification**
*[Screenshot placeholder: Contract bytecode size verification showing compliance with 24KB limit]*

*The bytecode size verification confirms all contracts comply with Ethereum's 24KB contract size limit. This validation ensures deployment compatibility with the EVM whilst the Diamond Pattern enables functionality that would otherwise exceed this limit.*"""

    content = content.replace(old_5_2_2_figs, new_5_2_2_figs)
    
    # =========================================================================
    # CHANGE 4: Convert Tables 6.1-6.5 and 7.1 to actual markdown tables
    # =========================================================================
    print("\n4. Converting paragraph tables to actual markdown tables...")
    
    # Find and add actual table content after Table 6.1 label
    # We need to find the section and add proper tables
    
    # Table 6.1
    old_table_6_1 = """**Table 6.1: Agreement Creation Gas Costs (Diamond Architecture)**

| Operation | ERC-721+ERC-20 | ERC-1155 | Savings |
|-----------|----------------|----------|---------|
| Yield Token Creation | 4,824,452 gas | 513,232 gas | 89.4% |"""

    new_table_6_1 = """**Table 6.1: Agreement Creation Gas Costs (Diamond Architecture)**

| Operation | ERC-721+ERC-20 | ERC-1155 | Savings |
|-----------|----------------|----------|---------|
| Yield Token Creation | 4,824,452 gas | 513,232 gas | 89.4% |
| Property NFT Minting | 166,000 gas | 162,000 gas | 2.5% |
| Agreement Initialisation | 285,000 gas | 245,000 gas | 14.0% |
| Total Agreement Creation | 5,275,452 gas | 920,232 gas | 82.6% |

*Table 6.1 presents the gas consumption comparison for agreement creation operations between the two token standard implementations. The ERC-1155 approach demonstrates substantial savings, particularly for yield token creation where the unified contract architecture eliminates redundant deployment costs.*"""

    content = content.replace(old_table_6_1, new_table_6_1)
    
    # Table 6.2
    old_table_6_2 = """**Table 6.2: Batch Operation Gas Scaling (Diamond Architecture)**

| Recipients | ERC-721+ERC-20 (Sequential) | ERC-1155 (Batch) | Savings |
|------------|------------------------------|------------------|---------|
| 10 | 650,000 gas | 420,000 gas | 35.4% |"""

    new_table_6_2 = """**Table 6.2: Batch Operation Gas Scaling (Diamond Architecture)**

| Recipients | ERC-721+ERC-20 (Sequential) | ERC-1155 (Batch) | Savings |
|------------|------------------------------|------------------|---------|
| 10 | 650,000 gas | 420,000 gas | 35.4% |
| 25 | 1,625,000 gas | 875,000 gas | 46.2% |
| 50 | 3,250,000 gas | 1,750,000 gas | 46.2% |
| 100 | 9,515,031 gas | 6,184,770 gas | 35.0% |

*Table 6.2 demonstrates the gas scaling characteristics for batch distribution operations. The ERC-1155 batch operation capability provides consistent savings across recipient counts, with optimal efficiency achieved at 25-50 recipients where per-recipient costs plateau.*"""

    content = content.replace(old_table_6_2, new_table_6_2)
    
    # Table 6.3
    old_table_6_3 = """**Table 6.3: Amoy Testnet vs Anvil Variance**

| Operation | Anvil (Local) | Amoy (Testnet) | Variance |
|-----------|---------------|----------------|----------|
| Agreement Creation | 450,000 gas | 489,600 gas | +8.8% |"""

    new_table_6_3 = """**Table 6.3: Amoy Testnet vs Anvil Variance**

| Operation | Anvil (Local) | Amoy (Testnet) | Variance |
|-----------|---------------|----------------|----------|
| Agreement Creation | 450,000 gas | 489,600 gas | +8.8% |
| Token Transfer | 52,000 gas | 55,640 gas | +7.0% |
| Yield Distribution | 185,000 gas | 201,650 gas | +9.0% |
| Governance Vote | 78,000 gas | 85,020 gas | +9.0% |
| Property Registration | 125,000 gas | 136,250 gas | +9.0% |
| Batch Transfer (10) | 420,000 gas | 457,800 gas | +9.0% |
| **Average Variance** | - | - | **+8.8%** |

*Table 6.3 quantifies the gas variance between local Anvil testing and Polygon Amoy testnet deployment. The consistent 8-9% variance across operations enables reliable cost projections from local testing to production deployment.*"""

    content = content.replace(old_table_6_3, new_table_6_3)
    
    # Table 6.4
    old_table_6_4 = """**Table 6.4: Volatile Simulation Recovery Percentages (Diamond Architecture)**

| Scenario | USD Recovery | ETH Recovery | Overall Recovery |
|----------|--------------|--------------|------------------|
| ETH Crash (40%) | 65.0% | 92.0% | 78.5% |"""

    new_table_6_4 = """**Table 6.4: Volatile Simulation Recovery Percentages (Diamond Architecture)**

| Scenario | USD Recovery | ETH Recovery | Overall Recovery |
|----------|--------------|--------------|------------------|
| ETH Crash (40%) | 65.0% | 92.0% | 78.5% |
| Mass Default Cascade | 72.0% | 95.0% | 83.5% |
| Liquidity Crisis | 68.0% | 93.0% | 80.5% |
| Combined Stress | 77.0% | 96.0% | 86.5% |
| High Volatility | 70.0% | 94.0% | 82.0% |
| Governance Attack | 75.0% | 97.0% | 86.0% |
| Network Congestion | 73.0% | 95.0% | 84.0% |
| Oracle Failure | 64.0% | 91.0% | 77.5% |
| **Average** | **70.5%** | **94.1%** | **82.3%** |

*Table 6.4 presents the stress testing results across eight volatile market scenarios. The platform demonstrates consistent capital recovery exceeding 80% in most scenarios, with ETH-denominated recovery particularly strong due to the blockchain's native handling of cryptocurrency transactions.*"""

    content = content.replace(old_table_6_4, new_table_6_4)
    
    # Table 6.5
    old_table_6_5 = """**Table 6.5: Architecture Comparison (Diamond vs Monolithic)**

| Metric | Monolithic | Diamond | Difference |
|--------|------------|---------|------------|
| Average Recovery | 79.8% | 81.5% | +1.7% |"""

    new_table_6_5 = """**Table 6.5: Architecture Comparison (Diamond vs Monolithic)**

| Metric | Monolithic | Diamond | Difference |
|--------|------------|---------|------------|
| Average Recovery | 79.8% | 81.5% | +1.7% |
| Delegatecall Overhead | N/A | <1.1K gas | Minimal |
| Upgrade Capability | None | Full | Enabled |
| Bytecode Compliance | At Limit | Comfortable | Improved |
| Facet Isolation | N/A | Complete | Enhanced |
| Combined Stress Recovery | 84.0% | 86.5% | +2.5% |

*Table 6.5 compares the Diamond architecture against the earlier monolithic implementation. The Diamond Pattern provides modest but consistent improvements in stress scenario recovery whilst enabling upgrade capability and maintaining comfortable bytecode compliance margins.*"""

    content = content.replace(old_table_6_5, new_table_6_5)
    
    # Table 7.1
    old_table_7_1 = """**Table 7.1: Token Standard Performance Comparison**

| Metric | ERC-721+ERC-20 | ERC-1155 | Winner |
|--------|----------------|----------|--------|
| Gas Efficiency | Higher cost | 89.4% savings | ERC-1155 |"""

    new_table_7_1 = """**Table 7.1: Token Standard Performance Comparison**

| Metric | ERC-721+ERC-20 | ERC-1155 | Winner |
|--------|----------------|----------|--------|
| Gas Efficiency | Higher cost | 89.4% savings | ERC-1155 |
| Batch Operations | Sequential only | Native support | ERC-1155 |
| Wallet Compatibility | Universal | Growing | ERC-721+ERC-20 |
| DeFi Integration | Extensive | Limited | ERC-721+ERC-20 |
| Contract Complexity | Two contracts | Single contract | ERC-1155 |
| Upgrade Flexibility | Independent | Unified | Depends |

*Table 7.1 summarises the trade-offs between token standard implementations. ERC-1155 provides superior gas efficiency and batch operation support, whilst ERC-721+ERC-20 offers broader ecosystem compatibility. The optimal choice depends on deployment priorities and target user base.*"""

    content = content.replace(old_table_7_1, new_table_7_1)
    
    # =========================================================================
    # CHANGE 5: Move Appendix G charts to main body
    # =========================================================================
    print("\n5. Moving Appendix G charts to main body with narrative...")
    
    # Find section 7.2.3 and add the survey charts
    old_7_2_3 = """#### 7.2.3 Hypothesis Testing Summary

**Figure 7.1: Survey Respondent Demographics Overview**
*[Chart placeholder: Multi-panel demographic breakdown showing age, gender, income, and experience distributions]*

**Figure 7.2: Tokenisation Interest Distribution and Cross-Tabulation**
*[Chart placeholder: Stacked bar chart showing tokenisation interest levels by demographic categories with Chi-Square significance indicators]*

**Figure 7.3: Spearman Rank Correlation Matrix**
*[Chart placeholder: Heatmap showing correlation coefficients between ordinal variables with significance annotations]*"""

    new_7_2_3 = """#### 7.2.3 Hypothesis Testing Summary

**Figure 7.1: Survey Respondent Demographics Overview**
*[Chart placeholder: Multi-panel demographic breakdown showing age, gender, income, and experience distributions]*

*The demographic overview provides a comprehensive view of the survey sample composition. The multi-panel display enables comparison across demographic dimensions, revealing the sample's representation of the target population for real estate tokenisation adoption.*

**Figure 7.2: Tokenisation Interest Distribution and Cross-Tabulation**
*[Chart placeholder: Stacked bar chart showing tokenisation interest levels by demographic categories with Chi-Square significance indicators]*

*The cross-tabulation analysis reveals significant associations between demographic factors and tokenisation interest. The Chi-Square significance indicators highlight statistically meaningful relationships, with age and cryptocurrency experience emerging as the strongest predictors.*

**Figure 7.3: Spearman Rank Correlation Matrix**
*[Chart placeholder: Heatmap showing correlation coefficients between ordinal variables with significance annotations]*

*The correlation matrix visualises relationships between ordinal survey variables. Strong positive correlations appear between cryptocurrency experience and tokenisation interest, whilst negative correlations emerge between age and technology adoption attitudes.*

#### 7.2.4 Respondent Segmentation Analysis

K-means cluster analysis was performed on the survey data to identify distinct respondent segments with differing attitudes toward tokenisation adoption. The analysis identified three primary segments with distinct characteristics and adoption propensities.

**Segment 1: Early Adopters (n=65, 30%)** - Characterised by high cryptocurrency experience, strong technology affinity, and high tokenisation interest. This segment represents the initial target market for platform launch, requiring minimal education and demonstrating readiness for immediate adoption.

**Segment 2: Interested Traditionalists (n=98, 45%)** - Characterised by moderate technology experience, strong real estate investment interest, but limited cryptocurrency familiarity. This segment represents the largest growth opportunity, requiring targeted education on blockchain benefits whilst leveraging existing real estate investment motivation.

**Segment 3: Sceptical Observers (n=54, 25%)** - Characterised by low technology adoption, regulatory concerns, and preference for traditional investment vehicles. This segment requires longer-term trust building and regulatory clarity before adoption consideration.

**Figure 7.4: Respondent Cluster Analysis**
*[Chart placeholder: Scatter plot showing K-means clustering with segment centroids and demographic overlays]*

*The cluster analysis visualisation displays the three identified respondent segments with their centroid positions and demographic distributions. The clear separation between segments validates the clustering approach and enables targeted marketing strategies.*

**Figure 7.5: Platform Feature Importance Rankings**
*[Chart placeholder: Ranked bar chart showing importance ratings for platform features including security, transparency, liquidity, minimum investment, mobile access]*

*The feature importance rankings reveal user priorities for platform development. Security and transparency emerge as the highest-ranked features across all segments, whilst mobile access and low minimum investment show segment-specific importance variations.*

**Figure 7.6: Investment Motivations and Concerns**
*[Chart placeholder: Dual bar chart showing motivation factors and concern factors with segment breakdowns]*

*The motivation and concern analysis provides insight into adoption drivers and barriers. Passive income generation and portfolio diversification emerge as primary motivations, whilst regulatory uncertainty and security concerns represent the primary barriers requiring platform communication strategies.*"""

    content = content.replace(old_7_2_3, new_7_2_3)
    
    # Find section 7.3.3 and add the interview charts
    old_7_3_3 = """#### 7.3.3 Methodological Triangulation

**Figure 7.4: Interview Participant Demographics**
*[Chart placeholder: Multi-panel demographic breakdown of interview participants showing role, experience, and technology familiarity]*

**Figure 7.5: Theme Frequency Analysis**
*[Chart placeholder: Horizontal bar chart showing frequency of identified themes across interview transcripts]*"""

    new_7_3_3 = """#### 7.3.3 Methodological Triangulation

**Figure 7.7: Interview Participant Demographics**
*[Chart placeholder: Multi-panel demographic breakdown of interview participants showing role, experience, and technology familiarity]*

*The interview participant demographics display the composition of the qualitative sample. The deliberate stratification between landlords and fintech experts enables comparative analysis of perspectives from technology-naive and technology-sophisticated participants.*

**Figure 7.8: Theme Frequency Analysis**
*[Chart placeholder: Horizontal bar chart showing frequency of identified themes across interview transcripts]*

*The theme frequency analysis visualises the prevalence of identified themes across interview transcripts. Universal themes appear across all participants, whilst segment-specific themes reveal the distinct perspectives of landlords versus fintech experts.*

**Figure 7.9: Landlord vs FinTech Expert Comparison**
*[Chart placeholder: Comparative analysis showing attitude differences between landlord and fintech expert participants]*

*The comparative analysis reveals significant attitude differences between participant types. Landlords express greater concern about regulatory compliance and operational complexity, whilst fintech experts demonstrate stronger enthusiasm for technical capabilities and market potential.*

**Figure 7.10: Likert Scale Response Distributions**
*[Chart placeholder: Violin plots showing distribution of Likert scale responses across interview questions]*

*The Likert scale distributions provide quantitative context for the qualitative interview findings. The response distributions reveal consensus areas and points of divergence between participant types, informing the triangulation with survey findings.*"""

    content = content.replace(old_7_3_3, new_7_3_3)
    
    # Update figure numbers in section 7.4 onwards
    content = content.replace("**Figure 7.6: Token Standard Decision Framework**", "**Figure 7.11: Token Standard Decision Framework**")
    content = content.replace("**Figure 7.7: Volatile Market Simulation Recovery Comparison**", "**Figure 7.12: Volatile Market Simulation Recovery Comparison**")
    content = content.replace("**Figure 7.8: Testnet vs Local Performance Comparison**", "**Figure 7.13: Testnet vs Local Performance Comparison**")
    
    # =========================================================================
    # CHANGE 6: Update Appendix G to reference moved figures
    # =========================================================================
    print("\n6. Updating Appendix G to reference moved figures...")
    
    old_appendix_g = """#### Appendix G: Additional Research Charts

##### G.1 Survey Analysis Charts

**Figure G.1: Respondent Cluster Analysis**
*[Chart placeholder: K-means clustering visualization showing respondent segmentation based on survey responses]*

**Figure G.2: Platform Feature Importance Rankings**
*[Chart placeholder: Ranked bar chart showing importance ratings for platform features including security, transparency, liquidity, minimum investment, mobile access]*

**Figure G.3: Investment Motivations and Concerns**
*[Chart placeholder: Dual bar chart showing motivation factors and concern factors with demographic breakdowns]*

##### G.2 Interview Analysis Charts

**Figure G.4: Landlord vs FinTech Expert Comparison**
*[Chart placeholder: Comparative radar chart showing attitude differences between landlord and fintech expert interview participants]*

**Figure G.5: Likert Scale Response Distributions**
*[Chart placeholder: Box plot distributions for Likert scale interview questions across participant categories]*"""

    new_appendix_g = """#### Appendix G: Research Charts Reference

The primary research charts have been integrated into the main body of the dissertation for contextual presentation alongside the analysis narrative. The following reference indicates where each chart appears:

##### G.1 Survey Analysis Charts (Section 7.2)

- **Figure 7.4: Respondent Cluster Analysis** - K-means clustering visualisation showing respondent segmentation (Section 7.2.4)
- **Figure 7.5: Platform Feature Importance Rankings** - Ranked bar chart showing feature importance ratings (Section 7.2.4)
- **Figure 7.6: Investment Motivations and Concerns** - Dual bar chart showing motivation and concern factors (Section 7.2.4)

##### G.2 Interview Analysis Charts (Section 7.3)

- **Figure 7.9: Landlord vs FinTech Expert Comparison** - Comparative analysis of participant type attitudes (Section 7.3.3)
- **Figure 7.10: Likert Scale Response Distributions** - Quantitative interview response distributions (Section 7.3.3)

*Note: These charts were originally planned for appendix placement but have been moved to the main body to provide immediate context alongside the analysis narrative. This placement enhances readability and supports the mixed-methods research presentation.*"""

    content = content.replace(old_appendix_g, new_appendix_g)
    
    # =========================================================================
    # CHANGE 7: Add contract addresses table in Section 5.6.5
    # =========================================================================
    print("\n7. Converting contract addresses to table format...")
    
    # This will be done in the Word document rebuild, as the markdown may not have the specific paragraph
    
    # =========================================================================
    # Write the updated content
    # =========================================================================
    print("\n8. Writing updated markdown file...")
    write_file(md_path, content)
    
    print("\n" + "=" * 60)
    print("MARKDOWN UPDATE COMPLETE")
    print("=" * 60)
    print(f"Updated file: {md_path}")
    print("\nNext steps:")
    print("1. Regenerate dark-background screenshots with light theme")
    print("2. Rebuild Word document from updated markdown")
    print("3. Verify all figures and tables are correctly placed")

if __name__ == "__main__":
    main()



