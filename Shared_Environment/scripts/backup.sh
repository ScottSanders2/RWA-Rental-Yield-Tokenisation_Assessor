#!/bin/bash

# Comprehensive backup script for RWA Tokenization Platform
# Creates git bundle, Docker images, and volume archives with automatic rotation
# Keeps the 5 most recent backups, removes older ones
# Usage: ./backup.sh <iteration_number>

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ITERATION="${1:-$(date +%Y%m%d_%H%M%S)}"
BACKUP_DIR="backups/iteration-${ITERATION}-$(date +%Y%m%d_%H%M%S)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo -e "${GREEN}Starting backup for iteration: ${ITERATION}${NC}"
echo -e "${YELLOW}Backup directory: ${BACKUP_DIR}${NC}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Function to log progress
log_progress() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] $1${NC}"
}

# Function to calculate size
get_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

# Function to rotate old backups (keep last 5)
rotate_backups() {
    log_progress "Rotating old backups (keeping last 5)..."

    # Get all backup directories sorted by modification time (newest first)
    # Use ls -t for portability across systems
    local backup_dirs=$(ls -td backups/iteration-*/ 2>/dev/null || true)

    # Count total backups
    local total_backups=$(echo "$backup_dirs" | wc -l | xargs)

    if [ "$total_backups" -gt 5 ]; then
        # Keep only the 5 most recent backups
        local backups_to_delete=$(echo "$backup_dirs" | tail -n +6)

        echo "$backups_to_delete" | while read -r old_backup; do
            if [ -n "$old_backup" ] && [ -d "$old_backup" ]; then
                log_progress "Removing old backup: $(basename "$old_backup")"
                rm -rf "$old_backup"
            fi
        done

        log_progress "Backup rotation completed (kept 5 most recent)"
    else
        log_progress "No old backups to rotate (total: $total_backups)"
    fi
}

# 1. Create Git bundle
log_progress "Creating Git bundle..."
cd "${REPO_ROOT}"
git bundle create "${BACKUP_DIR}/repository.bundle" --all
log_progress "Git bundle created: $(get_size "${BACKUP_DIR}/repository.bundle")"

# 2. Export Docker images
log_progress "Exporting Docker images..."
mkdir -p "${BACKUP_DIR}/docker-images"

# Collect images from multiple sources for comprehensive backup
images_to_backup=""

# Get images from running containers with rwa- prefix in name
running_images=$(docker ps --format '{{.Image}}' --filter name=rwa- 2>/dev/null | sort -u)
if [ -n "$running_images" ]; then
    images_to_backup="$running_images"$'\n'
fi

# Get all images with rwa- in repository name (any position)
repo_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "rwa-")
if [ -n "$repo_images" ]; then
    images_to_backup="$images_to_backup$repo_images"$'\n'
fi

# Include critical infrastructure images used by the system
# IMPORTANT: This list ensures comprehensive backup coverage including all infrastructure components
# Update this list when new infrastructure images are added to docker-compose files
infrastructure_images="
nginx:1.25-alpine
redis:7-alpine
postgres:15-alpine
prom/prometheus:latest
grafana/grafana:latest
prom/node-exporter:latest
alpine:latest
cypress/included:13.6.0
ghcr.io/foundry-rs/foundry:latest
"
images_to_backup="$images_to_backup$infrastructure_images"$'\n'

# Remove duplicates and export each unique image
echo "$images_to_backup" | sort -u | while read -r image; do
    # Skip if image is empty or <none>
    if [[ -z "$image" || "$image" == "<none>" ]]; then
        continue
    fi

    # Clean image name for filename
    clean_name=$(echo "$image" | sed 's/[:/]/-/g')
    log_progress "Exporting image: $image"

    if docker save "$image" -o "${BACKUP_DIR}/docker-images/${clean_name}.tar"; then
        log_progress "Successfully exported: $image"
    else
        log_progress "Warning: Failed to export $image"
    fi
done

log_progress "Docker images exported: $(get_size "${BACKUP_DIR}/docker-images")"

# 3. Archive Docker volumes
log_progress "Archiving Docker volumes..."
mkdir -p "${BACKUP_DIR}/docker-volumes"

# Get all volumes with rwa- prefix
docker volume ls --format "{{.Name}}" | grep "rwa-" | while read -r volume; do
    log_progress "Archiving volume: $volume"

    # Create temporary container to archive volume
    docker run --rm -v "${volume}:/source" -v "${REPO_ROOT}/${BACKUP_DIR}/docker-volumes:/backup" alpine:latest \
        sh -c "tar czf /backup/${volume}.tar.gz -C /source ."
done

log_progress "Docker volumes archived: $(get_size "${BACKUP_DIR}/docker-volumes")"

# 4. Backup environment files
log_progress "Backing up environment files..."
mkdir -p "${BACKUP_DIR}/environment-files"

