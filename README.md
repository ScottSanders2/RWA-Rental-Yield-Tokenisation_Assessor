# RWA Tokenisation Platform - Real Estate Rental Yield Tokenisation Prototype

This repository contains the prototype implementation for an MSc Financial Technology dissertation on blockchain-based tokenisation of real estate rental yields. The platform enables fractional ownership of rental income streams through a hybrid token system (ERC-20, ERC-721, ERC-1155), addressing traditional financing inefficiencies for underserved landlords.

**GitHub Repository:** https://github.com/ScottSanders2/RWA-Rental-Yield-Tokenisation_Assessor

---

## ⚠️ For Assessors: Extracting the Split Archive

If you received this repository as split zip files (`RWA_Platform_Complete.z01`, `.z02`, etc.), follow these instructions to extract:

### Prerequisites
- All split archive files must be in the same directory
- Files required: `RWA_Platform_Complete.z01` through `RWA_Platform_Complete.z07` AND `RWA_Platform_Complete.zip`

### Extraction Instructions

**On macOS/Linux:**
```bash
# Navigate to the directory containing all zip parts
cd /path/to/zip/files

# Combine and extract using zip command
zip -s 0 RWA_Platform_Complete.zip --out RWA_Platform_Combined.zip
unzip RWA_Platform_Combined.zip

# Or use a single command (requires all parts present)
unzip RWA_Platform_Complete.zip
```

**On Windows:**
```powershell
# Option 1: Use 7-Zip (recommended, free download from https://www.7-zip.org/)
# Right-click on RWA_Platform_Complete.zip → 7-Zip → Extract Here

# Option 2: Use PowerShell with 7-Zip CLI
& "C:\Program Files\7-Zip\7z.exe" x RWA_Platform_Complete.zip

# Option 3: Use WinRAR
# Right-click on RWA_Platform_Complete.zip → Extract Here
```

**Using 7-Zip (Cross-Platform):**
```bash
# 7-Zip automatically detects split archives
7z x RWA_Platform_Complete.zip
```

### After Extraction

Once extracted, you will have the complete repository structure. Continue with the "Quick Start for Assessors" section below.

### Archive Contents

| Part | Size | Description |
|------|------|-------------|
| RWA_Platform_Complete.z01 | 450 MB | Part 1 of 2 |
| RWA_Platform_Complete.zip | 83 MB | Part 2 of 2 (main file) |
| **Total** | **533 MB** | Complete platform with all environments |

**Excludes:** 
- node_modules, __pycache__, .git, venv, build artifacts (regenerated during setup)
- Documentation files (.md) that are not essential for platform operation
- Dissertation-specific working documents

---

## Project Summary

| Metric | Value |
|--------|-------|
| **Development Duration** | 16 iterations (4 months) |
| **Smart Contracts** | 23 deployed to Polygon Amoy |
| **Total Tests** | 534 automated tests |
| **Test Pass Rate** | 83.3% (Development), 89.5% (Production) |
| **Gas Savings (ERC-1155)** | 89.4% for batch operations |
| **Docker Containers** | 11-13 per environment |
| **API Endpoints** | 45+ REST endpoints |
| **Documentation** | 7,000+ lines |

---

## Key Achievements

- ✅ **89.4% gas savings** demonstrated through ERC-1155 batch operations vs ERC-721+ERC-20
- ✅ **Diamond Pattern (EIP-2535)** implementation overcoming Ethereum's 24KB bytecode limit
- ✅ **100% transfer restriction enforcement** across 600 violation attempts
- ✅ **85.8% capital recovery** under volatile market stress testing
- ✅ **On-chain governance** with token-weighted voting (10% quorum, 7-day periods)
- ✅ **KYC compliance** via on-chain whitelist enforcement
- ✅ **Real-time analytics** via The Graph Protocol with sub-second query latency
- ✅ **Multi-environment deployment** (Development, Test, Production) with Docker

---

## Development Journey: 16 Iterations

The platform was developed through 16 structured iterations following a mandatory CI/CD development process:

