"""
Pydantic Settings class for environment variable management.

This module provides centralized configuration management using Pydantic's
BaseSettings class with automatic environment variable loading. It handles
database connections, Web3 provider setup, contract addresses, and API metadata.

Environment variables are loaded from .env.dev file in development environment.
Contract addresses must be populated after running deployment script in Foundry container.
"""

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings
from typing import Optional, List
import os


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database Configuration
    postgres_user: str = Field(default="rwa_dev_user", description="PostgreSQL username")
    postgres_password: str = Field(default="dev_password", description="PostgreSQL password")
    postgres_db: str = Field(default="rwa_dev_db", description="PostgreSQL database name")
    postgres_host: str = Field(default="rwa-dev-postgres", description="PostgreSQL host")
    postgres_port: int = Field(default=5432, description="PostgreSQL port")

    # Redis Configuration
    redis_host: str = Field(default="rwa-dev-redis", description="Redis host")
    redis_port: int = Field(default=6379, description="Redis port")
    redis_password: str = Field(default="dev_redis_pass", description="Redis password")

    # Web3/Anvil Configuration
    web3_provider_uri: str = Field(
        default="http://rwa-dev-foundry:8546",
        description="Web3 provider URI for Anvil connection"
    )
    anvil_chain_id: int = Field(default=31337, description="Anvil chain ID")

    # Contract Addresses - Must be populated after deployment
    property_nft_address: str = Field(
        default="0xB0f05d25e41FbC2b52013099ED9616f1206Ae21B",
        description="PropertyNFT proxy contract address",
        alias="PROPERTY_NFT_CONTRACT_ADDRESS"
    )
    yield_base_address: str = Field(
        default="0x99dBE4AEa58E518C50a1c04aE9b48C9F6354612f",
        description="YieldBase proxy contract address",
        alias="YIELD_BASE_CONTRACT_ADDRESS"
    )
    combined_token_address: str = Field(
        default="0x6C2d83262fF84cBaDb3e416D527403135D757892",
        description="CombinedPropertyYieldToken proxy contract address",
        alias="COMBINED_PROPERTY_YIELD_TOKEN_CONTRACT_ADDRESS"
    )
    kyc_registry_address: str = Field(
        default="0x5FbDB2315678afecb367f032d93F642f64180aa3",
        description="KYCRegistry contract address",
        alias="KYC_REGISTRY_CONTRACT_ADDRESS"
    )

    # Deployer Credentials
    deployer_private_key: str = Field(
        default="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
        description="Deployer private key for transaction signing"
    )
    deployer_address: str = Field(
        default="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        description="Deployer Ethereum address"
    )

    # IPFS Configuration
    ipfs_gateway_url: str = Field(
        default="https://ipfs.io/ipfs/",
        description="IPFS gateway URL for content retrieval"
    )
    ipfs_api_url: str = Field(
        default="https://ipfs.infura.io:5001",
        description="IPFS API URL for content upload (future use)"
    )

    # API Metadata
    api_title: str = Field(
        default="RWA Tokenization Platform API",
        description="API title for OpenAPI documentation"
    )
    api_version: str = Field(default="0.1.0", description="API version")
    api_description: str = Field(
        default="Backend API for real estate rental yield tokenization",
        description="API description for OpenAPI documentation"
    )

    # General Settings
    fastapi_env: str = Field(default="development", description="FastAPI environment")
    fastapi_debug: bool = Field(default=True, description="Enable FastAPI debug mode")
    log_level: str = Field(default="INFO", description="Logging level")

    # CORS Configuration
    cors_origins: List[str] = Field(
        default_factory=lambda: ["http://localhost:3000", "http://localhost:5173", "http://localhost:5174"],
        description="List of allowed CORS origins",
        alias="_cors_origins"  # Don't load from environment
    )

    model_config = {
        "env_file": ".env.dev",
        "env_prefix": "",
        "populate_by_name": True,
        "case_sensitive": False,
        "env_ignore_empty": True,
    }

    @property
    def database_url(self) -> str:
        """Construct PostgreSQL database URL from individual components."""
        return (
            f"postgresql://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @property
    def redis_url(self) -> str:
        """Construct Redis URL from individual components."""
        return f"redis://:{self.redis_password}@{self.redis_host}:{self.redis_port}"



# Create singleton settings instance
settings = Settings()
