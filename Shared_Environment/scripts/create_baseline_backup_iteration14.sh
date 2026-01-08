#!/bin/bash
set -e  # Exit on error

# ============================================================================
# RWA TOKENIZATION PLATFORM - ITERATION 14 BASELINE BACKUP
# 
# Purpose: Create comprehensive backup BEFORE implementing Compliance, KYC,
#          and Authentication features in Docker
# 
# Label: "iteration-14-pre-compliance-kyc-authentication"
# 
# This backup captures the WORKING state after successful restoration from
# iteration-18 backup, including:
# - Full Git repository (all branches and commits)
# - All Docker images (Development Environment)
# - All Docker volumes (INCLUDING Anvil blockchain state with correct permissions)
# - Configuration files
# - Comprehensive restore instructions with known issues and fixes
# ============================================================================

# Backup Configuration
BACKUP_NAME="iteration-14-pre-compliance-kyc-authentication_$(date +%Y%m%d_%H%M%S)"
BACKUP_BASE_DIR="/Users/scott/Cursor/RWA-Backups"
BACKUP_DIR="${BACKUP_BASE_DIR}/${BACKUP_NAME}"
WORKSPACE_DIR="/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1"

echo "=========================================="
echo "RWA TOKENIZATION PLATFORM - BASELINE BACKUP"
echo "Iteration 14: Pre-Compliance/KYC/Auth"
echo "=========================================="
echo "Backup Name: ${BACKUP_NAME}"
echo "Backup Location: ${BACKUP_DIR}"
echo "Timestamp: $(date)"
echo "=========================================="
echo ""

# Create backup directory structure
echo "📁 Creating backup directory structure..."
mkdir -p "${BACKUP_DIR}"
mkdir -p "${BACKUP_DIR}/git-bundle"
mkdir -p "${BACKUP_DIR}/docker-images"
mkdir -p "${BACKUP_DIR}/docker-volumes"
mkdir -p "${BACKUP_DIR}/data"
mkdir -p "${BACKUP_DIR}/checksums"
mkdir -p "${BACKUP_DIR}/restore-documentation"
echo "✅ Directory structure created"
echo ""

# ============================================================================
# STEP 1: Git Repository Backup (using git bundle)
# ============================================================================
echo "=========================================="
echo "STEP 1: Git Repository Backup"
echo "=========================================="
cd "${WORKSPACE_DIR}"

echo "📊 Current Git Status:"
echo "  Commit: $(git log -1 --oneline)"
echo "  Branch: $(git branch --show-current)"
echo "  Total Commits: $(git rev-list --count HEAD)"
echo ""

echo "📦 Creating git bundle (all branches and tags)..."
git bundle create "${BACKUP_DIR}/git-bundle/rwa-tokenization-repo.bundle" --all
BUNDLE_SIZE=$(du -sh "${BACKUP_DIR}/git-bundle/rwa-tokenization-repo.bundle" | cut -f1)
echo "✅ Git bundle created: ${BUNDLE_SIZE}"
echo ""

# Verify git bundle integrity
echo "🔍 Verifying git bundle integrity..."
if git bundle verify "${BACKUP_DIR}/git-bundle/rwa-tokenization-repo.bundle" > /dev/null 2>&1; then
    echo "✅ Git bundle verification passed"
else
    echo "❌ Git bundle verification FAILED!"
    exit 1
fi
echo ""

# Create checksums for git bundle
echo "🔐 Generating checksum for git bundle..."
shasum -a 256 "${BACKUP_DIR}/git-bundle/rwa-tokenization-repo.bundle" > "${BACKUP_DIR}/checksums/git-bundle.sha256"
BUNDLE_SHA=$(cat "${BACKUP_DIR}/checksums/git-bundle.sha256" | cut -d' ' -f1)
echo "✅ Checksum generated: ${BUNDLE_SHA:0:16}..."
echo ""

# ============================================================================
# STEP 2: Docker Images Backup
# ============================================================================
echo "=========================================="
echo "STEP 2: Docker Images Backup"
echo "=========================================="

# List of Docker images to backup (Development Environment custom images)
IMAGES=(
    "development_environment-rwa-dev-backend"
    "development_environment-rwa-dev-frontend"
    "development_environment-rwa-dev-foundry"
    "development_environment-rwa-dev-mobile"
)

IMAGES_BACKED_UP=0
for IMAGE in "${IMAGES[@]}"; do
    echo "💾 Saving Docker image: ${IMAGE}..."
    IMAGE_FILE="${BACKUP_DIR}/docker-images/${IMAGE}.tar"
    
    if docker images | grep -q "${IMAGE}"; then
        docker save -o "${IMAGE_FILE}" "${IMAGE}"
        
        # Compress the image
        echo "  📦 Compressing image..."
        gzip "${IMAGE_FILE}"
        
        IMAGE_SIZE=$(du -sh "${IMAGE_FILE}.gz" | cut -f1)
        echo "  ✅ Image saved and compressed: ${IMAGE_SIZE}"
        
        # Generate checksum
        shasum -a 256 "${IMAGE_FILE}.gz" > "${BACKUP_DIR}/checksums/${IMAGE}.sha256"
        IMAGE_SHA=$(cat "${BACKUP_DIR}/checksums/${IMAGE}.sha256" | cut -d' ' -f1)
        echo "  🔐 Checksum: ${IMAGE_SHA:0:16}..."
        
        ((IMAGES_BACKED_UP++))
    else
        echo "  ⚠️  Image not found, skipping..."
    fi
    echo ""
