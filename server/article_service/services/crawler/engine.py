import os
import asyncio
import httpx
import feedparser
from datetime import datetime
from typing import Dict, List, Optional
from config.database import DatabaseManager
from config.redis_manager import RedisManager
from models.news_source import NewsSource
from repositories.news_source_repository import NewsSourceRepository
from services.article_cache import ArticleCache
from utils.logger import get_logger

from .discovery import FeedDiscovery
from .extractor import ContentExtractor
from .metadata import MetadataParser
from .storage import StorageService

class CrawlerEngine:
    def __init__(self):
        self.logger = get_logger(__name__)
        self.db_manager = DatabaseManager()
        
        redis_manager = RedisManager()
        self.article_cache = ArticleCache(redis_manager.client)
        
        self.discovery = FeedDiscovery()
        self.extractor = ContentExtractor()
        self.metadata_parser = MetadataParser()
        self.storage = StorageService(self.db_manager, self.article_cache)

        self.timeout = float(os.getenv('REQUEST_TIMEOUT_SECONDS', '30'))
        self.max_concurrent = int(os.getenv('MAX_CONCURRENT_REQUESTS', '10'))
        
        # Dual-semaphore strategy:
        # 1. Dedupe semaphore: Allow more concurrent checks (aligned with Redis pool)
        # 2. Crawl semaphore: Limit heavy content extraction (aligned with target server limits)
        self.dedupe_semaphore = asyncio.Semaphore(40) 
        self.crawl_semaphore = asyncio.Semaphore(self.max_concurrent)

        self._http_headers = {
            'User-Agent': (
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/120.0.0.0 Safari/537.36'
            ),
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
        }

    async def crawl_all_sources(self) -> Dict:
        stats = {'sources': 0, 'feeds': 0, 'articles_saved': 0, 'articles_skipped': 0, 'errors': 0}
        
        async with self.db_manager.session_factory() as session:
            repo = NewsSourceRepository(session)
            sources = await repo.get_active_sources()

        stats['sources'] = len(sources)
        self.logger.info(f"Found {len(sources)} active news source(s) to crawl.")

        if not sources:
            return stats

        async with httpx.AsyncClient(
            headers=self._http_headers,
            timeout=httpx.Timeout(self.timeout),
            follow_redirects=True,
        ) as client:
            tasks = [self._crawl_source(client, source, stats) for source in sources]
            results = await asyncio.gather(*tasks, return_exceptions=True)
            for i, result in enumerate(results):
                if isinstance(result, Exception):
                    self.logger.error(f"Unhandled exception for source '{sources[i].name}': {result}", exc_info=result)
                    stats['errors'] += 1

        self.logger.info(f"Crawl finished — {stats}")
        return stats

    async def _crawl_source(self, client: httpx.AsyncClient, source: NewsSource, stats: Dict) -> None:
        self.logger.info(f"[{source.name}] Starting — rss_url={source.rss_url}")
        try:
            # Use dedupe semaphore for feed discovery (light network task)
            async with self.dedupe_semaphore:
                feed_urls = await self.discovery.discover_rss_feeds(client, source.rss_url, self.dedupe_semaphore)
            
            if not feed_urls:
                self.logger.info(f"[{source.name}] No feeds discovered, attempting rss_url directly.")
                feed_urls = [source.rss_url]

            stats['feeds'] += len(feed_urls)
            for feed_url in feed_urls:
                await self._crawl_feed(client, feed_url, source, stats)
        except Exception as exc:
            self.logger.error(f"[{source.name}] Error: {exc}", exc_info=True)
            stats['errors'] += 1

    async def _crawl_feed(self, client: httpx.AsyncClient, feed_url: str, source: NewsSource, stats: Dict) -> None:
        self.logger.info(f"[{source.name}] Parsing feed: {feed_url}")
        # Use dedupe semaphore for feed fetching
        async with self.dedupe_semaphore:
            try:
                resp = await client.get(feed_url)
                resp.raise_for_status()
                raw_feed = resp.text
            except Exception as exc:
                self.logger.warning(f"[{source.name}] Failed to fetch feed {feed_url}: {exc}")
                stats['errors'] += 1
                return

        feed = feedparser.parse(raw_feed)
        if not feed.entries:
            self.logger.warning(f"[{source.name}] Feed has no entries: {feed_url}")
            return

        article_tasks = [self._crawl_article(client, entry, source, stats) for entry in feed.entries if entry.get('link')]
        await asyncio.gather(*article_tasks, return_exceptions=True)

    async def _crawl_article(self, client: httpx.AsyncClient, entry: feedparser.FeedParserDict, source: NewsSource, stats: Dict) -> None:
        # --- PHASE 1: DEDUPLICATION (FAST & LIGHT) ---
        # We use a larger semaphore to allow many checks to run in parallel
        async with self.dedupe_semaphore:
            article_url = (entry.get('link') or '').strip()
            if not article_url:
                return

            guid = (entry.get('id') or entry.get('guid') or '').strip() or article_url

            if await self.storage.check_duplicate(article_url, guid):
                self.logger.debug(f"[{source.name}] Skip duplicate: {article_url}")
                stats['articles_skipped'] += 1
                return

        # --- PHASE 2: CONTENT CRAWL (SLOW & HEAVY) ---
        # We use the strict semaphore to limit heavy IO and avoid getting blocked
        async with self.crawl_semaphore:
            # Extract metadata from feed entry
            title = self.metadata_parser.normalize_text(entry.get('title')) or 'Untitled'
            author = self.metadata_parser.extract_author(entry)
            published_at = self.metadata_parser.parse_date(entry)
            summary = self.metadata_parser.extract_summary(entry)
            thumbnail_url = self.metadata_parser.extract_thumbnail(entry)

            # --- LOGIC: CHỈ CRAWL BÀI TRONG HÔM NAY ---
            if published_at:
                today = datetime.now().date()
                article_date = published_at.date()
                if article_date != today:
                    self.logger.debug(
                        f"[{source.name}] Skip (not today): {article_url} "
                        f"(Published: {article_date}, Today: {today})"
                    )
                    stats['articles_skipped'] += 1
                    return

            # Heavy network call
            content_html = await self.extractor.fetch_and_extract_content(client, article_url)

            # Persistence
            saved = await self.storage.save_article(
                source_id=source.id,
                title=title,
                article_url=article_url,
                content_html=content_html,
                author=author,
                summary=summary,
                thumbnail_url=thumbnail_url,
                published_at=published_at,
                guid=guid
            )

            if saved:
                self.logger.info(f"[{source.name}] Saved: {title[:70]}")
                stats['articles_saved'] += 1
            else:
                stats['articles_skipped'] += 1
