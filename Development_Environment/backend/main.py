"""
FastAPI backend application for RWA Tokenization Platform.

This application provides REST API endpoints for property registration,
yield agreement creation, and blockchain integration. It follows clean
architecture principles with layered design (API → Service → Repository → Blockchain).
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config.database import init_db
from config.settings import settings
from api.property import router as property_router, alias_router
from api.yield_agreement import router as yield_agreement_router
from api.governance import router as governance_router
from api.users import router as users_router
from api.marketplace import router as marketplace_router
from api.portfolio import router as portfolio_router
from api.kyc import router as kyc_router

# Create FastAPI application with configuration from settings
app = FastAPI(
    title=settings.api_title,
    description="""
    REST API for RWA Tokenization Platform with On-Chain Governance and Secondary Market.
    
    Features:
    - Property NFT registration and verification
    - Yield agreement creation with ERC-20 token minting
    - On-chain governance for ROI adjustments and reserve management
    - Token-weighted voting (1 token = 1 vote)
    - Autonomous yield distribution and default protection
    - Secondary market trading with transfer restrictions and fractional pooling
    """,
    version=settings.api_version,
    debug=settings.fastapi_debug
)

# Configure CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """
    Application startup event handler.

    Initializes database tables on application startup for development.
    In production/testing, rely on Alembic migrations instead.
    """
    # Only create tables automatically in development environment
    # Production and test environments should use Alembic migrations
    if settings.fastapi_env == "development":
        init_db()


@app.get("/")
async def root():
    """Root endpoint returning API information."""
    return {
        "message": "RWA Tokenization Platform API",
        "status": "healthy",
        "environment": settings.fastapi_env,
        "version": settings.api_version
    }


@app.get("/health")
async def health():
    """Health check endpoint for container monitoring."""
    return {
        "status": "ok",
        "environment": settings.fastapi_env,
        "message": "Backend service is operational"
    }


@app.get("/contracts")
async def get_contract_addresses():
    """
    Get deployed smart contract addresses.

    Returns contract addresses for frontend integration.
    Contract addresses must be populated after deployment script execution.
    """
    from config.web3_config import get_contract_addresses

    try:
        addresses = get_contract_addresses()
        return {
            "contracts": addresses,
            "note": "Contract addresses populated after deployment script execution"
        }
    except Exception as e:
        return {
            "error": f"Contract addresses not configured: {str(e)}",
            "note": "Run deployment script and populate .env.dev with contract addresses"
        }


# Include API routers
app.include_router(property_router)
app.include_router(alias_router)
app.include_router(yield_agreement_router)
app.include_router(governance_router)  # On-chain governance endpoints for proposal creation, voting, and execution
app.include_router(users_router)  # User profile management for multi-voter testing
app.include_router(marketplace_router)  # Secondary market marketplace endpoints for yield share trading with transfer restrictions
app.include_router(portfolio_router)  # User portfolio endpoints for tracking share ownership and transaction history
app.include_router(kyc_router)  # KYC verification endpoints for regulatory compliance and whitelist management