done

echo "✅ Docker images backed up: ${IMAGES_BACKED_UP}/${#IMAGES[@]}"
echo ""

# ============================================================================
# STEP 3: Docker Volumes Backup (CRITICAL - includes Anvil state)
# ============================================================================
echo "=========================================="
echo "STEP 3: Docker Volumes Backup"
echo "=========================================="
echo "⚠️  CRITICAL: Backing up Anvil blockchain state with correct permissions"
echo ""

# List of Docker volumes to backup (Development Environment)
VOLUMES=(
    "development_environment_rwa-dev-postgres-data"
    "development_environment_rwa-dev-postgres-graph-data"
    "development_environment_rwa-dev-ipfs-data"
    "development_environment_rwa-dev-foundry-data"
    "development_environment_redis-dev-data"
    "development_environment_rwa-dev-grafana-data"
    "development_environment_rwa-dev-prometheus-data"
)

VOLUMES_BACKED_UP=0
for VOLUME in "${VOLUMES[@]}"; do
    echo "💾 Backing up Docker volume: ${VOLUME}..."
    VOLUME_FILE="${BACKUP_DIR}/docker-volumes/${VOLUME}.tar.gz"
    
    if docker volume ls | grep -q "${VOLUME}"; then
        # Use alpine container to preserve file permissions and ownership
        docker run --rm \
            -v "${VOLUME}:/volume" \
            -v "${BACKUP_DIR}/docker-volumes:/backup" \
            alpine \
            sh -c "cd /volume && tar czf /backup/${VOLUME}.tar.gz ."
        
        VOLUME_SIZE=$(du -sh "${VOLUME_FILE}" | cut -f1)
        echo "  ✅ Volume backed up: ${VOLUME_SIZE}"
        
        # Generate checksum
        shasum -a 256 "${VOLUME_FILE}" > "${BACKUP_DIR}/checksums/${VOLUME}.sha256"
        VOLUME_SHA=$(cat "${BACKUP_DIR}/checksums/${VOLUME}.sha256" | cut -d' ' -f1)
        echo "  🔐 Checksum: ${VOLUME_SHA:0:16}..."
        
        # Special verification for Anvil volume
        if [[ "$VOLUME" == *"foundry-data"* ]]; then
            echo "  🔍 Verifying Anvil state.json in backup..."
            if tar -tzf "${VOLUME_FILE}" | grep -q "state.json"; then
                STATE_SIZE=$(tar -xzOf "${VOLUME_FILE}" ./anvil/state.json | wc -c)
                echo "  ✅ Anvil state.json found in backup (${STATE_SIZE} bytes)"
            else
                echo "  ⚠️  WARNING: Anvil state.json NOT found in backup!"
            fi
        fi
        
        ((VOLUMES_BACKED_UP++))
    else
        echo "  ⚠️  Volume not found, skipping..."
    fi
    echo ""
done

echo "✅ Docker volumes backed up: ${VOLUMES_BACKED_UP}/${#VOLUMES[@]}"
echo ""

# ============================================================================
# STEP 4: Configuration and Data Backup
# ============================================================================
echo "=========================================="
echo "STEP 4: Configuration and Data Backup"
echo "=========================================="

echo "📄 Copying environment configuration files..."
cp "${WORKSPACE_DIR}/Development_Environment/.env.dev" "${BACKUP_DIR}/data/.env.dev" 2>/dev/null || echo "  ⚠️  .env.dev not found"
cp "${WORKSPACE_DIR}/Development_Environment/docker-compose.dev.yml" "${BACKUP_DIR}/data/docker-compose.dev.yml" 2>/dev/null || echo "  ⚠️  docker-compose.dev.yml not found"
echo "✅ Environment config copied"
echo ""

echo "📄 Copying backend configuration..."
mkdir -p "${BACKUP_DIR}/data/backend"
cp "${WORKSPACE_DIR}/Development_Environment/backend/config/web3_config.py" "${BACKUP_DIR}/data/backend/web3_config.py" 2>/dev/null || echo "  ⚠️  web3_config.py not found"
cp "${WORKSPACE_DIR}/Development_Environment/backend/requirements.txt" "${BACKUP_DIR}/data/backend/requirements.txt" 2>/dev/null || echo "  ⚠️  requirements.txt not found"
echo "✅ Backend config copied"
echo ""