| Iteration | Focus Area | Key Deliverable |
|-----------|------------|-----------------|
| **1-3** | Foundation | Docker architecture, basic smart contracts, environment setup |
| **4-6** | Core Features | Property NFT, yield agreements, repayment logic |
| **7-8** | Frontend | React web application with USD-first display |
| **9** | Mobile | React Native with WalletConnect integration |
| **10** | Monitoring | Prometheus, Grafana, Node Exporter |
| **11** | Governance | Token-weighted voting, proposal system |
| **12** | Secondary Market | Marketplace, transfer restrictions, load testing |
| **13** | Analytics | The Graph Protocol integration |
| **14** | Compliance | KYC whitelist, Diamond Pattern migration |
| **15** | Testing | Fuzzing, invariants, security audits (Slither/Mythril) |
| **16** | Finalisation | Gas benchmarking, Polygon Amoy deployment, documentation |

---

## Repository Structure

```
RWA-Rental-Yield-Tokenisation_Assessor/
├── Development_Environment/      # Development Docker setup (11 containers)
│   ├── contracts/                # Smart contracts with Foundry tests
│   │   └── REMIX_Deployment/     # Flattened contracts for Amoy deployment
│   ├── backend/                  # FastAPI backend service
│   ├── frontend/                 # React web + React Native mobile
│   └── docker-compose.dev.yml    # Development orchestration
├── Test_Environment/             # Test Docker setup (13 containers)
│   ├── contracts/                # Contract submodule
│   ├── backend/                  # Backend with test configuration
│   ├── frontend/                 # Frontend with Cypress/Detox
│   └── docker-compose.test.yml   # Test orchestration
├── Production_Environment/       # Production Docker setup (13 containers)
│   ├── contracts/                # Contract submodule
│   ├── backend/                  # Backend with production settings
│   ├── frontend/                 # Optimised production build
│   └── docker-compose.prod.yml   # Production with Nginx
├── Shared_Environment/           # Common configurations and shared resources
│   ├── docs/                     # Comprehensive documentation suite
│   │   ├── architecture/         # Architecture diagrams (Mermaid + PNG)
│   │   ├── deployment/           # Deployment guides and records
│   │   ├── iterations/           # Iteration-specific documentation (1-16)
│   │   ├── testing/              # Test strategies, patterns, and reports
│   │   └── operations/           # Backup registry and operational docs
│   ├── scripts/                  # Assessor setup and utility scripts
│   ├── monitoring/               # Prometheus/Grafana configurations
│   └── theme/                    # Shared Material-UI theme
├── README.md                     # This file
└── LICENSE                       # Project license
```

---

## Key Documentation

| Document | Purpose | Location |
|----------|---------|----------|
| **DEPLOYMENT_GUIDE.md** | Polygon Amoy deployment instructions | `Shared_Environment/docs/deployment/guides/` |
| **AMOY_DEPLOYMENT_RECORD_V3.md** | Complete deployment record (23 contracts) | `Shared_Environment/docs/deployment/records/` |
| **MANUAL_UAT_TEST_CHECKLIST.md** | User acceptance testing results | `Shared_Environment/docs/testing/reports/` |
| **Load_Testing_Report.md** | Performance and load testing analysis | `Shared_Environment/docs/testing/reports/` |

---

## Getting Started

### Prerequisites

| Requirement | Minimum | Recommended | Check Command |
|-------------|---------|-------------|---------------|
| Docker Desktop | 4.0+ | Latest | `docker --version` |
| Git | 2.30+ | Latest | `git --version` |
| RAM | 8GB | 16GB+ | - |
| Disk Space | 10GB | 20GB+ | - |

### Quick Start for Assessors

```bash
# 1. Clone the repository
git clone https://github.com/ScottSanders2/RWA-Rental-Yield-Tokenisation_Assessor.git
cd RWA-Rental-Yield-Tokenisation_Assessor

# 2. Initialise submodules
git submodule update --init --recursive

# 3. Run assessor setup script
chmod +x Shared_Environment/scripts/assessor_setup.sh
./Shared_Environment/scripts/assessor_setup.sh dev setup

# 4. Access the platform
# Frontend: http://localhost:5173
# Backend API: http://localhost:8000
# API Docs: http://localhost:8000/docs
```

### Access URLs by Environment

| Service | Development | Test | Production |
|---------|-------------|------|------------|
| **Frontend** | http://localhost:5173 | http://localhost:5174 | http://localhost:80 |
| **Backend API** | http://localhost:8000 | http://localhost:8001 | http://localhost:80/api |
| **API Docs (Swagger)** | http://localhost:8000/docs | http://localhost:8001/docs | http://localhost:8002/docs |
| **Prometheus** | http://localhost:9090 | http://localhost:9091 | Internal only |
| **Grafana** | http://localhost:3000 | http://localhost:3001 | Internal only |

---

## Technology Stack

