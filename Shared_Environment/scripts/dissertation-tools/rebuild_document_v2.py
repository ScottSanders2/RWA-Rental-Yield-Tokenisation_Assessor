#!/usr/bin/env python3
"""
Rebuild the Word document with CORRECT figure mappings and proper captions.
"""

from docx import Document
from docx.shared import Inches, Pt, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import re
import os
import shutil

# CORRECTED figure mapping based on actual files
FIGURE_MAPPING = {
    # Section 4 - System Design (32 figures)
    "Figure 4.1": "rendered_diagrams_drawio/docker-architecture-logical.png",
    "Figure 4.2": "rendered_diagrams_drawio/docker-architecture-physical.png",
    "Figure 4.3": "rendered_diagrams_drawio/monitoring-architecture.png",
    "Figure 4.4": "rendered_diagrams_drawio/mobile-architecture.png",
    "Figure 4.5": "rendered_diagrams_drawio/backend-api-architecture.png",
    "Figure 4.6": "rendered_diagrams_drawio/property-owner-workflow.png",
    "Figure 4.7": "rendered_diagrams_drawio/yield-architecture.png",  # Check if exists
    "Figure 4.8": "rendered_diagrams_drawio/yield-tokenization-flow.png",  # Check if exists
    "Figure 4.9": "rendered_diagrams_drawio/repayment-processing-flow.png",
    "Figure 4.10": "rendered_diagrams_drawio/pooling-mechanism-flow.png",
    "Figure 4.11": "rendered_diagrams_drawio/default-handling-flow.png",
    "Figure 4.12": "rendered_diagrams_drawio/storage-layout-diagram.png",  # CORRECTED
    "Figure 4.13": "rendered_diagrams_drawio/analytics-architecture.png",
    "Figure 4.14": "rendered_diagrams_drawio/subgraph-entity-relationships.png",
    "Figure 4.15": "rendered_diagrams_drawio/governance-architecture.png",
    "Figure 4.16": "rendered_diagrams_drawio/governance-proposal-flow.png",
    "Figure 4.17": "rendered_diagrams_drawio/secondary-market-architecture.png",
    "Figure 4.18": "rendered_diagrams_drawio/transfer-restriction-flow.png",
    "Figure 4.19": "rendered_diagrams_drawio/kyc-architecture.png",
    "Figure 4.20": "rendered_diagrams_drawio/kyc-workflow.png",  # CORRECTED
    "Figure 4.21": "rendered_diagrams_drawio/er-diagram.png",
    "Figure 4.22": "rendered_diagrams_drawio/erc1155-architecture.png",
    "Figure 4.23": "rendered_diagrams_drawio/erc20-token-flow.png",
    "Figure 4.24": "rendered_diagrams_drawio/property-nft-architecture.png",
    "Figure 4.25": "rendered_diagrams_drawio/share-transfer-architecture.png",
    "Figure 4.26": "rendered_diagrams_drawio/use-case-diagram.png",
    "Figure 4.27": "rendered_diagrams_drawio/mobile-workflow.png",
    "Figure 4.28": "rendered_diagrams_drawio/wireframe-dashboard.png",  # CORRECTED
    "Figure 4.29": "rendered_diagrams_drawio/wireframe-property-registration.png",  # CORRECTED
    "Figure 4.30": "rendered_diagrams_drawio/wireframe-yield-agreement.png",  # CORRECTED
    "Figure 4.31": "rendered_diagrams_drawio/wireframe-mobile-dashboard.png",  # CORRECTED
    "Figure 4.32": "rendered_diagrams_drawio/wireframe-mobile-yield-agreement.png",  # CORRECTED
    
    # Section 5 - Implementation (23 figures)
    "Figure 5.1": "generated_screenshots/docker-desktop-dashboard.png",
    "Figure 5.2": "generated_screenshots/grafana-dashboard.png",
    "Figure 5.3": "generated_screenshots/prometheus-targets.png",
    "Figure 5.4": "generated_screenshots/node-exporter-metrics.png",
    "Figure 5.5": "generated_screenshots/multi-env-orchestration.png",  # CORRECTED
    "Figure 5.6": "generated_screenshots/backup-directory.png",
    "Figure 5.7": "generated_screenshots/foundry-project-structure.png",
    "Figure 5.8": "generated_screenshots/forge-test-output.png",
    "Figure 5.9": "generated_screenshots/gas-report.png",
    "Figure 5.10": "generated_screenshots/anvil-container-logs.png",
    "Figure 5.11": "generated_screenshots/smart-contract-deployment.png",  # CORRECTED
    "Figure 5.12": "generated_screenshots/erc7201-storage-layout.png",
    "Figure 5.13": "generated_screenshots/bytecode-size-verification.png",
    "Figure 5.14": "generated_screenshots/amoy-testnet-deployment.png",
    "Figure 5.15": "generated_screenshots/polygonscan-confirmation.png",  # CORRECTED
    "Figure 5.16": "generated_screenshots/diamond-test-results.png",
    "Figure 5.17": "generated_screenshots/property-registration-form.png",
    "Figure 5.18": "generated_screenshots/yield-agreement-interface.png",  # CORRECTED
    "Figure 5.19": "generated_screenshots/analytics-dashboard.png",
    "Figure 5.20": "generated_screenshots/simulation-test-results.png",
    "Figure 5.21": "generated_screenshots/gas-comparison-report.png",
    "Figure 5.22": "generated_screenshots/variance-tracking.png",  # CORRECTED
    "Figure 5.23": "rendered_diagrams_drawio/yield-tokenization-flow.png",  # Check if exists
    
    # Section 6 - Testing (24 figures)
    "Figure 6.1": "generated_charts/fig_6_1_token_standard_gas_comparison.png",  # CORRECTED
    "Figure 6.2": "generated_charts/fig_6_2_batch_operation_scaling.png",  # CORRECTED
    "Figure 6.3": "generated_charts/fig_6_3_amoy_anvil_variance_heatmap.png",  # CORRECTED
    "Figure 6.4": "generated_charts/fig_6_4_volatile_simulation_radar.png",  # CORRECTED
    "Figure 6.5": "generated_charts/fig_6_5_diamond_overhead_boxplot.png",  # CORRECTED
    "Figure 6.6": "generated_charts/fig_6_6_load_testing_scatter.png",  # CORRECTED
    "Figure 6.7": "generated_charts/fig_6_7_gas_cost_projections.png",  # CORRECTED
    "Figure 6.8": "generated_charts/fig_6_8_test_pass_rate_evolution.png",  # CORRECTED
    "Figure 6.9": "generated_charts/architecture-comparison.png",  # CORRECTED
    "Figure 6.10": "generated_charts/user-workflow-diagrams.png",  # CORRECTED
    "Figure 6.11": "rendered_diagrams_drawio/load-test-system-architecture.png",  # CORRECTED
    "Figure 6.12": "rendered_diagrams_drawio/load-test-workflow.png",
    "Figure 6.13": "rendered_diagrams_drawio/load-testing-results.png",  # CORRECTED
    "Figure 6.14": "rendered_diagrams_drawio/load-test-gas-scaling.png",
    "Figure 6.15": "rendered_diagrams_drawio/load-test-shareholder-distribution.png",
    "Figure 6.16": "rendered_diagrams_drawio/load-test-success-rates.png",
    "Figure 6.17": "rendered_diagrams_drawio/load-test-latency-distribution.png",
    "Figure 6.18": "rendered_diagrams_drawio/load-test-metrics-summary.png",
    "Figure 6.19": "rendered_diagrams_drawio/load-test-cost-comparison.png",
    "Figure 6.20": "rendered_diagrams_drawio/load-test-erc1155-efficiency.png",
    "Figure 6.21": "rendered_diagrams_drawio/load-test-token-recycling.png",
    "Figure 6.22": "rendered_diagrams_drawio/load-test-restriction-enforcement.png",
    "Figure 6.23": "rendered_diagrams_drawio/load-test-restriction-overhead.png",
    "Figure 6.24": "rendered_diagrams_drawio/load-test-rq-validation.png",  # CORRECTED
    
    # Section 7 - Evaluation (8 figures)
    "Figure 7.1": "survey_interview_charts/fig_demographic_overview.png",  # CORRECTED
    "Figure 7.2": "survey_interview_charts/fig_tokenisation_interest_analysis.png",  # CORRECTED
    "Figure 7.3": "survey_interview_charts/fig_correlation_matrix.png",  # CORRECTED
    "Figure 7.4": "survey_interview_charts/fig_interview_demographics.png",  # CORRECTED
    "Figure 7.5": "survey_interview_charts/fig_thematic_code_frequencies.png",  # CORRECTED
    "Figure 7.6": "generated_charts/token-decision-framework.png",  # CORRECTED
    "Figure 7.7": "generated_charts/fig_7_7_volatile_recovery_comparison.png",  # CORRECTED
    "Figure 7.8": "generated_charts/fig_7_8_testnet_local_comparison.png",  # CORRECTED
}

