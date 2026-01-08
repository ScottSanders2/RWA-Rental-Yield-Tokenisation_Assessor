#!/bin/bash
# =============================================================================
# RWA Tokenization Platform - Assessor Bootstrap Script
# =============================================================================
# This bootstrap script provides a single-command setup for dissertation
# assessors who do NOT yet have the repository cloned.
#
# Download and run this script to automatically:
#   1) Check for prerequisites (git, docker)
#   2) Clone the GitHub repository
#   3) Run the full assessor setup
#
# Usage (from anywhere on your system):
#   curl -fsSL https://raw.githubusercontent.com/<owner>/RWA-Rental-Yield-Tokenisation_v5.1/main/assessor_bootstrap.sh | bash
#   
#   OR download and run manually:
#   chmod +x assessor_bootstrap.sh
#   ./assessor_bootstrap.sh [environment] [target_directory]
#
# Arguments:
#   environment      - dev (default), test, or prod
#   target_directory - Where to clone the repo (default: ./RWA-Rental-Yield-Tokenisation_v5.1)
#
# Prerequisites:
#   - Git installed
#   - Docker Desktop installed and running
#   - 16GB+ RAM recommended
#   - 20GB+ free disk space
#
# Author: RWA Tokenization Platform - MSc Dissertation
# Date: December 2025
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
ENVIRONMENT="${1:-dev}"
TARGET_DIR="${2:-./RWA-Rental-Yield-Tokenisation_v5.1}"
GITHUB_REPO_URL="${GITHUB_REPO_URL:-https://github.com/YOUR_USERNAME/RWA-Rental-Yield-Tokenisation_v5.1.git}"

# Print banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║   RWA Tokenization Platform - Assessor Bootstrap                     ║"
    echo "║   Real-World Asset Rental Yield Tokenization Prototype               ║"
    echo "║                                                                      ║"
    echo "║   MSc Dissertation Project                                           ║"
    echo "║   December 2025                                                      ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}📋 Checking prerequisites...${NC}"
    local has_errors=0
    
    # Check Git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}❌ Git not found.${NC}"
        echo "   Please install Git from: https://git-scm.com/downloads"
        has_errors=1
    else
        echo -e "${GREEN}  ✓ Git installed ($(git --version | cut -d' ' -f3))${NC}"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker not found.${NC}"
        echo "   Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
        has_errors=1
    else
        echo -e "${GREEN}  ✓ Docker installed ($(docker --version | cut -d' ' -f3 | tr -d ','))${NC}"
    fi
    
    # Check Docker is running
    if command -v docker &> /dev/null; then
        if ! docker info &> /dev/null 2>&1; then
            echo -e "${RED}❌ Docker is not running.${NC}"
            echo "   Please start Docker Desktop and try again."
            has_errors=1
        else
            echo -e "${GREEN}  ✓ Docker daemon running${NC}"
        fi
    fi
    
    # Check docker-compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        echo -e "${RED}❌ docker-compose not found.${NC}"
        echo "   Docker Compose should be included with Docker Desktop."
        has_errors=1
    else
        echo -e "${GREEN}  ✓ docker-compose available${NC}"
    fi
    
    if [ $has_errors -eq 1 ]; then
        echo ""
        echo -e "${RED}Please install missing prerequisites and try again.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}  ✓ All prerequisites satisfied${NC}"
    echo ""
}

# Clone repository
clone_repository() {
    echo -e "${BLUE}📥 Cloning repository...${NC}"
    
    # Check if target directory already exists
    if [ -d "$TARGET_DIR" ]; then
        echo -e "${YELLOW}⚠️  Directory '$TARGET_DIR' already exists.${NC}"
        read -p "   Do you want to use the existing directory? (y/N): " use_existing
        
        if [[ "$use_existing" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}  ✓ Using existing directory${NC}"
            
            # Verify it's a git repo and pull latest
            if [ -d "$TARGET_DIR/.git" ]; then
                echo -e "${YELLOW}  Pulling latest changes...${NC}"
                cd "$TARGET_DIR"
                git pull origin main || echo -e "${YELLOW}  Warning: Could not pull latest changes${NC}"
                cd - > /dev/null
            fi
        else
            echo -e "${RED}  Please remove the directory or specify a different target:${NC}"
            echo "    ./assessor_bootstrap.sh $ENVIRONMENT ./different_directory"
            exit 1
        fi
    else
        # Clone the repository
        echo "   Cloning from: $GITHUB_REPO_URL"
        echo "   Target: $TARGET_DIR"
        echo ""
        
        git clone "$GITHUB_REPO_URL" "$TARGET_DIR"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to clone repository.${NC}"
            echo "   Please check the repository URL and your network connection."
            exit 1
        fi
        
        echo -e "${GREEN}  ✓ Repository cloned successfully${NC}"
    fi
    echo ""
}

# Initialize submodules
init_submodules() {
    echo -e "${BLUE}📦 Initializing Git submodules...${NC}"
    
    cd "$TARGET_DIR"
    
    # Initialize and update submodules
    git submodule update --init --recursive
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓ Submodules initialized${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Submodule initialization had warnings (non-critical)${NC}"
    fi
    
    cd - > /dev/null
    echo ""
}

# Run assessor setup
run_assessor_setup() {
    echo -e "${BLUE}🚀 Running assessor setup script...${NC}"
    echo ""
    
    cd "$TARGET_DIR"
    
    # Check if assessor_setup.sh exists
    if [ -f "Shared_Environment/scripts/assessor_setup.sh" ]; then
        # Make it executable
        chmod +x Shared_Environment/scripts/assessor_setup.sh
        
        # Run the setup
        ./Shared_Environment/scripts/assessor_setup.sh "$ENVIRONMENT" setup
    else
        echo -e "${RED}❌ assessor_setup.sh not found in expected location.${NC}"
        echo "   Expected: Shared_Environment/scripts/assessor_setup.sh"
        exit 1
    fi
}

# Display completion message
display_completion() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    BOOTSTRAP COMPLETE!                                  ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Repository Location:${NC} $TARGET_DIR"
    echo -e "${CYAN}Environment:${NC} $ENVIRONMENT"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Open the frontend URL in your browser (see access info above)"
    echo "  2. Explore the platform features"
    echo "  3. Review documentation in Shared_Environment/docs/"
    echo ""
    echo -e "${YELLOW}Useful Commands:${NC}"
    echo "  cd $TARGET_DIR"
    echo "  ./Shared_Environment/scripts/assessor_setup.sh $ENVIRONMENT info   # Show access URLs"
    echo "  ./Shared_Environment/scripts/assessor_setup.sh $ENVIRONMENT test   # Run tests"
    echo "  ./Shared_Environment/scripts/assessor_setup.sh $ENVIRONMENT stop   # Stop environment"
    echo ""
}

# Main execution
main() {
    print_banner
    
    echo -e "${YELLOW}Environment: ${NC}$ENVIRONMENT"
    echo -e "${YELLOW}Target Directory: ${NC}$TARGET_DIR"
    echo ""
    
    check_prerequisites
    clone_repository
    init_submodules
    run_assessor_setup
    display_completion
}

main "$@"

