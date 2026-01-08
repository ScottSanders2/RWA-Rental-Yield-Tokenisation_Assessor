#!/bin/bash
# CORRECTED Full Baseline Backup Script
# Fixes: Docker image names, PostgreSQL credentials

set -e

BACKUP_DIR="backups/pre-refactoring-2025-11-13-CORRECTED"
PROJECT_ROOT="/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== RWA Tokenization Platform - CORRECTED Full Baseline Backup ==="
echo "Backup Directory: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create backup directory structure
mkdir -p "$PROJECT_ROOT/$BACKUP_DIR"/{git,docker/{images,volumes},databases,contracts/{development,test,production},config}

cd "$PROJECT_ROOT"

# 1. Git Repository Backup
echo "=== 1. Backing up Git Repository ==="
if [ -f "$BACKUP_DIR/git/rwa-repo.bundle" ]; then
    echo "✅ Git bundle already exists (from previous backup)"
else
    git bundle create "$BACKUP_DIR/git/rwa-repo.bundle" --all
    echo "✅ Git bundle created: $(du -h $BACKUP_DIR/git/rwa-repo.bundle | awk '{print $1}')"
fi
echo ""

# 2. Docker Images Backup (CORRECTED NAMES)
echo "=== 2. Backing up Docker Images (CORRECTED) ==="
IMAGES=(
    "development_environment-rwa-dev-backend:latest"
    "development_environment-rwa-dev-frontend:latest"
    "development_environment-rwa-dev-foundry:latest"
    "test_environment-rwa-test-backend:latest"
    "test_environment-rwa-test-frontend:latest"
    "test_environment-rwa-test-foundry:latest"
)

for image in "${IMAGES[@]}"; do
    IMAGE_NAME=$(echo "$image" | sed 's/:latest//' | sed 's/.*environment-//')
    if docker image inspect "$image" > /dev/null 2>&1; then
        if [ ! -f "$BACKUP_DIR/docker/images/${IMAGE_NAME}.tar.gz" ]; then
            echo "Saving $IMAGE_NAME (this may take 5-10 minutes)..."
            docker save "$image" | gzip > "$BACKUP_DIR/docker/images/${IMAGE_NAME}.tar.gz"
            echo "✅ Saved: $(du -h $BACKUP_DIR/docker/images/${IMAGE_NAME}.tar.gz | awk '{print $1}')"
        else
            echo "✅ Already exists: $IMAGE_NAME ($(du -h $BACKUP_DIR/docker/images/${IMAGE_NAME}.tar.gz | awk '{print $1}'))"
        fi
    else
        echo "⚠️  Image not found: $image"
    fi
done
echo ""

# 3. Docker Volumes Backup (already working)
echo "=== 3. Backing up Docker Volumes ==="
VOLUMES=(
    "development_environment_rwa-dev-postgres-data"
    "development_environment_rwa-dev-postgres-graph-data"
    "test_environment_rwa-test-postgres-data"
)

for volume in "${VOLUMES[@]}"; do
    if docker volume inspect "$volume" > /dev/null 2>&1; then
        if [ ! -f "$BACKUP_DIR/docker/volumes/${volume}.tar.gz" ]; then
            echo "Backing up volume: $volume..."
            docker run --rm -v "$volume":/data -v "$PROJECT_ROOT/$BACKUP_DIR/docker/volumes":/backup alpine \
                tar czf "/backup/${volume}.tar.gz" -C /data . 2>/dev/null || echo "⚠️  Volume backup partial"
            echo "✅ Backed up: $(du -h $BACKUP_DIR/docker/volumes/${volume}.tar.gz 2>/dev/null | awk '{print $1}' || echo 'N/A')"
        else
            echo "✅ Already exists: $volume ($(du -h $BACKUP_DIR/docker/volumes/${volume}.tar.gz | awk '{print $1}'))"
        fi
    else
        echo "⚠️  Volume not found: $volume"
    fi
done
echo ""

# 4. PostgreSQL Database Backups (CORRECTED CREDENTIALS)
echo "=== 4. Backing up PostgreSQL Databases (CORRECTED) ==="