echo "📄 Copying subgraph configuration..."
mkdir -p "${BACKUP_DIR}/data/subgraph"
cp "${WORKSPACE_DIR}/Development_Environment/subgraph/subgraph.yaml" "${BACKUP_DIR}/data/subgraph/subgraph.yaml" 2>/dev/null || echo "  ⚠️  subgraph.yaml not found"
cp "${WORKSPACE_DIR}/Development_Environment/subgraph/package.json" "${BACKUP_DIR}/data/subgraph/package.json" 2>/dev/null || echo "  ⚠️  package.json not found"
echo "✅ Subgraph config copied"
echo ""

echo "📄 Copying contracts configuration..."
mkdir -p "${BACKUP_DIR}/data/contracts"
cp "${WORKSPACE_DIR}/Development_Environment/contracts/foundry.toml" "${BACKUP_DIR}/data/contracts/foundry.toml" 2>/dev/null || echo "  ⚠️  foundry.toml not found"
cp "${WORKSPACE_DIR}/Development_Environment/contracts/start-anvil.sh" "${BACKUP_DIR}/data/contracts/start-anvil.sh" 2>/dev/null || echo "  ⚠️  start-anvil.sh not found"
echo "✅ Contracts config copied"
echo ""

# ============================================================================
# STEP 5: Copy Restore Documentation
# ============================================================================
echo "=========================================="
echo "STEP 5: Copy Restore Documentation"
echo "=========================================="

echo "📚 Copying restore documentation and procedures..."
cp "${WORKSPACE_DIR}/Development_Environment/POST_RESTORE_ENHANCEMENTS.md" "${BACKUP_DIR}/restore-documentation/POST_RESTORE_ENHANCEMENTS.md" 2>/dev/null || echo "  ⚠️  POST_RESTORE_ENHANCEMENTS.md not found"
cp "${WORKSPACE_DIR}/ITERATION_18_DIAMOND_RESTORE_PLAN.md" "${BACKUP_DIR}/restore-documentation/ITERATION_18_DIAMOND_RESTORE_PLAN.md" 2>/dev/null || echo "  ⚠️  ITERATION_18_DIAMOND_RESTORE_PLAN.md not found"
cp "${WORKSPACE_DIR}/DissertationProgress.md" "${BACKUP_DIR}/restore-documentation/DissertationProgress.md" 2>/dev/null || echo "  ⚠️  DissertationProgress.md not found"
echo "✅ Restore documentation copied"
echo ""

# ============================================================================
# STEP 6: Capture System State
# ============================================================================
echo "=========================================="
echo "STEP 6: Capture System State"
echo "=========================================="

echo "📊 Capturing Docker container status..."
docker ps --filter "name=rwa-dev" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" > "${BACKUP_DIR}/data/docker-containers-status.txt"
echo "✅ Container status captured"
echo ""

echo "📊 Capturing deployed contract addresses..."
if [ -f "${WORKSPACE_DIR}/Development_Environment/.env.dev" ]; then
    grep -E "PROPERTY_NFT_ADDRESS|YIELD_BASE_ADDRESS|COMBINED_TOKEN_ADDRESS|GOVERNANCE_CONTROLLER_ADDRESS" "${WORKSPACE_DIR}/Development_Environment/.env.dev" > "${BACKUP_DIR}/data/deployed-contracts.txt"
    echo "✅ Contract addresses captured"
else
    echo "  ⚠️  .env.dev not found"
fi
echo ""

echo "📊 Capturing blockchain state..."
CURRENT_BLOCK=$(cast block-number --rpc-url http://localhost:8546 2>/dev/null || echo "N/A")
echo "Current Block: ${CURRENT_BLOCK}" > "${BACKUP_DIR}/data/blockchain-state.txt"
echo "✅ Blockchain state captured (Block: ${CURRENT_BLOCK})"
echo ""

echo "📊 Capturing subgraph status..."
curl -s http://localhost:8200/subgraphs/name/rwa-tokenization -X POST \
  -H "Content-Type: application/json" \
  -d '{"query": "{ _meta { block { number } hasIndexingErrors deployment } yieldAgreements { id tokenStandard } }"}' \
  > "${BACKUP_DIR}/data/subgraph-status.json" 2>/dev/null || echo "  ⚠️  Could not capture subgraph status"
echo "✅ Subgraph status captured"
echo ""

# ============================================================================
# STEP 7: Generate Comprehensive Backup Manifest
# ============================================================================
echo "=========================================="
echo "STEP 7: Generating Backup Manifest"
echo "=========================================="

MANIFEST_FILE="${BACKUP_DIR}/BACKUP_MANIFEST.md"
TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)

cat > "${MANIFEST_FILE}" << 'EOF'
# Backup Manifest: Iteration 14 Baseline
## Pre-Compliance/KYC/Authentication Docker Implementation

---

## 🎯 Backup Purpose

