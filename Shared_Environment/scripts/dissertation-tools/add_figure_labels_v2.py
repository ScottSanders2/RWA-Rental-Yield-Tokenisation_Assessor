#!/usr/bin/env python3
"""
Add Figure Labels from v2.3 to v2.6 - Version 2

This script extracts figure labels from v2.3.md and adds them to v2.6.md
by matching the italic description text that follows each figure label.

Strategy:
1. Extract all (figure_label, description_first_line) pairs from v2.3
2. For each description in v2.6 that starts with *, check if it matches
3. Insert the figure label BEFORE the description (after the image)
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
    Returns a list of (figure_label, description_key) tuples.
    """
    with open(V23_MD, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    figure_data = []
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Check if this line is a figure label
        if line.startswith('**Figure ') and ':' in line:
            figure_label = line
            
            # Look for the italic description that follows (skip blank lines)
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            
            if j < len(lines):
                desc_line = lines[j].strip()
                if desc_line.startswith('*'):
                    # Get first 80 chars of description as key (without leading *)
                    desc_key = desc_line[1:81].strip()
                    figure_data.append((figure_label, desc_key))
                    print(f"  {figure_label[:60]}...")
                    print(f"    -> {desc_key[:50]}...")
        
        i += 1
    
    return figure_data

def add_labels_to_v26(figure_data):
    """
    Add figure labels to v2.6 by matching description text.
    """
    with open(V26_MD, 'r', encoding='utf-8') as f:
        content = f.read()
    
    labels_added = 0
    labels_not_found = []
    
    for figure_label, desc_key in figure_data:
        # Search for the description in v2.6
        # The description should start with * and contain desc_key
        
        # Try to find "*{desc_key}" pattern
        search_pattern = f"*{desc_key[:40]}"
        
        if search_pattern in content:
            # Find the position and insert figure label before it
            pos = content.find(search_pattern)
            
            # Check if figure label already exists (avoid duplicates)
            check_region = content[max(0, pos-200):pos]
            if figure_label in check_region:
                print(f"  SKIP (already exists): {figure_label[:50]}...")
                continue
            
            # Insert figure label with newlines
            insert_text = f"\n{figure_label}\n\n"
            content = content[:pos] + insert_text + content[pos:]
            labels_added += 1
            print(f"  ADDED: {figure_label[:50]}...")
        else:
            # Try a shorter match
            short_key = desc_key[:25]
            search_pattern = f"*{short_key}"
            
            if search_pattern in content:
                pos = content.find(search_pattern)
                check_region = content[max(0, pos-200):pos]
                if figure_label in check_region:
                    print(f"  SKIP (already exists): {figure_label[:50]}...")
                    continue
                
                insert_text = f"\n{figure_label}\n\n"
                content = content[:pos] + insert_text + content[pos:]
                labels_added += 1
                print(f"  ADDED (short match): {figure_label[:50]}...")
            else:
                labels_not_found.append((figure_label, desc_key))
                print(f"  NOT FOUND: {figure_label[:50]}...")
    
    # Write output
    with open(OUTPUT_MD, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return labels_added, labels_not_found

def main():
    print("=" * 70)
    print("STEP 1: Extracting figure labels from v2.3")
    print("=" * 70)
    
    figure_data = extract_figure_labels_from_v23()
    print(f"\nExtracted {len(figure_data)} figure labels with descriptions")
    
    print("\n" + "=" * 70)
    print("STEP 2: Adding figure labels to v2.6 -> v2.7")
    print("=" * 70)
    
    added, not_found = add_labels_to_v26(figure_data)
    
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Figure labels extracted from v2.3: {len(figure_data)}")
    print(f"Figure labels added to v2.7: {added}")
    print(f"Figure labels not found: {len(not_found)}")
    print(f"Output file: {OUTPUT_MD}")
    
    if not_found:
        print(f"\n--- Labels not found ({len(not_found)}) ---")
        for label, desc in not_found:
            print(f"  {label[:60]}...")
            print(f"    Desc: {desc[:40]}...")

if __name__ == "__main__":
    main()


