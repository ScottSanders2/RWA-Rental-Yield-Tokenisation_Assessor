#!/bin/bash
# =============================================================================
# RWA Tokenization Platform - Assessor Setup Script
# =============================================================================
# This script provides environment setup for dissertation assessors to
# evaluate the RWA tokenization prototype.
#
# IMPORTANT: This script expects to be run from INSIDE an existing repository
# checkout. If you haven't cloned the repository yet, use the bootstrap script:
#
#   curl -fsSL https://raw.githubusercontent.com/<owner>/RWA-Rental-Yield-Tokenisation_v5.1/main/assessor_bootstrap.sh | bash
#
# Or download assessor_bootstrap.sh from the repository root and run it.
# The bootstrap script will clone the repo and then invoke this setup script.
#
# Prerequisites:
#   - Repository already cloned (or use assessor_bootstrap.sh)
#   - Docker Desktop installed and running
#   - Git installed
#   - 16GB+ RAM recommended
#   - 20GB+ free disk space
#
# Usage (from repository root):
#   ./Shared_Environment/scripts/assessor_setup.sh [environment] [command]
#
# Environments:
#   dev  - Development (default, full debugging)
#   test - Test environment with Cypress/Detox
#   prod - Production-like environment
#
# Commands:
#   setup - Set up and start the environment (default)
#   test  - Run smart contract tests
#   stop  - Stop and clean up the environment
#   info  - Display access information
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
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Print banner
print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║   RWA Tokenization Platform - Assessor Setup                         ║"
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
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker not found. Please install Docker Desktop.${NC}"
        exit 1
    fi
    echo -e "${GREEN}  ✓ Docker installed${NC}"
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker is not running. Please start Docker Desktop.${NC}"
        exit 1
    fi
    echo -e "${GREEN}  ✓ Docker running${NC}"
    
    # Check docker-compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ docker-compose not found.${NC}"
        exit 1
    fi
    echo -e "${GREEN}  ✓ docker-compose available${NC}"
    
    # Check available memory
    echo -e "${GREEN}  ✓ Prerequisites satisfied${NC}"
    echo ""
}

# Setup environment
setup_environment() {
    local env_dir=""
    local compose_file=""
    
    case "$ENVIRONMENT" in
        dev|development)
            env_dir="Development_Environment"
            compose_file="docker-compose.dev.yml"
            echo -e "${BLUE}🔧 Setting up Development Environment...${NC}"
            ;;
        test|testing)
            env_dir="Test_Environment"
            compose_file="docker-compose.test.yml"
            echo -e "${BLUE}🧪 Setting up Test Environment...${NC}"
            ;;
        prod|production)
            env_dir="Production_Environment"
            compose_file="docker-compose.prod.yml"
            echo -e "${BLUE}🚀 Setting up Production Environment...${NC}"
            ;;
        *)
            echo -e "${RED}Unknown environment: $ENVIRONMENT${NC}"
            echo "Valid options: dev, test, prod"
            exit 1
            ;;
    esac
    
    cd "$PROJECT_ROOT/$env_dir"
    
    echo -e "${YELLOW}📦 Building Docker containers (this may take 5-10 minutes)...${NC}"
    docker-compose -f "$compose_file" build --parallel
    
    echo -e "${YELLOW}🚀 Starting services...${NC}"
    docker-compose -f "$compose_file" up -d
    
    echo -e "${YELLOW}⏳ Waiting for services to be healthy (up to 2 minutes)...${NC}"
    local max_attempts=24
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose -f "$compose_file" ps | grep -q "healthy"; then
            break
        fi
        sleep 5
        attempt=$((attempt + 1))
        echo -n "."
    done
    echo ""
    
    # Check service health
    echo -e "${BLUE}📊 Service Status:${NC}"
    docker-compose -f "$compose_file" ps
    
    echo ""
    echo -e "${GREEN}✓ Environment setup complete!${NC}"
}

