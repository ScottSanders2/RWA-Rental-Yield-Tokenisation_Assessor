#!/usr/bin/env python3
"""
Add the remaining missing figure labels to v2.7.md

Based on analysis:
- image6 at line 3351 (Smart Contract) -> Figure 4.7: Yield Tokenisation Architecture (duplicate image)
- image9 at line 3357 (Smart Contract) -> Figure 4.11: Default Handling Workflow
- image6 at line 3546 (Backend API) -> Already has label nearby
- image38 at line 4332 -> Figure 5.7: ERC-7201 Storage Layout
- image43 at line 5407 -> Figure 5.12: Diamond Deployment to Amoy
- image73 -> Figure 7.1: Survey Respondent Demographics Overview
- image53/54 -> Figure 6.6: Load Testing Throughput vs Shareholder Count
- image55 -> Figure 6.7: Gas Cost Projections for Mainnet Scenarios
"""

import re
from pathlib import Path

WORKSPACE = Path("/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1")
INPUT_MD = WORKSPACE / "DissertationProgressFinal_v2.7.md"
OUTPUT_MD = WORKSPACE / "DissertationProgressFinal_v2.7.md"  # Overwrite

# Manual fixes needed based on analysis
# Format: (line_number, image_pattern, figure_label)
# Line numbers are approximate - we'll search for the image pattern

MANUAL_FIXES = [
    # Section 4 missing
    ("image9.png", "Smart Contract Architecture", "**Figure 4.11: Default Handling Workflow**"),
    
    # Section 5 missing
    ("image38.png", "Smart Contract Foundation", "**Figure 5.7: ERC-7201 Storage Layout**"),
    ("image43.png", "Polygon Amoy Testnet", "**Figure 5.12: Diamond Deployment to Amoy**"),
    
    # Section 6 missing - these are in Comparative Architecture Analysis section
    ("image54.png", "Comparative Architecture", "**Figure 6.6: Load Testing Throughput vs Shareholder Count (Scatter Plot)**"),
    ("image55.png", "Comparative Architecture", "**Figure 6.7: Gas Cost Projections for Mainnet Scenarios (Multi-Series Line Chart)**"),
    
    # Section 7 missing
    ("image73.png", "Hypothesis Testing", "**Figure 7.1: Survey Respondent Demographics Overview (4-Panel Composite)**"),
]

def add_missing_labels():
    with open(INPUT_MD, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    # Track current section
    current_section = ""
    labels_added = 0
    
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Track section headers
        if line.startswith("##"):
            current_section = line.strip()
        
        new_lines.append(line)
        
        # Check if this line has an image that needs a label
        for img_pattern, section_hint, figure_label in MANUAL_FIXES:
            if img_pattern in line and section_hint in current_section:
                # Check if label already exists in next few lines
                label_exists = False
                for j in range(i+1, min(i+6, len(lines))):
                    if figure_label in lines[j] or "**Figure" in lines[j]:
                        label_exists = True
                        break
                
                if not label_exists:
                    new_lines.append("\n")
                    new_lines.append(figure_label + "\n")
                    labels_added += 1
                    print(f"  ADDED: {img_pattern} -> {figure_label[:50]}...")
        
        i += 1
    
    with open(OUTPUT_MD, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    
    return labels_added

def verify_counts():
    with open(OUTPUT_MD, "r") as f:
        content = f.read()
    
    counts = {
        "4.x": len(re.findall(r'\*\*Figure 4\.\d+:', content)),
        "5.x": len(re.findall(r'\*\*Figure 5\.\d+:', content)),
        "6.x": len(re.findall(r'\*\*Figure 6\.\d+:', content)),
        "7.x": len(re.findall(r'\*\*Figure 7\.\d+:', content)),
        "S.x": len(re.findall(r'\*\*Figure S\.\d+:', content)),
        "I.x": len(re.findall(r'\*\*Figure I\.\d+:', content)),
        "F.x": len(re.findall(r'\*\*Figure F\.\d+:', content)),
        "G.x": len(re.findall(r'\*\*Figure G\.\d+:', content)),
    }
    
    total = sum(counts.values())
    
    print("\n=== FINAL VERIFICATION ===")
    for key, count in counts.items():
        print(f"  Figure {key}: {count}")
    print(f"  TOTAL: {total}")
    
    return total

def main():
    print("=" * 70)
    print("ADDING REMAINING MISSING FIGURE LABELS")
    print("=" * 70)
    
    added = add_missing_labels()
    print(f"\nLabels added: {added}")
    
    total = verify_counts()
    
    if total >= 80:
        print("\n✅ SUCCESS!")
    else:
        print(f"\n⚠️ Still missing some labels")

if __name__ == "__main__":
    main()


