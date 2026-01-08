"""
SQLAlchemy model for UserProfile entity representing test user accounts.

This model manages user profiles for testing governance with multiple voters,
simulating different wallet connections in Development/Test environments.
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, Index, CheckConstraint
from sqlalchemy.sql import func
from config.database import Base


class UserProfile(Base):
    """
    UserProfile model representing test user accounts for multi-voter governance.

    Provides a way to simulate multiple wallet connections in Dev/Test environments.
    Each profile represents a different user who can vote on governance proposals.
    In Production, user profiles would come from actual wallet connections.
    """

    __tablename__ = "user_profiles"

    # Primary key
    id = Column(Integer, primary_key=True, index=True)

    # Wallet address (unique)
    wallet_address = Column(
        String(42),
        nullable=False,
        unique=True,
        index=True,
        comment="Ethereum address (0x... format, 42 characters)"
    )

    # Display name
    display_name = Column(
        String(100),
        nullable=False,
        comment="Human-readable name for UI display"
    )

    # User role
    role = Column(
        String(20),
        nullable=False,
        index=True,
        comment="User role: property_owner, investor, or admin"
    )

    # Email (optional)
    email = Column(
        String(255),
        nullable=True,
        comment="Email address (optional, for notifications in testing)"
    )

    # Active flag
    is_active = Column(
        Boolean,
        default=True,
        comment="Whether this profile is active and available for selection"
    )

    # Created timestamp
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        comment="Timestamp when profile was created"
    )

    # Table-level constraints
    __table_args__ = (
        CheckConstraint(
            "role IN ('property_owner', 'investor', 'admin')",
            name='chk_role'
        ),
        # Wallet address format validation moved to Pydantic schema layer for database portability
        Index('idx_user_profiles_wallet', 'wallet_address'),
        Index('idx_user_profiles_role', 'role'),
        Index('idx_user_profiles_active', 'is_active', postgresql_where=(is_active == True)),
    )

    def __repr__(self):
        return (
            f"<UserProfile(id={self.id}, "
            f"name='{self.display_name}', "
            f"role='{self.role}', "
            f"wallet={self.wallet_address[:10]}..., "
            f"active={self.is_active})>"
        )
    
    def to_dict(self):
        """Convert to dictionary for API responses"""
        return {
            'id': self.id,
            'wallet_address': self.wallet_address,
            'display_name': self.display_name,
            'role': self.role,
            'email': self.email,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