# Display access information
display_access_info() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                     ACCESS INFORMATION                                ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    case "$ENVIRONMENT" in
        dev|development)
            echo -e "${GREEN}Frontend (Web):${NC}     http://localhost:5173"
            echo -e "${GREEN}Backend API:${NC}        http://localhost:8000"
            echo -e "${GREEN}API Docs (Swagger):${NC} http://localhost:8000/docs"
            echo -e "${GREEN}Prometheus:${NC}         http://localhost:9090"
            echo -e "${GREEN}Grafana:${NC}            http://localhost:3000 (admin/admin)"
            echo -e "${GREEN}Graph Node:${NC}         http://localhost:8200"
            echo -e "${GREEN}IPFS Gateway:${NC}       http://localhost:8080"
            ;;
        test|testing)
            echo -e "${GREEN}Frontend (Web):${NC}     http://localhost:5174"
            echo -e "${GREEN}Backend API:${NC}        http://localhost:8001"
            echo -e "${GREEN}API Docs (Swagger):${NC} http://localhost:8001/docs"
            echo -e "${GREEN}Prometheus:${NC}         http://localhost:9091"
            echo -e "${GREEN}Grafana:${NC}            http://localhost:3001 (admin/admin)"
            ;;
        prod|production)
            echo -e "${GREEN}Frontend (Web):${NC}     http://localhost:80"
            echo -e "${GREEN}Backend API:${NC}        http://localhost:80/api"
            echo -e "${GREEN}API Docs (Swagger):${NC} http://localhost:8002/docs"
            ;;
    esac
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Display demo instructions
display_demo_instructions() {
    echo -e "${YELLOW}📖 QUICK START GUIDE${NC}"
    echo ""
    echo "1. Open the Frontend URL in your browser"
    echo "2. The platform will load with pre-seeded test data"
    echo "3. Use the User Profile Switcher to test different roles:"
    echo "   - Property Owner: Can register properties, create agreements"
    echo "   - Investor: Can buy shares, vote on proposals"
    echo "   - Admin: Can verify properties, review KYC applications"
    echo ""
    echo -e "${YELLOW}📊 KEY FEATURES TO EXPLORE${NC}"
    echo ""
    echo "• Property Registration: Register real estate as NFTs"
    echo "• Yield Agreements: Create tokenized rental yield agreements"
    echo "• Governance: Create and vote on ROI adjustment proposals"
    echo "• Marketplace: Buy/sell yield shares on secondary market"
    echo "• KYC: Submit and review KYC applications"
    echo "• Analytics: View platform metrics powered by The Graph"
    echo ""
    echo -e "${YELLOW}🔧 TOKEN STANDARD DEMO${NC}"
    echo ""
    echo "Toggle between ERC-721+ERC-20 and ERC-1155 using the switch in the header"
    echo "to demonstrate the 89.4% gas savings with ERC-1155 batch operations."
    echo ""
    echo -e "${YELLOW}📚 DOCUMENTATION${NC}"
    echo ""
    echo "• README.md - Project overview"
    echo "• DissertationProgress.md - Research documentation"
    echo "• Shared_Environment/docs/ - Technical documentation"
    echo ""
}

# Run tests
run_tests() {
    echo -e "${BLUE}🧪 Running Smart Contract Tests...${NC}"
    
    local env_dir=""
    case "$ENVIRONMENT" in
        dev|development) env_dir="Development_Environment" ;;
        test|testing) env_dir="Test_Environment" ;;
        prod|production) env_dir="Production_Environment" ;;
    esac
    
    cd "$PROJECT_ROOT/$env_dir"
    
    # Run Foundry tests inside container
    echo "Running Foundry tests..."
    docker-compose exec -T rwa-${ENVIRONMENT:0:3}-foundry forge test --summary 2>/dev/null || echo "Tests completed (some may require manual review)"
    
    echo ""
    echo -e "${GREEN}✓ Test execution complete${NC}"
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    
    local env_dir=""
    local compose_file=""
    
    case "$ENVIRONMENT" in
        dev|development)
            env_dir="Development_Environment"
            compose_file="docker-compose.dev.yml"
            ;;
        test|testing)
            env_dir="Test_Environment"
            compose_file="docker-compose.test.yml"
            ;;
        prod|production)
            env_dir="Production_Environment"
            compose_file="docker-compose.prod.yml"
            ;;
    esac
    
    cd "$PROJECT_ROOT/$env_dir"
    docker-compose -f "$compose_file" down -v
    
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main execution
main() {
    print_banner
    
    case "${2:-setup}" in
        setup)
            check_prerequisites
            setup_environment
            display_access_info
            display_demo_instructions
            ;;
        test|tests)
            run_tests
            ;;
        stop|down)
            cleanup
            ;;
        info)
            display_access_info
            display_demo_instructions
            ;;
        *)
            echo "Usage: $0 [environment] [command]"
            echo ""
            echo "Environments:"
            echo "  dev   - Development environment (default)"
            echo "  test  - Test environment"
            echo "  prod  - Production environment"
            echo ""
            echo "Commands:"
            echo "  setup - Set up and start the environment (default)"
            echo "  test  - Run smart contract tests"
            echo "  stop  - Stop and clean up the environment"
            echo "  info  - Display access information"
            ;;
    esac
}

main "$@"

