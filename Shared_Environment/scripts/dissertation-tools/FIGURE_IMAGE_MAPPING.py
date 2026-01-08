#!/usr/bin/env python3
"""
PHASE 3: Complete Figure-to-Image Mapping
Creates a verified mapping of every figure to its correct image file.
"""

from pathlib import Path
import json

# Available images
drawio_dir = Path("rendered_diagrams_drawio")
survey_dir = Path("survey_interview_charts")
charts_dir = Path("generated_charts")
screenshots_dir = Path("generated_screenshots")

# Build image inventory
images = {}
for f in drawio_dir.glob("*.png"):
    images[f.stem] = str(f)
for f in survey_dir.glob("*.png"):
    images[f.stem] = str(f)
for f in charts_dir.glob("*.png"):
    images[f.stem] = str(f)
for f in screenshots_dir.glob("*.png"):
    images[f.stem] = str(f)

# COMPLETE FIGURE MAPPING
# Format: "Figure Number": ("Image Filename", "Caption", "Status")
# Status: "mapped" = has correct image, "missing" = needs to be created

FIGURE_MAPPING = {
    # ============================================================
    # SECTION 4: SYSTEM DESIGN (32 figures) - All Mermaid/Draw.io
    # ============================================================
    "4.1": ("docker-architecture-logical", "Multi-Environment Docker Architecture (Logical View)"),
    "4.2": ("docker-architecture-physical", "Multi-Environment Docker Architecture (Physical View)"),
    "4.3": ("monitoring-architecture", "Monitoring Architecture Diagram"),
    "4.4": ("mobile-architecture", "Mobile Application Architecture"),
    "4.5": ("backend-api-architecture", "Backend API Architecture"),
    "4.6": ("property-owner-workflow", "Property Owner Workflow"),
    "4.7": ("yield-architecture", "Yield Tokenisation Architecture"),
    "4.8": ("yield-tokenization-flow", "Complete Yield Tokenization Workflow"),
    "4.9": ("repayment-processing-flow", "Repayment Processing Decision Tree"),
    "4.10": ("pooling-mechanism-flow", "Pooling Mechanism Workflow"),
    "4.11": ("default-handling-flow", "Default Handling Workflow"),
    "4.12": ("storage-layout-diagram", "ERC-7201 Storage Layout"),
    "4.13": ("analytics-architecture", "Analytics Architecture (The Graph Protocol)"),
    "4.14": ("subgraph-entity-relationships", "Subgraph Entity Relationships"),
    "4.15": ("governance-architecture", "Governance Architecture"),
    "4.16": ("governance-proposal-flow", "Governance Proposal Flow"),
    "4.17": ("secondary-market-architecture", "Secondary Market Architecture"),
    "4.18": ("transfer-restriction-flow", "Transfer Restriction Flow"),
    "4.19": ("kyc-architecture", "KYC Architecture"),
    "4.20": ("kyc-workflow", "KYC Verification Workflow"),
    "4.21": ("er-diagram", "Entity-Relationship Diagram"),
    "4.22": ("erc1155-architecture", "ERC-1155 Architecture"),
    "4.23": ("erc20-token-flow", "ERC-20 Token Flow"),
    "4.24": ("property-nft-architecture", "Property NFT Architecture"),
    "4.25": ("share-transfer-architecture", "Share Transfer Architecture"),
    "4.26": ("use-case-diagram", "Use Case Diagram"),
    "4.27": ("mobile-workflow", "Mobile Workflow"),
    "4.28": ("wireframe-dashboard", "Dashboard Wireframe"),
    "4.29": ("wireframe-property-registration", "Property Registration Wireframe"),
    "4.30": ("wireframe-yield-agreement", "Yield Agreement Wireframe"),
    "4.31": ("wireframe-mobile-dashboard", "Mobile Dashboard Wireframe"),
    "4.32": ("wireframe-mobile-yield-agreement", "Mobile Yield Agreement Wireframe"),
    
    # ============================================================
    # SECTION 5: IMPLEMENTATION (23 figures) - Screenshots
    # ============================================================
    "5.1": ("docker-desktop-dashboard", "Docker Desktop Container Status"),
    "5.2": ("NEED_CREATE_grafana-dashboard", "Grafana Monitoring Dashboard"),
    "5.3": ("NEED_CREATE_prometheus-targets", "Prometheus Targets"),
    "5.4": ("NEED_CREATE_node-exporter-metrics", "Node-Exporter Metrics"),
    "5.5": ("NEED_CREATE_multi-env-orchestration", "Multi-Environment Orchestration"),
    "5.6": ("NEED_CREATE_backup-directory", "Backup Directory Structure"),
    "5.7": ("NEED_CREATE_foundry-project-structure", "Foundry Project Structure"),
    "5.8": ("NEED_CREATE_forge-test-output", "Forge Test Output"),
    "5.9": ("NEED_CREATE_gas-report", "Gas Report"),
    "5.10": ("NEED_CREATE_anvil-container-logs", "Anvil Container Logs"),
    "5.11": ("smart-contract-deployment", "Deployment Script Output"),
    "5.12": ("NEED_CREATE_erc7201-storage-layout", "ERC-7201 Storage Layout Screenshot"),
    "5.13": ("NEED_CREATE_bytecode-size-verification", "Bytecode Size Verification"),
    "5.14": ("amoy-testnet-deployment", "Diamond Deployment to Amoy"),
    "5.15": ("NEED_CREATE_polygonscan-confirmation", "PolygonScan Transaction Confirmation"),
    "5.16": ("NEED_CREATE_diamond-test-results", "Diamond Architecture Test Results"),
    "5.17": ("NEED_CREATE_property-registration-form", "Property Registration Form"),
    "5.18": ("NEED_CREATE_yield-agreement-interface", "Yield Agreement Creation Interface"),
    "5.19": ("analytics-dashboard", "Analytics Dashboard"),
    "5.20": ("NEED_CREATE_simulation-test-results", "Simulation Test Results"),
    "5.21": ("NEED_CREATE_gas-comparison-report", "Gas Comparison Report"),
    "5.22": ("NEED_CREATE_variance-tracking", "Variance Tracking Metrics"),
    "5.23": ("yield-tokenization-flow", "Yield Tokenization Flowchart"),
    
    # ============================================================
    # SECTION 6: TESTING (24 figures) - Charts and Diagrams
    # ============================================================
    "6.1": ("fig_6_1_token_standard_gas_comparison", "Token Standard Gas Comparison"),
    "6.2": ("fig_6_2_batch_operation_scaling", "Batch Operation Scaling Curve"),
    "6.3": ("fig_6_3_amoy_anvil_variance_heatmap", "Amoy vs Anvil Variance Heatmap"),
    "6.4": ("fig_6_4_volatile_simulation_radar", "Volatile Simulation Recovery Radar"),
    "6.5": ("fig_6_5_diamond_overhead_boxplot", "Diamond Architecture Call Overhead"),
    "6.6": ("fig_6_6_load_testing_scatter", "Load Testing Throughput Scatter"),
    "6.7": ("fig_6_7_gas_cost_projections", "Gas Cost Projections"),
    "6.8": ("fig_6_8_test_pass_rate_evolution", "Test Pass Rate Evolution"),
    "6.9": ("NEED_CREATE_architecture-comparison", "Architecture Comparison Diagram"),
    "6.10": ("NEED_CREATE_user-workflow-diagrams", "User Workflow Diagrams"),
    "6.11": ("load-test-system-architecture", "Load Test System Architecture"),
    "6.12": ("load-test-workflow", "Load Test Workflow"),
    "6.13": ("load-testing-results", "Load Testing Results Summary"),
    "6.14": ("load-test-gas-scaling", "Load Test Gas Scaling"),
    "6.15": ("load-test-shareholder-distribution", "Load Test Shareholder Distribution"),
    "6.16": ("load-test-success-rates", "Load Test Success Rates"),
    "6.17": ("load-test-latency-distribution", "Load Test Latency Distribution"),
    "6.18": ("load-test-metrics-summary", "Load Test Metrics Summary"),
    "6.19": ("load-test-cost-comparison", "Load Test Cost Comparison"),
    "6.20": ("load-test-erc1155-efficiency", "Load Test ERC-1155 Efficiency"),
    "6.21": ("load-test-token-recycling", "Load Test Token Recycling"),
    "6.22": ("load-test-restriction-enforcement", "Load Test Restriction Enforcement"),
    "6.23": ("load-test-restriction-overhead", "Load Test Restriction Overhead"),
    "6.24": ("load-test-rq-validation", "Load Test Research Question Validation"),
    
    # ============================================================
    # SECTION 7: EVALUATION (8 figures) - Survey/Interview Charts
    # ============================================================
    "7.1": ("fig_demographic_overview", "Survey Demographics Overview"),
    "7.2": ("fig_tokenisation_interest_analysis", "Tokenisation Interest Analysis"),
    "7.3": ("fig_correlation_matrix", "Spearman Correlation Matrix"),
    "7.4": ("fig_interview_demographics", "Interview Demographics"),
    "7.5": ("fig_thematic_code_frequencies", "Theme Frequency Analysis"),
    "7.6": ("NEED_CREATE_token-decision-framework", "Token Standard Decision Framework"),
    "7.7": ("fig_7_7_volatile_recovery_comparison", "Volatile Market Recovery Comparison"),
    "7.8": ("fig_7_8_testnet_local_comparison", "Testnet vs Local Performance"),
}

