#!/bin/bash

# Comprehensive Backup Script for Iteration 12
# Following Mandatory Backup Procedures
# Created: 2025-11-11
# Purpose: Full backup of all environments (Dev/Test/Prod) with verification

set -e  # Exit on error

# Configuration
BACKUP_ROOT="/Users/scott/Cursor/RWA_Backups"
BACKUP_NAME="iteration-12-$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${BACKUP_NAME}"
PROJECT_ROOT="/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup directory structure
create_backup_structure() {
    log_info "Creating backup directory structure..."
    mkdir -p "${BACKUP_DIR}"/{git,docker,volumes,databases,verification,mobile_builds}
    mkdir -p "${BACKUP_DIR}/docker"/{images,containers}
    mkdir -p "${BACKUP_DIR}/volumes"/{development,test,production}
    mkdir -p "${BACKUP_DIR}/databases"/{development,test,production}
    log_success "Backup structure created at: ${BACKUP_DIR}"
}

# Backup Git repository using git bundle
backup_git_repo() {
    log_info "Backing up Git repository using git bundle..."
    cd "${PROJECT_ROOT}"
    
    # Create git bundle (includes all branches, tags, and history)
    git bundle create "${BACKUP_DIR}/git/rwa-project-full.bundle" --all
    
    # Export current branch name
    git branch --show-current > "${BACKUP_DIR}/git/current-branch.txt"
    
    # Export git status
    git status > "${BACKUP_DIR}/git/git-status.txt"
    
    # Export commit log
    git log --oneline --graph --all --decorate -50 > "${BACKUP_DIR}/git/git-log.txt"
    
    # Export diff of uncommitted changes
    git diff > "${BACKUP_DIR}/git/uncommitted-changes.diff" || true
    git diff --cached > "${BACKUP_DIR}/git/staged-changes.diff" || true
    
    log_success "Git repository backed up"
}

# Backup Docker images
backup_docker_images() {
    log_info "Backing up Docker images..."
    
    # Development images
    docker save development_environment-rwa-dev-backend:latest | gzip > "${BACKUP_DIR}/docker/images/dev-backend.tar.gz" &
    docker save development_environment-rwa-dev-frontend:latest | gzip > "${BACKUP_DIR}/docker/images/dev-frontend.tar.gz" &
    docker save development_environment-rwa-dev-foundry:latest | gzip > "${BACKUP_DIR}/docker/images/dev-foundry.tar.gz" &
    docker save development_environment-rwa-dev-mobile:latest | gzip > "${BACKUP_DIR}/docker/images/dev-mobile.tar.gz" &
    
    # Base images (smaller, faster to backup)
    docker save postgres:15-alpine | gzip > "${BACKUP_DIR}/docker/images/postgres-15-alpine.tar.gz" &
    docker save redis:7-alpine | gzip > "${BACKUP_DIR}/docker/images/redis-7-alpine.tar.gz" &
    docker save grafana/grafana:latest | gzip > "${BACKUP_DIR}/docker/images/grafana-latest.tar.gz" &
    docker save prom/prometheus:latest | gzip > "${BACKUP_DIR}/docker/images/prometheus-latest.tar.gz" &
    docker save prom/node-exporter:latest | gzip > "${BACKUP_DIR}/docker/images/node-exporter-latest.tar.gz" &
    
    wait  # Wait for all background saves to complete
    
    log_success "Docker images backed up"
}

