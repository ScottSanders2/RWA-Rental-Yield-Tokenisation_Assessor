#!/bin/bash

# Restore Script for RWA Tokenization Platform
# Purpose: Restore from backup with verification
# Usage: ./restore_from_backup.sh <backup-name>

set -e  # Exit on error

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

# Check arguments
if [ $# -eq 0 ]; then
    log_error "Usage: $0 <backup-name>"
    log_info "Example: $0 iteration-12-20251111-153436"
    log_info "Available backups:"
    ls -1 /Users/scott/Cursor/RWA_Backups/
    exit 1
fi

BACKUP_NAME=$1
BACKUP_ROOT="/Users/scott/Cursor/RWA_Backups"
BACKUP_DIR="${BACKUP_ROOT}/${BACKUP_NAME}"
RESTORE_TARGET="/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1-restored"

# Verify backup exists
if [ ! -d "${BACKUP_DIR}" ]; then
    log_error "Backup directory not found: ${BACKUP_DIR}"
    log_info "Available backups:"
    ls -1 "${BACKUP_ROOT}/"
    exit 1
fi

# Main restore function
main() {
    echo "================================================================================"
    echo "  RWA Tokenization Platform - Restore from Backup"
    echo "================================================================================"
    echo ""
    log_info "Backup: ${BACKUP_NAME}"
    log_info "Backup location: ${BACKUP_DIR}"
    log_info "Restore target: ${RESTORE_TARGET}"
    echo ""
    
    # Step 1: Verify backup integrity
    log_info "Step 1: Verifying backup integrity..."
    cd "${BACKUP_DIR}"
    if shasum -a 256 -c verification/checksums.sha256 2>&1 | grep -v "checksums.sha256: FAILED" | grep "FAILED"; then
        log_error "Backup integrity check FAILED!"
        exit 1
    fi
    log_success "Backup integrity verified (all files OK)"
    echo ""
    
    # Step 2: Restore Git repository
    log_info "Step 2: Restoring Git repository..."
    if [ -d "${RESTORE_TARGET}" ]; then
        log_warning "Restore target already exists: ${RESTORE_TARGET}"
        read -p "Remove and continue? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Restore cancelled"
            exit 0
        fi
        rm -rf "${RESTORE_TARGET}"
    fi
    
    git clone "${BACKUP_DIR}/git/rwa-project-full.bundle" "${RESTORE_TARGET}"
    cd "${RESTORE_TARGET}"
    
    # Restore uncommitted changes
    if [ -s "${BACKUP_DIR}/git/uncommitted-changes.diff" ]; then
        git apply "${BACKUP_DIR}/git/uncommitted-changes.diff" || log_warning "Failed to apply uncommitted changes"
    fi
    
    # Restore staged changes
    if [ -s "${BACKUP_DIR}/git/staged-changes.diff" ]; then
        git apply --cached "${BACKUP_DIR}/git/staged-changes.diff" || log_warning "Failed to apply staged changes"
    fi
    
    log_success "Git repository restored"
    echo ""
    
    # Step 3: Display Docker restore instructions
    log_info "Step 3: Docker restore instructions"
    log_warning "Docker images and volumes must be restored manually:"
    echo ""
    echo "To restore Docker images:"
    echo "  docker load < ${BACKUP_DIR}/docker/images/dev-backend.tar.gz"
    echo "  docker load < ${BACKUP_DIR}/docker/images/dev-frontend.tar.gz"
    echo "  docker load < ${BACKUP_DIR}/docker/images/dev-foundry.tar.gz"
    echo "  docker load < ${BACKUP_DIR}/docker/images/dev-mobile.tar.gz"
    echo ""
    echo "To restore Docker volumes (Development):"
    echo "  docker run --rm -v development_environment_rwa-dev-postgres-data:/data -v ${BACKUP_DIR}/volumes/development:/backup alpine tar xzf /backup/postgres-data.tar.gz -C /data"
    echo "  docker run --rm -v development_environment_rwa-dev-redis-data:/data -v ${BACKUP_DIR}/volumes/development:/backup alpine tar xzf /backup/redis-data.tar.gz -C /data"
    echo "  docker run --rm -v development_environment_rwa-dev-grafana-data:/data -v ${BACKUP_DIR}/volumes/development:/backup alpine tar xzf /backup/grafana-data.tar.gz -C /data"
    echo "  docker run --rm -v development_environment_rwa-dev-prometheus-data:/data -v ${BACKUP_DIR}/volumes/development:/backup alpine tar xzf /backup/prometheus-data.tar.gz -C /data"
    echo ""
    echo "To restore database (Development):"
    echo "  cd ${RESTORE_TARGET}/Development_Environment"
    echo "  docker-compose up -d rwa-dev-postgres"
    echo "  gunzip -c ${BACKUP_DIR}/databases/development/rwa_dev_db.sql.gz | docker exec -i rwa-dev-postgres psql -U rwa_dev_user rwa_dev_db"
    echo ""
    
    log_success "Restore verification complete!"
    echo ""
    echo "================================================================================"
    echo "  RESTORE SUMMARY"
    echo "================================================================================"
    echo "✅ Git repository: ${RESTORE_TARGET}"
    echo "✅ Backup integrity: Verified"
    echo "⚠️  Docker images: Manual restore required (see instructions above)"
    echo "⚠️  Docker volumes: Manual restore required (see instructions above)"
    echo "⚠️  Databases: Manual restore required (see instructions above)"
    echo ""
    echo "Restored Git repository is ready at: ${RESTORE_TARGET}"
    echo "================================================================================"
}

# Run main function
main



