from __future__ import annotations

from datetime import datetime, timedelta, timezone
import json
import logging
import threading
import time
from typing import TYPE_CHECKING, Any, Callable

from kafka import KafkaProducer
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import KafkaError, NoBrokersAvailable, TopicAlreadyExistsError

from app.config.settings import KafkaSettings

if TYPE_CHECKING:
    from app.model.repository import EmbeddingRepository


class KafkaArticleCategorySyncPublisher:
    def __init__(
        self,
        settings: KafkaSettings,
        repository: "EmbeddingRepository",
        logger: logging.Logger,
        producer_factory: Callable[..., KafkaProducer] | None = None,
    ) -> None:
        self._settings = settings
        self._repository = repository
        self._logger = logger
        self._producer_factory = producer_factory or KafkaProducer
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None
        self._lock = threading.Lock()
        self._state: dict[str, Any] = {
            "topic_ready": False,
            "publisher_connected": False,
            "published_events": 0,
            "failed_events": 0,
            "last_event_id": None,
            "last_error": None,
        }

    def start(self) -> None:
        self.ensure_topic_exists()
        self._thread = threading.Thread(
            target=self._publish_forever,
            name="embedding-category-sync-publisher",
            daemon=True,
        )
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        if self._thread is not None:
            self._thread.join(timeout=10)

    def status(self) -> dict[str, Any]:
        with self._lock:
            return {
                "topic": self._settings.article_category_sync_topic,
                **self._state,
            }

    def ensure_topic_exists(self) -> None:
        deadline = time.monotonic() + self._settings.startup_timeout_seconds
        attempt = 0

        while not self._stop_event.is_set():
            attempt += 1
            admin_client: KafkaAdminClient | None = None
            try:
                admin_client = KafkaAdminClient(
                    bootstrap_servers=self._settings.brokers,
                    client_id=f"{self._settings.client_id}-category-sync-admin",
                    request_timeout_ms=self._settings.request_timeout_ms,
                    api_version_auto_timeout_ms=self._settings.request_timeout_ms,
                )
                existing_topics = set(admin_client.list_topics())
                if self._settings.article_category_sync_topic not in existing_topics:
                    admin_client.create_topics(
                        [
                            NewTopic(
                                name=self._settings.article_category_sync_topic,
                                num_partitions=self._settings.topic_partitions,
                                replication_factor=self._settings.topic_replication_factor,
                            )
                        ],
                        validate_only=False,
                    )
                    self._logger.info(
                        "Created Kafka topic for article-category sync: %s",
                        self._settings.article_category_sync_topic,
                    )
                else:
                    self._logger.info(
                        "Kafka topic already exists for article-category sync: %s",
                        self._settings.article_category_sync_topic,
                    )
                self._set_state(topic_ready=True, last_error=None)
                return
            except TopicAlreadyExistsError:
                self._set_state(topic_ready=True, last_error=None)
                return
            except (KafkaError, NoBrokersAvailable, OSError) as exc:
                self._set_state(last_error=str(exc))
                if time.monotonic() >= deadline:
                    raise RuntimeError(
                        "Timed out while waiting to create topic "
                        f"{self._settings.article_category_sync_topic}: {exc}"
                    ) from exc
                self._logger.warning(
                    "Kafka admin for article-category sync is not ready yet (attempt %s). "
                    "Retrying in %.1fs. Error: %s",
                    attempt,
                    self._settings.retry_delay_seconds,
                    exc,
                )
                time.sleep(self._settings.retry_delay_seconds)
            finally:
                if admin_client is not None:
                    admin_client.close()

    def flush_once(self) -> int:
        producer = self._create_producer()
        try:
            return self._flush_pending_events(producer)
        finally:
            self._set_state(publisher_connected=False)
            producer.close()

    def _publish_forever(self) -> None:
        while not self._stop_event.is_set():
            producer: KafkaProducer | None = None
            try:
                producer = self._create_producer()
                while not self._stop_event.is_set():
                    self._flush_pending_events(producer)
                    self._stop_event.wait(self._settings.outbox_poll_interval_seconds)
            except (KafkaError, NoBrokersAvailable, OSError, RuntimeError) as exc:
                self._set_state(publisher_connected=False, last_error=str(exc))
                if self._stop_event.is_set():
                    break
                self._logger.warning(
                    "Article-category sync publisher disconnected. Retrying in %.1fs. Error: %s",
                    self._settings.retry_delay_seconds,
                    exc,
                )
                self._stop_event.wait(self._settings.retry_delay_seconds)
            finally:
                self._set_state(publisher_connected=False)
                if producer is not None:
                    producer.close()

    def _create_producer(self) -> KafkaProducer:
        return self._producer_factory(
            bootstrap_servers=self._settings.brokers,
            client_id=f"{self._settings.client_id}-category-sync-publisher",
            request_timeout_ms=self._settings.request_timeout_ms,
            api_version_auto_timeout_ms=self._settings.request_timeout_ms,
            key_serializer=lambda value: value.encode("utf-8"),
            value_serializer=lambda value: json.dumps(value).encode("utf-8"),
        )

    def _flush_pending_events(self, producer: KafkaProducer) -> int:
        published_count = 0
        self._set_state(publisher_connected=True, last_error=None)
        events = self._repository.list_publishable_outbox_events(
            limit=self._settings.outbox_batch_size,
        )
        for event in events:
            try:
                future = producer.send(
                    self._settings.article_category_sync_topic,
                    key=event.aggregate_id,
                    value=event.payload,
                )
                future.get(timeout=self._settings.request_timeout_ms / 1000)
                producer.flush(timeout=self._settings.request_timeout_ms / 1000)
                self._repository.mark_outbox_event_published(event_id=event.id)
                published_count += 1
                self._set_state(
                    published_events=self._state["published_events"] + 1,
                    last_event_id=event.id,
                    last_error=None,
                )
            except Exception as exc:
                self._repository.mark_outbox_event_failed(
                    event_id=event.id,
                    next_retry_at=_next_retry_at(event.attempts + 1),
                    error_message=str(exc),
                )
                self._set_state(
                    failed_events=self._state["failed_events"] + 1,
                    last_error=str(exc),
                )
                self._logger.error(
                    "Article-category sync publish failed | event_id=%s event_type=%s error=%s",
                    event.id,
                    event.event_type,
                    exc,
                )
        return published_count

    def _set_state(self, **updates: Any) -> None:
        with self._lock:
            self._state.update(updates)


def _next_retry_at(attempt: int):
    bounded_attempt = max(1, min(attempt, 6))
    delay_seconds = 2 ** (bounded_attempt - 1)
    return datetime.now(timezone.utc) + timedelta(seconds=delay_seconds)
