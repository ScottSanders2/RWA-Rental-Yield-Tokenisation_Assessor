#!/bin/bash

# Audit script for RWA Tokenization Platform
# Validates compliance with governance templates
# Usage: ./audit.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUDIT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
AUDIT_REPORT="${REPO_ROOT}/Shared_Environment/docs/audit-reports/audit-report-$(date +%Y%m%d_%H%M%S).txt"

# Global counters
PASSED=0
FAILED=0

# Function to log results
log_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"

    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC} - $test_name" | tee -a "$AUDIT_REPORT"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} - $test_name" | tee -a "$AUDIT_REPORT"
        ((FAILED++))
    fi

    if [ -n "$details" ]; then
        echo "    $details" | tee -a "$AUDIT_REPORT"
    fi
}

# Function to check if file exists
check_file_exists() {
    local file="$1"
    local description="$2"

    if [ -f "$file" ]; then
        log_result "$description" "PASS" "Found: $file"
        return 0
    else
        log_result "$description" "FAIL" "Missing: $file"
        return 1
    fi
}

# Function to check if directory exists
check_dir_exists() {
    local dir="$1"
    local description="$2"

    if [ -d "$dir" ]; then
        log_result "$description" "PASS" "Found: $dir"
        return 0
    else
        log_result "$description" "FAIL" "Missing: $dir"
        return 1
    fi
}

# Initialize audit report
{
    echo "RWA Tokenization Platform - Governance Audit Report"
    echo "Date: $AUDIT_DATE"
    echo "Repository: $REPO_ROOT"
    echo "=================================================================="
    echo ""
} > "$AUDIT_REPORT"

echo -e "${BLUE}RWA Tokenization Platform - Governance Audit${NC}"
echo -e "${BLUE}Date: $AUDIT_DATE${NC}"
echo -e "${BLUE}Report: $AUDIT_REPORT${NC}"
echo ""

# ================================
# Git Repository Structure Audit
# ================================

echo -e "${YELLOW}=== Git Repository Structure Audit ===${NC}" | tee -a "$AUDIT_REPORT"
echo "" | tee -a "$AUDIT_REPORT"

# Check repository root files
PERMITTED_ROOT_FILES=("README.md" "LICENSE" ".gitignore" ".dockerignore" "standard-git-repository-template.md" "standard-docker-container-configuration-template.md" "DissertationProgress.md")

for file in "${PERMITTED_ROOT_FILES[@]}"; do
    check_file_exists "$REPO_ROOT/$file" "Repository root file: $file"
done

# Check for non-permitted root files
root_files=$(find "$REPO_ROOT" -maxdepth 1 -type f | grep -v "/\.git/" | sed "s|$REPO_ROOT/||")
non_permitted_files=""

for file in $root_files; do
    permitted=false
    for permitted_file in "${PERMITTED_ROOT_FILES[@]}"; do
        if [ "$file" = "$permitted_file" ]; then
            permitted=true
            break
        fi
    done
    if [ "$permitted" = false ]; then
        non_permitted_files="$non_permitted_files $file"
    fi
done

if [ -z "$non_permitted_files" ]; then
    log_result "Repository root cleanliness" "PASS" "No non-permitted files in root"
else
    log_result "Repository root cleanliness" "FAIL" "Non-permitted files:$non_permitted_files"
fi

# Check environment folders
ENV_FOLDERS=("Shared_Environment" "Development_Environment" "Test_Environment" "Production_Environment")

for folder in "${ENV_FOLDERS[@]}"; do
    check_dir_exists "$REPO_ROOT/$folder" "Environment folder: $folder"
done

# Check Shared_Environment structure
SHARED_SUBDIRS=("config" "docs" "frontend" "scripts")
for subdir in "${SHARED_SUBDIRS[@]}"; do
    check_dir_exists "$REPO_ROOT/Shared_Environment/$subdir" "Shared_Environment/$subdir directory"
done

# Check environment-specific structures
check_dir_exists "$REPO_ROOT/Development_Environment/backend" "Development_Environment/backend directory"
check_dir_exists "$REPO_ROOT/Development_Environment/frontend" "Development_Environment/frontend directory"
check_dir_exists "$REPO_ROOT/Development_Environment/contracts" "Development_Environment/contracts directory"
check_dir_exists "$REPO_ROOT/Development_Environment/data" "Development_Environment/data directory"

check_dir_exists "$REPO_ROOT/Test_Environment/cypress" "Test_Environment/cypress directory"

check_dir_exists "$REPO_ROOT/Production_Environment/nginx" "Production_Environment/nginx directory"

# ================================
# Docker Configuration Audit
# ================================

echo "" | tee -a "$AUDIT_REPORT"
echo -e "${YELLOW}=== Docker Configuration Audit ===${NC}" | tee -a "$AUDIT_REPORT"
echo "" | tee -a "$AUDIT_REPORT"

