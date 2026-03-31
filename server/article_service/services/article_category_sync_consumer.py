from __future__ import annotations

import asyncio
from datetime import datetime, timezone
import logging
import threading
import time
from typing import Any

from kafka import KafkaConsumer
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import KafkaError, NoBrokersAvailable, TopicAlreadyExistsError
from kafka.structs import TopicPartition

from category_sync_event import (
    InvalidArticleCategoryMatchesEventError,
    parse_article_category_matches_event,
)
from config import DatabaseManager
from config.category_sync_settings import ArticleCategorySyncConsumerSettings
from repositories.article_category_projection_repository import ArticleCategoryProjectionRepository
from services.article_category_projection_service import ArticleCategoryProjectionService
from utils.kafka_payload import decode_optional_bytes, format_payload, normalize_payload


class ArticleCategorySyncConsumer:
    def __init__(
        self,
        settings: ArticleCategorySyncConsumerSettings,
        logger: logging.Logger,
    ) -> None:
        self._settings = settings
        self._logger = logger
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None
        self._lock = threading.Lock()
        self._state: dict[str, Any] = {
            "topic_ready": False,
            "consumer_connected": False,
            "message_count": 0,
            "processed_events": 0,
            "skipped_events": 0,
            "failed_events": 0,
            "last_message_at": None,
            "last_article_id": None,
            "last_error": None,
        }

    def start(self) -> None:
        if not self._settings.enabled:
            self._logger.info("Article-category sync consumer is disabled by configuration.")
            return
        self.ensure_topic_exists()
        self._thread = threading.Thread(
            target=self._consume_forever,
            name="article-category-sync-consumer",
            daemon=True,
        )
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        if self._thread is not None:
            self._thread.join(timeout=10)

    def ensure_topic_exists(self) -> None:
        deadline = time.monotonic() + self._settings.startup_timeout_seconds
        attempt = 0

        while not self._stop_event.is_set():
            attempt += 1
            admin_client: KafkaAdminClient | None = None
            try:
                admin_client = KafkaAdminClient(
                    bootstrap_servers=self._settings.brokers,
                    client_id=f"{self._settings.client_id}-admin",
                    request_timeout_ms=self._settings.request_timeout_ms,
                    api_version_auto_timeout_ms=self._settings.request_timeout_ms,
                )
                existing_topics = set(admin_client.list_topics())
                if self._settings.topic not in existing_topics:
                    admin_client.create_topics(
                        [
                            NewTopic(
                                name=self._settings.topic,
                                num_partitions=self._settings.topic_partitions,
                                replication_factor=self._settings.topic_replication_factor,
                            )
                        ],
                        validate_only=False,
                    )
                    self._logger.info("Created Kafka topic for article-category sync: %s", self._settings.topic)
                else:
                    self._logger.info("Kafka topic already exists for article-category sync: %s", self._settings.topic)
                self._set_state(topic_ready=True, last_error=None)
                return
            except TopicAlreadyExistsError:
                self._set_state(topic_ready=True, last_error=None)
                return
            except (KafkaError, NoBrokersAvailable, OSError) as exc:
                self._set_state(last_error=str(exc))
                if time.monotonic() >= deadline:
                    raise RuntimeError(
                        f"Timed out while waiting to create topic {self._settings.topic}: {exc}"
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

    def _consume_forever(self) -> None:
        while not self._stop_event.is_set():
            consumer: KafkaConsumer | None = None
            try:
                consumer = KafkaConsumer(
                    self._settings.topic,
                    bootstrap_servers=self._settings.brokers,
                    group_id=self._settings.consumer_group,
                    client_id=self._settings.client_id,
                    enable_auto_commit=False,
                    auto_offset_reset=self._settings.auto_offset_reset,
                    consumer_timeout_ms=1000,
                    max_poll_records=1,
                    session_timeout_ms=self._settings.session_timeout_ms,
                    request_timeout_ms=self._settings.request_timeout_ms,
                    api_version_auto_timeout_ms=self._settings.request_timeout_ms,
                    key_deserializer=decode_optional_bytes,
                    value_deserializer=decode_optional_bytes,
                )
                self._set_state(consumer_connected=True, last_error=None)
                self._logger.info(
                    "Article-category sync consumer started for topic %s with group %s",
                    self._settings.topic,
                    self._settings.consumer_group,
                )
                while not self._stop_event.is_set():
                    for kafka_message in consumer:
                        if self._stop_event.is_set():
                            break
                        if self._handle_message(consumer, kafka_message):
                            continue
                        raise RuntimeError("Retrying article-category sync message after transient failure")
            except (KafkaError, NoBrokersAvailable, OSError, RuntimeError) as exc:
                self._set_state(consumer_connected=False, last_error=str(exc))
                if self._stop_event.is_set():
                    break
                self._logger.warning(
                    "Article-category sync consumer disconnected. Retrying in %.1fs. Error: %s",
                    self._settings.retry_delay_seconds,
                    exc,
                )
                time.sleep(self._settings.retry_delay_seconds)
            finally:
                self._set_state(consumer_connected=False)
                if consumer is not None:
                    consumer.close()

    def _handle_message(self, consumer: KafkaConsumer, kafka_message: Any) -> bool:
        payload = normalize_payload(kafka_message.value)
        now = datetime.now(timezone.utc).isoformat()

        try:
            result = asyncio.run(self._consume_payload(payload))
            consumer.commit()
            self._set_state(
                message_count=self._state["message_count"] + 1,
                processed_events=self._state["processed_events"] + (1 if result == "applied" else 0),
                skipped_events=self._state["skipped_events"] + (1 if result != "applied" else 0),
                last_message_at=now,
                last_error=None,
            )
            return True
        except InvalidArticleCategoryMatchesEventError as exc:
            consumer.commit()
            self._set_state(
                message_count=self._state["message_count"] + 1,
                failed_events=self._state["failed_events"] + 1,
                last_message_at=now,
                last_error=str(exc),
            )
            self._logger.error(
                "Article-category sync message skipped permanently | topic=%s partition=%s offset=%s error=%s payload=%s",
                kafka_message.topic,
                kafka_message.partition,
                kafka_message.offset,
                exc,
                format_payload(payload),
            )
            return True
        except Exception as exc:
            topic_partition = TopicPartition(kafka_message.topic, kafka_message.partition)
            consumer.seek(topic_partition, kafka_message.offset)
            self._set_state(
                failed_events=self._state["failed_events"] + 1,
                last_error=str(exc),
            )
            self._logger.exception(
                "Article-category sync processing failed | topic=%s partition=%s offset=%s",
                kafka_message.topic,
                kafka_message.partition,
                kafka_message.offset,
            )
            return False

    async def _consume_payload(self, payload: object) -> str:
        event = parse_article_category_matches_event(payload)
        session = DatabaseManager().session_factory()
        try:
            repository = ArticleCategoryProjectionRepository(session)
            service = ArticleCategoryProjectionService(repository, self._logger.getChild("service"))
            result = await service.apply_event(event)
            await session.commit()
            self._set_state(last_article_id=event.article_id)
            return result
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

    def _set_state(self, **updates: Any) -> None:
        with self._lock:
            self._state.update(updates)
