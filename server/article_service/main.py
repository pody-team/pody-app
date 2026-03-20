"""
Main Entry Point - News Crawler Microservice
Automated scheduler for crawling news articles from RSS feeds.
"""
import html
import os
import sys
import asyncio
import signal
from datetime import datetime
from sqlalchemy import text
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger

from services.crawler_service import CrawlerService
from config.database import DatabaseManager, get_db_session
from config.redis_manager import RedisManager
from repositories.article_repository import ArticleRepository
from utils.logger import get_logger

from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from pydantic import BaseModel
from typing import Optional, List
import uvicorn


def clean_text(value):
    if not value:
        return value
    return html.unescape(value)


class InteractionRequest(BaseModel):
    user_id: int
    type: str  # 'LIKE', 'DISLIKE', 'LOVE'


class MetricRequest(BaseModel):
    user_id: int
    reading_time_seconds: int


class NewscrawlerApplication:
    """
    Main application class for the News Crawler Microservice.
    Manages the scheduler and coordinates the crawling process.
    """
    
    def __init__(self):
        """Initialize the application."""
        self.logger = get_logger(__name__)
        self.scheduler = AsyncIOScheduler()
        self.crawler_service = CrawlerService()
        self.is_running = False
        
        # Setup FastAPI
        self.api = FastAPI(title="Pody Article Service", version="1.0.0")
        self.api.add_middleware(GZipMiddleware, minimum_size=1024)
        self._setup_api_routes()
        
        # Get configuration from environment
        self.crawler_interval = int(os.getenv('CRAWLER_INTERVAL_MINUTES', '30'))
        self.api_port = int(os.getenv('PORT', '8084'))
        self.api_host = os.getenv('HOST', '0.0.0.0')
        
        # Setup signal handlers for graceful shutdown (updated for Windows/Docker)
        if sys.platform != 'win32':
            for sig in (signal.SIGINT, signal.SIGTERM):
                signal.signal(sig, self._signal_handler)
    
    def _setup_api_routes(self):
        """Define the API endpoints for the news service."""
        
        @self.api.get("/healthz")
        async def healthz():
            return {"status": "ok", "timestamp": datetime.now().isoformat()}

        @self.api.get("/api/v1/article")
        async def list_articles(
            limit: int = 50, 
            offset: int = 0,
            category: Optional[str] = Query(None, description="Filter by category"),
            q: Optional[str] = Query(None, description="Search keyword in title/summary")
        ):
            try:
                async with get_db_session() as session:
                    repo = ArticleRepository(session)
                    # Use the new method that joins with extra tables
                    results = await repo.list_articles_with_extra(
                        limit=limit, 
                        offset=offset,
                        category=category,
                        query=q
                    )
                    return {
                        "count": len(results),
                        "limit": limit,
                        "offset": offset,
                        "articles": [
                            {
                                "id": a.id,
                                "title": clean_text(a.title),
                                "summary": clean_text(a.summary),
                                "author": clean_text(a.author),
                                "category": cat,
                                "view_count": views,
                                "thumbnail_url": a.thumbnail_url,
                                "original_url": a.original_url,
                                "published_at": a.published_at.isoformat() if a.published_at else None,
                                "source_id": a.source_id,
                                "status": a.status
                            } for a, cat, views in results
                        ]
                    }
            except Exception as e:
                self.logger.error(f"API Error fetching articles: {str(e)}")
                raise HTTPException(status_code=500, detail="Internal server error")

        @self.api.get("/api/v1/article/{article_id}")
        async def get_article(article_id: int):
            try:
                async with get_db_session() as session:
                    repo = ArticleRepository(session)
                    detail = await repo.get_article_detail(article_id)
                    if not detail:
                        raise HTTPException(status_code=404, detail="Article not found")
                    
                    article, categories, view_count = detail
                    
                    # Increment view count in separate table
                    await repo.increment_view_count(article_id)
                    
                    return {
                        "id": article.id,
                        "title": clean_text(article.title),
                        "content": article.content,
                        "summary": clean_text(article.summary),
                        "author": clean_text(article.author),
                        "categories": categories,
                        "view_count": view_count + 1,
                        "thumbnail_url": article.thumbnail_url,
                        "original_url": article.original_url,
                        "published_at": article.published_at.isoformat() if article.published_at else None,
                        "source_id": article.source_id,
                    }
            except HTTPException:
                raise
            except Exception as e:
                self.logger.error(f"API Error fetching article {article_id}: {str(e)}")
                raise HTTPException(status_code=500, detail="Internal server error")

        @self.api.post("/api/v1/article/{article_id}/interaction")
        async def add_interaction(article_id: int, req: InteractionRequest):
            try:
                async with get_db_session() as session:
                    repo = ArticleRepository(session)
                    article = await repo.get_by_id(article_id)
                    if not article:
                        raise HTTPException(status_code=404, detail="Article not found")
                    
                    await repo.add_interaction(article_id, req.user_id, req.type)
                    return {"status": "success", "message": f"Interaction {req.type} added"}
            except HTTPException:
                raise
            except Exception as e:
                self.logger.error(f"API Error adding interaction: {str(e)}")
                raise HTTPException(status_code=500, detail="Internal server error")

        @self.api.post("/api/v1/article/{article_id}/metric")
        async def track_metric(article_id: int, req: MetricRequest):
            try:
                async with get_db_session() as session:
                    repo = ArticleRepository(session)
                    article = await repo.get_by_id(article_id)
                    if not article:
                        raise HTTPException(status_code=404, detail="Article not found")
                    
                    await repo.track_metric(article_id, req.user_id, req.reading_time_seconds)
                    return {"status": "success", "message": "Metric tracked"}
            except HTTPException:
                raise
            except Exception as e:
                self.logger.error(f"API Error tracking metric: {str(e)}")
                raise HTTPException(status_code=500, detail="Internal server error")
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals."""
        self.logger.info(f"Received signal {signum}, initiating graceful shutdown...")
        self.is_running = False
        self.scheduler.shutdown(wait=False)
        sys.exit(0)
    
    async def crawl_job(self):
        """
        The scheduled job that runs the crawler.
        This is the main work function called by the scheduler.
        """
        try:
            self.logger.info(f"[{datetime.now()}] Starting scheduled crawl job")
            start_time = datetime.now()
            
            # Execute the crawl
            stats = await self.crawler_service.crawl_all_sources()
            
            # Calculate duration
            duration = (datetime.now() - start_time).total_seconds()
            self.logger.info(f"Crawl job completed in {duration:.2f} seconds")
            self.logger.info(f"Next crawl scheduled in {self.crawler_interval} minutes")
            
        except Exception as e:
            self.logger.error(f"Error in crawl job: {str(e)}", exc_info=True)

    async def run_initial_crawl(self):
        """Run the first crawl after the API is already accepting requests."""
        self.logger.info("Running initial crawl in background...")
        await self.crawl_job()
    
    async def run(self):
        """
        Main run method: Start the scheduler and keep the application running.
        """
        self.logger.info("=" * 80)
        self.logger.info("News Crawler Microservice Starting")
        self.logger.info("=" * 80)
        self.logger.info(f"Crawler interval: {self.crawler_interval} minutes")
        self.logger.info(f"Max concurrent requests: {os.getenv('MAX_CONCURRENT_REQUESTS', '10')}")
        self.logger.info(f"Request timeout: {os.getenv('REQUEST_TIMEOUT_SECONDS', '30')} seconds")
        self.logger.info("=" * 80)
        
        try:
            # Test database connection
            self.logger.info("Testing database connection...")
            db_manager = DatabaseManager()
            async with db_manager.session_factory() as session:
                await session.execute(text("SELECT 1"))
            self.logger.info("✓ Database connection successful")

            # Test Redis connection
            self.logger.info("Testing Redis connection...")
            redis_manager = RedisManager()
            if await redis_manager.ping():
                self.logger.info("✓ Redis connection successful")
            else:
                self.logger.warning(
                    "⚠ Redis is unreachable — deduplication will fall back to DB-only mode."
                )
            
            # Schedule periodic crawls
            self.logger.info(f"Scheduling periodic crawls every {self.crawler_interval} minutes")
            self.scheduler.add_job(
                self.crawl_job,
                trigger=IntervalTrigger(minutes=self.crawler_interval),
                id='news_crawler',
                name='News Crawler Job',
                replace_existing=True,
                max_instances=1,  # Prevent overlapping executions
                coalesce=True,    # Combine missed executions into one
            )
            
            # Start the scheduler
            self.scheduler.start()
            self.is_running = True
            self.logger.info("✓ Scheduler started successfully")
            
            # Use FastAPI event handlers to run operations after API is up
            @self.api.on_event("startup")
            async def on_startup():
                asyncio.create_task(self.run_initial_crawl())

            # Run FastAPI with uvicorn
            config = uvicorn.Config(
                app=self.api, 
                host=self.api_host, 
                port=self.api_port, 
                log_level="info"
            )
            server = uvicorn.Server(config)
            
            self.logger.info(f"✓ API Server starting on {self.api_host}:{self.api_port}")
            self.logger.info("Application is running. Press Ctrl+C to stop.")
            
            # Run the uvicorn server in the current event loop
            await server.serve()
            
        except Exception as e:
            self.logger.error(f"Fatal error: {str(e)}", exc_info=True)
        finally:
            await self.shutdown()
    
    async def shutdown(self):
        """Gracefully shutdown the application."""
        self.logger.info("Shutting down application...")
        
        try:
            # Stop the scheduler
            if self.scheduler.running:
                self.scheduler.shutdown(wait=True)
                self.logger.info("✓ Scheduler stopped")
            
            # Close database connections
            db_manager = DatabaseManager()
            await db_manager.close()
            self.logger.info("✓ Database connections closed")

            # Close Redis connections
            redis_manager = RedisManager()
            await redis_manager.close()
            self.logger.info("✓ Redis connections closed")
            
        except Exception as e:
            self.logger.error(f"Error during shutdown: {str(e)}")
        
        self.logger.info("Application shutdown complete")


async def main():
    """
    Application entry point.
    """
    app = NewscrawlerApplication()
    await app.run()


if __name__ == '__main__':
    # Set event loop policy for Windows (if needed)
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    
    # Run the application
    asyncio.run(main())
