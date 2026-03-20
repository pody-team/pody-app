from typing import Dict, Optional
from datetime import datetime
from config.database import DatabaseManager
from repositories.article_repository import ArticleRepository
from services.article_cache import ArticleCache
from utils.logger import get_logger

class StorageService:
    def __init__(self, db_manager: DatabaseManager, article_cache: ArticleCache):
        self.logger = get_logger(__name__)
        self.db_manager = db_manager
        self._article_cache = article_cache

    async def check_duplicate(self, url: str, guid: Optional[str]) -> bool:
        """Process check in Cache and DB."""
        # Layer 1: Redis cache check
        if await self._article_cache.is_cached(url):
            return True
        if guid and guid != url and await self._article_cache.is_cached(guid):
            return True

        # Layer 2: DB check
        async with self.db_manager.session_factory() as session:
            repo = ArticleRepository(session)
            if await repo.exists_by_url(url):
                # Backfill Redis
                await self._article_cache.mark_crawled(url)
                if guid and guid != url:
                    await self._article_cache.mark_crawled(guid)
                return True
        return False

    async def save_article(
        self,
        source_id: int,
        title: str,
        article_url: str,
        content_html: Optional[str],
        author: Optional[str],
        summary: Optional[str],
        thumbnail_url: Optional[str],
        published_at: Optional[datetime],
        guid: Optional[str]
    ) -> bool:
        """Persist to DB and Cache."""
        try:
            async with self.db_manager.session_factory() as session:
                repo = ArticleRepository(session)
                # Second duplicate check inside transaction
                if await repo.exists_by_url(article_url):
                    return False

                await repo.insert_article(
                    title=title,
                    original_url=article_url,
                    source_id=source_id,
                    content=content_html,
                    author=author,
                    summary=summary,
                    thumbnail_url=thumbnail_url,
                    published_at=published_at,
                    status='PUBLISHED',
                )
                await session.commit()

            # Write-through to Redis
            await self._article_cache.mark_crawled(article_url)
            if guid and guid != article_url:
                await self._article_cache.mark_crawled(guid)
            return True

        except Exception as exc:
            self.logger.error(f"DB error for {article_url}: {exc}", exc_info=True)
            return False
