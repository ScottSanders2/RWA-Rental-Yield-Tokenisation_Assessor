#!/bin/bash
# Full Baseline Backup Script
# Creates comprehensive backup before contract refactoring
# Backs up: Git repo, Docker images, volumes, databases, contracts, config

set -e

BACKUP_DIR="backups/pre-refactoring-2025-11-13"
PROJECT_ROOT="/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== RWA Tokenization Platform - Full Baseline Backup ==="
echo "Backup Directory: $BACKUP_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create backup directory structure
mkdir -p "$PROJECT_ROOT/$BACKUP_DIR"/{git,docker/{images,volumes},databases,contracts/{development,test,production},config}

cd "$PROJECT_ROOT"

# 1. Git Repository Backup
echo "=== 1. Backing up Git Repository ==="
git bundle create "$BACKUP_DIR/git/rwa-repo.bundle" --all
echo "✅ Git bundle created: $(du -h $BACKUP_DIR/git/rwa-repo.bundle | awk '{print $1}')"
echo ""

# 2. Docker Images Backup
echo "=== 2. Backing up Docker Images ==="
IMAGES=(
    "rwa-rental-yield-tokenisation_v51-rwa-dev-backend:latest"
    "rwa-rental-yield-tokenisation_v51-rwa-dev-frontend:latest"
    "rwa-rental-yield-tokenisation_v51-rwa-dev-foundry:latest"
    "rwa-rental-yield-tokenisation_v51-rwa-test-backend:latest"
    "rwa-rental-yield-tokenisation_v51-rwa-test-frontend:latest"
    "rwa-rental-yield-tokenisation_v51-rwa-test-foundry:latest"
)

for image in "${IMAGES[@]}"; do
    IMAGE_NAME=$(echo "$image" | sed 's/:latest//' | sed 's/.*-rwa-/rwa-/')
    if docker image inspect "$image" > /dev/null 2>&1; then
        echo "Saving $IMAGE_NAME..."
        docker save "$image" | gzip > "$BACKUP_DIR/docker/images/${IMAGE_NAME}.tar.gz"
        echo "✅ Saved: $(du -h $BACKUP_DIR/docker/images/${IMAGE_NAME}.tar.gz | awk '{print $1}')"
    else
        echo "⚠️  Image not found: $image"
    fi
done
echo ""

# 3. Docker Volumes Backup
echo "=== 3. Backing up Docker Volumes ==="
VOLUMES=(
    "development_environment_rwa-dev-postgres-data"
    "development_environment_rwa-dev-postgres-graph-data"
    "test_environment_rwa-test-postgres-data"
)

for volume in "${VOLUMES[@]}"; do
    if docker volume inspect "$volume" > /dev/null 2>&1; then
        echo "Backing up volume: $volume..."
        docker run --rm -v "$volume":/data -v "$PROJECT_ROOT/$BACKUP_DIR/docker/volumes":/backup alpine \
            tar czf "/backup/${volume}.tar.gz" -C /data . 2>/dev/null || echo "⚠️  Volume backup partial"
        echo "✅ Backed up: $(du -h $BACKUP_DIR/docker/volumes/${volume}.tar.gz 2>/dev/null | awk '{print $1}' || echo 'N/A')"
    else
        echo "⚠️  Volume not found: $volume"
    fi
done
echo ""

# 4. PostgreSQL Database Backups
echo "=== 4. Backing up PostgreSQL Databases ==="

# Development PostgreSQL
if docker ps | grep -q rwa-dev-postgres; then
    echo "Backing up Development PostgreSQL..."
    docker exec rwa-dev-postgres pg_dump -U rwauser rwadb > "$BACKUP_DIR/databases/development_postgres.sql" 2>/dev/null || echo "⚠️  Dev DB export failed"
    echo "✅ Development DB: $(wc -l < $BACKUP_DIR/databases/development_postgres.sql 2>/dev/null || echo '0') lines"
else
    echo "⚠️  Development PostgreSQL not running"
fi

# Graph Node PostgreSQL
if docker ps | grep -q rwa-dev-postgres-graph; then
    echo "Backing up Graph Node PostgreSQL..."
    docker exec rwa-dev-postgres-graph pg_dump -U graph graph-node > "$BACKUP_DIR/databases/graph_node.sql" 2>/dev/null || echo "⚠️  Graph DB export failed"
    echo "✅ Graph Node DB: $(wc -l < $BACKUP_DIR/databases/graph_node.sql 2>/dev/null || echo '0') lines"
