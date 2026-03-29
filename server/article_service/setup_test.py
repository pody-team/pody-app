"""
Quick Setup and Test Script
Run this script to verify your environment setup before running the main application.
"""
import asyncio
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import text
from config.database import DatabaseManager
from utils.logger import get_logger


async def test_setup():
    """Test the basic setup and configuration."""
    logger = get_logger(__name__)
    
    logger.info("=" * 80)
    logger.info("News Crawler Setup Test")
    logger.info("=" * 80)
    
    # Test 1: Check environment variables
    logger.info("\n1. Checking environment variables...")
    required_vars = ['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD']
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        logger.warning(f"⚠ Missing environment variables: {', '.join(missing_vars)}")
        logger.warning("Please create a .env file based on .env.example")
    else:
        logger.info("✓ All required environment variables are set")
    
    # Test 2: Database connection
    logger.info("\n2. Testing database connection...")
    try:
        db_manager = DatabaseManager()
        async with db_manager.session_factory() as session:
            result = await session.execute(text("SELECT 1 as test"))
            row = result.fetchone()
            if row and row[0] == 1:
                logger.info("✓ Database connection successful")
            else:
                logger.error("✗ Unexpected database response")
                return False
    except Exception as e:
        logger.error(f"✗ Database connection failed: {str(e)}")
        logger.error("Please check your database credentials in .env file")
        return False
    
    # Test 3: Check if tables exist
    logger.info("\n3. Checking database tables...")
    try:
        async with db_manager.session_factory() as session:
            # Helper to check if a table exists
            async def table_exists(table_name):
                result = await session.execute(
                    text(f"SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '{table_name}')")
                )
                return result.scalar()

            # Check core tables
            for table in ['news_sources', 'articles']:
                if await table_exists(table):
                    logger.info(f"✓ Table '{table}' exists")
                else:
                    logger.warning(f"⚠ Table '{table}' not found")
            
            # Check extension tables
            extensions = [
                'categories',
                'category_articles',
                'outbox_events',
                'article_stats', 
                'article_interactions', 
                'article_metrics',
                'article_comments',
            ]
            for table in extensions:
                if await table_exists(table):
                    logger.info(f"✓ Extension table '{table}' exists")
                else:
                    logger.warning(f"⚠ Extension table '{table}' MISSING")
            
            # Check for active sources
            result = await session.execute(
                text("SELECT COUNT(*) FROM news_sources WHERE status = 'ACTIVE'")
            )
            count = result.scalar()
            logger.info(f"✓ Found {count} active news sources")
    
    except Exception as e:
        logger.error(f"✗ Error checking tables: {str(e)}")
        return False
    
    # Test 4: Check dependencies
    logger.info("\n4. Checking dependencies...")
    dependencies_ok = True
    try:
        import feedparser
        logger.info("✓ feedparser installed")
    except ImportError:
        logger.error("✗ feedparser not installed")
        dependencies_ok = False
    
    try:
        import httpx
        logger.info("✓ httpx installed")
    except ImportError:
        logger.error("✗ httpx not installed")
        dependencies_ok = False
    
    try:
        import newspaper
        logger.info("✓ newspaper3k installed")
    except ImportError:
        logger.error("✗ newspaper3k not installed")
        dependencies_ok = False
    
    try:
        import apscheduler
        logger.info("✓ APScheduler installed")
    except ImportError:
        logger.error("✗ APScheduler not installed")
        dependencies_ok = False
    
    if not dependencies_ok:
        logger.error("\nPlease install missing dependencies:")
        logger.error("  pip install -r requirements.txt")
    
    # Summary
    logger.info("\n" + "=" * 80)
    logger.info("Setup test completed!")
    if missing_vars or not dependencies_ok:
        logger.warning("⚠ Some issues detected. Please resolve them before running the application.")
        logger.info("\nNext steps:")
        logger.info("  1. Copy .env.example to .env and configure your database credentials")
        logger.info("  2. Install dependencies: pip install -r requirements.txt")
        logger.info("  3. Ensure PostgreSQL is running with the required tables")
        logger.info("  4. Add active news sources to the database")
    else:
        logger.info("✓ Setup looks good! You can now run the application:")
        logger.info("  python main.py")
    logger.info("=" * 80)
    
    return True


if __name__ == '__main__':
    # Set event loop policy for Windows
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    
    asyncio.run(test_setup())
