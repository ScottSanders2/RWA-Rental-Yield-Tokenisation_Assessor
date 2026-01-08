"""
KYC Document Model

Tracks document metadata for KYC verification process. Actual files are stored
off-chain (IPFS) to minimize gas costs and maintain privacy.

Supports multiple document types:
- Identity documents (passport, driver's license, national ID)
- Proof of address (utility bill, bank statement)
- Accreditation letters (for accredited investors)
"""

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum as SQLEnum, Index
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from config.database import Base
import enum


class DocumentType(enum.Enum):
    """Supported KYC document types"""
    PASSPORT = "passport"
    DRIVERS_LICENSE = "drivers_license"
    NATIONAL_ID = "national_id"
    PROOF_OF_ADDRESS = "proof_of_address"
    ACCREDITATION_LETTER = "accreditation_letter"  # For accredited investors
    BANK_STATEMENT = "bank_statement"
    UTILITY_BILL = "utility_bill"


class KYCDocument(Base):
    """
    KYC Document metadata tracking table
    
    Stores document metadata and IPFS URIs. Actual document files are stored
    off-chain for privacy and cost efficiency.
    
    Attributes:
        id: Primary key
        kyc_verification_id: Foreign key to KYCVerification
        document_type: Type of document (passport, ID, etc.)
        file_name: Original file name
        file_hash: SHA-256 hash for integrity verification
        ipfs_uri: IPFS URI for decentralized storage
        file_size: File size in bytes
        mime_type: MIME type (e.g., image/jpeg, application/pdf)
        uploaded_at: When document was uploaded
        verified_at: When admin verified the document
    """
    __tablename__ = "kyc_documents"
    
    # Primary key
    id = Column(Integer, primary_key=True, index=True)
    
    # Foreign key to KYCVerification
    kyc_verification_id = Column(
        Integer,
        ForeignKey('kyc_verifications.id', ondelete='CASCADE'),
        nullable=False,
        index=True,
        comment="Reference to KYC verification record"
    )
    
    # Document type
    document_type = Column(
        SQLEnum(DocumentType),
        nullable=False,
        comment="Type of KYC document"
    )
    
    # File information
    file_name = Column(
        String(255),
        nullable=False,
        comment="Original file name"
    )
    
    file_hash = Column(
        String(64),
        nullable=False,
        comment="SHA-256 hash for integrity verification"
    )
    
    ipfs_uri = Column(
        String(255),
        nullable=True,
        comment="IPFS URI for decentralized storage (ipfs://...)"
    )
    
    # Metadata
    file_size = Column(
        Integer,
        nullable=False,
        comment="File size in bytes"
    )
    
    mime_type = Column(
        String(100),
        nullable=False,
        comment="MIME type (e.g., image/jpeg, application/pdf)"
    )
    
    # Timestamps
    uploaded_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="When document was uploaded"
    )
    
    verified_at = Column(
        DateTime(timezone=True),
        nullable=True,
        comment="When admin verified the document"
    )
    
    # Relationship to KYCVerification
    kyc_verification = relationship(
        "KYCVerification",
        backref="documents",
        foreign_keys=[kyc_verification_id]
    )
    
    # Composite indexes for common queries
    __table_args__ = (
        Index('idx_kyc_doc_verification', 'kyc_verification_id'),
        Index('idx_kyc_doc_type', 'document_type'),
        Index('idx_kyc_doc_hash', 'file_hash'),
    )
    
    def to_dict(self):
        """
        Convert model to dictionary for API responses
        
        Returns:
            dict: Dictionary representation of KYC document
        """
        return {
            'id': self.id,
            'kyc_verification_id': self.kyc_verification_id,
            'document_type': self.document_type.value,
            'file_name': self.file_name,
            'file_hash': self.file_hash,
            'ipfs_uri': self.ipfs_uri,
            'file_size': self.file_size,
            'mime_type': self.mime_type,
            'uploaded_at': self.uploaded_at.isoformat() if self.uploaded_at else None,
            'verified_at': self.verified_at.isoformat() if self.verified_at else None
        }
    
    def to_dict_public(self):
        """
        Convert model to dictionary for public API responses (excludes sensitive fields)
        
        Returns:
            dict: Public dictionary representation (no IPFS URI or file hash)
        """
        return {
            'id': self.id,
            'document_type': self.document_type.value,
            'uploaded_at': self.uploaded_at.isoformat() if self.uploaded_at else None,
            'verified_at': self.verified_at.isoformat() if self.verified_at else None
        }
    
    def __repr__(self):
        return f"<KYCDocument(id={self.id}, type={self.document_type.value}, verification_id={self.kyc_verification_id})>"