# Appendix D - Additional wireframes
APPENDIX_D = {
    "Figure D.1": "rendered_diagrams_drawio/wireframe-analytics-dashboard.png",
    "Figure D.2": "rendered_diagrams_drawio/wireframe-governance.png",
    "Figure D.3": "rendered_diagrams_drawio/wireframe-governance-proposal-detail.png",
    "Figure D.4": "rendered_diagrams_drawio/wireframe-kyc.png",
    "Figure D.5": "rendered_diagrams_drawio/wireframe-kyc-admin.png",
    "Figure D.6": "rendered_diagrams_drawio/wireframe-marketplace.png",
    "Figure D.7": "rendered_diagrams_drawio/wireframe-portfolio.png",
    "Figure D.8": "rendered_diagrams_drawio/wireframe-properties-list.png",
    "Figure D.9": "rendered_diagrams_drawio/wireframe-yield-agreement-detail.png",
    "Figure D.10": "rendered_diagrams_drawio/wireframe-yield-agreements-list.png",
    "Figure D.11": "rendered_diagrams_drawio/wireframe-mobile-analytics.png",
    "Figure D.12": "rendered_diagrams_drawio/wireframe-mobile-governance.png",
    "Figure D.13": "rendered_diagrams_drawio/wireframe-mobile-kyc.png",
    "Figure D.14": "rendered_diagrams_drawio/wireframe-mobile-kyc-admin.png",
    "Figure D.15": "rendered_diagrams_drawio/wireframe-mobile-marketplace.png",
    "Figure D.16": "rendered_diagrams_drawio/wireframe-mobile-portfolio.png",
    "Figure D.17": "rendered_diagrams_drawio/wireframe-mobile-properties-list.png",
    "Figure D.18": "rendered_diagrams_drawio/wireframe-mobile-register-property.png",
    "Figure D.19": "rendered_diagrams_drawio/wireframe-mobile-yield-agreements-list.png",
}

