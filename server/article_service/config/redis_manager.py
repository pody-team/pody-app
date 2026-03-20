"""
Redis connection manager — async singleton.

Reads connection settings from environment variables:
  REDIS_HOST      (default: localhost)
  REDIS_PORT      (default: 6379)
  REDIS_DB        (default: 0)
  REDIS_PASSWORD  (default: none)
"""
import os
import redis.asyncio as aioredis
from dotenv import load_dotenv

load_dotenv()


class RedisManager:
    """
    Singleton that owns a single async Redis client for the entire process.
    """
    _instance = None
    _client: aioredis.Redis | None = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if self._client is None:
            host = os.getenv('REDIS_HOST', 'localhost')
            port = int(os.getenv('REDIS_PORT', '6379'))
            db = int(os.getenv('REDIS_DB', '0'))
            password = os.getenv('REDIS_PASSWORD') or None

            self._client = aioredis.Redis(
                host=host,
                port=port,
                db=db,
                password=password,
                decode_responses=True,
                # Increase pool size to handle high concurrency article deduplication
                max_connections=50,
            )

    @property
    def client(self) -> aioredis.Redis:
        """Return the underlying async Redis client."""
        return self._client

    async def ping(self) -> bool:
        """Return True if Redis is reachable."""
        try:
            return await self._client.ping()
        except Exception:
            return False

    async def close(self) -> None:
        """Close all connections in the pool."""
        if self._client:
            await self._client.aclose()
