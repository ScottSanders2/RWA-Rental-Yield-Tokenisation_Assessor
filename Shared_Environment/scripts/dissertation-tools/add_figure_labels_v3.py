#!/usr/bin/env python3
"""
Add Figure Labels from v2.3 to v2.6 - Version 3

This script extracts ALL figure labels from v2.3.md and adds them to v2.6.md.

Strategy:
1. Extract all figure labels and the NEXT non-empty line after them
2. Match by finding that next line in v2.6
3. Insert the figure label BEFORE that line
"""

import re
from pathlib import Path

WORKSPACE = Path("/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1")
V23_MD = WORKSPACE / "DissertationProgressFinal_v2.3.md"
V26_MD = WORKSPACE / "DissertationProgressFinal_v2.6.md"
OUTPUT_MD = WORKSPACE / "DissertationProgressFinal_v2.7.md"

def extract_all_figure_labels_from_v23():
    """
    Extract ALL figure labels and the line that follows them.
    """
    with open(V23_MD, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    figure_data = []
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Check if this line is a figure label (starts with **Figure and has :)
        if line.startswith('**Figure ') and ':' in line and line.endswith('**'):
            figure_label = line
            
            # Get the next non-empty line
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            
            if j < len(lines):
                next_line = lines[j].strip()
                # Get first 60 chars as key
                next_key = next_line[:60]
                figure_data.append((figure_label, next_key))
        
        i += 1
    
    return figure_data

def add_labels_to_v26(figure_data):
    """
    Add figure labels to v2.6 by matching the line that follows each label.
    """
    with open(V26_MD, 'r', encoding='utf-8') as f:
        content = f.read()
    
    labels_added = 0
    labels_not_found = []
    labels_already_exist = []
    
    for figure_label, next_key in figure_data:
        # Skip if figure label already in content
        if figure_label in content:
            labels_already_exist.append(figure_label)
            continue
        
        # Try to find the next_key in content
        # Use first 40 chars for more reliable matching
        search_key = next_key[:40]
        
        if search_key in content:
            pos = content.find(search_key)
            
            # Find the start of this line (go back to newline)
            line_start = content.rfind('\n', 0, pos)
            if line_start == -1:
                line_start = 0
            else:
                line_start += 1  # Skip the newline itself
            
            # Insert figure label before this line
            insert_text = f"{figure_label}\n\n"
            content = content[:line_start] + insert_text + content[line_start:]
            labels_added += 1
            print(f"  ADDED: {figure_label[:55]}...")
        else:
            # Try shorter key
            search_key = next_key[:25]
            if search_key in content:
                pos = content.find(search_key)
                line_start = content.rfind('\n', 0, pos)
                if line_start == -1:
                    line_start = 0
                else:
                    line_start += 1
                
                insert_text = f"{figure_label}\n\n"
                content = content[:line_start] + insert_text + content[line_start:]
                labels_added += 1
                print(f"  ADDED (short): {figure_label[:55]}...")
            else:
                labels_not_found.append((figure_label, next_key))
                print(f"  NOT FOUND: {figure_label[:55]}...")
                print(f"    Key: {next_key[:40]}...")
    
    # Write output
    with open(OUTPUT_MD, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return labels_added, labels_not_found, labels_already_exist

def main():
    print("=" * 70)
    print("STEP 1: Extracting ALL figure labels from v2.3")
    print("=" * 70)
    
    figure_data = extract_all_figure_labels_from_v23()
    print(f"\nExtracted {len(figure_data)} figure labels")
    
    # Show all extracted labels
    print("\n--- All extracted labels ---")
    for label, key in figure_data:
        print(f"  {label[:60]}...")
    
    print("\n" + "=" * 70)
    print("STEP 2: Adding figure labels to v2.6 -> v2.7")
    print("=" * 70)
    
    added, not_found, already_exist = add_labels_to_v26(figure_data)
    
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Figure labels extracted from v2.3: {len(figure_data)}")
    print(f"Figure labels added to v2.7: {added}")
    print(f"Figure labels already existed: {len(already_exist)}")
    print(f"Figure labels not found: {len(not_found)}")
    print(f"Output file: {OUTPUT_MD}")
    
    if not_found:
        print(f"\n--- Labels not found ({len(not_found)}) ---")
        for label, key in not_found:
            print(f"  {label}")
            print(f"    Key: {key[:50]}...")
    
    if already_exist:
        print(f"\n--- Labels already existed ({len(already_exist)}) ---")
        for label in already_exist[:5]:
            print(f"  {label[:60]}...")
        if len(already_exist) > 5:
            print(f"  ... and {len(already_exist) - 5} more")

if __name__ == "__main__":
    main()