# Backup Docker volumes
backup_docker_volumes() {
    log_info "Backing up Docker volumes..."
    
    # Development volumes
    docker run --rm -v development_environment_rwa-dev-postgres-data:/data -v "${BACKUP_DIR}/volumes/development":/backup alpine tar czf /backup/postgres-data.tar.gz -C /data . &
    docker run --rm -v development_environment_rwa-dev-redis-data:/data -v "${BACKUP_DIR}/volumes/development":/backup alpine tar czf /backup/redis-data.tar.gz -C /data . &
    docker run --rm -v development_environment_rwa-dev-grafana-data:/data -v "${BACKUP_DIR}/volumes/development":/backup alpine tar czf /backup/grafana-data.tar.gz -C /data . &
    docker run --rm -v development_environment_rwa-dev-prometheus-data:/data -v "${BACKUP_DIR}/volumes/development":/backup alpine tar czf /backup/prometheus-data.tar.gz -C /data . &
    
    # Test volumes
    docker run --rm -v test_environment_rwa-test-postgres-data:/data -v "${BACKUP_DIR}/volumes/test":/backup alpine tar czf /backup/postgres-data.tar.gz -C /data . &
    docker run --rm -v test_environment_rwa-test-redis-data:/data -v "${BACKUP_DIR}/volumes/test":/backup alpine tar czf /backup/redis-data.tar.gz -C /data . &
    docker run --rm -v test_environment_rwa-test-grafana-data:/data -v "${BACKUP_DIR}/volumes/test":/backup alpine tar czf /backup/grafana-data.tar.gz -C /data . &
    docker run --rm -v test_environment_rwa-test-prometheus-data:/data -v "${BACKUP_DIR}/volumes/test":/backup alpine tar czf /backup/prometheus-data.tar.gz -C /data . &
    
    # Production volumes
    docker run --rm -v production_environment_rwa-prod-postgres-data:/data -v "${BACKUP_DIR}/volumes/production":/backup alpine tar czf /backup/postgres-data.tar.gz -C /data . &
    docker run --rm -v production_environment_rwa-prod-redis-data:/data -v "${BACKUP_DIR}/volumes/production":/backup alpine tar czf /backup/redis-data.tar.gz -C /data . &
    docker run --rm -v production_environment_rwa-prod-grafana-data:/data -v "${BACKUP_DIR}/volumes/production":/backup alpine tar czf /backup/grafana-data.tar.gz -C /data . &
    docker run --rm -v production_environment_rwa-prod-prometheus-data:/data -v "${BACKUP_DIR}/volumes/production":/backup alpine tar czf /backup/prometheus-data.tar.gz -C /data . &
    
    wait  # Wait for all background backups to complete
    
    log_success "Docker volumes backed up"
}

# Backup databases (PostgreSQL dumps)
backup_databases() {
    log_info "Backing up databases..."
    
    # Development database
    docker exec rwa-dev-postgres pg_dump -U rwa_dev_user rwa_dev_db > "${BACKUP_DIR}/databases/development/rwa_dev_db.sql"
    gzip "${BACKUP_DIR}/databases/development/rwa_dev_db.sql"
    
    # Test database (if container exists)
    if docker ps -a --format '{{.Names}}' | grep -q 'rwa-test-postgres'; then
        docker exec rwa-test-postgres pg_dump -U rwa_test_user rwa_test_db > "${BACKUP_DIR}/databases/test/rwa_test_db.sql" 2>/dev/null || log_warning "Test database backup failed (container may be stopped)"
        [ -f "${BACKUP_DIR}/databases/test/rwa_test_db.sql" ] && gzip "${BACKUP_DIR}/databases/test/rwa_test_db.sql"
    else
        log_warning "Test database container not found"
    fi
    
    # Production database (if container exists)
    if docker ps -a --format '{{.Names}}' | grep -q 'rwa-prod-postgres'; then
        docker exec rwa-prod-postgres pg_dump -U rwa_prod_user rwa_prod_db > "${BACKUP_DIR}/databases/production/rwa_prod_db.sql" 2>/dev/null || log_warning "Production database backup failed (container may be stopped)"
        [ -f "${BACKUP_DIR}/databases/production/rwa_prod_db.sql" ] && gzip "${BACKUP_DIR}/databases/production/rwa_prod_db.sql"
    else
        log_warning "Production database container not found"
    fi
    
    log_success "Databases backed up"
}