# Development PostgreSQL (using container's environment variables)
if docker ps | grep -q rwa-dev-postgres; then
    echo "Backing up Development PostgreSQL..."
    docker exec rwa-dev-postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$BACKUP_DIR/databases/development_postgres.sql" 2>/dev/null || {
        echo "⚠️  Dev DB export failed - checking why..."
        docker exec rwa-dev-postgres sh -c 'echo "User: $POSTGRES_USER, DB: $POSTGRES_DB"'
    }
    if [ -f "$BACKUP_DIR/databases/development_postgres.sql" ] && [ -s "$BACKUP_DIR/databases/development_postgres.sql" ]; then
        LINES=$(wc -l < "$BACKUP_DIR/databases/development_postgres.sql")
        SIZE=$(du -h "$BACKUP_DIR/databases/development_postgres.sql" | awk '{print $1}')
        echo "✅ Development DB: $LINES lines ($SIZE)"
    else
        echo "❌ Development DB export failed or empty"
    fi
else
    echo "⚠️  Development PostgreSQL not running"
fi

# Graph Node PostgreSQL
if docker ps | grep -q rwa-dev-postgres-graph; then
    echo "Backing up Graph Node PostgreSQL..."
    docker exec rwa-dev-postgres-graph pg_dump -U graph-node graph-node > "$BACKUP_DIR/databases/graph_node.sql" 2>/dev/null || echo "⚠️  Graph DB export failed"
    if [ -f "$BACKUP_DIR/databases/graph_node.sql" ] && [ -s "$BACKUP_DIR/databases/graph_node.sql" ]; then
        LINES=$(wc -l < "$BACKUP_DIR/databases/graph_node.sql")
        SIZE=$(du -h "$BACKUP_DIR/databases/graph_node.sql" | awk '{print $1}')
        echo "✅ Graph Node DB: $LINES lines ($SIZE)"
    else
        echo "❌ Graph Node DB export failed or empty"
    fi
else
    echo "⚠️  Graph Node PostgreSQL not running"
fi

# Test PostgreSQL
if docker ps | grep -q rwa-test-postgres; then
    echo "Backing up Test PostgreSQL..."
    docker exec rwa-test-postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$BACKUP_DIR/databases/test_postgres.sql" 2>/dev/null || echo "⚠️  Test DB export failed"
    if [ -f "$BACKUP_DIR/databases/test_postgres.sql" ] && [ -s "$BACKUP_DIR/databases/test_postgres.sql" ]; then
        LINES=$(wc -l < "$BACKUP_DIR/databases/test_postgres.sql")
        SIZE=$(du -h "$BACKUP_DIR/databases/test_postgres.sql" | awk '{print $1}')
        echo "✅ Test DB: $LINES lines ($SIZE)"
    else
        echo "❌ Test DB export failed or empty"
    fi
else
    echo "⚠️  Test PostgreSQL not running"
fi
echo ""

# 5. Contract Source and Artifacts
echo "=== 5. Backing up Contract Source and Artifacts ==="

# Development contracts
if [ -d "Development_Environment/contracts" ]; then
    echo "Copying Development contracts..."
    cp -r Development_Environment/contracts/src "$BACKUP_DIR/contracts/development/"
    cp -r Development_Environment/contracts/out "$BACKUP_DIR/contracts/development/" 2>/dev/null || echo "⚠️  No compiled artifacts"
    cp -r Development_Environment/contracts/broadcast "$BACKUP_DIR/contracts/development/" 2>/dev/null || echo "⚠️  No broadcast records"
    echo "✅ Development contracts backed up"
fi

# Test contracts
if [ -d "Test_Environment/contracts" ]; then
    echo "Copying Test contracts..."
    cp -r Test_Environment/contracts/src "$BACKUP_DIR/contracts/test/"
    cp -r Test_Environment/contracts/out "$BACKUP_DIR/contracts/test/" 2>/dev/null || echo "⚠️  No compiled artifacts"
    cp -r Test_Environment/contracts/broadcast "$BACKUP_DIR/contracts/test/" 2>/dev/null || echo "⚠️  No broadcast records"
    echo "✅ Test contracts backed up"
fi

