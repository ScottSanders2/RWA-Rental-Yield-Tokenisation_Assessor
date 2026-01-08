#!/bin/bash

# Restore script for RWA Tokenization Platform
# Restores git bundle, Docker images, and volumes from backup
# Usage: ./restore.sh <backup_directory>

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="$1"

if [ -z "$BACKUP_DIR" ]; then
    echo -e "${RED}Error: Backup directory required${NC}"
    echo "Usage: $0 <backup_directory>"
    exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Error: Backup directory does not exist: $BACKUP_DIR${NC}"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Function to log progress
log_progress() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] $1${NC}"
}

# Function to prompt user
prompt_user() {
    echo -e "${YELLOW}$1${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operation cancelled by user${NC}"
        exit 1
    fi
}

echo -e "${BLUE}RWA Tokenization Platform - Restore Operation${NC}"
echo -e "${YELLOW}Backup directory: $BACKUP_DIR${NC}"
echo -e "${RED}WARNING: This will overwrite existing data!${NC}"
echo ""

# 1. Verify backup manifest
log_progress "Verifying backup manifest..."
MANIFEST="${BACKUP_DIR}/backup-manifest.txt"

if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Error: Backup manifest not found${NC}"
    exit 1
fi

# Verify checksums
log_progress "Verifying file checksums..."
while IFS= read -r line; do
    # Skip header lines
    if [[ "$line" == "RWA"* ]] || [[ "$line" == "Iteration"* ]] || [[ "$line" == "Created"* ]] || \
        [[ "$line" == "Repository"* ]] || [[ "$line" == "" ]] || [[ "$line" == "==="* ]]; then
        continue
    fi

    # Parse checksum line
    if [[ "$line" =~ ^([a-f0-9]{64})\ \ ([0-9]+)\ \ (.+)$ ]]; then
        expected_checksum="${BASH_REMATCH[1]}"
        expected_size="${BASH_REMATCH[2]}"
        file_path="${BACKUP_DIR}/${BASH_REMATCH[3]}"

        if [ -f "$file_path" ]; then
            actual_checksum=$(sha256sum "$file_path" | cut -d' ' -f1)
            actual_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)

            if [ "$actual_checksum" != "$expected_checksum" ]; then
                echo -e "${RED}Checksum mismatch for: $file_path${NC}"
                exit 1
            fi

            if [ "$actual_size" != "$expected_size" ]; then
                echo -e "${RED}Size mismatch for: $file_path${NC}"
                exit 1
            fi
        else
            echo -e "${RED}File missing: $file_path${NC}"
            exit 1
        fi
    fi
done < "$MANIFEST"

log_progress "Backup verification completed"

# 2. Stop running containers
log_progress "Stopping running containers..."
docker-compose -f "${REPO_ROOT}/Development_Environment/docker-compose.dev.yml" down 2>/dev/null || true
docker-compose -f "${REPO_ROOT}/Test_Environment/docker-compose.test.yml" down 2>/dev/null || true
docker-compose -f "${REPO_ROOT}/Production_Environment/docker-compose.prod.yml" down 2>/dev/null || true

# Stop any remaining containers
docker ps -q --filter "name=rwa-" | xargs -r docker stop || true

prompt_user "About to restore Git repository. This will overwrite current state."

# 3. Restore Git repository
log_progress "Restoring Git repository..."
cd "${REPO_ROOT}"

# Remove existing .git and all files
rm -rf .git
rm -rf * .[^.]* 2>/dev/null || true

# Restore from bundle
git clone "${BACKUP_DIR}/repository.bundle" .

# If the bundle lacks a HEAD, fallback to manual setup
if [ $? -ne 0 ] || [ ! -d ".git" ]; then
    log_progress "Bundle clone failed, attempting manual setup..."
    git init .
    git remote add origin "${BACKUP_DIR}/repository.bundle"
    git fetch origin --tags
    git checkout -f main || git checkout -f master || log_progress "Warning: Could not checkout default branch"
fi

log_progress "Git repository restored"

# 4. Restore Docker images
log_progress "Restoring Docker images..."
if [ -d "${BACKUP_DIR}/docker-images" ]; then
    for image_tar in "${BACKUP_DIR}/docker-images"/*.tar; do
        if [ -f "$image_tar" ]; then
            log_progress "Loading image: $(basename "$image_tar")"
            docker load -i "$image_tar"
        fi
    done
fi

# 5. Restore Docker volumes
log_progress "Restoring Docker volumes..."
if [ -d "${BACKUP_DIR}/docker-volumes" ]; then
    for volume_tar in "${BACKUP_DIR}/docker-volumes"/*.tar.gz; do
        if [ -f "$volume_tar" ]; then
            volume_name=$(basename "$volume_tar" .tar.gz)
            log_progress "Restoring volume: $volume_name"

            # Create volume if it doesn't exist
            docker volume create "$volume_name" 2>/dev/null || true

            # Restore volume contents
            docker run --rm -v "${volume_name}:/target" -v "${BACKUP_DIR}/docker-volumes:/source" alpine:latest \
                sh -c "cd /target && tar xzf /source/$(basename "$volume_tar")"
        fi
    done
fi

# 6. Restore environment files
log_progress "Restoring environment files..."
if [ -d "${BACKUP_DIR}/environment-files" ]; then
    cd "${BACKUP_DIR}/environment-files"

    # Find and restore .env files
    find . -name ".env.*" -type f | while read -r env_file; do
        # Remove leading ./
        relative_path="${env_file#./}"
        dest_path="${REPO_ROOT}/${relative_path}"

        # Create destination directory
        mkdir -p "$(dirname "$dest_path")"

        # Restore file
        cp "$env_file" "$dest_path"
        log_progress "Restored: $relative_path"
    done
fi

cd "${REPO_ROOT}"

echo ""
log_progress "Restore completed successfully!"
echo -e "${GREEN}Next steps:${NC}"
echo "1. Choose which environment to start:"
echo "   Development: cd Development_Environment && docker-compose -f docker-compose.dev.yml up -d"
echo "   Test: cd Test_Environment && docker-compose -f docker-compose.test.yml up -d"
echo "   Production: cd Production_Environment && docker-compose -f docker-compose.prod.yml up -d"
echo ""
echo "2. Verify applications are working correctly"
echo "3. Check docker logs for any errors"
echo ""
echo -e "${YELLOW}Note: If you encounter issues, the original state may be recoverable from git history${NC}"