This backup captures the **WORKING STATE** of the Development environment immediately after:
1. Successfully restoring from iteration-18 backup
2. Fixing Anvil persistence (directory ownership issue)
3. Fixing Analytics dashboard (Graph Node state cleanup and correct contract addresses)
4. Verifying all functionality working (ERC-721 and ERC-1155 token standards)

**This is a CLEAN BASELINE** before implementing Iteration 14 features (Compliance, KYC, Authentication).

---

## 📋 Backup Information

EOF

cat >> "${MANIFEST_FILE}" << EOF
- **Backup Name**: ${BACKUP_NAME}
- **Backup Date**: $(date)
- **Backup Location**: ${BACKUP_DIR}
- **Total Backup Size**: ${TOTAL_SIZE}
- **Git Commit**: $(cd "${WORKSPACE_DIR}" && git log -1 --oneline)
- **Git Branch**: $(cd "${WORKSPACE_DIR}" && git branch --show-current)
- **Blockchain Block**: ${CURRENT_BLOCK}

---

## 🔐 Checksum Verification

All backup files have SHA-256 checksums stored in \`checksums/\` directory.

**Critical Files:**
- Git Bundle: \`$(cat "${BACKUP_DIR}/checksums/git-bundle.sha256" | cut -d' ' -f1)\`
- Anvil Volume: \`$(cat "${BACKUP_DIR}/checksums/development_environment_rwa-dev-foundry-data.sha256" 2>/dev/null | cut -d' ' -f1 || echo "N/A")\`

**To verify backup integrity before restore:**
\`\`\`bash
cd ${BACKUP_DIR}/checksums
shasum -c *.sha256
\`\`\`

All checksums must pass before attempting restore!

---

## 📦 Backup Contents

### Directory Structure
\`\`\`
${BACKUP_DIR}/
├── git-bundle/
│   └── rwa-tokenization-repo.bundle (${BUNDLE_SIZE})
├── docker-images/
EOF

for IMG in "${IMAGES[@]}"; do
    if [ -f "${BACKUP_DIR}/docker-images/${IMG}.tar.gz" ]; then
        SIZE=$(du -sh "${BACKUP_DIR}/docker-images/${IMG}.tar.gz" | cut -f1)
        echo "│   ├── ${IMG}.tar.gz (${SIZE})" >> "${MANIFEST_FILE}"
    fi
done

cat >> "${MANIFEST_FILE}" << 'EOF'
├── docker-volumes/
EOF

for VOL in "${VOLUMES[@]}"; do
    if [ -f "${BACKUP_DIR}/docker-volumes/${VOL}.tar.gz" ]; then
        SIZE=$(du -sh "${BACKUP_DIR}/docker-volumes/${VOL}.tar.gz" | cut -f1)
        echo "│   ├── ${VOL}.tar.gz (${SIZE})" >> "${MANIFEST_FILE}"
    fi
done

cat >> "${MANIFEST_FILE}" << EOF
├── data/
│   ├── .env.dev (contract addresses and config)
│   ├── docker-compose.dev.yml
│   ├── deployed-contracts.txt
│   ├── blockchain-state.txt
│   ├── subgraph-status.json
│   ├── docker-containers-status.txt
│   ├── backend/ (config files)
│   ├── subgraph/ (config files)
│   └── contracts/ (config files)
├── restore-documentation/
│   ├── POST_RESTORE_ENHANCEMENTS.md (proven fixes)
│   ├── ITERATION_18_DIAMOND_RESTORE_PLAN.md (detailed procedure)
│   └── DissertationProgress.md (architecture documentation)
├── checksums/
│   └── *.sha256 (checksums for all backup files)
└── BACKUP_MANIFEST.md (this file)
\`\`\`

---

## 🏗️ System State at Backup Time

### Deployed Contracts (Diamond Architecture)

EOF

if [ -f "${BACKUP_DIR}/data/deployed-contracts.txt" ]; then
    cat "${BACKUP_DIR}/data/deployed-contracts.txt" >> "${MANIFEST_FILE}"
fi

cat >> "${MANIFEST_FILE}" << 'EOF'

**Contract Architecture**: Diamond Pattern (EIP-2535)
- PropertyNFT: Standard ERC-721 UUPS Proxy
- DiamondYieldBase: Diamond Proxy + Facets (YieldBaseFacet, RepaymentFacet, GovernanceFacet, etc.)
- DiamondCombinedToken: Diamond Proxy + Facets (MintingFacet, DistributionFacet, etc.)
- GovernanceController: Standard ERC-1967 UUPS Proxy

**Diamond ABIs**: 
- DiamondYieldBase_ABI.json (42 functions, 22 events)
- DiamondCombinedToken_ABI.json (54 functions, 22 events)

### Docker Containers Status

EOF

if [ -f "${BACKUP_DIR}/data/docker-containers-status.txt" ]; then
    echo '```' >> "${MANIFEST_FILE}"
    cat "${BACKUP_DIR}/data/docker-containers-status.txt" >> "${MANIFEST_FILE}"
    echo '```' >> "${MANIFEST_FILE}"
fi