# Check Docker Compose files exist and validate structure
DOCKER_COMPOSE_FILES=("Development_Environment/docker-compose.dev.yml" "Test_Environment/docker-compose.test.yml" "Production_Environment/docker-compose.prod.yml")

for compose_file in "${DOCKER_COMPOSE_FILES[@]}"; do
    check_file_exists "$REPO_ROOT/$compose_file" "Docker Compose file: $compose_file"
done

# Function to audit compose file with yq
audit_compose_file() {
    local compose_file="$1"
    local env="$2"

    if [ ! -f "$compose_file" ]; then
        log_result "Compose file audit: $env" "FAIL" "File not found: $compose_file"
        return 1
    fi

    # Check if yq is available
    if ! command -v yq &> /dev/null; then
        log_result "Compose file audit: $env" "FAIL" "yq not available for advanced parsing"
        return 1
    fi

    local all_passed=true

    # Check version header
    local version=$(yq '.version' "$compose_file" 2>/dev/null)
    if [ "$version" = "3.8" ]; then
        log_result "Compose version check: $env" "PASS" "version: '3.8'"
    else
        log_result "Compose version check: $env" "FAIL" "Expected version: '3.8', got: '$version'"
        all_passed=false
    fi

    # Get all services
    local services=$(yq '.services | keys[]' "$compose_file" 2>/dev/null)

    # Check service naming pattern
    for service in $services; do
        if [[ "$service" =~ ^rwa-${env}- ]]; then
            log_result "Service naming: $service" "PASS" "Follows rwa-${env}-<service> pattern"
        else
            log_result "Service naming: $service" "FAIL" "Does not follow rwa-${env}-<service> pattern"
            all_passed=false
        fi

        # Check restart policy
        local restart_policy=$(yq ".services.\"$service\".restart" "$compose_file" 2>/dev/null)
        if [ "$restart_policy" = "unless-stopped" ]; then
            log_result "Restart policy: $service" "PASS" "restart: unless-stopped"
        else
            log_result "Restart policy: $service" "FAIL" "Expected restart: unless-stopped, got: '$restart_policy'"
            all_passed=false
        fi

        # Check healthcheck exists
        local has_healthcheck=$(yq ".services.\"$service\" | has(\"healthcheck\")" "$compose_file" 2>/dev/null)
        if [ "$has_healthcheck" = "true" ]; then
            log_result "Healthcheck presence: $service" "PASS" "Healthcheck configured"
        else
            log_result "Healthcheck presence: $service" "FAIL" "Missing healthcheck configuration"
            all_passed=false
        fi
    done

    # Check resource allocations based on environment
    case $env in
        dev)
            check_exact_resources "$compose_file" "rwa-dev-postgres" "1GB" "1.0" "512MB" "0.5"
            check_exact_resources "$compose_file" "rwa-dev-redis" "512MB" "0.5" "256MB" "0.25"
            check_exact_resources "$compose_file" "rwa-dev-foundry" "1GB" "1.0" "512MB" "0.5"
            check_exact_resources "$compose_file" "rwa-dev-backend" "2GB" "1.5" "1GB" "0.75"
            check_exact_resources "$compose_file" "rwa-dev-frontend" "1GB" "0.5" "512MB" "0.25"
            ;;
        test)
            check_exact_resources "$compose_file" "rwa-test-postgres" "2GB" "2.0" "1GB" "1.0"
            check_exact_resources "$compose_file" "rwa-test-redis" "1GB" "1.0" "512MB" "0.5"
            check_exact_resources "$compose_file" "rwa-test-foundry" "2GB" "2.0" "1GB" "1.0"
            check_exact_resources "$compose_file" "rwa-test-backend" "3GB" "2.5" "1536MB" "1.25"
            check_exact_resources "$compose_file" "rwa-test-frontend" "2GB" "1.0" "1GB" "0.5"
            check_exact_resources "$compose_file" "rwa-test-cypress" "1GB" "1.0" "512MB" "0.5"
            check_exact_resources "$compose_file" "rwa-test-detox" "1GB" "1.0" "512MB" "0.5"
            ;;
        prod)
            check_exact_resources "$compose_file" "rwa-prod-postgres" "3GB" "2.5" "1536MB" "1.25"
            check_exact_resources "$compose_file" "rwa-prod-redis" "1GB" "1.0" "512MB" "0.5"
            check_exact_resources "$compose_file" "rwa-prod-foundry" "2GB" "2.0" "1GB" "1.0"
            check_exact_resources "$compose_file" "rwa-prod-backend" "4GB" "3.0" "2GB" "1.5"
            check_exact_resources "$compose_file" "rwa-prod-frontend" "2GB" "1.0" "1GB" "0.5"
            check_exact_resources "$compose_file" "rwa-prod-nginx" "512MB" "0.5" "256MB" "0.25"
            ;;
    esac

    # Check volume naming conventions
    local volumes=$(yq '.volumes | keys[]' "$compose_file" 2>/dev/null)
    for volume in $volumes; do
        if [[ "$volume" =~ ^rwa-${env}-.*-data$ ]]; then
            log_result "Volume naming: $volume" "PASS" "Follows rwa-${env}-<service>-data pattern"
        else
            log_result "Volume naming: $volume" "FAIL" "Does not follow rwa-${env}-<service>-data pattern"
            all_passed=false
        fi
    done

    if [ "$all_passed" = true ]; then
        log_result "Compose file audit: $env" "PASS" "All standards met"
    else
        log_result "Compose file audit: $env" "FAIL" "Some standards not met"
    fi
}

