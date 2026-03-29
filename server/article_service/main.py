"""
Main entry point for the article crawler and HTTP API lifecycle.
"""
import asyncio
import os
import signal
import sys
from datetime import datetime

import uvicorn
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
from sqlalchemy import text

from api import create_api
from config import load_article_category_sync_consumer_settings
from config.database import DatabaseManager
from config.redis_manager import RedisManager
from services.article_category_sync_consumer import ArticleCategorySyncConsumer
from services.crawler_service import CrawlerService
from utils.logger import get_logger


class NewscrawlerApplication:
    """
    Main application class for the article service.
    Handles scheduler, startup checks, and web server lifecycle.
    """

    def __init__(self):
        self.logger = get_logger(__name__)
        self.scheduler = AsyncIOScheduler()
        self.crawler_service = CrawlerService()
        self.category_sync_consumer = ArticleCategorySyncConsumer(
            load_article_category_sync_consumer_settings(),
            self.logger.getChild("category-sync"),
        )
        self.is_running = False

        self.api = create_api(self.logger)
        self.crawler_interval = int(os.getenv("CRAWLER_INTERVAL_MINUTES", "30"))
        self.initial_crawl_enabled = os.getenv("ENABLE_INITIAL_CRAWL", "true").strip().lower() in {"1", "true", "yes"}
        self.initial_crawl_delay_seconds = int(os.getenv("INITIAL_CRAWL_DELAY_SECONDS", "20"))
        self.api_port = int(os.getenv("PORT", "8084"))
        self.api_host = os.getenv("HOST", "0.0.0.0")

        if sys.platform != "win32":
            for sig in (signal.SIGINT, signal.SIGTERM):
                signal.signal(sig, self._signal_handler)

    def _signal_handler(self, signum, frame):
        self.logger.info(f"Received signal {signum}, initiating graceful shutdown...")
        self.is_running = False
        self.scheduler.shutdown(wait=False)
        sys.exit(0)

    async def crawl_job(self):
        try:
            self.logger.info(f"[{datetime.now()}] Starting scheduled crawl job")
            start_time = datetime.now()
            await self.crawler_service.crawl_all_sources()
            duration = (datetime.now() - start_time).total_seconds()
            self.logger.info(f"Crawl job completed in {duration:.2f} seconds")
            self.logger.info(f"Next crawl scheduled in {self.crawler_interval} minutes")
        except Exception as exc:
            self.logger.error(f"Error in crawl job: {str(exc)}", exc_info=True)

    async def run_initial_crawl(self):
        if not self.initial_crawl_enabled:
            self.logger.info("Initial crawl disabled by configuration.")
            return
        if self.initial_crawl_delay_seconds > 0:
            self.logger.info(f"Delaying initial crawl by {self.initial_crawl_delay_seconds} seconds.")
            await asyncio.sleep(self.initial_crawl_delay_seconds)
        self.logger.info("Running initial crawl in background...")
        await self.crawl_job()

    async def run(self):
        self.logger.info("=" * 80)
        self.logger.info("News Crawler Microservice Starting")
        self.logger.info("=" * 80)
        self.logger.info(f"Crawler interval: {self.crawler_interval} minutes")
        self.logger.info(f"Initial crawl enabled: {self.initial_crawl_enabled}")
        self.logger.info(f"Initial crawl delay: {self.initial_crawl_delay_seconds} seconds")
        self.logger.info(f"Max concurrent requests: {os.getenv('MAX_CONCURRENT_REQUESTS', '10')}")
        self.logger.info(f"Request timeout: {os.getenv('REQUEST_TIMEOUT_SECONDS', '30')} seconds")
        self.logger.info("=" * 80)

        try:
            self.logger.info("Testing database connection...")
            db_manager = DatabaseManager()
            async with db_manager.session_factory() as session:
                await session.execute(text("SELECT 1"))
            self.logger.info("Database connection successful")

            self.logger.info("Testing Redis connection...")
            redis_manager = RedisManager()
            if await redis_manager.ping():
                self.logger.info("Redis connection successful")
            else:
                self.logger.warning("Redis is unreachable, deduplication will fall back to DB-only mode.")

            self.logger.info(f"Scheduling periodic crawls every {self.crawler_interval} minutes")
            self.scheduler.add_job(
                self.crawl_job,
                trigger=IntervalTrigger(minutes=self.crawler_interval),
                id="news_crawler",
                name="News Crawler Job",
                replace_existing=True,
                max_instances=1,
                coalesce=True,
            )

            self.scheduler.start()
            self.is_running = True
            self.logger.info("Scheduler started successfully")
            self.category_sync_consumer.start()
            self.logger.info("Article-category sync consumer started")

            @self.api.on_event("startup")
            async def on_startup():
                asyncio.create_task(self.run_initial_crawl())

            server = uvicorn.Server(
                uvicorn.Config(
                    app=self.api,
                    host=self.api_host,
                    port=self.api_port,
                    log_level="info",
                )
            )

            self.logger.info(f"API Server starting on {self.api_host}:{self.api_port}")
            self.logger.info("Application is running. Press Ctrl+C to stop.")
            await server.serve()
        except Exception as exc:
            self.logger.error(f"Fatal error: {str(exc)}", exc_info=True)
        finally:
            await self.shutdown()

    async def shutdown(self):
        self.logger.info("Shutting down application...")
        try:
            self.category_sync_consumer.stop()
            if self.scheduler.running:
                self.scheduler.shutdown(wait=True)
                self.logger.info("Scheduler stopped")

            await DatabaseManager().close()
            self.logger.info("Database connections closed")

            await RedisManager().close()
            self.logger.info("Redis connections closed")
        except Exception as exc:
            self.logger.error(f"Error during shutdown: {str(exc)}")

        self.logger.info("Application shutdown complete")


async def main():
    await NewscrawlerApplication().run()


if __name__ == "__main__":
    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

    asyncio.run(main())