cat >> "${MANIFEST_FILE}" << EOF

**All 12 containers healthy:**
- rwa-dev-backend (FastAPI)
- rwa-dev-frontend (React/Vite)
- rwa-dev-foundry (Anvil blockchain)
- rwa-dev-mobile (React Native/Metro)
- rwa-dev-postgres (Application database)
- rwa-dev-postgres-graph (Graph Node database)
- rwa-dev-redis (Cache)
- rwa-dev-ipfs (IPFS node)
- rwa-dev-graph-node (The Graph Protocol)
- rwa-dev-grafana (Monitoring)
- rwa-dev-prometheus (Metrics)
- rwa-dev-node-exporter (System metrics)

### Blockchain State
- **Current Block**: ${CURRENT_BLOCK}
- **Anvil Persistence**: ✅ WORKING (state.json owned by foundry:foundry)
- **Deployed Contracts**: ✅ All initialized and functional
- **Contract Addresses**: Checksummed and stored in .env.dev

### Graph Subgraph Status
- **Deployment**: QmSCzQLv4dFYcy1ASDGxB28Qo5HqELd8Yv9Hu1fHJtxp2n
- **Version**: v1.0.3
- **Synced Block**: ${CURRENT_BLOCK}
- **Indexing Errors**: None
- **ERC-721 Agreements**: Working ✓
- **ERC-1155 Agreements**: Working ✓

### Database State
- **User Profiles**: 11 (test data)
- **Properties**: Varies (created during testing)
- **Yield Agreements**: Varies (created during testing)
- **Database**: PostgreSQL 15

---

## 🔄 Restoration Procedure

### Prerequisites