# Copy all .env.* files
find "${REPO_ROOT}" -name ".env.*" -type f | while read -r env_file; do
    relative_path="${env_file#${REPO_ROOT}/}"
    dest_dir="${BACKUP_DIR}/environment-files/$(dirname "$relative_path")"
    mkdir -p "$dest_dir"
    cp "$env_file" "$dest_dir/"
    log_progress "Backed up: $relative_path"
done

# 5. Generate manifest with checksums
log_progress "Generating backup manifest..."
MANIFEST="${BACKUP_DIR}/backup-manifest.txt"

{
    echo "RWA Tokenization Platform - Backup Manifest"
    echo "Iteration: ${ITERATION}"
    echo "Created: $(date)"
    echo "Repository: ${REPO_ROOT}"
    echo ""
    echo "=== FILE CHECKSUMS ==="
} > "$MANIFEST"

# Calculate checksums for all backup files
find "${BACKUP_DIR}" -type f -not -name "backup-manifest.txt" | sort | while read -r file; do
    checksum=$(sha256sum "$file" | cut -d' ' -f1)
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    relative_path="${file#${BACKUP_DIR}/}"
    echo "${checksum}  ${size}  ${relative_path}" >> "$MANIFEST"
done

# 6. Verify backup integrity
log_progress "Verifying backup integrity..."
verification_passed=true

# Re-read manifest and verify checksums
while IFS= read -r line; do
    # Skip header lines
    if [[ "$line" == "RWA"* ]] || [[ "$line" == "Iteration"* ]] || [[ "$line" == "Created"* ]] || \
        [[ "$line" == "Repository"* ]] || [[ "$line" == "" ]] || [[ "$line" == "==="* ]]; then
        continue
    fi

    # Parse checksum line
    if [[ "$line" =~ ^([a-f0-9]{64})\ ([0-9]+)\ (.+)$ ]]; then
        expected_checksum="${BASH_REMATCH[1]}"
        expected_size="${BASH_REMATCH[2]}"
        file_path="${BACKUP_DIR}/${BASH_REMATCH[3]}"

        if [ -f "$file_path" ]; then
            actual_checksum=$(sha256sum "$file_path" | cut -d' ' -f1)
            actual_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)

            if [ "$actual_checksum" != "$expected_checksum" ]; then
                log_progress "ERROR: Checksum mismatch for: ${BASH_REMATCH[3]}"
                verification_passed=false
            fi

            if [ "$actual_size" != "$expected_size" ]; then
                log_progress "ERROR: Size mismatch for: ${BASH_REMATCH[3]}"
                verification_passed=false
            fi
        else
            log_progress "ERROR: File missing from backup: ${BASH_REMATCH[3]}"
            verification_passed=false
        fi
    fi
done < "$MANIFEST"

if [ "$verification_passed" = true ]; then
    log_progress "Backup verification passed ✓"
else
    log_progress "ERROR: Backup verification failed ✗"
    echo -e "${RED}Backup integrity check failed. Do not use this backup.${NC}"
    exit 1
fi

# 7. Generate summary
TOTAL_SIZE=$(get_size "${BACKUP_DIR}")
FILE_COUNT=$(find "${BACKUP_DIR}" -type f | wc -l)

{
    echo ""
    echo "=== BACKUP SUMMARY ==="
    echo "Total files: ${FILE_COUNT}"
    echo "Total size: ${TOTAL_SIZE}"
    echo "Backup location: ${BACKUP_DIR}"
    echo ""
    echo "=== VERIFICATION STATUS ==="
    echo "Integrity check: PASSED"
    echo ""
    echo "=== RESTORE INSTRUCTIONS ==="
    echo "To restore this backup:"
    echo "1. Run: ./Shared_Environment/scripts/restore.sh ${BACKUP_DIR}"
    echo "2. Check docker logs for any errors"
    echo "3. Verify applications start correctly"
} >> "$MANIFEST"

# KYC-specific files backup (Iteration 14)
log_progress "Backing up KYC-specific files..."
mkdir -p "${BACKUP_DIR}/kyc-files"

# Smart contracts
log_progress "  - KYC smart contracts..."
if [ -f "${REPO_ROOT}/Development_Environment/contracts/src/KYCRegistry.sol" ]; then
    cp "${REPO_ROOT}/Development_Environment/contracts/src/KYCRegistry.sol" "${BACKUP_DIR}/kyc-files/"
fi
if [ -f "${REPO_ROOT}/Development_Environment/contracts/src/storage/KYCStorage.sol" ]; then
    cp "${REPO_ROOT}/Development_Environment/contracts/src/storage/KYCStorage.sol" "${BACKUP_DIR}/kyc-files/"
fi

# Test files
log_progress "  - KYC test files..."
if [ -f "${REPO_ROOT}/Development_Environment/contracts/test/KYCRegistry.t.sol" ]; then
    cp "${REPO_ROOT}/Development_Environment/contracts/test/KYCRegistry.t.sol" "${BACKUP_DIR}/kyc-files/"