# Check mapping status
print("=" * 80)
print("PHASE 3: FIGURE-TO-IMAGE MAPPING VERIFICATION")
print("=" * 80)

mapped = []
missing = []

for fig_num, (img_name, caption) in FIGURE_MAPPING.items():
    if img_name.startswith("NEED_CREATE"):
        missing.append((fig_num, img_name, caption))
    elif img_name in images:
        mapped.append((fig_num, img_name, caption, images[img_name]))
    else:
        missing.append((fig_num, img_name, caption))

print(f"\n✅ MAPPED ({len(mapped)} figures):")
for fig_num, img_name, caption, path in mapped:
    print(f"  Figure {fig_num}: {img_name} → {path}")

print(f"\n⚠️  NEED TO CREATE ({len(missing)} figures):")
for fig_num, img_name, caption in missing:
    print(f"  Figure {fig_num}: {caption}")
    print(f"    → Need: {img_name}")

# Save mapping to JSON
mapping_data = {
    "mapped": [(f, i, c, p) for f, i, c, p in mapped],
    "missing": [(f, i, c) for f, i, c in missing],
}

with open("FIGURE_MAPPING.json", "w") as f:
    json.dump(mapping_data, f, indent=2)

print(f"\n{'='*80}")
print(f"SUMMARY")
print(f"{'='*80}")
print(f"Total figures: {len(FIGURE_MAPPING)}")
print(f"Mapped (ready): {len(mapped)}")
print(f"Missing (need creation): {len(missing)}")
print(f"\nMapping saved to FIGURE_MAPPING.json")