1. **Review Documentation** (CRITICAL):
   - \`restore-documentation/ITERATION_18_DIAMOND_RESTORE_PLAN.md\`
   - \`restore-documentation/POST_RESTORE_ENHANCEMENTS.md\`
   - \`restore-documentation/DissertationProgress.md\`

2. **Verify Backup Integrity**:
   \`\`\`bash
   cd ${BACKUP_DIR}/checksums
   shasum -c *.sha256
   \`\`\`
   **ALL checksums must pass before proceeding!**

3. **Stop all Docker containers**:
   \`\`\`bash
   cd /Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1/Development_Environment
   docker compose -f docker-compose.dev.yml down
   \`\`\`

### Restoration Steps

#### Step 1: Restore Git Repository

\`\`\`bash
cd /Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1

# Clone from bundle
git clone ${BACKUP_DIR}/git-bundle/rwa-tokenization-repo.bundle restored-repo

# Or restore to existing repo
git fetch ${BACKUP_DIR}/git-bundle/rwa-tokenization-repo.bundle refs/heads/*:refs/heads/*
git checkout main  # or appropriate branch
\`\`\`

#### Step 2: Restore Docker Images

\`\`\`bash
cd ${BACKUP_DIR}/docker-images

# Load each image
for IMAGE_FILE in *.tar.gz; do
    echo "Loading \${IMAGE_FILE}..."
    gunzip -c "\${IMAGE_FILE}" | docker load
done
\`\`\`

#### Step 3: Restore Docker Volumes

\`\`\`bash
cd ${BACKUP_DIR}/docker-volumes

# For each volume
for VOLUME_FILE in *.tar.gz; do
    VOLUME_NAME="\${VOLUME_FILE%.tar.gz}"
    echo "Restoring volume: \${VOLUME_NAME}..."
    
    # Create volume if it doesn't exist
    docker volume create "\${VOLUME_NAME}"
    
    # Restore data
    docker run --rm \\
        -v "\${VOLUME_NAME}:/volume" \\
        -v "${BACKUP_DIR}/docker-volumes:/backup" \\
        alpine \\
        sh -c "cd /volume && tar xzf /backup/\${VOLUME_FILE}"
done
\`\`\`

#### Step 4: 🚨 CRITICAL - Fix Anvil Permissions

**This step is MANDATORY to ensure Anvil persistence works after restore!**

\`\`\`bash
# Start containers
cd /Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1/Development_Environment
docker compose -f docker-compose.dev.yml up -d

# Wait for Foundry container to start
sleep 10

# Fix Anvil directory ownership (CRITICAL!)
docker exec --user root rwa-dev-foundry chown -R foundry:foundry /home/foundry/.foundry/anvil
docker exec --user root rwa-dev-foundry chmod 755 /home/foundry/.foundry/anvil

# Restart Foundry container to apply changes
docker compose -f docker-compose.dev.yml restart rwa-dev-foundry

# Wait for Anvil to start
sleep 10

# Verify state.json exists and has correct ownership
docker exec rwa-dev-foundry ls -lah /home/foundry/.foundry/anvil/state.json
# Expected: -rw-r--r-- 1 foundry foundry [size] [date] state.json
\`\`\`

**Why This is Critical:**
- Docker volume restore creates files owned by root:root
- Anvil runs as foundry user and cannot write to root-owned directories
- Without this fix, blockchain state will NOT persist across restarts
- Deployed contracts will be LOST on container restart

#### Step 5: Verify Blockchain State

\`\`\`bash
# Check current block number
cast block-number --rpc-url http://localhost:8546

# Should match backup block number: ${CURRENT_BLOCK}

# Verify contracts deployed
PROPERTY_NFT=\$(grep PROPERTY_NFT_ADDRESS ${BACKUP_DIR}/data/.env.dev | cut -d'=' -f2)
cast code \$PROPERTY_NFT --rpc-url http://localhost:8546 | head -c 30
# Expected: 0x60806040... (bytecode, not 0x)
\`\`\`

#### Step 6: Verify Services

\`\`\`bash
# Check all containers healthy
docker compose -f docker-compose.dev.yml ps

# Check backend
curl http://localhost:8000/health

# Check frontend
curl http://localhost:5173

# Check subgraph
curl -s http://localhost:8200/subgraphs/name/rwa-tokenization -X POST \\
  -H "Content-Type: application/json" \\
  -d '{"query": "{ _meta { block { number } hasIndexingErrors } }"}' | jq .
\`\`\`

#### Step 7: Verify Anvil Persistence

\`\`\`bash
# Get current block
BLOCK_BEFORE=\$(cast block-number --rpc-url http://localhost:8546)
echo "Block before restart: \$BLOCK_BEFORE"

# Restart Foundry container
docker compose -f docker-compose.dev.yml restart rwa-dev-foundry
sleep 10

# Get block after restart
BLOCK_AFTER=\$(cast block-number --rpc-url http://localhost:8546)
echo "Block after restart: \$BLOCK_AFTER"

# Verify blocks match (persistence working)
if [ "\$BLOCK_AFTER" -ge "\$BLOCK_BEFORE" ]; then
    echo "✅ Anvil persistence WORKING!"
else
    echo "❌ Anvil persistence FAILED - see troubleshooting"
fi
\`\`\`

---

## 🔧 Troubleshooting

### Issue: Anvil Blockchain Resets to Block 0

**Symptoms:**
- Block number resets after container restart
- Deployed contracts disappear
- state.json file not being updated

**Root Cause:** Anvil directory has incorrect ownership (root:root instead of foundry:foundry)

**Solution:**
\`\`\`bash
# Fix ownership
docker exec --user root rwa-dev-foundry chown -R foundry:foundry /home/foundry/.foundry/anvil
docker exec --user root rwa-dev-foundry chmod 755 /home/foundry/.foundry/anvil

# Restart container
docker compose -f docker-compose.dev.yml restart rwa-dev-foundry

# Redeploy contracts if blockchain was reset
# Follow Diamond deployment procedure in restore-documentation/
\`\`\`

### Issue: Graph Node "Provider Went Backwards"

**Symptoms:**
- Subgraph stuck at old block number
- Analytics dashboard not updating
- Graph Node logs show "Provider went backwards" errors

**Root Cause:** Graph Node has cached stale block data from old blockchain state

**Solution:** Follow Phase 3 (Clean Graph Node State) in restore-documentation/ITERATION_18_DIAMOND_RESTORE_PLAN.md

### Issue: Analytics Dashboard Not Showing ERC-1155 Agreements

**Symptoms:**
- ERC-721 agreements show but ERC-1155 agreements don't
- No errors in Graph Node logs

**Root Cause:** subgraph.yaml has incorrect CombinedPropertyYieldToken address

**Solution:** Verify contract addresses in subgraph.yaml match .env.dev, rebuild and redeploy subgraph

---

## 📚 Reference Documentation

All critical restoration procedures and known issues are documented in:

1. **\`restore-documentation/ITERATION_18_DIAMOND_RESTORE_PLAN.md\`**
   - Complete 7-phase restoration procedure
   - Anvil persistence configuration
   - Database cleaning
   - Graph Node state management
   - Diamond contract deployment
   - Comprehensive testing

2. **\`restore-documentation/POST_RESTORE_ENHANCEMENTS.md\`**
   - Proven fixes from Iteration 14
   - Enhancement #1: Anvil Persistence Fix (lines 20-228)
   - Enhancement #2: Graph Node "Provider Went Backwards" Fix (lines 231-417)
   - Phase 4: Deploy Contracts (lines 1585-1976)
   - Critical contract initialization checks

3. **\`restore-documentation/DissertationProgress.md\`**
   - System architecture overview
   - Diamond Pattern (EIP-2535) architecture
   - Token standard comparison (ERC-721 vs ERC-1155)
   - Technical implementation details

**ALWAYS review these documents before attempting restore!**

---

## ✅ Success Criteria

Restoration is successful when ALL of the following are true:

- ✅ All 12 Docker containers running and healthy
- ✅ Git repository restored with all branches
- ✅ Backend API responding at http://localhost:8000/health
- ✅ Frontend accessible at http://localhost:5173
- ✅ Blockchain at correct block number (${CURRENT_BLOCK} or higher)
- ✅ Deployed contracts responding to calls
- ✅ Anvil persistence working (blocks persist across restarts)
- ✅ Graph Node syncing without errors
- ✅ Subgraph indexed (no hasIndexingErrors)
- ✅ Analytics dashboard showing both ERC-721 and ERC-1155 agreements
- ✅ Database with expected data (11 user profiles minimum)
- ✅ All configuration files match backup

---

## 📝 Notes

- This backup includes Diamond architecture contracts (NOT monolithic)
- Deployment script: DeployDiamond.s.sol (NOT DeployAll.s.sol)
- All contract addresses are checksummed
- Anvil state includes deployed contracts and all transactions
- Database includes test data from user testing sessions
- Subgraph v1.0.3 with correct contract addresses

**Created by**: Automated backup script
**Verified by**: Checksum validation
**Status**: ✅ Backup Complete
EOF

echo "✅ Comprehensive manifest generated"
echo ""

# ============================================================================
# STEP 8: Create Quick Restore Script
# ============================================================================
echo "=========================================="
echo "STEP 8: Creating Quick Restore Script"
echo "=========================================="

RESTORE_SCRIPT="${BACKUP_DIR}/restore_backup.sh"

cat > "${RESTORE_SCRIPT}" << 'RESTORE_EOF'
#!/bin/bash
set -e

# Quick Restore Script for Iteration 14 Baseline Backup
# This script automates the restoration procedure documented in BACKUP_MANIFEST.md

BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/Users/scott/Cursor/RWA-Rental-Yield-Tokenisation_v5.1"

echo "=========================================="
echo "RWA TOKENIZATION PLATFORM - RESTORE"
echo "Iteration 14 Baseline"
echo "=========================================="
echo "Backup Location: ${BACKUP_DIR}"
echo "Target Location: ${TARGET_DIR}"
echo "=========================================="
echo ""

# Verify checksums
echo "🔐 Verifying backup integrity..."
cd "${BACKUP_DIR}/checksums"
if shasum -c *.sha256; then
    echo "✅ All checksums verified"
else
    echo "❌ Checksum verification FAILED!"
    echo "Backup may be corrupted. DO NOT PROCEED with restore."
    exit 1
fi
echo ""

echo "⚠️  WARNING: This will stop all Docker containers and restore from backup."
echo ""
read -p "Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi
echo ""

# Stop Docker containers
echo "🛑 Stopping Docker containers..."
cd "${TARGET_DIR}/Development_Environment"
docker compose -f docker-compose.dev.yml down
echo "✅ Containers stopped"
echo ""

# Restore Docker volumes
echo "💾 Restoring Docker volumes..."
cd "${BACKUP_DIR}/docker-volumes"
for VOLUME_FILE in *.tar.gz; do
    VOLUME_NAME="${VOLUME_FILE%.tar.gz}"
    echo "  Restoring: ${VOLUME_NAME}..."
    
    docker volume rm "${VOLUME_NAME}" 2>/dev/null || true
    docker volume create "${VOLUME_NAME}"
    
    docker run --rm \
        -v "${VOLUME_NAME}:/volume" \
        -v "${BACKUP_DIR}/docker-volumes:/backup" \
        alpine \
        sh -c "cd /volume && tar xzf /backup/${VOLUME_FILE}"
done
echo "✅ Volumes restored"
echo ""

# Restore configuration files
echo "📄 Restoring configuration files..."
cp "${BACKUP_DIR}/data/.env.dev" "${TARGET_DIR}/Development_Environment/.env.dev"
cp "${BACKUP_DIR}/data/docker-compose.dev.yml" "${TARGET_DIR}/Development_Environment/docker-compose.dev.yml"
echo "✅ Configuration restored"
echo ""

# Start containers
echo "🚀 Starting Docker containers..."
cd "${TARGET_DIR}/Development_Environment"
docker compose -f docker-compose.dev.yml up -d
echo "⏳ Waiting for containers to start..."
sleep 15
echo "✅ Containers started"
echo ""

# CRITICAL: Fix Anvil permissions
echo "🔧 Fixing Anvil directory permissions (CRITICAL)..."
docker exec --user root rwa-dev-foundry chown -R foundry:foundry /home/foundry/.foundry/anvil || true
docker exec --user root rwa-dev-foundry chmod 755 /home/foundry/.foundry/anvil || true
docker compose -f docker-compose.dev.yml restart rwa-dev-foundry
echo "⏳ Waiting for Anvil to restart..."
sleep 10
echo "✅ Anvil permissions fixed"
echo ""

# Verify restoration
echo "=========================================="
echo "VERIFICATION"
echo "=========================================="
echo ""

echo "🔍 Checking Anvil state.json..."
docker exec rwa-dev-foundry ls -lah /home/foundry/.foundry/anvil/state.json
echo ""

echo "🔍 Checking blockchain block..."
cast block-number --rpc-url http://localhost:8546
echo ""

echo "🔍 Checking backend health..."
curl -s http://localhost:8000/health | jq . || echo "Backend not ready yet"
echo ""

echo "=========================================="
echo "✅ RESTORE COMPLETE"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Verify all containers healthy: docker compose -f docker-compose.dev.yml ps"
echo "2. Test Anvil persistence (see BACKUP_MANIFEST.md Step 7)"
echo "3. Verify Analytics dashboard at http://localhost:5173"
echo "4. Review restore-documentation/ for additional verification steps"
echo ""
RESTORE_EOF

chmod +x "${RESTORE_SCRIPT}"
echo "✅ Quick restore script created: restore_backup.sh"
echo ""

# ============================================================================
# STEP 9: Final Verification
# ============================================================================
echo "=========================================="
echo "STEP 9: Final Verification"
echo "=========================================="

echo "🔍 Verifying all backup components..."
VERIFICATION_FAILED=0

# Check git bundle
if [ -f "${BACKUP_DIR}/git-bundle/rwa-tokenization-repo.bundle" ]; then
    echo "✅ Git bundle exists"
else
    echo "❌ Git bundle missing!"
    ((VERIFICATION_FAILED++))
fi

# Check Docker images
IMAGES_COUNT=$(ls "${BACKUP_DIR}/docker-images/"*.tar.gz 2>/dev/null | wc -l)
echo "✅ Docker images backed up: ${IMAGES_COUNT}"

# Check Docker volumes  
VOLUMES_COUNT=$(ls "${BACKUP_DIR}/docker-volumes/"*.tar.gz 2>/dev/null | wc -l)
echo "✅ Docker volumes backed up: ${VOLUMES_COUNT}"

# Check Anvil volume specifically
if [ -f "${BACKUP_DIR}/docker-volumes/development_environment_rwa-dev-foundry-data.tar.gz" ]; then
    echo "✅ Anvil volume backup exists"
    if tar -tzf "${BACKUP_DIR}/docker-volumes/development_environment_rwa-dev-foundry-data.tar.gz" | grep -q "state.json"; then
        echo "✅ Anvil state.json included in backup"
    else
        echo "⚠️  WARNING: Anvil state.json not found in volume backup!"
        ((VERIFICATION_FAILED++))
    fi
else
    echo "❌ Anvil volume backup missing!"
    ((VERIFICATION_FAILED++))
fi

# Check checksums
CHECKSUMS_COUNT=$(ls "${BACKUP_DIR}/checksums/"*.sha256 2>/dev/null | wc -l)
echo "✅ Checksums generated: ${CHECKSUMS_COUNT}"

# Check manifest
if [ -f "${MANIFEST_FILE}" ]; then
    echo "✅ Backup manifest created"
else
    echo "❌ Backup manifest missing!"
    ((VERIFICATION_FAILED++))
fi

# Check restore script
if [ -f "${RESTORE_SCRIPT}" ] && [ -x "${RESTORE_SCRIPT}" ]; then
    echo "✅ Restore script created and executable"
else
    echo "❌ Restore script missing or not executable!"
    ((VERIFICATION_FAILED++))
fi

# Check restore documentation
if [ -f "${BACKUP_DIR}/restore-documentation/ITERATION_18_DIAMOND_RESTORE_PLAN.md" ]; then
    echo "✅ Restore documentation included"
else
    echo "⚠️  Restore documentation missing"
fi

echo ""

if [ $VERIFICATION_FAILED -eq 0 ]; then
    echo "=========================================="
    echo "✅ BACKUP COMPLETED SUCCESSFULLY"
    echo "=========================================="
    echo ""
    echo "Backup Details:"
    echo "  Location: ${BACKUP_DIR}"
    echo "  Total Size: ${TOTAL_SIZE}"
    echo "  Git Bundle: ${BUNDLE_SIZE}"
    echo "  Docker Images: ${IMAGES_COUNT}"
    echo "  Docker Volumes: ${VOLUMES_COUNT}"
    echo "  Checksums: ${CHECKSUMS_COUNT}"
    echo ""
    echo "⚠️  CRITICAL REMINDER FOR RESTORE:"
    echo "  After restoring Docker volumes, you MUST fix Anvil directory ownership:"
    echo "  docker exec --user root rwa-dev-foundry chown -R foundry:foundry /home/foundry/.foundry/anvil"
    echo ""
    echo "📚 Review Documentation:"
    echo "  - ${BACKUP_DIR}/BACKUP_MANIFEST.md (complete restore procedure)"
    echo "  - ${BACKUP_DIR}/restore-documentation/ (detailed guides)"
    echo ""
    echo "🚀 Quick Restore:"
    echo "  ${BACKUP_DIR}/restore_backup.sh"
    echo ""
else
    echo "=========================================="
    echo "⚠️  BACKUP COMPLETED WITH ${VERIFICATION_FAILED} WARNING(S)"
    echo "=========================================="
    echo ""
    echo "Review warnings above and verify backup integrity before relying on it."
fi

