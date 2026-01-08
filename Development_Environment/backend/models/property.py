"""
SQLAlchemy model for Property entity representing tokenized real estate.

This model mirrors the ER diagram Property entity and tracks property metadata,
verification status, and blockchain token information. It supports both ERC-721
and ERC-1155 token standards through the token_standard field.
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, LargeBinary
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from config.database import Base


class Property(Base):
    """
    Property model representing tokenized real estate assets.

    Tracks property metadata, verification status, and blockchain integration.
    Supports dual token standard approach for comparative analysis.
    """

    __tablename__ = "properties"

    # Primary key
    id = Column(Integer, primary_key=True, autoincrement=True)

    # Property identification - stored as bytes32 for blockchain compatibility
    property_address_hash = Column(
        LargeBinary(32),
        nullable=False,
        unique=True,
        comment="Keccak256 hash of property address (bytes32)"
    )

    # IPFS metadata
    metadata_uri = Column(
        String,
        nullable=True,
        comment="IPFS CID containing property metadata JSON (optional)"
    )
    metadata_json = Column(
        String,
        nullable=True,
        comment="JSON string containing property metadata"
    )
    rental_agreement_uri = Column(
        String,
        nullable=True,
        comment="IPFS URI containing rental agreement document"
    )

    # Verification status
    verification_timestamp = Column(
        DateTime,
        nullable=True,
        comment="Timestamp when property was verified by authorized verifier"
    )
    is_verified = Column(
        Boolean,
        default=False,
        comment="Whether property has been verified by authorized party"
    )
    verifier_address = Column(
        String(42),
        nullable=True,
        comment="Ethereum address of the verifier (0x-prefixed)"
    )
    
    # Property ownership
    owner_address = Column(
        String(100),
        nullable=True,
        index=True,
        comment="Ethereum address of the property owner (0x-prefixed)"
    )

    # Blockchain token information
    blockchain_token_id = Column(
        Integer,
        nullable=True,
        comment="Token ID from PropertyNFT or CombinedPropertyYieldToken contract"
    )

    # Token standard
    token_standard = Column(
        String(10),
        nullable=False,
        server_default='ERC721',
        comment="Token standard used: 'ERC721' or 'ERC1155'"
    )

    # Timestamps
    created_at = Column(
        DateTime,
        default=func.now(),
        comment="Record creation timestamp"
    )
    updated_at = Column(
        DateTime,
        default=func.now(),
        onupdate=func.now(),
        comment="Last update timestamp"
    )

    # Relationships
    yield_agreements = relationship(
        "YieldAgreement",
        back_populates="property",
        cascade="all, delete-orphan"
    )
    validation_records = relationship(
        "ValidationRecord",
        back_populates="property",
        cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        """String representation for debugging."""
        return (
            f"<Property(id={self.id}, "
            f"address_hash={self.property_address_hash.hex()[:8]}..., "
            f"verified={self.is_verified}, "
            f"token_id={self.blockchain_token_id})>"
        )
