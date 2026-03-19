"""
Article deduplication cache backed by Redis.

Each crawled article URL is stored in Redis with a configurable TTL so that
subsequent crawl cycles (every 30 min) can skip already-processed articles
without hitting the database.

Key format : taha:article:<url>
TTL        : ARTICLE_CACHE_TTL_SECONDS  (default 7 days = 604 800 s)

Design decisions
----------------
* **Fail-open** — any Redis error causes is_cached() to return False,
  so the system falls back to the DB duplicate check.  This means Redis
  is an *optimisation*, not a hard dependency.
* **7-day TTL** — long enough to cover weeks of crawl cycles for the same
  article, short enough to avoid Redis growing unbounded.  Adjust via the
  env-var ARTICLE_CACHE_TTL_SECONDS if needed.
* **Pipeline for batch writes** — when multiple URLs need to be marked at
  once (future extension), a single pipeline call is used.
"""
import os
from typing import List

import redis.asyncio as aioredis

from utils.logger import get_logger

# 7 days in seconds — sensible default for a news crawler that runs every 30 min
_DEFAULT_TTL_SECONDS = 7 * 24 * 3600


class ArticleCache:
    """
    Thin wrapper around a Redis client that provides article-level
    deduplication semantics for the crawler.
    """

    _KEY_PREFIX = "taha:article:"

    def __init__(self, redis_client: aioredis.Redis):
        self._redis = redis_client
        self._ttl: int = int(
            os.getenv('ARTICLE_CACHE_TTL_SECONDS', str(_DEFAULT_TTL_SECONDS))
        )
        self.logger = get_logger(__name__)

    # ------------------------------------------------------------------ #
    #  Key helpers
    # ------------------------------------------------------------------ #

    def _key(self, url: str) -> str:
        return f"{self._KEY_PREFIX}{url}"

    # ------------------------------------------------------------------ #
    #  Public API
    # ------------------------------------------------------------------ #

    async def is_cached(self, url: str) -> bool:
        """
        Return True if this URL has been crawled recently (exists in Redis).

        Fail-open: returns False on any Redis error so the caller can fall
        back to the DB check.
        """
        try:
            return bool(await self._redis.exists(self._key(url)))
        except Exception as exc:
            self.logger.warning(
                f"[ArticleCache] Redis EXISTS error for '{url}': {exc} — "
                "falling back to DB check."
            )
            return False

    async def mark_crawled(self, url: str) -> None:
        """
        Record that this URL has been crawled, with the configured TTL.
        Silently ignores Redis errors.
        """
        try:
            await self._redis.set(self._key(url), "1", ex=self._ttl)
        except Exception as exc:
            self.logger.warning(
                f"[ArticleCache] Redis SET error for '{url}': {exc}"
            )

    async def mark_crawled_batch(self, urls: List[str]) -> None:
        """
        Mark multiple URLs as crawled in a single Redis pipeline.
        Useful for bulk backfill scenarios.
        """
        if not urls:
            return
        try:
            async with self._redis.pipeline(transaction=False) as pipe:
                for url in urls:
                    pipe.set(self._key(url), "1", ex=self._ttl)
                await pipe.execute()
            self.logger.debug(
                f"[ArticleCache] Batch-marked {len(urls)} URL(s) in Redis."
            )
        except Exception as exc:
            self.logger.warning(
                f"[ArticleCache] Redis pipeline error during batch mark: {exc}"
            )

    async def invalidate(self, url: str) -> None:
        """
        Remove a URL from the cache (e.g., to force a re-crawl).
        """
        try:
            await self._redis.delete(self._key(url))
        except Exception as exc:
            self.logger.warning(
                f"[ArticleCache] Redis DELETE error for '{url}': {exc}"
            )
