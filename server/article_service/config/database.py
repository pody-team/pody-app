"""
Database configuration and session management
"""
import os
from typing import AsyncGenerator
from contextlib import asynccontextmanager
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import NullPool
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


class DatabaseManager:
    """
    Singleton class for managing database connections and sessions.
    """
    _instance = None
    _engine = None
    _session_factory = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(DatabaseManager, cls).__new__(cls)
        return cls._instance
    
    def __init__(self):
        if self._engine is None:
            self._initialize_engine()
    
    def _initialize_engine(self):
        """Initialize the async database engine."""
        # Try full connection string first
        database_url = os.getenv('ARTICLE_DATABASE_URL') or os.getenv('DATABASE_URL')
        
        # SQLAlchemy with asyncpg handles SSL differently than psycopg2
        connect_args = {}
        use_null_pool = False
        if database_url:
            # SQLAlchemy with asyncpg requires 'postgresql+asyncpg://'
            if database_url.startswith('postgres://'):
                database_url = database_url.replace('postgres://', 'postgresql+asyncpg://', 1)
            elif database_url.startswith('postgresql://'):
                database_url = database_url.replace('postgresql://', 'postgresql+asyncpg://', 1)
            
            # Handle Supabase/PostgreSQL sslmode parameter
            if 'sslmode=' in database_url:
                import re
                database_url = re.sub(r'([?&])sslmode=[^&]*(&|$)', r'\1', database_url).rstrip('?&')
                connect_args["ssl"] = "require"
            elif 'pooler.supabase.com' in database_url:
                # Supabase poolers already manage connections well; avoid double-pooling
                # in the app to reduce idle client pressure and startup spikes.
                connect_args["ssl"] = "require"
                connect_args["statement_cache_size"] = 0
                use_null_pool = True
        else:
            # Fallback to individual components
            db_host = os.getenv('DB_HOST', 'localhost')
            db_port = os.getenv('DB_PORT', '5432')
            db_name = os.getenv('DB_NAME', 'tahanews')
            db_user = os.getenv('DB_USER', 'postgres')
            db_password = os.getenv('DB_PASSWORD', '')
            database_url = f"postgresql+asyncpg://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
        
        force_null_pool = os.getenv("DB_USE_NULL_POOL", "").strip().lower() in {"1", "true", "yes"}
        if force_null_pool:
            use_null_pool = True

        engine_kwargs = {
            "echo": False,
            "pool_pre_ping": True,
            "connect_args": connect_args,
        }
        if use_null_pool:
            engine_kwargs["poolclass"] = NullPool
        else:
            engine_kwargs["pool_size"] = int(os.getenv('DB_POOL_SIZE', '8'))
            engine_kwargs["max_overflow"] = int(os.getenv('DB_MAX_OVERFLOW', '4'))

        # Create async engine
        self._engine = create_async_engine(
            database_url,
            **engine_kwargs,
        )
        
        # Create session factory
        self._session_factory = async_sessionmaker(
            bind=self._engine,
            class_=AsyncSession,
            expire_on_commit=False,
            autocommit=False,
            autoflush=False,
        )
    
    @property
    def engine(self):
        """Get the database engine."""
        return self._engine
    
    @property
    def session_factory(self):
        """Get the session factory."""
        return self._session_factory
    
    async def close(self):
        """Close the database engine."""
        if self._engine:
            await self._engine.dispose()


@asynccontextmanager
async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    """
    Async context manager for database sessions.
    
    Usage:
        async with get_db_session() as session:
            # Use session here
            pass
    
    Yields:
        AsyncSession: SQLAlchemy async session
    """
    db_manager = DatabaseManager()
    session: AsyncSession = db_manager.session_factory()
    
    try:
        yield session
        await session.commit()
    except Exception:
        await session.rollback()
        raise
    finally:
        await session.close()
