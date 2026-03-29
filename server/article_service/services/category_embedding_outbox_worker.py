"""
Background worker that publishes category embedding requests from the article_service outbox.
"""
from __future__ import annotations

import asyncio
import json
from typing import Callable

from kafka import KafkaProducer
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from config.category_embedding_eventing import CategoryEmbeddingEventingSettings
from repositories import OutboxEventRepository


class CategoryEmbeddingOutboxWorker:
    def __init__(
        self,
        session_factory: async_sessionmaker[AsyncSession],
        settings: CategoryEmbeddingEventingSettings,
        logger,
    ) -> None:
        self._session_factory = session_factory
        self._settings = settings
        self._logger = logger
        self._stop_event = asyncio.Event()
        self._task: asyncio.Task[None] | None = None
        self._producer_factory: Callable[[], KafkaProducer] = self._build_producer
        self._producer: KafkaProducer | None = None

    @property
    def enabled(self) -> bool:
        return self._settings.enabled

    async def start(self) -> None:
        if not self._settings.enabled:
            self._logger.info("Category embedding outbox worker disabled by configuration")
            return
        if self._task is not None:
            return
        self._stop_event.clear()
        self._task = asyncio.create_task(self._run(), name="category-embedding-outbox-worker")
        self._logger.info(
            "Category embedding outbox worker started for topic %s",
            self._settings.topic,
        )

    async def stop(self) -> None:
        self._stop_event.set()
        if self._task is not None:
            await self._task
            self._task = None
        if self._producer is not None:
            await asyncio.to_thread(self._producer.close)
            self._producer = None

    async def _run(self) -> None:
        while not self._stop_event.is_set():
            published_any = await self._publish_batch()
            if published_any:
                continue
            try:
                await asyncio.wait_for(
                    self._stop_event.wait(),
                    timeout=self._settings.poll_interval_seconds,
                )
            except asyncio.TimeoutError:
                continue

    async def _publish_batch(self) -> bool:
        async with self._session_factory() as session:
            repository = OutboxEventRepository(session)
            events = await repository.claim_pending(limit=self._settings.batch_size)
            await session.commit()

        if not events:
            return False

        for event in events:
            try:
                await self._publish_event(event)
                async with self._session_factory() as session:
                    repository = OutboxEventRepository(session)
                    await repository.mark_published(event_id=str(event.id))
                    await session.commit()
            except Exception as exc:
                self._logger.error(
                    "Failed to publish category embedding outbox event %s: %s",
                    event.id,
                    exc,
                )
                async with self._session_factory() as session:
                    repository = OutboxEventRepository(session)
                    await repository.mark_failed(
                        event_id=str(event.id),
                        error_message=str(exc),
                        retry_delay_seconds=self._settings.retry_delay_seconds,
                        max_attempts=self._settings.max_attempts,
                    )
                    await session.commit()
        return True

    async def _publish_event(self, event) -> None:
        producer = await self._ensure_producer()
        payload_bytes = json.dumps(event.payload, ensure_ascii=False).encode("utf-8")
        key = str(event.aggregate_id).encode("utf-8")
        future = producer.send(self._settings.topic, key=key, value=payload_bytes)
        await asyncio.to_thread(future.get, timeout=max(self._settings.request_timeout_ms / 1000.0, 1.0))
        await asyncio.to_thread(producer.flush)

    async def _ensure_producer(self) -> KafkaProducer:
        if self._producer is None:
            self._producer = await asyncio.to_thread(self._producer_factory)
        return self._producer

    def _build_producer(self) -> KafkaProducer:
        return KafkaProducer(
            bootstrap_servers=self._settings.brokers,
            client_id=self._settings.client_id,
            request_timeout_ms=self._settings.request_timeout_ms,
            max_block_ms=self._settings.request_timeout_ms,
            linger_ms=0,
        )