### Smart Contracts
- **Solidity 0.8.24** with Foundry testing framework
- **Diamond Pattern (EIP-2535)** for modular, upgradeable architecture
- **OpenZeppelin** contracts for security standards
- **Dual token support**: ERC-721+ERC-20 vs ERC-1155 for empirical comparison

### Backend
- **FastAPI** with PostgreSQL and Redis
- **Web3.py** for blockchain integration
- 45+ REST endpoints with comprehensive API documentation

### Frontend
- **React 18.2** web application with Material-UI
- **React Native 0.73** mobile application with WalletConnect
- USD-first display for non-crypto users

### Infrastructure
- **Docker** multi-environment architecture (Development, Test, Production)
- **Prometheus/Grafana** for monitoring
- **The Graph Protocol** for decentralised analytics

### Testing
- **Foundry**: Smart contract unit tests, fuzzing, invariants
- **PyTest**: Backend API testing
- **Cypress**: Web E2E testing
- **Detox**: Mobile E2E testing
- **Slither/Mythril**: Security audits

---

## Research Questions Addressed

This prototype addresses 10 research questions with empirical evidence:

| RQ | Question | Key Finding |
|----|----------|-------------|
| **RQ1** | Token standard suitability | ERC-1155 provides 89.4% gas savings for batch operations |
| **RQ2** | Smart contract architecture | Diamond Pattern enables modular contracts within 24KB limit |
| **RQ3** | Layer 2 scalability | Polygon reduces costs 100x vs Ethereum mainnet |
| **RQ4** | User experience factors | USD-first display improves accessibility for non-crypto users |
| **RQ5** | Regulatory compliance | 100% transfer restriction enforcement (600/600 tests) |
| **RQ6** | Financial inclusion | Platform enables £100 minimum investments vs £50,000 traditional |
| **RQ7** | Secondary market | Marketplace with fractional trading (1-100%) |
| **RQ8** | Operational sustainability | 85.8% capital recovery under volatile market stress |
| **RQ9** | System resilience | 99.65% success rate across 2,889 load test operations |
| **RQ10** | Governance mechanisms | Token-weighted voting with 10% quorum, 7-day periods |

---

## Test Results Summary

### Smart Contract Tests (Foundry)

| Test Category | Tests | Pass Rate |
|---------------|-------|-----------|
| Diamond Architecture | 233 | 93.1% |
| Unit Tests | 156 | 83.3% |
| Integration Tests | 48 | - |
| Fuzzing Tests | 24 | - |
| Invariant Tests | 12 | - |
| Simulation Tests | 18 | - |
| Load Tests | 43 | - |
| **TOTAL** | **534** | **83.3%** |

### Load Testing Results

| Metric | Result | Target |
|--------|--------|--------|
| Total Operations | 2,889 | - |
| Success Rate | 99.65% | >95% |
| Restriction Enforcement | 100% (600/600) | 100% |
| Gas Scaling | O(1) for 10-500 shareholders | O(1) |

### Gas Benchmarks (ERC-1155 vs ERC-721+ERC-20)

| Operation | ERC-721+ERC-20 | ERC-1155 | Savings |
|-----------|----------------|----------|---------|
| Property Mint | 150,432 gas | 79,845 gas | 47.0% |
| Yield Token Mint | 118,234 gas | 58,123 gas | 50.8% |
| Batch Transfer (10) | 850,000 gas | 89,000 gas | **89.4%** |

---

## Smart Contract Deployment (Polygon Amoy Testnet)

- **Network:** Polygon Amoy Testnet (Chain ID: 80002)
- **Contracts Deployed:** 23 (Diamond Pattern + UUPS Proxies)
- **Total Deployment Gas:** 32,647,862 (0.86 POL)
- **Deployer Address:** `0xa5902Da508412B8782B5CD18DAf6C6956cAB19F9`

For complete deployment record and contract addresses, see:
`Shared_Environment/docs/deployment/records/AMOY_DEPLOYMENT_RECORD_V3.md`

---

## Development Workflow

The project follows a strict 4-step mandatory development process:

1. **Implement** changes in Development environment with logical testing
2. **Migrate** to Test environment for user validation and E2E testing
3. **Promote** to Production environment as stable baseline
4. **Document**, backup, and audit against governance templates

---

## License

MIT License - See LICENSE file for details.

## Author

Scott Sanders - MSc Financial Technology, Middlesex University Dubai

## Acknowledgments

Supervisor guidance and support throughout the dissertation process.
