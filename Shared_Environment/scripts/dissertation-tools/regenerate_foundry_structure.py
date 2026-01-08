#!/usr/bin/env python3
"""
Regenerate foundry-project-structure.png with a cleaner, more professional layout
"""

import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle

fig, ax = plt.subplots(1, 1, figsize=(11, 9))
fig.patch.set_facecolor('#FFFFFF')
ax.set_facecolor('#FFFFFF')

ax.set_xlim(0, 11)
ax.set_ylim(0, 10)
ax.axis('off')

# Title
ax.text(5.5, 9.6, 'Foundry Smart Contract Project Structure', fontsize=16, fontweight='bold', 
        ha='center', color='#1a1a1a')

# Colors
folder_bg = '#FFF8E1'      # Light amber for folders
file_bg = '#E3F2FD'        # Light blue for files
border_folder = '#FF8F00'  # Amber border
border_file = '#1976D2'    # Blue border

def draw_item(x, y, width, is_folder, name, description, indent=0):
    """Draw a file or folder item"""
    actual_x = x + (indent * 0.3)
    actual_width = width - (indent * 0.3)
    
    if is_folder:
        box = FancyBboxPatch((actual_x, y), actual_width, 0.4, boxstyle="round,pad=0.01",
                              facecolor=folder_bg, edgecolor=border_folder, linewidth=1.5)
        prefix = "[DIR]"
        name_color = '#E65100'
    else:
        box = FancyBboxPatch((actual_x, y), actual_width, 0.4, boxstyle="round,pad=0.01",
                              facecolor=file_bg, edgecolor=border_file, linewidth=1)
        prefix = ""
        name_color = '#1565C0'
    
    ax.add_patch(box)
    ax.text(actual_x + 0.15, y + 0.2, f"{prefix} {name}" if prefix else name, 
            fontsize=9, fontweight='bold' if is_folder else 'normal',
            color=name_color, va='center', fontfamily='monospace')
    ax.text(actual_x + actual_width - 0.1, y + 0.2, description, 
            fontsize=8, color='#666666', va='center', ha='right', style='italic')

# Root
draw_item(0.5, 9.0, 10, True, "contracts/", "Smart contract root directory")

# foundry.toml
draw_item(0.5, 8.5, 10, False, "foundry.toml", "Solidity 0.8.24, optimizer @ 200 runs", indent=1)

# src/
draw_item(0.5, 8.0, 10, True, "src/", "Source contracts", indent=1)

# src/diamond/
draw_item(0.5, 7.5, 5, True, "diamond/", "Diamond proxy core", indent=2)
draw_item(0.5, 7.05, 5, False, "Diamond.sol", "Main proxy contract", indent=3)
draw_item(0.5, 6.6, 5, False, "DiamondCutFacet.sol", "Upgrade functionality", indent=3)
draw_item(0.5, 6.15, 5, False, "DiamondLoupeFacet.sol", "Introspection", indent=3)
draw_item(0.5, 5.7, 5, False, "OwnershipFacet.sol", "Access control", indent=3)

# src/facets/
draw_item(5.5, 7.5, 5, True, "facets/", "Business logic facets", indent=0)
draw_item(5.5, 7.05, 5, False, "PropertyNFTFacet.sol", "ERC-721 property tokens", indent=1)
draw_item(5.5, 6.6, 5, False, "YieldBaseFacet.sol", "Core yield management", indent=1)
draw_item(5.5, 6.15, 5, False, "YieldAgreementFacet.sol", "Agreement lifecycle", indent=1)
draw_item(5.5, 5.7, 5, False, "YieldTokenFacet.sol", "ERC-1155 yield shares", indent=1)
draw_item(5.5, 5.25, 5, False, "GovernanceFacet.sol", "Democratic voting", indent=1)
draw_item(5.5, 4.8, 5, False, "KYCFacet.sol", "Compliance registry", indent=1)

# src/libraries/
draw_item(0.5, 5.0, 5, True, "libraries/", "Shared libraries", indent=2)
draw_item(0.5, 4.55, 5, False, "LibDiamond.sol", "Diamond storage", indent=3)
draw_item(0.5, 4.1, 5, False, "YieldCalculations.sol", "Interest math", indent=3)
draw_item(0.5, 3.65, 5, False, "YieldStorage.sol", "ERC-7201 storage", indent=3)

# test/
draw_item(0.5, 3.0, 5, True, "test/", "Foundry test suites", indent=1)
draw_item(0.5, 2.55, 5, False, "PropertyNFT.t.sol", "NFT tests (15 tests)", indent=2)
draw_item(0.5, 2.1, 5, False, "YieldAgreement.t.sol", "Agreement tests (28)", indent=2)
draw_item(0.5, 1.65, 5, False, "Integration.t.sol", "E2E tests (12)", indent=2)
draw_item(0.5, 1.2, 5, False, "GasOptimization.t.sol", "Gas benchmarks", indent=2)

# script/
draw_item(5.5, 4.1, 5, True, "script/", "Deployment scripts", indent=0)
draw_item(5.5, 3.65, 5, False, "Deploy.s.sol", "Main deployment", indent=1)
draw_item(5.5, 3.2, 5, False, "DiamondDeploy.s.sol", "Diamond setup", indent=1)
draw_item(5.5, 2.75, 5, False, "UpgradeFacet.s.sol", "Facet upgrades", indent=1)

# Summary box
summary_box = FancyBboxPatch((5.5, 1.0), 5, 1.5, boxstyle="round,pad=0.02",
                              facecolor='#E8F5E9', edgecolor='#4CAF50', linewidth=2)
ax.add_patch(summary_box)
ax.text(8, 2.25, 'Project Summary', fontsize=11, fontweight='bold', color='#2E7D32', ha='center')
ax.text(5.7, 1.85, '* 15 Diamond facet contracts', fontsize=9, color='#424242')
ax.text(5.7, 1.5, '* 23 total deployable contracts', fontsize=9, color='#424242')
ax.text(5.7, 1.15, '* ERC-7201 namespaced storage pattern', fontsize=9, color='#424242')

plt.tight_layout()
plt.savefig('generated_screenshots/foundry-project-structure-new.png', dpi=150, 
            facecolor='white', edgecolor='none', bbox_inches='tight')
plt.close()

print("Generated: generated_screenshots/foundry-project-structure-new.png")
