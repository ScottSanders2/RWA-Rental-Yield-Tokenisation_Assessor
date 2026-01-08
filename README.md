# RWA Tokenisation Platform - Real Estate Rental Yield Tokenisation Prototype

## Assessor Access Information

This repository contains the complete prototype implementation for an MSc Financial Technology dissertation on blockchain-based tokenisation of real estate rental yields.

| Access Details | Value |
|----------------|-------|
| **Repository URL** | https://github.com/ScottSanders2/RWA-Rental-Yield-Tokenisation_Assessor |
| **Visibility** | Public |
| **Clone Command** | `git clone https://github.com/ScottSanders2/RWA-Rental-Yield-Tokenisation_Assessor.git` |

---

## Quick Start for Assessors

### Step 1: Clone the Repository

```bash
git clone https://github.com/ScottSanders2/RWA-Rental-Yield-Tokenisation_Assessor.git
cd RWA-Rental-Yield-Tokenisation_Assessor
```

### Step 2: Verify Prerequisites

| Requirement | Minimum | Check Command |
|-------------|---------|---------------|
| Docker Desktop | 4.0+ | `docker --version` |
| Git | 2.30+ | `git --version` |
| RAM | 8GB | - |
| Disk Space | 10GB | - |

### Step 3: Start the Development Environment

**Option A: Using the Assessor Setup Script (Recommended)**

```bash
# Make the script executable
chmod +x Shared_Environment/scripts/assessor_setup.sh

# Run the setup script for Development environment
./Shared_Environment/scripts/assessor_setup.sh dev setup
```

The script will:
- Check all prerequisites (Docker, docker-compose)
- Build all Docker containers
- Start all services
- Wait for services to be healthy
- Display access URLs and demo instructions

**Option B: Manual Docker Compose**

```bash
# Navigate to Development Environment
cd Development_Environment

# Start all Docker containers (11 services)
docker-compose -f docker-compose.dev.yml up -d --build

# Wait for services to initialise (approximately 2-3 minutes)
docker-compose -f docker-compose.dev.yml logs -f
```

### Step 4: Access the Platform

| Service | URL | Description |
|---------|-----|-------------|
| **Web Frontend** | http://localhost:5173 | React web application |
| **Backend API** | http://localhost:8000 | FastAPI REST endpoints |
| **API Documentation** | http://localhost:8000/docs | Swagger/OpenAPI interface |
| **Prometheus** | http://localhost:9090 | Metrics monitoring |
| **Grafana** | http://localhost:3000 | Dashboard visualisation |

### Step 5: Run Smart Contract Tests

```bash
# In a new terminal, access the contracts container
docker exec -it rwa-dev-contracts bash

# Run Foundry tests
forge test -vvv

# Run specific test suites
forge test --match-path test/Diamond* -vvv  # Diamond architecture tests
forge test --match-path test/LoadTesting* -vvv  # Load tests
```

### Step 6: Shutdown

**Option A: Using the Assessor Setup Script**

```bash
./Shared_Environment/scripts/assessor_setup.sh dev stop
```

**Option B: Manual Docker Compose**

```bash
# Stop all containers
docker-compose -f docker-compose.dev.yml down

# Remove volumes (optional - clears all data)
docker-compose -f docker-compose.dev.yml down -v
```

---

## Assessor Scripts Reference

The following scripts are provided in `Shared_Environment/scripts/` for assessor convenience:

| Script | Purpose | Usage |
|--------|---------|-------|
| `assessor_setup.sh` | Main setup/teardown script | `./assessor_setup.sh [env] [command]` |
| `assessor_bootstrap.sh` | Clone and setup in one step | `curl -fsSL [url] \| bash` |

### assessor_setup.sh Commands

