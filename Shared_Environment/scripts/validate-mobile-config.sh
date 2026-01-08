#!/bin/bash

# Mobile Configuration Validation Script
# Validates .env.mobile files exist and have correct configuration across all environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================================="
echo "Mobile Configuration Validation"
echo "=================================================="
echo ""

ERRORS=0
WARNINGS=0

# Function to check .env.mobile file
check_env_mobile() {
    local env_name=$1
    local env_path=$2
    local expected_api_url=$3
    local expected_env=$4
    local expected_node_env=$5
    
    echo "Checking ${env_name}..."
    
    if [ ! -f "${env_path}/frontend/.env.mobile" ]; then
        echo -e "${RED}  ✗ CRITICAL: .env.mobile missing${NC}"
        ((ERRORS++))
        return
    fi
    
    echo -e "${GREEN}  ✓ File exists${NC}"
    
    # Check API_BASE_URL
    if grep -q "^API_BASE_URL=${expected_api_url}" "${env_path}/frontend/.env.mobile"; then
        echo -e "${GREEN}  ✓ API_BASE_URL correct: ${expected_api_url}${NC}"
    else
        actual=$(grep "^API_BASE_URL=" "${env_path}/frontend/.env.mobile" | cut -d'=' -f2)
        echo -e "${RED}  ✗ API_BASE_URL incorrect${NC}"
        echo "    Expected: ${expected_api_url}"
        echo "    Actual: ${actual}"
        ((ERRORS++))
    fi
    
    # Check ENVIRONMENT
    if grep -q "^ENVIRONMENT=${expected_env}" "${env_path}/frontend/.env.mobile"; then
        echo -e "${GREEN}  ✓ ENVIRONMENT correct: ${expected_env}${NC}"
    else
        actual=$(grep "^ENVIRONMENT=" "${env_path}/frontend/.env.mobile" | cut -d'=' -f2)
        echo -e "${RED}  ✗ ENVIRONMENT incorrect${NC}"
        echo "    Expected: ${expected_env}"
        echo "    Actual: ${actual}"
        ((ERRORS++))
    fi
    
    # Check NODE_ENV
    if grep -q "^NODE_ENV=${expected_node_env}" "${env_path}/frontend/.env.mobile"; then
        echo -e "${GREEN}  ✓ NODE_ENV correct: ${expected_node_env}${NC}"
    else
        actual=$(grep "^NODE_ENV=" "${env_path}/frontend/.env.mobile" | cut -d'=' -f2)
        echo -e "${RED}  ✗ NODE_ENV incorrect${NC}"
        echo "    Expected: ${expected_node_env}"
        echo "    Actual: ${actual}"
        ((ERRORS++))
    fi
    
    # Check comments
    env_upper=$(echo "${env_name}" | tr '[:lower:]' '[:upper:]')
    if grep -q "# Mobile Environment Variables - ${env_upper}" "${env_path}/frontend/.env.mobile"; then
        echo -e "${GREEN}  ✓ Header comment correct${NC}"
    else
        echo -e "${YELLOW}  ! Header comment may be incorrect${NC}"
        ((WARNINGS++))
    fi
    
    echo ""
}

# Check each environment
check_env_mobile "Development" "Development_Environment" "http://192.168.1.144:8000" "development" "development"
check_env_mobile "Test" "Test_Environment" "http://192.168.1.144:8001" "testing" "test"
check_env_mobile "Production" "Production_Environment" "http://192.168.1.144/api" "production" "production"

# Check apiClient.native.js consistency
echo "Checking apiClient.native.js consistency..."
echo ""

check_apiclient() {
    local env_name=$1
    local env_path=$2
    
    if [ ! -f "${env_path}/frontend/src/services/apiClient.native.js" ]; then
        echo -e "${RED}  ✗ ${env_name}: apiClient.native.js missing${NC}"
        ((ERRORS++))
        return
    fi
    
    # Check for consistent import pattern
    if grep -q "import { API_BASE_URL, ENVIRONMENT } from '@env';" "${env_path}/frontend/src/services/apiClient.native.js"; then
        echo -e "${GREEN}  ✓ ${env_name}: Import pattern correct${NC}"
    else
        echo -e "${RED}  ✗ ${env_name}: Import pattern incorrect${NC}"
        ((ERRORS++))
    fi
    
    # Check for consistent export pattern
    if grep -q "export { ENVIRONMENT };" "${env_path}/frontend/src/services/apiClient.native.js"; then
        echo -e "${GREEN}  ✓ ${env_name}: Export pattern correct${NC}"
    else
        echo -e "${RED}  ✗ ${env_name}: Export pattern incorrect${NC}"
        ((ERRORS++))
    fi
}

check_apiclient "Development" "Development_Environment"
check_apiclient "Test" "Test_Environment"
check_apiclient "Production" "Production_Environment"

echo ""
echo "=================================================="
echo "Validation Summary"
echo "=================================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}! ${WARNINGS} warning(s)${NC}"
    echo "Configuration is functional but has minor issues."
    exit 0
else
    echo -e "${RED}✗ ${ERRORS} error(s), ${WARNINGS} warning(s)${NC}"
    echo "Configuration issues must be fixed before iOS builds."
    exit 1
fi

