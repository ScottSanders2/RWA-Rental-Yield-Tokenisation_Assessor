#!/usr/bin/env python3
"""
Script to restructure DissertationProgressFinal_v2.5.md
Task 4.1/4.3: Move architecture sections from 4.3 to 4.5
"""

import re

def read_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_file(filepath, lines):
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)

def find_section_boundaries(lines, section_header):
    """Find the start and end of a section by its header"""
    start_idx = None
    end_idx = None
    
    for i, line in enumerate(lines):
        if section_header in line and line.startswith('### '):
            start_idx = i
            # Find the next ### or ## header
            for j in range(i + 1, len(lines)):
                if lines[j].startswith('### ') or lines[j].startswith('## '):
                    end_idx = j
                    break
            break
    
    return start_idx, end_idx

def main():
    filepath = '/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1/DissertationProgressFinal_v2.5.md'
    output_path = '/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1/DissertationProgressFinal_v2.6.md'
    
    lines = read_file(filepath)
    original_count = len(lines)
    print(f"Read {original_count} lines from {filepath}")
    
    # Define sections to extract with their headers
    sections_to_move = [
        'GitHub Repository Architecture',
        'Frontend Web Architecture', 
        'Mobile Frontend Architecture',
        'Backend API Architecture',
        'Smart Contract Architecture',
        'Diamond Pattern Architecture',
        'Secondary Market Architecture',
        'KYC and Compliance Architecture',
        'Data Model Architecture',
        'Token Architecture Comparison',
    ]
    
    # Step 1: Find all section boundaries FIRST (before any modifications)
    print("\n=== STEP 1: Finding section boundaries ===")
    section_data = {}
    for section_name in sections_to_move:
        header = f'### {section_name}'
        start, end = find_section_boundaries(lines, section_name)
        if start is not None and end is not None:
            section_data[section_name] = {
                'start': start,
                'end': end,
                'content': lines[start:end]
            }
            print(f"Found '{section_name}': lines {start}-{end} ({end - start} lines)")
        else:
            print(f"WARNING: Could not find '{section_name}'")
    
    # Step 2: Mark lines for removal (sections to be moved)
    lines_to_remove = set()
    for section_name, data in section_data.items():
        for i in range(data['start'], data['end']):
            lines_to_remove.add(i)
    
    print(f"\nMarked {len(lines_to_remove)} lines for removal")
    
    # Step 3: Find the insertion point in Section 4.5
    print("\n=== STEP 2: Finding insertion point ===")
    insert_idx = None
    for i, line in enumerate(lines):
        if '### Physical Architecture (Docker Container Resources)' in line:
            # Find the next ### header
            for j in range(i + 1, len(lines)):
                if lines[j].startswith('### '):
                    insert_idx = j
                    break
            break
    
    if insert_idx is None:
        print("ERROR: Could not find insertion point")
        return
    
    print(f"Insertion point: line {insert_idx}")
    
    # Step 4: Build the new content to insert
    print("\n=== STEP 3: Building new sections ===")
    
    # Add diagram descriptions where needed
    def add_diagram_desc(content, desc):
        content.append('\n')
        content.append(f'*{desc}*\n')
        content.append('\n')
        return content
    
    new_sections = []
    
    # 4.5.3 GitHub Repository Architecture
    if 'GitHub Repository Architecture' in section_data:
        content = section_data['GitHub Repository Architecture']['content'].copy()
        content = add_diagram_desc(content, 'The repository architecture diagram illustrates the monorepo structure with environment-specific directories, shared components, and Git submodule integration for smart contract versioning.')
        new_sections.extend(content)
    
    # 4.5.4 Smart Contract Architecture
    if 'Smart Contract Architecture' in section_data:
        new_sections.extend(section_data['Smart Contract Architecture']['content'])
    
    # 4.5.5 Diamond Pattern Architecture
    if 'Diamond Pattern Architecture' in section_data:
        new_sections.extend(section_data['Diamond Pattern Architecture']['content'])
    
    # 4.5.6 Token Architecture Comparison
    if 'Token Architecture Comparison' in section_data:
        new_sections.extend(section_data['Token Architecture Comparison']['content'])
    
    # 4.5.7 Backend API Architecture (with merged diagram description)
    if 'Backend API Architecture' in section_data:
        content = section_data['Backend API Architecture']['content'].copy()
        content = add_diagram_desc(content, 'The backend API architecture diagram illustrates the four-tier design: API layer comprising FastAPI routers, Service layer containing PropertyService, YieldService, and Web3Service, Repository layer implementing SQLAlchemy models, and Blockchain layer integrating Web3.py. The diagram shows data flow patterns, dependency injection relationships, and integration points between layers.')
        new_sections.extend(content)
    
    # 4.5.8 Data Model Architecture
    if 'Data Model Architecture' in section_data:
        new_sections.extend(section_data['Data Model Architecture']['content'])
    
    # 4.5.9 Frontend Web Architecture
    if 'Frontend Web Architecture' in section_data:
        content = section_data['Frontend Web Architecture']['content'].copy()
        content = add_diagram_desc(content, 'The frontend architecture diagram illustrates the component hierarchy, service layer integration, and state management patterns supporting the React-based web application.')
        new_sections.extend(content)
    
    # 4.5.10 Mobile Frontend Architecture
    if 'Mobile Frontend Architecture' in section_data:
        new_sections.extend(section_data['Mobile Frontend Architecture']['content'])
    
    # 4.5.11 KYC and Compliance Architecture
    if 'KYC and Compliance Architecture' in section_data:
        new_sections.extend(section_data['KYC and Compliance Architecture']['content'])
    
    # 4.5.12 Secondary Market Architecture
    if 'Secondary Market Architecture' in section_data:
        new_sections.extend(section_data['Secondary Market Architecture']['content'])
    
    print(f"Built {len(new_sections)} lines to insert")
    
    # Step 5: Create new document
    print("\n=== STEP 4: Creating new document ===")
    
    # Build new lines list
    new_lines = []
    inserted = False
    
    for i, line in enumerate(lines):
        # Skip lines marked for removal
        if i in lines_to_remove:
            continue
        
        # Insert new sections at the insertion point
        if i == insert_idx and not inserted:
            new_lines.extend(new_sections)
            inserted = True
        
        # Rename section 4.5 header
        if '## Architecture Diagrams {#architecture-diagrams' in line:
            new_lines.append('## System Architecture {#system-architecture .Heading-2---Dissertation}\n')
            continue
        
        # Update introduction paragraph
        if "The platform's technical architecture is documented through a" in line:
            new_lines.append("This section documents the platform's technical architecture through detailed descriptions and visual diagrams supporting dissertation analysis and replication. The architecture sections are organised by implementation phase, beginning with infrastructure overview, followed by core system components, and concluding with process flow documentation.\n")
            # Skip the rest of the old intro paragraph
            continue
        
        if 'comprehensive suite of visual diagrams supporting dissertation analysis' in line:
            continue
        if 'and replication. All diagrams are implemented in Mermaid format and' in line:
            continue
        if 'stored in the shared documentation directory, with instructions for' in line:
            continue
        if 'Draw.io recreation enabling dissertation figure preparation.' in line:
            continue
        
        # Rename sections in 4.3
        if '### Monitoring and Observability Infrastructure' in line:
            new_lines.append(line.replace('Infrastructure', 'Methodology'))
            continue
        if '### Analytics Infrastructure (The Graph Protocol)' in line:
            new_lines.append(line.replace('Infrastructure', 'Methodology'))
            continue
        if '### Git Submodule Management System' in line:
            new_lines.append(line.replace('System', 'Methodology'))
            continue
        
        # Remove duplicate Backend API diagram description from old 4.5
        if '### Backend API Architecture' in line and i > 3500:
            # Check if this is the diagram-only version
            if i + 2 < len(lines) and 'The backend API architecture diagram illustrates the four-tier design' in lines[i + 1]:
                # Skip this section entirely
                continue
        
        new_lines.append(line)
    
    print(f"New document: {len(new_lines)} lines")
    
    # Verify the count is reasonable
    expected_count = original_count  # Should be roughly the same (moved, not added)
    if abs(len(new_lines) - expected_count) > 500:
        print(f"WARNING: Line count changed significantly ({original_count} -> {len(new_lines)})")
    
    # Write output
    print(f"\n=== Writing output to {output_path} ===")
    write_file(output_path, new_lines)
    print(f"Done! Output written to {output_path}")

if __name__ == '__main__':
    main()