# Backup mobile builds
backup_mobile_builds() {
    log_info "Backing up mobile builds..."
    
    # Copy all EAS build artifacts from frontend directory
    find "${PROJECT_ROOT}/Development_Environment/frontend" -name "build-*.tar.gz" -type f -mtime -7 -exec cp {} "${BACKUP_DIR}/mobile_builds/" \; || true
    
    # Count and log
    BUILD_COUNT=$(ls -1 "${BACKUP_DIR}/mobile_builds" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$BUILD_COUNT" -gt 0 ]; then
        log_success "Backed up ${BUILD_COUNT} mobile builds (last 7 days)"
    else
        log_warning "No recent mobile builds found"
    fi
}

# Generate checksums for verification
generate_checksums() {
    log_info "Generating checksums for verification..."
    
    cd "${BACKUP_DIR}"
    find . -type f -exec shasum -a 256 {} \; > verification/checksums.sha256
    
    log_success "Checksums generated"
}

# Create backup manifest
create_manifest() {
    log_info "Creating backup manifest..."
    
    cat > "${BACKUP_DIR}/BACKUP_MANIFEST.txt" <<EOF
================================================================================
RWA Tokenization Platform - Iteration 12 Backup
================================================================================
Backup Date: $(date)
Backup Location: ${BACKUP_DIR}
Project Root: ${PROJECT_ROOT}

================================================================================
BACKUP CONTENTS
================================================================================

1. GIT REPOSITORY
   - Full repository bundle: git/rwa-project-full.bundle
   - Current branch: $(cat ${BACKUP_DIR}/git/current-branch.txt)
   - Uncommitted changes: git/uncommitted-changes.diff
   - Staged changes: git/staged-changes.diff

2. DOCKER IMAGES
   - Development: dev-backend, dev-frontend, dev-foundry, dev-mobile
   - Base: postgres:15-alpine, redis:7-alpine, grafana, prometheus, node-exporter

3. DOCKER VOLUMES
   - Development: postgres, redis, grafana, prometheus
   - Test: postgres, redis, grafana, prometheus
   - Production: postgres, redis, grafana, prometheus

4. DATABASES
   - Development: rental_yield_db (PostgreSQL dump)
   - Test: rental_yield_db (PostgreSQL dump)
   - Production: rental_yield_db (PostgreSQL dump)

5. MOBILE BUILDS
   - EAS build artifacts (last 7 days)

6. VERIFICATION
   - SHA-256 checksums: verification/checksums.sha256

================================================================================
DOCKER CONTAINER STATUS AT BACKUP TIME
================================================================================
$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}")

================================================================================
DOCKER VOLUME LIST
================================================================================
$(docker volume ls)

================================================================================
DISK USAGE SUMMARY
================================================================================
$(du -sh ${BACKUP_DIR}/*)

================================================================================
RESTORE INSTRUCTIONS
================================================================================
To restore this backup, use the restore script:
  ./restore_from_backup.sh ${BACKUP_NAME}

Or manually:
1. Git: git clone ${BACKUP_DIR}/git/rwa-project-full.bundle
2. Docker Images: docker load < docker/images/[image-name].tar.gz
3. Docker Volumes: docker run --rm -v [volume-name]:/data -v ${BACKUP_DIR}/volumes/[env]:/backup alpine tar xzf /backup/[file].tar.gz -C /data
4. Database: docker exec -i [container] psql -U postgres rental_yield_db < databases/[env]/rental_yield_db.sql.gz

================================================================================
VERIFICATION
================================================================================
To verify backup integrity:
  cd ${BACKUP_DIR}
  shasum -a 256 -c verification/checksums.sha256

================================================================================
EOF

    log_success "Backup manifest created"
}

# Calculate total backup size
calculate_backup_size() {
    log_info "Calculating backup size..."
    TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | awk '{print $1}')
    log_success "Total backup size: ${TOTAL_SIZE}"
}

# Main backup execution
main() {
    echo "================================================================================"
    echo "  RWA Tokenization Platform - Iteration 12 Full Backup"
    echo "================================================================================"
    echo ""
    
    log_info "Starting backup process..."
    log_info "Backup location: ${BACKUP_DIR}"
    echo ""
    
    # Execute backup steps
    create_backup_structure
    echo ""
    
    backup_git_repo
    echo ""
    
    backup_docker_images
    echo ""
    
    backup_docker_volumes
    echo ""
    
    backup_databases
    echo ""
    
    backup_mobile_builds
    echo ""
    
    generate_checksums
    echo ""
    
    create_manifest
    echo ""
    
    calculate_backup_size
    echo ""
    
    log_success "================================================================================"
    log_success "  BACKUP COMPLETE!"
    log_success "================================================================================"
    log_success "Backup saved to: ${BACKUP_DIR}"
    log_success ""
    log_success "Next steps:"
    log_success "1. Verify backup integrity: cd ${BACKUP_DIR} && shasum -a 256 -c verification/checksums.sha256"
    log_success "2. Review manifest: cat ${BACKUP_DIR}/BACKUP_MANIFEST.txt"
    log_success "3. Test restore (optional): ./restore_from_backup.sh ${BACKUP_NAME}"
    echo ""
}

# Run main function
main

