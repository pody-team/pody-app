import logging
import unittest
from datetime import datetime, timezone

from app.config.settings import KafkaSettings
from app.controller.kafka_article_category_sync_publisher import KafkaArticleCategorySyncPublisher
from app.model.entity import OutboxEvent


class FakeRepository:
    def __init__(self, events: list[OutboxEvent]) -> None:
        self.events = events
        self.published_event_ids: list[str] = []
        self.failed_event_ids: list[tuple[str, str]] = []

    def list_publishable_outbox_events(self, *, limit: int) -> list[OutboxEvent]:
        return list(self.events[:limit])

    def mark_outbox_event_published(self, *, event_id: str) -> None:
        self.published_event_ids.append(event_id)

    def mark_outbox_event_failed(self, *, event_id: str, next_retry_at, error_message: str) -> None:
        self.failed_event_ids.append((event_id, error_message))


class FakeFuture:
    def __init__(self, error: Exception | None = None) -> None:
        self.error = error

    def get(self, timeout=None):
        if self.error is not None:
            raise self.error
        return None


class FakeProducer:
    def __init__(self, *, error: Exception | None = None, **kwargs) -> None:
        self.error = error
        self.sent_messages: list[tuple[str, str, dict[str, object]]] = []

    def send(self, topic: str, key: str, value: dict[str, object]):
        self.sent_messages.append((topic, key, value))
        return FakeFuture(self.error)

    def flush(self, timeout=None):
        return None

    def close(self):
        return None


class ArticleCategorySyncPublisherTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settings = KafkaSettings(
            brokers=["localhost:9092"],
            topic="article.embedding.requested",
            article_category_sync_topic="article.category.matches.generated",
            client_id="embedding-service",
            consumer_group="embedding-service",
            auto_offset_reset="earliest",
            topic_partitions=1,
            topic_replication_factor=1,
            request_timeout_ms=30000,
            session_timeout_ms=10000,
            startup_timeout_seconds=120,
            retry_delay_seconds=2.0,
            outbox_poll_interval_seconds=1.0,
            outbox_batch_size=20,
        )
        self.logger = logging.getLogger("embedding-sync-publisher-tests")

    def test_flush_once_publishes_pending_outbox_events(self):
        event = self._event(event_id="evt-1")
        repository = FakeRepository([event])
        producer = FakeProducer()
        publisher = KafkaArticleCategorySyncPublisher(
            self.settings,
            repository,
            self.logger,
            producer_factory=lambda **kwargs: producer,
        )

        published_count = publisher.flush_once()

        self.assertEqual(published_count, 1)
        self.assertEqual(repository.published_event_ids, ["evt-1"])
        self.assertEqual(repository.failed_event_ids, [])
        self.assertEqual(producer.sent_messages[0][0], "article.category.matches.generated")
        self.assertEqual(producer.sent_messages[0][1], "42")

    def test_flush_once_marks_failure_for_retry(self):
        event = self._event(event_id="evt-2")
        repository = FakeRepository([event])
        publisher = KafkaArticleCategorySyncPublisher(
            self.settings,
            repository,
            self.logger,
            producer_factory=lambda **kwargs: FakeProducer(error=RuntimeError("boom")),
        )

        published_count = publisher.flush_once()

        self.assertEqual(published_count, 0)
        self.assertEqual(repository.published_event_ids, [])
        self.assertEqual(repository.failed_event_ids[0][0], "evt-2")
        self.assertIn("boom", repository.failed_event_ids[0][1])

    @staticmethod
    def _event(*, event_id: str) -> OutboxEvent:
        now = datetime(2026, 3, 29, 12, 0, 0, tzinfo=timezone.utc)
        return OutboxEvent(
            id=event_id,
            aggregate_type="article",
            aggregate_id="42",
            event_type="article.category.matches.generated.v1",
            payload_version=1,
            payload={
                "event_id": event_id,
                "idempotency_key": "article-category-sync:42:hash:model:v1",
                "event_type": "article.category.matches.generated.v1",
                "occurred_at": now.isoformat(),
                "source_service": "embedding-service",
                "article_id": 42,
                "article_status": "PUBLISHED",
                "content_hash": "hash",
                "model_name": "gemini-embedding-001",
                "embedding_version": "v1",
                "matches": [],
            },
            attempts=0,
            last_error=None,
            status="pending",
            available_at=now,
            published_at=None,
            created_at=now,
            updated_at=now,
        )


if __name__ == "__main__":
    unittest.main()