```bash
# Setup and start Development environment
./Shared_Environment/scripts/assessor_setup.sh dev setup

# Setup and start Test environment
./Shared_Environment/scripts/assessor_setup.sh test setup

# Setup and start Production environment
./Shared_Environment/scripts/assessor_setup.sh prod setup

# Run smart contract tests
./Shared_Environment/scripts/assessor_setup.sh dev test

# Display access URLs and demo instructions
./Shared_Environment/scripts/assessor_setup.sh dev info

# Stop and cleanup environment
./Shared_Environment/scripts/assessor_setup.sh dev stop
```

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
│   │   ├── src/                  # Solidity source files
│   │   ├── test/                 # Foundry test suites
│   │   ├── script/               # Deployment scripts
│   │   └── REMIX_Deployment/     # Flattened contracts for Amoy deployment
│   ├── backend/                  # FastAPI backend service
│   │   ├── app/                  # Application code
│   │   ├── config/               # Configuration files
│   │   └── tests/                # PyTest test suites
│   ├── frontend/                 # React web + React Native mobile
│   │   ├── web/                  # React web application
│   │   └── mobile/               # React Native application
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
│   ├── scripts/                  # Assessor setup and utility scripts
│   ├── monitoring/               # Prometheus/Grafana configurations
│   └── theme/                    # Shared Material-UI theme
├── README.md                     # This file (assessor guide)
└── LICENSE                       # MIT Licence
```

---

## Key Files for Assessment

| File/Directory | Purpose |
|----------------|---------|
| `Development_Environment/contracts/` | All smart contracts with 534 Foundry tests |
| `Development_Environment/backend/` | FastAPI backend with 45+ REST endpoints |
| `Development_Environment/frontend/` | React web + React Native mobile apps |
| `Development_Environment/docker-compose.dev.yml` | Docker orchestration for all services |

---

## Alternative Setup Methods

### Method A: Using Docker Compose (Recommended)

See "Quick Start for Assessors" section above.

### Method B: Manual Container Start

```bash
cd Development_Environment

# Build containers
docker-compose -f docker-compose.dev.yml build

# Start in detached mode
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f
```

### Method C: Running Tests Only (No Full Platform)

```bash
cd Development_Environment/contracts

# If Foundry is installed locally
forge test -vvv

# Or use Docker
docker run --rm -v $(pwd):/app -w /app ghcr.io/foundry-rs/foundry forge test -vvv
```

---

## Access URLs by Environment

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

---

## Development Workflow

The project follows a strict 4-step mandatory development process:

1. **Implement** changes in Development environment with logical testing
2. **Migrate** to Test environment for user validation and E2E testing
3. **Promote** to Production environment as stable baseline
4. **Document**, backup, and audit against governance templates

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **Port already in use** | Stop existing services: `docker-compose down` or change ports in `.env` |
| **Docker build fails** | Ensure Docker Desktop is running and has sufficient memory (8GB+) |
| **Contracts not compiling** | Run `forge clean && forge build` inside contracts container |
| **Backend connection refused** | Wait 30 seconds for PostgreSQL to initialise |
| **Frontend blank page** | Clear browser cache or check console for errors |

### Verifying Installation

```bash
# Check all containers are running
docker ps

# Expected output: 11 containers for Development environment
# - rwa-dev-frontend
# - rwa-dev-backend
# - rwa-dev-contracts
# - rwa-dev-postgres
# - rwa-dev-redis
# - rwa-dev-prometheus
# - rwa-dev-grafana
# - rwa-dev-node-exporter
# - rwa-dev-anvil
# - rwa-dev-graph-node
# - rwa-dev-ipfs
```

### Getting Help

If you encounter issues not covered above, please check:
1. Docker Desktop logs for container-specific errors
2. Browser developer console for frontend issues
3. Backend logs: `docker logs rwa-dev-backend`

---

## Licence

MIT Licence - See LICENCE file for details.

## Author

Scott Sanders - MSc Financial Technology, Middlesex University Dubai

## Acknowledgements

Supervisor guidance and support throughout the dissertation process.