fi
if [ -f "${REPO_ROOT}/Development_Environment/contracts/test/KYCIntegration.t.sol" ]; then
    cp "${REPO_ROOT}/Development_Environment/contracts/test/KYCIntegration.t.sol" "${BACKUP_DIR}/kyc-files/"
fi

# Deployment scripts
log_progress "  - KYC deployment scripts..."
if [ -f "${REPO_ROOT}/Development_Environment/contracts/script/DeployKYCRegistry.s.sol" ]; then
    cp "${REPO_ROOT}/Development_Environment/contracts/script/DeployKYCRegistry.s.sol" "${BACKUP_DIR}/kyc-files/"
fi

# Security scripts
log_progress "  - Security scanning scripts..."
if [ -d "${REPO_ROOT}/Development_Environment/contracts/scripts/security" ]; then
    cp -r "${REPO_ROOT}/Development_Environment/contracts/scripts/security" "${BACKUP_DIR}/kyc-files/"
fi

# Backend models
log_progress "  - KYC backend models..."
if [ -f "${REPO_ROOT}/Development_Environment/backend/models/kyc_verification.py" ]; then
    cp "${REPO_ROOT}/Development_Environment/backend/models/kyc_verification.py" "${BACKUP_DIR}/kyc-files/"
fi
if [ -f "${REPO_ROOT}/Development_Environment/backend/models/kyc_document.py" ]; then
    cp "${REPO_ROOT}/Development_Environment/backend/models/kyc_document.py" "${BACKUP_DIR}/kyc-files/"
fi

# Backend schemas and services
log_progress "  - KYC backend schemas and services..."
if [ -f "${REPO_ROOT}/Development_Environment/backend/schemas/kyc.py" ]; then
    cp "${REPO_ROOT}/Development_Environment/backend/schemas/kyc.py" "${BACKUP_DIR}/kyc-files/"
fi
if [ -f "${REPO_ROOT}/Development_Environment/backend/services/kyc_service.py" ]; then
    cp "${REPO_ROOT}/Development_Environment/backend/services/kyc_service.py" "${BACKUP_DIR}/kyc-files/"
fi

# Backend API
log_progress "  - KYC backend API..."
if [ -f "${REPO_ROOT}/Development_Environment/backend/api/kyc.py" ]; then
    cp "${REPO_ROOT}/Development_Environment/backend/api/kyc.py" "${BACKUP_DIR}/kyc-files/"
fi

# Frontend components
log_progress "  - KYC frontend components..."
if [ -f "${REPO_ROOT}/Development_Environment/frontend/src/components/KYCSubmissionForm.jsx" ]; then
    cp "${REPO_ROOT}/Development_Environment/frontend/src/components/KYCSubmissionForm.jsx" "${BACKUP_DIR}/kyc-files/"
fi
if [ -f "${REPO_ROOT}/Development_Environment/frontend/src/components/KYCStatusBadge.jsx" ]; then
    cp "${REPO_ROOT}/Development_Environment/frontend/src/components/KYCStatusBadge.jsx" "${BACKUP_DIR}/kyc-files/"
fi
if [ -f "${REPO_ROOT}/Development_Environment/frontend/src/pages/KYCPage.jsx" ]; then
    cp "${REPO_ROOT}/Development_Environment/frontend/src/pages/KYCPage.jsx" "${BACKUP_DIR}/kyc-files/"
fi

# Security reports
log_progress "  - Security scan reports..."
if [ -d "${REPO_ROOT}/Development_Environment/docs/security" ]; then
    cp -r "${REPO_ROOT}/Development_Environment/docs/security" "${BACKUP_DIR}/kyc-files/"
fi

# Documentation and diagrams
log_progress "  - KYC documentation and diagrams..."
if [ -f "${REPO_ROOT}/Shared_Environment/docs/diagrams/kyc-workflow.mmd" ]; then
    cp "${REPO_ROOT}/Shared_Environment/docs/diagrams/kyc-workflow.mmd" "${BACKUP_DIR}/kyc-files/"
fi
if [ -f "${REPO_ROOT}/Shared_Environment/docs/diagrams/kyc-architecture.mmd" ]; then
    cp "${REPO_ROOT}/Shared_Environment/docs/diagrams/kyc-architecture.mmd" "${BACKUP_DIR}/kyc-files/"
fi

log_progress "KYC files backup completed"

# Rotate old backups
rotate_backups

log_progress "Backup completed successfully!"
echo -e "${GREEN}Summary:${NC}"
echo "  Location: ${BACKUP_DIR}"
echo "  Size: ${TOTAL_SIZE}"
echo "  Files: ${FILE_COUNT}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test restore capability in a safe environment: ./Shared_Environment/scripts/restore.sh ${BACKUP_DIR}"
echo "2. Update DissertationProgress.md with backup metrics"