# Appendix E - Additional survey/interview charts
APPENDIX_E = {
    "Figure E.1": "survey_interview_charts/fig_cluster_analysis.png",
    "Figure E.2": "survey_interview_charts/fig_feature_importance.png",
    "Figure E.3": "survey_interview_charts/fig_motivations_concerns.png",
    "Figure E.4": "survey_interview_charts/fig_landlord_fintech_comparison.png",
    "Figure E.5": "survey_interview_charts/fig_likert_distributions.png",
}

ALL_FIGURES = {**FIGURE_MAPPING, **APPENDIX_D, **APPENDIX_E}

def verify_all_images():
    """Verify all images exist"""
    print("=" * 80)
    print("VERIFYING ALL IMAGE FILES")
    print("=" * 80)
    
    missing = []
    found = []
    
    for fig_num, img_path in ALL_FIGURES.items():
        if os.path.exists(img_path):
            found.append((fig_num, img_path))
        else:
            missing.append((fig_num, img_path))
            print(f"  MISSING: {fig_num} -> {img_path}")
    
    print(f"\nFound: {len(found)} / {len(ALL_FIGURES)}")
    print(f"Missing: {len(missing)}")
    
    return missing, found

def check_for_yield_files():
    """Check for yield-related files that might be named differently"""
    print("\n=== Checking for yield-related files ===")
    import glob
    
    patterns = [
        "rendered_diagrams_drawio/*yield*",
        "rendered_diagrams_drawio/*token*",
        "Shared_Environment/docs/architecture/diagrams/Draw.io/*yield*",
        "Shared_Environment/docs/architecture/diagrams/Draw.io/*token*"
    ]
    
    for pattern in patterns:
        files = glob.glob(pattern)
        if files:
            print(f"Pattern {pattern}:")
            for f in files:
                print(f"  {f}")

if __name__ == "__main__":
    missing, found = verify_all_images()
    check_for_yield_files()
