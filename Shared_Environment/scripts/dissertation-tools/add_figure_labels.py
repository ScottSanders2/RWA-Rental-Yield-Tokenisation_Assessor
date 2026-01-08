#!/usr/bin/env python3
"""
Add Figure Labels from v2.3 to v2.6

This script extracts figure labels from v2.3.md and adds them to v2.6.md
by matching the italic description text that follows each image.

Strategy:
1. Extract all (image, figure_label, description) tuples from v2.3
2. For each image in v2.6, find the matching description
3. Insert the figure label between the image and description
"""

import re
from pathlib import Path

WORKSPACE = Path("/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1")
V23_MD = WORKSPACE / "DissertationProgressFinal_v2.3.md"
V26_MD = WORKSPACE / "DissertationProgressFinal_v2.6.md"
OUTPUT_MD = WORKSPACE / "DissertationProgressFinal_v2.7.md"

def extract_figure_labels_from_v23():
    """
    Extract all figure labels and their associated descriptions from v2.3.
    Returns a dict mapping description_start -> figure_label
    """
    with open(V23_MD, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match: image, figure label, italic description
    # The figure label is on a line starting with **Figure
    # The description starts with * (italic)
    
    figure_labels = {}
    lines = content.split('\n')
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Check if this line is a figure label
        if line.startswith('**Figure ') and ':**' in line:
            figure_label = line.strip()
            
            # Look for the italic description that follows
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            
            if j < len(lines) and lines[j].strip().startswith('*'):
                # Get the first ~50 chars of the description as a key
                desc_line = lines[j].strip()
                # Remove the leading * and get first 50 chars
                desc_key = desc_line[1:60].strip() if len(desc_line) > 1 else ""
                
                if desc_key:
                    figure_labels[desc_key] = figure_label
                    print(f"Found: {figure_label[:50]}...")
                    print(f"  Key: {desc_key[:40]}...")
        
        i += 1
    
    return figure_labels

def add_labels_to_v26(figure_labels):
    """
    Add figure labels to v2.6 by matching description text.
    """
    with open(V26_MD, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    labels_added = 0
    labels_matched = set()
    
    i = 0
    while i < len(lines):
        line = lines[i]
        new_lines.append(line)
        
        # Check if this line is an image
        if line.strip().startswith('![](media/image'):
            # Look for the italic description that follows (may be after blank lines)
            j = i + 1
            blank_lines = []
            
            while j < len(lines) and not lines[j].strip():
                blank_lines.append(lines[j])
                j += 1
            
            if j < len(lines) and lines[j].strip().startswith('*'):
                desc_line = lines[j].strip()
                desc_key = desc_line[1:60].strip() if len(desc_line) > 1 else ""
                
                # Try to find a matching figure label
                matched_label = None
                for key, label in figure_labels.items():
                    if key and desc_key and key[:30] in desc_key or desc_key[:30] in key:
                        matched_label = label
                        labels_matched.add(key)
                        break
                
                if matched_label:
                    # Add blank line, then figure label, then original blank lines
                    new_lines.append('\n')
                    new_lines.append(matched_label + '\n')
                    labels_added += 1
                    print(f"Added: {matched_label[:60]}...")
                else:
                    # Just add the blank lines
                    new_lines.extend(blank_lines)
            else:
                new_lines.extend(blank_lines)
        
        i += 1
    
    # Write output
    with open(OUTPUT_MD, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    return labels_added, len(figure_labels), labels_matched

def main():
    print("=" * 70)
    print("STEP 1: Extracting figure labels from v2.3")
    print("=" * 70)
    
    figure_labels = extract_figure_labels_from_v23()
    print(f"\nExtracted {len(figure_labels)} figure labels")
    
    print("\n" + "=" * 70)
    print("STEP 2: Adding figure labels to v2.6")
    print("=" * 70)
    
    added, total, matched = add_labels_to_v26(figure_labels)
    
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Figure labels in v2.3: {total}")
    print(f"Figure labels added to v2.7: {added}")
    print(f"Output file: {OUTPUT_MD}")
    
    # Show unmatched labels
    unmatched = set(figure_labels.keys()) - matched
    if unmatched:
        print(f"\nUnmatched labels ({len(unmatched)}):")
        for key in list(unmatched)[:10]:
            print(f"  - {figure_labels[key][:50]}...")

if __name__ == "__main__":
    main()