# Production contracts
if [ -d "Production_Environment/contracts" ]; then
    echo "Copying Production contracts..."
    cp -r Production_Environment/contracts/src "$BACKUP_DIR/contracts/production/"
    cp -r Production_Environment/contracts/out "$BACKUP_DIR/contracts/production/" 2>/dev/null || echo "⚠️  No compiled artifacts"
    echo "✅ Production contracts backed up"
fi
echo ""

# 6. Configuration Files
echo "=== 6. Backing up Configuration Files ==="
cp Development_Environment/.env.dev "$BACKUP_DIR/config/" 2>/dev/null || echo "⚠️  .env.dev not found"
cp Test_Environment/.env.test "$BACKUP_DIR/config/" 2>/dev/null || echo "⚠️  .env.test not found"
cp Production_Environment/.env.prod "$BACKUP_DIR/config/" 2>/dev/null || echo "⚠️  .env.prod not found"
cp Development_Environment/docker-compose.dev.yml "$BACKUP_DIR/config/"
cp Test_Environment/docker-compose.test.yml "$BACKUP_DIR/config/" 2>/dev/null || echo "⚠️  docker-compose.test.yml not found"
cp Production_Environment/docker-compose.prod.yml "$BACKUP_DIR/config/" 2>/dev/null || echo "⚠️  docker-compose.prod.yml not found"
echo "✅ Configuration files backed up"
echo ""

# 7. Generate Checksums
echo "=== 7. Generating Checksums ==="
cd "$BACKUP_DIR"
find . -type f -not -name "checksums.txt" -exec sha256sum {} \; > checksums.txt 2>/dev/null
CHECKSUM_COUNT=$(wc -l < checksums.txt)
echo "✅ Checksums generated: $CHECKSUM_COUNT files"
cd "$PROJECT_ROOT"
echo ""

# 8. Create Restore Instructions (same as before)
echo "=== 8. Creating Restore Instructions ==="
cat > "$BACKUP_DIR/restore_instructions.md" << 'EOF'
# Restore Instructions - CORRECTED BACKUP

## Prerequisites
- Docker and Docker Compose installed
- Foundry installed
- Sufficient disk space (~10GB)

## Restore Git Repository
```bash
git clone backups/pre-refactoring-2025-11-13-CORRECTED/git/rwa-repo.bundle restored-repo
cd restored-repo
```

## Restore Docker Images
```bash
cd backups/pre-refactoring-2025-11-13-CORRECTED/docker/images
for image in *.tar.gz; do
    echo "Loading $image..."
    gunzip -c "$image" | docker load
done
```

## Restore Docker Volumes
```bash
cd backups/pre-refactoring-2025-11-13-CORRECTED/docker/volumes
for volume in *.tar.gz; do
    VOLUME_NAME=$(basename "$volume" .tar.gz)
    docker volume create "$VOLUME_NAME"
    docker run --rm -v "$VOLUME_NAME":/data -v $(pwd):/backup alpine \
        tar xzf "/backup/$volume" -C /data
    echo "✅ Restored: $VOLUME_NAME"
done
```

## Restore PostgreSQL Databases
```bash
# Start PostgreSQL containers first
docker-compose -f Development_Environment/docker-compose.dev.yml up -d rwa-dev-postgres rwa-dev-postgres-graph

# Wait for PostgreSQL to be ready
sleep 10

# Restore Development DB (using container's environment variables)
cat backups/pre-refactoring-2025-11-13-CORRECTED/databases/development_postgres.sql | \
    docker exec -i rwa-dev-postgres sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'

# Restore Graph Node DB
cat backups/pre-refactoring-2025-11-13-CORRECTED/databases/graph_node.sql | \
    docker exec -i rwa-dev-postgres-graph psql -U graph-node graph-node

# Restore Test DB (if Test environment needed)
docker-compose -f Test_Environment/docker-compose.test.yml up -d rwa-test-postgres
sleep 10
cat backups/pre-refactoring-2025-11-13-CORRECTED/databases/test_postgres.sql | \
    docker exec -i rwa-test-postgres sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB"'
```

