from __future__ import annotations

from datetime import datetime, timezone
import json
import logging
import threading
import time
from typing import Any

from kafka import KafkaConsumer
from kafka.admin import KafkaAdminClient, NewTopic
from kafka.errors import KafkaError, NoBrokersAvailable, TopicAlreadyExistsError
from kafka.structs import TopicPartition

from app.config.settings import KafkaSettings
from app.controller.article_event_controller import ArticleEventController
from app.model.request import KafkaMessageContext
from app.model.response import ArticleProcessingResult
from app.service.article_embedding_service import PermanentArticleProcessingError
from app.service.gemini_provider import EmbeddingRateLimitError


class KafkaArticleConsumerController:
    def __init__(
        self,
        settings: KafkaSettings,
        article_event_controller: ArticleEventController,
        logger: logging.Logger,
    ) -> None:
        self._settings = settings
        self._article_event_controller = article_event_controller
        self._logger = logger
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None
        self._lock = threading.Lock()
        self._state: dict[str, Any] = {
            "topic_ready": False,
            "consumer_connected": False,
            "message_count": 0,
            "processed_articles": 0,
            "skipped_articles": 0,
            "failed_articles": 0,
            "last_message_at": None,
            "last_article_id": None,
            "last_error": None,
        }

    def start(self) -> None:
        self.ensure_topic_exists()
        self._thread = threading.Thread(
            target=self._consume_forever,
            name="embedding-kafka-consumer",
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
                "topic": self._settings.topic,
                "consumer_group": self._settings.consumer_group,
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
                    client_id=self._settings.client_id,
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
                    self._logger.info("Created Kafka topic: %s", self._settings.topic)
                else:
                    self._logger.info("Kafka topic already exists: %s", self._settings.topic)
                self._set_state(topic_ready=True, last_error=None)
                return
            except TopicAlreadyExistsError:
                self._logger.info("Kafka topic already exists: %s", self._settings.topic)
                self._set_state(topic_ready=True, last_error=None)
                return
            except (KafkaError, NoBrokersAvailable, OSError) as exc:
                self._set_state(last_error=str(exc))
                if time.monotonic() >= deadline:
                    raise RuntimeError(
                        f"Timed out while waiting to create topic {self._settings.topic}: {exc}"
                    ) from exc
                self._logger.warning(
                    "Kafka admin is not ready yet (attempt %s). Retrying in %.1fs. Error: %s",
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
                    key_deserializer=_decode_optional_bytes,
                    value_deserializer=_decode_optional_bytes,
                )

                self._set_state(consumer_connected=True, last_error=None)
                self._logger.info(
                    "Kafka consumer started for topic %s with group %s",
                    self._settings.topic,
                    self._settings.consumer_group,
                )

                while not self._stop_event.is_set():
                    for kafka_message in consumer:
                        if self._stop_event.is_set():
                            break
                        if self._handle_message(consumer, kafka_message):
                            continue
                        raise RuntimeError("Retrying Kafka message after transient processing failure")
            except (KafkaError, NoBrokersAvailable, OSError, RuntimeError) as exc:
                self._set_state(consumer_connected=False, last_error=str(exc))
                if self._stop_event.is_set():
                    break
                self._logger.warning(
                    "Kafka consumer disconnected. Retrying in %.1fs. Error: %s",
                    self._settings.retry_delay_seconds,
                    exc,
                )
                time.sleep(self._settings.retry_delay_seconds)
            finally:
                self._set_state(consumer_connected=False)
                if consumer is not None:
                    consumer.close()

    def _handle_message(self, consumer: KafkaConsumer, kafka_message: Any) -> bool:
        payload = _normalize_payload(kafka_message.value)
        context = KafkaMessageContext(
            topic=kafka_message.topic,
            partition=kafka_message.partition,
            offset=kafka_message.offset,
            key=kafka_message.key,
        )
        now = datetime.now(timezone.utc).isoformat()

        try:
            result = self._article_event_controller.handle_message(payload, context)
            consumer.commit()
            self._record_success(result, now=now)
            self._logger.info(
                "Kafka article message handled | topic=%s partition=%s offset=%s article_id=%s status=%s chunk_count=%s",
                kafka_message.topic,
                kafka_message.partition,
                kafka_message.offset,
                result.article_id,
                result.status,
                result.chunk_count,
            )
            return True
        except PermanentArticleProcessingError as exc:
            consumer.commit()
            self._set_state(
                message_count=self._state["message_count"] + 1,
                failed_articles=self._state["failed_articles"] + 1,
                last_message_at=now,
                last_error=str(exc),
            )
            self._logger.error(
                "Kafka article message skipped permanently | topic=%s partition=%s offset=%s error=%s payload=%s",
                kafka_message.topic,
                kafka_message.partition,
                kafka_message.offset,
                exc,
                _format_payload(payload),
            )
            return True
        except EmbeddingRateLimitError as exc:
            self._set_state(
                failed_articles=self._state["failed_articles"] + 1,
                last_message_at=now,
                last_error=str(exc),
            )
            topic_partition = TopicPartition(kafka_message.topic, kafka_message.partition)
            consumer.seek(topic_partition, kafka_message.offset)
            self._logger.warning(
                "Gemini embedding quota exhausted | topic=%s partition=%s offset=%s retry_in=%.1fs error=%s",
                kafka_message.topic,
                kafka_message.partition,
                kafka_message.offset,
                exc.retry_delay_seconds,
                exc,
            )
            self._stop_event.wait(exc.retry_delay_seconds)
            return True
        except Exception as exc:
            self._set_state(
                failed_articles=self._state["failed_articles"] + 1,
                last_error=str(exc),
            )
            topic_partition = TopicPartition(kafka_message.topic, kafka_message.partition)
            consumer.seek(topic_partition, kafka_message.offset)
            self._logger.exception(
                "Kafka article message processing failed | topic=%s partition=%s offset=%s",
                kafka_message.topic,
                kafka_message.partition,
                kafka_message.offset,
            )
            return False

    def _record_success(self, result: ArticleProcessingResult, *, now: str) -> None:
        self._set_state(
            message_count=self._state["message_count"] + 1,
            processed_articles=self._state["processed_articles"] + (1 if result.status == "processed" else 0),
            skipped_articles=self._state["skipped_articles"] + (1 if result.status == "skipped" else 0),
            last_message_at=now,
            last_article_id=result.article_id,
            last_error=None,
        )

    def _set_state(self, **updates: Any) -> None:
        with self._lock:
            self._state.update(updates)


def _decode_optional_bytes(value: bytes | None) -> str | None:
    if value is None:
        return None
    try:
        return value.decode("utf-8")
    except UnicodeDecodeError:
        return value.decode("utf-8", errors="replace")


def _normalize_payload(payload: str | None) -> Any:
    if payload is None:
        return None
    stripped = payload.strip()
    if not stripped:
        return ""
    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        return stripped


def _format_payload(payload: Any) -> str:
    if payload is None:
        return "null"
    if isinstance(payload, (dict, list)):
        return json.dumps(payload, ensure_ascii=False, sort_keys=True)
    return str(payload)
