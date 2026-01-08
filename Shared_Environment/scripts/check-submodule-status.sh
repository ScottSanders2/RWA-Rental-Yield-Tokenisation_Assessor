#!/bin/bash
#
# check-submodule-status.sh
# 
# PURPOSE: Check all contract submodules for uncommitted changes
# USAGE: Run regularly during development to catch uncommitted work
# LOCATION: Shared_Environment/scripts/check-submodule-status.sh
#
# This script prevents the issue where submodule changes are made but never
# committed, which can lead to data loss and environment inconsistencies.
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}=== Checking Contract Submodules for Uncommitted Changes ===${NC}"
echo ""

# Submodule directories
SUBMODULES=(
    "Development_Environment/contracts"
    "Test_Environment/contracts"
    "Production_Environment/contracts"
)

UNCOMMITTED_FOUND=0
WARNINGS=0

for submodule in "${SUBMODULES[@]}"; do
    submodule_path="$PROJECT_ROOT/$submodule"
    
    echo -e "${BLUE}Checking: ${submodule}${NC}"
    
    if [ ! -d "$submodule_path/.git" ]; then
        echo -e "${YELLOW}  ⊘ Skipped (not a git repository)${NC}"
        continue
    fi
    
    cd "$submodule_path"
    
    # Check for uncommitted changes
    if ! git diff --quiet 2>/dev/null; then
        echo -e "${RED}  ✗ HAS UNCOMMITTED CHANGES (modified files)${NC}"
        git status --short | head -5
        ((UNCOMMITTED_FOUND++))
    elif ! git diff --cached --quiet 2>/dev/null; then
        echo -e "${RED}  ✗ HAS STAGED BUT UNCOMMITTED CHANGES${NC}"
        git status --short | head -5
        ((UNCOMMITTED_FOUND++))
    elif [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
        echo -e "${YELLOW}  ⚠ HAS UNTRACKED FILES${NC}"
        git ls-files --others --exclude-standard | head -5
        ((WARNINGS++))
    else
        echo -e "${GREEN}  ✓ Clean (all changes committed)${NC}"
    fi
    
    # Check if submodule commit is referenced in main repo
    cd "$PROJECT_ROOT"
    CURRENT_COMMIT=$(cd "$submodule_path" && git rev-parse HEAD)
    EXPECTED_COMMIT=$(git ls-tree HEAD "$submodule" | awk '{print $3}')
    
    if [ "$CURRENT_COMMIT" != "$EXPECTED_COMMIT" ]; then
        echo -e "${YELLOW}  ⚠ Submodule commit changed but main repo not updated${NC}"
        echo -e "    Current:  ${CURRENT_COMMIT:0:7}"
        echo -e "    Expected: ${EXPECTED_COMMIT:0:7}"
        ((WARNINGS++))
    fi
    
    echo ""
done

echo -e "${BLUE}=== Summary ===${NC}"
echo ""

if [ $UNCOMMITTED_FOUND -gt 0 ]; then
    echo -e "${RED}✗ FOUND $UNCOMMITTED_FOUND SUBMODULE(S) WITH UNCOMMITTED CHANGES${NC}"
    echo ""
    echo -e "${YELLOW}ACTION REQUIRED:${NC}"
    echo "1. Navigate to each submodule directory"
    echo "2. Review changes with: git status"
    echo "3. Commit changes: git add -A && git commit -m 'your message'"
    echo "4. Update main repo: cd $PROJECT_ROOT && git add -A && git commit -m 'chore: Update submodule references'"
    echo ""
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $WARNINGS warning(s) - review needed${NC}"
    echo ""
    exit 0
else
    echo -e "${GREEN}✓ All submodules clean - no uncommitted changes${NC}"
    echo ""
    exit 0
fi