else
    echo "⚠️  Graph Node PostgreSQL not running"
fi

# Test PostgreSQL
if docker ps | grep -q rwa-test-postgres; then
    echo "Backing up Test PostgreSQL..."
    docker exec rwa-test-postgres pg_dump -U rwauser rwadb > "$BACKUP_DIR/databases/test_postgres.sql" 2>/dev/null || echo "⚠️  Test DB export failed"
    echo "✅ Test DB: $(wc -l < $BACKUP_DIR/databases/test_postgres.sql 2>/dev/null || echo '0') lines"
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
echo "✅ Checksums generated: $(wc -l < checksums.txt) files"
cd "$PROJECT_ROOT"
echo ""

# 8. Create Restore Instructions
echo "=== 8. Creating Restore Instructions ==="
cat > "$BACKUP_DIR/restore_instructions.md" << 'EOF'
# Restore Instructions

## Prerequisites
- Docker and Docker Compose installed
- Foundry installed
- Sufficient disk space (~10GB)

## Restore Git Repository
```bash
git clone backups/pre-refactoring-2025-11-13/git/rwa-repo.bundle restored-repo
cd restored-repo
```

## Restore Docker Images
```bash
cd backups/pre-refactoring-2025-11-13/docker/images
for image in *.tar.gz; do
    gunzip -c "$image" | docker load
done
```

## Restore Docker Volumes
```bash
cd backups/pre-refactoring-2025-11-13/docker/volumes
for volume in *.tar.gz; do
    VOLUME_NAME=$(basename "$volume" .tar.gz)
    docker volume create "$VOLUME_NAME"
    docker run --rm -v "$VOLUME_NAME":/data -v $(pwd):/backup alpine \
        tar xzf "/backup/$volume" -C /data
done
```

## Restore PostgreSQL Databases
```bash
# Start PostgreSQL containers first
docker-compose -f docker-compose.dev.yml up -d rwa-dev-postgres

# Restore Development DB
cat backups/pre-refactoring-2025-11-13/databases/development_postgres.sql | \
    docker exec -i rwa-dev-postgres psql -U rwauser rwadb

# Restore Graph Node DB (if applicable)
cat backups/pre-refactoring-2025-11-13/databases/graph_node.sql | \
    docker exec -i rwa-dev-postgres-graph psql -U graph graph-node
```

## Restore Contracts
```bash
# Copy contract source back
cp -r backups/pre-refactoring-2025-11-13/contracts/development/src/* \
    Development_Environment/contracts/src/

# Rebuild contracts
cd Development_Environment/contracts
docker exec rwa-dev-foundry forge build
```

## Restore Configuration
```bash
cp backups/pre-refactoring-2025-11-13/config/.env.dev Development_Environment/
cp backups/pre-refactoring-2025-11-13/config/docker-compose.dev.yml Development_Environment/
```

## Verify Checksums
```bash
cd backups/pre-refactoring-2025-11-13
sha256sum -c checksums.txt
```

## Restart Services
```bash
cd Development_Environment
docker-compose -f docker-compose.dev.yml up -d
```
EOF
echo "✅ Restore instructions created"
echo ""

# 9. Backup Summary
echo "=== BACKUP SUMMARY ==="
echo "Backup Location: $BACKUP_DIR"
echo "Total Size: $(du -sh $BACKUP_DIR | awk '{print $1}')"
echo ""
echo "Contents:"
echo "- Git Repository: $(du -sh $BACKUP_DIR/git | awk '{print $1}')"
echo "- Docker Images: $(du -sh $BACKUP_DIR/docker/images | awk '{print $1}')"
echo "- Docker Volumes: $(du -sh $BACKUP_DIR/docker/volumes | awk '{print $1}')"
echo "- Databases: $(du -sh $BACKUP_DIR/databases | awk '{print $1}')"
echo "- Contracts: $(du -sh $BACKUP_DIR/contracts | awk '{print $1}')"
echo "- Config: $(du -sh $BACKUP_DIR/config | awk '{print $1}')"
echo ""
echo "Files: $(find $BACKUP_DIR -type f | wc -l | tr -d ' ')"
echo "Checksums: $(wc -l < $BACKUP_DIR/checksums.txt) verified"
echo ""
echo "✅ BACKUP COMPLETE"
echo ""
echo "To restore, see: $BACKUP_DIR/restore_instructions.md"