# Function to check exact resource allocations (accepts both G/GB and M/MB formats)
check_exact_resources() {
    local compose_file="$1"
    local service="$2"
    local expected_mem_limit="$3"
    local expected_cpu_limit="$4"
    local expected_mem_reservation="$5"
    local expected_cpu_reservation="$6"

    local actual_mem_limit=$(yq ".services.\"$service\".deploy.resources.limits.memory" "$compose_file" 2>/dev/null)
    local actual_cpu_limit=$(yq ".services.\"$service\".deploy.resources.limits.cpus" "$compose_file" 2>/dev/null)
    local actual_mem_reservation=$(yq ".services.\"$service\".deploy.resources.reservations.memory" "$compose_file" 2>/dev/null)
    local actual_cpu_reservation=$(yq ".services.\"$service\".deploy.resources.reservations.cpus" "$compose_file" 2>/dev/null)

    local service_passed=true

    # Function to normalize memory units (convert GB to G, MB to M for comparison)
    normalize_memory() {
        local mem="$1"
        # Convert GB to G, MB to M for consistent comparison
        echo "$mem" | sed 's/GB/G/g; s/MB/M/g'
    }

    local normalized_expected_mem_limit=$(normalize_memory "$expected_mem_limit")
    local normalized_actual_mem_limit=$(normalize_memory "$actual_mem_limit")

    if [ "$normalized_actual_mem_limit" != "$normalized_expected_mem_limit" ]; then
        log_result "Resource allocation: $service memory limit" "FAIL" "Expected: $expected_mem_limit, got: $actual_mem_limit"
        service_passed=false
    fi

    if [ "$actual_cpu_limit" != "$expected_cpu_limit" ]; then
        log_result "Resource allocation: $service CPU limit" "FAIL" "Expected: $expected_cpu_limit, got: $actual_cpu_limit"
        service_passed=false
    fi

    local normalized_expected_mem_reservation=$(normalize_memory "$expected_mem_reservation")
    local normalized_actual_mem_reservation=$(normalize_memory "$actual_mem_reservation")

    if [ "$normalized_actual_mem_reservation" != "$normalized_expected_mem_reservation" ]; then
        log_result "Resource allocation: $service memory reservation" "FAIL" "Expected: $expected_mem_reservation, got: $actual_mem_reservation"
        service_passed=false
    fi

    if [ "$actual_cpu_reservation" != "$expected_cpu_reservation" ]; then
        log_result "Resource allocation: $service CPU reservation" "FAIL" "Expected: $expected_cpu_reservation, got: $actual_cpu_reservation"
        service_passed=false
    fi

    if [ "$service_passed" = true ]; then
        log_result "Resource allocation: $service" "PASS" "All resources match template specifications"
    fi
}

# Audit each compose file
audit_compose_file "$REPO_ROOT/Development_Environment/docker-compose.dev.yml" "dev"
audit_compose_file "$REPO_ROOT/Test_Environment/docker-compose.test.yml" "test"
audit_compose_file "$REPO_ROOT/Production_Environment/docker-compose.prod.yml" "prod"

# Check .env files exist
ENV_FILES=("Development_Environment/.env.dev" "Test_Environment/.env.test" "Production_Environment/.env.prod")

for env_file in "${ENV_FILES[@]}"; do
    check_file_exists "$REPO_ROOT/$env_file" "Environment file: $env_file"
done

# Check Dockerfiles exist
DOCKERFILES=("Development_Environment/Dockerfile.dev.foundry" "Development_Environment/Dockerfile.dev.backend" "Development_Environment/Dockerfile.dev.frontend"
             "Test_Environment/Dockerfile.test.backend" "Test_Environment/Dockerfile.test.frontend" "Test_Environment/Dockerfile.test.detox"
             "Production_Environment/Dockerfile.prod.backend" "Production_Environment/Dockerfile.prod.frontend")

