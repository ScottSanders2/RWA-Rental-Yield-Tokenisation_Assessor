"""
Validation record model for deed hash and rental agreement URI storage.

This model stores validation records created during property registration
to track deed hash and rental agreement URI validation for audit purposes.
"""

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from config.database import Base


class ValidationRecord(Base):
    """
    Validation record for property registration validation data.

    Stores deed hash and rental agreement URI for audit and verification purposes.
    Linked to the property that was validated during registration.
    """

    __tablename__ = "validation_records"

    id = Column(Integer, primary_key=True, index=True)
    property_id = Column(Integer, ForeignKey("properties.id"), nullable=False, index=True)
    deed_hash = Column(String(66), nullable=False)  # 0x-prefixed hex string (32 bytes)
    rental_agreement_uri = Column(String(1000), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationship to property
    property = relationship("Property", back_populates="validation_records")

    def __repr__(self):
        return f"<ValidationRecord(id={self.id}, property_id={self.property_id}, deed_hash={self.deed_hash[:10]}...)>"
