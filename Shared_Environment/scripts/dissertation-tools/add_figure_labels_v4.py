#!/usr/bin/env python3
"""
Add Figure Labels from v2.3 to v2.6 - Version 4 (FINAL)

This script uses image file size matching to create a reliable mapping
between v2.3 and v2.6 image numbers, then adds the correct figure labels.

Strategy:
1. Load the v2.3 figure labels with their image numbers
2. Load the image number mapping (v2.3 -> v2.6)
3. For each image in v2.6, find the corresponding v2.3 image and its figure label
4. Insert the figure label after the image
"""

import re
import json
from pathlib import Path

WORKSPACE = Path("/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1")
V26_MD = WORKSPACE / "DissertationProgressFinal_v2.6.md"
OUTPUT_MD = WORKSPACE / "DissertationProgressFinal_v2.7.md"

def load_mappings():
    """Load all mapping files."""
    # Load v2.3 figure labels
    with open(WORKSPACE / "v23_figure_image_mapping.json", "r") as f:
        v23_figures = json.load(f)
    
    # Load image number mapping
    with open(WORKSPACE / "image_number_mapping.json", "r") as f:
        img_mapping = json.load(f)
    
    return v23_figures, img_mapping

def create_v26_to_figure_map(v23_figures, img_mapping):
    """
    Create a mapping from v2.6 image numbers to figure labels.
    """
    v26_to_v23 = {int(k): v for k, v in img_mapping["v26_to_v23"].items()}
    
    # Create v2.3 image number to figure label mapping
    v23_img_to_label = {}
    for item in v23_figures:
        img_num = item["v23_img_num"]
        label = item["figure_label"]
        # Some images have multiple labels (duplicates in v2.3)
        # Keep the first one
        if img_num not in v23_img_to_label:
            v23_img_to_label[img_num] = label
    
    # Create v2.6 image number to figure label mapping
    v26_to_label = {}
    for v26_num, v23_num in v26_to_v23.items():
        if v23_num in v23_img_to_label:
            v26_to_label[v26_num] = v23_img_to_label[v23_num]
    
    return v26_to_label

def add_labels_to_v26(v26_to_label):
    """
    Add figure labels to v2.6 markdown file.
    """
    with open(V26_MD, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    new_lines = []
    labels_added = 0
    labels_skipped = 0
    images_without_labels = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        new_lines.append(line)
        
        # Check if this line contains an image
        if "![](media/image" in line:
            img_match = re.search(r'image(\d+)\.png', line)
            if img_match:
                img_num = int(img_match.group(1))
                
                # Check if we have a figure label for this image
                if img_num in v26_to_label:
                    label = v26_to_label[img_num]
                    
                    # Check if the label already exists nearby (within next 5 lines)
                    label_exists = False
                    for j in range(i+1, min(i+6, len(lines))):
                        if label in lines[j]:
                            label_exists = True
                            break
                    
                    if not label_exists:
                        # Insert the figure label after the image
                        new_lines.append("\n")
                        new_lines.append(label + "\n")
                        labels_added += 1
                        print(f"  ADDED: image{img_num} -> {label[:55]}...")
                    else:
                        labels_skipped += 1
                else:
                    images_without_labels.append(img_num)
        
        i += 1
    
    # Write output
    with open(OUTPUT_MD, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    
    return labels_added, labels_skipped, images_without_labels

def main():
    print("=" * 70)
    print("ADD FIGURE LABELS - VERSION 4 (FINAL)")
    print("=" * 70)
    
    print("\nStep 1: Loading mappings...")
    v23_figures, img_mapping = load_mappings()
    print(f"  - v2.3 figure labels: {len(v23_figures)}")
    print(f"  - Image mappings: {len(img_mapping['v26_to_v23'])}")
    
    print("\nStep 2: Creating v2.6 image to figure label mapping...")
    v26_to_label = create_v26_to_figure_map(v23_figures, img_mapping)
    print(f"  - v2.6 images with labels: {len(v26_to_label)}")
    
    print("\nStep 3: Adding labels to v2.6...")
    added, skipped, no_label = add_labels_to_v26(v26_to_label)
    
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Labels added: {added}")
    print(f"Labels skipped (already exist): {skipped}")
    print(f"Images without labels: {len(no_label)}")
    if no_label:
        print(f"  Image numbers: {sorted(no_label)}")
    print(f"\nOutput: {OUTPUT_MD}")
    
    # Verify final count
    print("\nStep 4: Verification...")
    with open(OUTPUT_MD, "r") as f:
        content = f.read()
    
    figure_count = len(re.findall(r'\*\*Figure [0-9]+\.[0-9]+:', content))
    survey_count = len(re.findall(r'\*\*Figure S\.[0-9]+:', content))
    interview_count = len(re.findall(r'\*\*Figure I\.[0-9]+:', content))
    appendix_f_count = len(re.findall(r'\*\*Figure F\.[0-9]+:', content))
    appendix_g_count = len(re.findall(r'\*\*Figure G\.[0-9]+:', content))
    
    total = figure_count + survey_count + interview_count + appendix_f_count + appendix_g_count
    
    print(f"  Section figures (4.x, 5.x, 6.x, 7.x): {figure_count}")
    print(f"  Survey figures (S.x): {survey_count}")
    print(f"  Interview figures (I.x): {interview_count}")
    print(f"  Appendix F figures (F.x): {appendix_f_count}")
    print(f"  Appendix G figures (G.x): {appendix_g_count}")
    print(f"  TOTAL: {total}")
    
    if total >= 80:
        print("\n✅ SUCCESS: Most figure labels have been added!")
    else:
        print(f"\n⚠️ WARNING: Only {total} labels found, expected ~82")

if __name__ == "__main__":
    main()