for dockerfile in "${DOCKERFILES[@]}"; do
    check_file_exists "$REPO_ROOT/$dockerfile" "Dockerfile: $dockerfile"
done

# ================================
# Resource Allocation Audit
# ================================

echo "" | tee -a "$AUDIT_REPORT"
echo -e "${YELLOW}=== Resource Allocation Audit ===${NC}" | tee -a "$AUDIT_REPORT"
echo "" | tee -a "$AUDIT_REPORT"

# Function to check resource allocation in docker-compose file
check_resource_allocation() {
    local compose_file="$1"
    local service="$2"
    local expected_mem_limit="$3"
    local expected_cpu_limit="$4"
    local expected_mem_reservation="$5"
    local expected_cpu_reservation="$6"

    if [ ! -f "$compose_file" ]; then
        log_result "Resource check for $service" "FAIL" "Compose file not found: $compose_file"
        return
    fi

    # Check if deploy.resources section exists
    if grep -q "deploy:" "$compose_file" && grep -q "resources:" "$compose_file"; then
        log_result "Resource allocation for $service" "PASS" "Resources configured"
    else
        log_result "Resource allocation for $service" "FAIL" "Missing deploy.resources section"
    fi
}

# Check Development environment resources
DEV_COMPOSE="$REPO_ROOT/Development_Environment/docker-compose.dev.yml"
check_resource_allocation "$DEV_COMPOSE" "rwa-dev-postgres" "1GB" "1.0" "512MB" "0.5"
check_resource_allocation "$DEV_COMPOSE" "rwa-dev-redis" "512MB" "0.5" "256MB" "0.25"
check_resource_allocation "$DEV_COMPOSE" "rwa-dev-foundry" "1GB" "1.0" "512MB" "0.5"
check_resource_allocation "$DEV_COMPOSE" "rwa-dev-backend" "2GB" "1.5" "1GB" "0.75"
check_resource_allocation "$DEV_COMPOSE" "rwa-dev-frontend" "1GB" "0.5" "512MB" "0.25"

# ================================
# Commit Message Audit
# ================================

echo "" | tee -a "$AUDIT_REPORT"
echo -e "${YELLOW}=== Commit Message Audit ===${NC}" | tee -a "$AUDIT_REPORT"
echo "" | tee -a "$AUDIT_REPORT"

# Check recent commits for conventional commit format
cd "$REPO_ROOT"
recent_commits=$(git log --oneline -10 2>/dev/null || echo "")

if [ -z "$recent_commits" ]; then
    log_result "Commit message format" "PASS" "No commits to check (new repository)"
else
    conventional_commit_count=0
    total_commits=0

    while IFS= read -r commit; do
        if [[ "$commit" =~ ^[a-f0-9]+\ (feat|fix|docs|test|refactor|chore)(\(.+\))?:\ .+ ]]; then
            ((conventional_commit_count++))
        fi
        ((total_commits++))
    done <<< "$recent_commits"

    if [ $total_commits -eq $conventional_commit_count ]; then
        log_result "Commit message format" "PASS" "All $total_commits recent commits follow conventional format"
    else
        log_result "Commit message format" "FAIL" "$conventional_commit_count/$total_commits recent commits follow conventional format"
    fi
fi

# ================================
# Final Summary
# ================================

echo "" | tee -a "$AUDIT_REPORT"
echo -e "${YELLOW}=== Audit Summary ===${NC}" | tee -a "$AUDIT_REPORT"
echo "" | tee -a "$AUDIT_REPORT"

{
    echo "Total Tests: $((PASSED + FAILED))"
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    echo ""
    if [ $FAILED -eq 0 ]; then
        echo "RESULT: ALL CHECKS PASSED ✓"
        echo ""
        echo "The repository is compliant with governance standards."
        echo "Ready to proceed to next iteration."
    else
        echo "RESULT: AUDIT FAILED ✗"
        echo ""
        echo "The repository has $FAILED governance violations."
        echo "Please correct the issues before proceeding."
        echo ""
        echo "Common remediation steps:"
        echo "- Move misplaced files to appropriate environment folders"
        echo "- Ensure all required directories exist"
        echo "- Check resource allocations in docker-compose files"
        echo "- Verify commit messages follow conventional format"
    fi
    echo ""
        echo "Full report saved to: Shared_Environment/docs/audit-reports/$(basename "$AUDIT_REPORT")"
} | tee -a "$AUDIT_REPORT"

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Audit completed successfully - all checks passed${NC}"
    exit 0
else
    echo -e "${RED}✗ Audit failed - $FAILED issues require attention${NC}"
    echo -e "${YELLOW}See full report: Shared_Environment/docs/audit-reports/$(basename "$AUDIT_REPORT")${NC}"
    exit 1
fi