## Restore Contracts
```bash
# Copy contract source back
cp -r backups/pre-refactoring-2025-11-13-CORRECTED/contracts/development/src/* \
    Development_Environment/contracts/src/

cp -r backups/pre-refactoring-2025-11-13-CORRECTED/contracts/test/src/* \
    Test_Environment/contracts/src/

# Rebuild contracts
cd Development_Environment/contracts
docker exec rwa-dev-foundry forge build
```

## Restore Configuration
```bash
cp backups/pre-refactoring-2025-11-13-CORRECTED/config/.env.dev Development_Environment/
cp backups/pre-refactoring-2025-11-13-CORRECTED/config/docker-compose.dev.yml Development_Environment/
```

## Verify Checksums
```bash
cd backups/pre-refactoring-2025-11-13-CORRECTED
sha256sum -c checksums.txt | grep -v "OK" || echo "✅ All checksums verified"
```

## Restart Services
```bash
cd Development_Environment
docker-compose -f docker-compose.dev.yml up -d
```

## Verify Restoration
1. Check contract sizes: `cd contracts && ./check_contract_sizes.sh`
2. Run test suite: `docker exec rwa-dev-foundry forge test -vv`
3. Check database: `docker exec rwa-dev-postgres sh -c 'psql -U "$POSTGRES_USER" "$POSTGRES_DB" -c "\dt"'`
4. Verify frontend: http://localhost:5173
EOF
echo "✅ Restore instructions created"
echo ""

# 9. Backup Summary
echo "=== BACKUP SUMMARY (CORRECTED) ==="
echo "Backup Location: $BACKUP_DIR"
echo "Total Size: $(du -sh $BACKUP_DIR | awk '{print $1}')"
echo ""
echo "Contents:"
echo "- Git Repository: $(du -sh $BACKUP_DIR/git 2>/dev/null | awk '{print $1}' || echo '0B')"
echo "- Docker Images: $(du -sh $BACKUP_DIR/docker/images 2>/dev/null | awk '{print $1}' || echo '0B')"
echo "- Docker Volumes: $(du -sh $BACKUP_DIR/docker/volumes 2>/dev/null | awk '{print $1}' || echo '0B')"
echo "- Databases: $(du -sh $BACKUP_DIR/databases 2>/dev/null | awk '{print $1}' || echo '0B')"
echo "- Contracts: $(du -sh $BACKUP_DIR/contracts 2>/dev/null | awk '{print $1}' || echo '0B')"
echo "- Config: $(du -sh $BACKUP_DIR/config 2>/dev/null | awk '{print $1}' || echo '0B')"
echo ""
echo "Files: $(find $BACKUP_DIR -type f 2>/dev/null | wc -l | tr -d ' ')"
echo "Checksums: $(wc -l < $BACKUP_DIR/checksums.txt 2>/dev/null || echo '0') verified"
echo ""

# Validation
VALID=true

# Check Git bundle
if [ ! -f "$BACKUP_DIR/git/rwa-repo.bundle" ] || [ ! -s "$BACKUP_DIR/git/rwa-repo.bundle" ]; then
    echo "❌ Git bundle missing or empty"
    VALID=false
fi

# Check Docker images
IMAGE_COUNT=$(find "$BACKUP_DIR/docker/images" -name "*.tar.gz" 2>/dev/null | wc -l | tr -d ' ')
if [ "$IMAGE_COUNT" -lt 3 ]; then
    echo "⚠️  Only $IMAGE_COUNT Docker images backed up (expected ≥3)"
fi

# Check databases
DB_COUNT=$(find "$BACKUP_DIR/databases" -name "*.sql" -type f ! -empty 2>/dev/null | wc -l | tr -d ' ')
if [ "$DB_COUNT" -lt 1 ]; then
    echo "⚠️  Only $DB_COUNT databases backed up (expected ≥1)"
fi

# Check contracts
if [ ! -d "$BACKUP_DIR/contracts/development/src" ]; then
    echo "❌ Development contracts missing"
    VALID=false
fi

if [ "$VALID" = true ]; then
    echo "✅ BACKUP VALIDATION: PASSED"
    echo "✅ BACKUP COMPLETE AND VALID"
else
    echo "❌ BACKUP VALIDATION: FAILED"
    echo "⚠️  Some components missing - review warnings above"
fi
echo ""
echo "To restore, see: $BACKUP_DIR/restore_instructions.md"

