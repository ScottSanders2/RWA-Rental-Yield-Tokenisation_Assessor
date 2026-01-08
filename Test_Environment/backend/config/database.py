"""
Database configuration module for SQLAlchemy engine and session management.

This module provides SQLAlchemy setup with connection pooling, session lifecycle
management, and declarative base for ORM models. It follows FastAPI best practices
for database dependency injection.

The session lifecycle ensures proper cleanup and prevents connection leaks.
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from .settings import settings

# Create SQLAlchemy engine with connection pooling
engine = create_engine(
    settings.database_url,
    echo=settings.fastapi_debug,  # Log SQL queries in development
    pool_pre_ping=True,  # Verify connections before use
    pool_recycle=300,  # Recycle connections after 5 minutes
)

# Create SessionLocal class for database sessions
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# Create declarative base for ORM models
Base = declarative_base()


def get_db() -> Session:
    """
    FastAPI dependency function for database session management.

    Yields a database session and ensures proper cleanup after request completion.
    This pattern prevents connection leaks and ensures thread safety.

    Yields:
        Session: SQLAlchemy database session

    Usage:
        def endpoint(db: Session = Depends(get_db)):
            # Use db session here
            pass
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """
    Initialize database by creating all tables defined in ORM models.

    This function should be called on application startup to ensure
    all database tables exist before handling requests.

    Note: In production, prefer Alembic migrations over this method.
    """
    Base.metadata.create_all(bind=engine)
