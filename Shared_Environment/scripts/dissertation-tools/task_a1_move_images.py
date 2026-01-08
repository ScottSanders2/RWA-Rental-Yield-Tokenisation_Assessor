#!/usr/bin/env python3
"""
TASK A1: Move images 1-3 from Section 4.3 to Section 4.5
"""

import re

def read_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(filepath, content):
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    input_file = '/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1/DissertationProgressFinal_v2.7.md'
    output_file = '/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1/DissertationProgressFinal_v2.8.md'
    
    content = read_file(input_file)
    lines = content.split('\n')
    
    print(f"Original file has {len(lines)} lines")
    
    # ============================================================
    # STEP 1: Define image blocks to move
    # ============================================================
    
    image1_block = """
![](media/image1.png){width="6.0in" height="6.210060148731409in"}

**Figure 4.1: Multi-Environment Docker Architecture (Logical View)**

*This diagram illustrates the complete platform architecture from the
GitHub repository through to the three segregated Docker environments.
The top section shows the repository structure with Shared_Environment
providing common assets to all environments, whilst the lower sections
detail the Development, Test, and Production environments with their
respective services, monitoring stacks, and subgraph infrastructure. The
"Promotes to" arrows indicate the code promotion pathway from
Development through Test to Production.*
"""

    image2_block = """
![](media/image2.png){width="6.0in" height="6.836861329833771in"}

**Figure 4.2: Multi-Environment Docker Architecture (Physical View)**

*The physical architecture diagram details the actual resource
allocations and network topology across environments. Each environment
operates on isolated Docker networks preventing cross-contamination
whilst maintaining service discoverability through Docker's internal DNS
resolution.*
"""

    image3_block = """
![](media/image3.png){width="6.0in" height="2.626288276465442in"}

**Figure 4.4: Monitoring Architecture Diagram**
"""

    # ============================================================
    # STEP 2: Remove image blocks from Section 4.3
    # ============================================================
    
    # Remove image1 block
    content = re.sub(
        r'\n!\[\]\(media/image1\.png\)\{width="6\.0in" height="6\.210060148731409in"\}\n\n\*\*Figure 4\.1: Multi-Environment Docker Architecture \(Logical View\)\*\*\n\n\*This diagram illustrates the complete platform architecture from the\nGitHub repository through to the three segregated Docker environments\.\nThe top section shows the repository structure with Shared_Environment\nproviding common assets to all environments, whilst the lower sections\ndetail the Development, Test, and Production environments with their\nrespective services, monitoring stacks, and subgraph infrastructure\. The\n"Promotes to" arrows indicate the code promotion pathway from\nDevelopment through Test to Production\.\*\n',
        '\n',
        content,
        count=1
    )
    
    # Remove image2 block
    content = re.sub(
        r'\n!\[\]\(media/image2\.png\)\{width="6\.0in" height="6\.836861329833771in"\}\n\n\*\*Figure 4\.2: Multi-Environment Docker Architecture \(Physical View\)\*\*\n\n\*The physical architecture diagram details the actual resource\nallocations and network topology across environments\. Each environment\noperates on isolated Docker networks preventing cross-contamination\nwhilst maintaining service discoverability through Docker\'s internal DNS\nresolution\.\*\n',
        '\n',
        content,
        count=1
    )
    
    # Remove image3 block
    content = re.sub(
        r'\n!\[\]\(media/image3\.png\)\{width="6\.0in" height="2\.626288276465442in"\}\n\n\*\*Figure 4\.4: Monitoring Architecture Diagram\*\*\n',
        '\n',
        content,
        count=1
    )
    
    # ============================================================
    # STEP 3: Add images to Section 4.5 subsections
    # ============================================================
    
    # Add image1 to end of 4.5.1 Logical Architecture section
    # Insert before "### Physical Architecture (Docker Container Resources)"
    content = content.replace(
        '### Physical Architecture (Docker Container Resources)\n\nThe physical architecture diagram documents',
        image1_block.strip() + '\n\n### Physical Architecture (Docker Container Resources)\n\nThe physical architecture diagram documents'
    )
    
    # Add image2 to end of 4.5.2 Physical Architecture section
    # Insert before "### GitHub Repository Architecture"
    content = content.replace(
        '### GitHub Repository Architecture\n\nBuilding on the repository overview',
        image2_block.strip() + '\n\n### GitHub Repository Architecture\n\nBuilding on the repository overview'
    )
    
    # Add image3 to end of 4.5.16 Monitoring Architecture section
    # Insert before "### Advanced Yield Management Flowcharts"
    content = content.replace(
        '### Advanced Yield Management Flowcharts\n\nFour detailed flowcharts',
        image3_block.strip() + '\n\n### Advanced Yield Management Flowcharts\n\nFour detailed flowcharts'
    )
    
    # Write output
    write_file(output_file, content)
    
    # Verify
    new_lines = content.split('\n')
    print(f"New file has {len(new_lines)} lines")
    print(f"Line count change: {len(new_lines) - len(lines)}")
    
    # Check if images are in new locations
    print("\n=== VERIFICATION ===")
    
    # Check image1
    if 'Figure 4.1' in content:
        idx = content.find('Figure 4.1')
        # Find nearest section header before this
        before = content[:idx]
        if '### Logical Architecture' in before and '### Physical Architecture' not in before.split('### Logical Architecture')[-1]:
            print("  ✓ Image1 (Figure 4.1) found in Section 4.5.1 Logical Architecture")
        else:
            print("  ? Image1 location unclear")
    else:
        print("  ✗ Figure 4.1 not found")
    
    # Check image2
    if 'Figure 4.2' in content:
        idx = content.find('Figure 4.2')
        before = content[:idx]
        if '### Physical Architecture' in before and '### GitHub Repository' not in before.split('### Physical Architecture')[-1]:
            print("  ✓ Image2 (Figure 4.2) found in Section 4.5.2 Physical Architecture")
        else:
            print("  ? Image2 location unclear")
    else:
        print("  ✗ Figure 4.2 not found")
    
    # Check image3
    if 'Figure 4.4' in content:
        idx = content.find('Figure 4.4')
        before = content[:idx]
        if '### Monitoring Architecture' in before and '### Advanced Yield' not in before.split('### Monitoring Architecture')[-1]:
            print("  ✓ Image3 (Figure 4.4) found in Section 4.5.16 Monitoring Architecture")
        else:
            print("  ? Image3 location unclear")
    else:
        print("  ✗ Figure 4.4 not found")
    
    # Count images in Section 4.3 vs 4.5
    print("\n=== IMAGE COUNT CHECK ===")
    section_43_end = content.find('## User Interface Design')
    section_45_start = content.find('## System Architecture')
    
    if section_43_end > 0 and section_45_start > 0:
        section_43 = content[:section_43_end]
        section_45 = content[section_45_start:]
        
        img1_in_43 = 'image1.png' in section_43
        img2_in_43 = 'image2.png' in section_43
        img3_in_43 = 'image3.png' in section_43
        
        img1_in_45 = 'image1.png' in section_45
        img2_in_45 = 'image2.png' in section_45
        img3_in_45 = 'image3.png' in section_45
        
        print(f"  image1.png in Section 4.3: {img1_in_43}, in Section 4.5: {img1_in_45}")
        print(f"  image2.png in Section 4.3: {img2_in_43}, in Section 4.5: {img2_in_45}")
        print(f"  image3.png in Section 4.3: {img3_in_43}, in Section 4.5: {img3_in_45}")
    
    print(f"\nOutput written to: {output_file}")

if __name__ == '__main__':
    main()
