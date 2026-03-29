from __future__ import annotations

import logging
import time

from app.config.database import create_pool
from app.config.settings import AppSettings
from app.controller import (
    ArticleSearchController,
    ArticleEventController,
    CategoryEventController,
    KafkaArticleConsumerController,
    KafkaCategoryConsumerController,
    SystemController,
)
from app.model.repository import EmbeddingRepository
from app.model.response import HealthResponse, ServiceOverviewResponse
from app.service.article_embedding_service import ArticleEmbeddingService
from app.service.category_embedding_service import CategoryEmbeddingService
from app.service.gemini_provider import GeminiEmbeddingProvider


class EmbeddingRuntime:
    def __init__(self, settings: AppSettings, logger: logging.Logger) -> None:
        self.settings = settings
        self._logger = logger
        self._pool = create_pool(settings.database)
        self._repository = EmbeddingRepository(self._pool)
        self._provider = GeminiEmbeddingProvider(settings.gemini, logger.getChild("gemini"))
        self._article_service = ArticleEmbeddingService(
            self._repository,
            self._provider,
            settings,
            logger.getChild("article"),
        )
        self._category_service = CategoryEmbeddingService(
            self._repository,
            self._provider,
            settings,
            logger.getChild("category"),
        )
        self.article_search_controller = ArticleSearchController(self._article_service)
        self.article_event_controller = ArticleEventController(self._article_service)
        self.category_event_controller = CategoryEventController(self._category_service)
        self.kafka_consumer_controller = KafkaArticleConsumerController(
            settings.kafka,
            self.article_event_controller,
            logger.getChild("kafka.article"),
        )
        self.kafka_category_consumer_controller = KafkaCategoryConsumerController(
            settings.kafka,
            self.category_event_controller,
            logger.getChild("kafka.category"),
        )
        self.system_controller = SystemController(self)
        self._runtime_state = {
            "database_ready": False,
            "provider_ready": self._provider.is_ready,
            "configured_api_keys": self._provider.configured_api_keys,
            "last_error": None,
        }

    def start(self) -> None:
        self._wait_for_database()
        if not self._provider.has_credentials:
            self._runtime_state.update(
                provider_ready=False,
                last_error="No Gemini API key configured for embedding-service",
            )
            self._logger.error(
                "Embedding service started without any Gemini API key. Kafka consumer will stay stopped."
            )
            return
        if not self._provider.probe():
            self._runtime_state.update(
                provider_ready=False,
                last_error=self._provider.last_error or "Gemini embedding provider is not reachable",
            )
            self._logger.error(
                "Embedding service failed provider probe. Kafka consumer will stay stopped. Error: %s",
                self._provider.last_error,
            )
            return
        self._runtime_state.update(provider_ready=True, last_error=None)
        self.kafka_consumer_controller.start()
        self.kafka_category_consumer_controller.start()

    def stop(self) -> None:
        self.kafka_consumer_controller.stop()
        self.kafka_category_consumer_controller.stop()
        self._pool.close()

    def service_overview(self) -> ServiceOverviewResponse:
        return ServiceOverviewResponse(
            name="embedding-service",
            status="ok" if self._provider.is_ready else "degraded",
            article_topic=self.settings.kafka.topic,
            category_topic=self.settings.kafka.category_topic,
            consumer_group=self.settings.kafka.consumer_group,
            embedding_model=self.settings.gemini.embedding_model,
            configured_api_keys=len(self.settings.gemini.api_keys),
        )

    def health(self) -> HealthResponse:
        database_ready = self._repository.ping()
        self._runtime_state["database_ready"] = database_ready
        article_consumer_state = self.kafka_consumer_controller.status()
        category_consumer_state = self.kafka_category_consumer_controller.status()
        provider_ready = self._provider.is_ready
        overall_ready = bool(
            database_ready
            and provider_ready
            and article_consumer_state.get("topic_ready")
            and category_consumer_state.get("topic_ready")
            and article_consumer_state.get("consumer_connected")
            and category_consumer_state.get("consumer_connected")
        )
        return HealthResponse(
            status="ok" if overall_ready else "degraded",
            database_ready=database_ready,
            provider_ready=provider_ready,
            configured_api_keys=self._provider.configured_api_keys,
            article_topic=str(article_consumer_state.get("topic") or self.settings.kafka.topic),
            category_topic=str(
                category_consumer_state.get("topic") or self.settings.kafka.category_topic
            ),
            consumer_group=str(
                article_consumer_state.get("consumer_group") or self.settings.kafka.consumer_group
            ),
            article_topic_ready=bool(article_consumer_state.get("topic_ready")),
            category_topic_ready=bool(category_consumer_state.get("topic_ready")),
            article_consumer_connected=bool(article_consumer_state.get("consumer_connected")),
            category_consumer_connected=bool(category_consumer_state.get("consumer_connected")),
            article_message_count=int(article_consumer_state.get("message_count") or 0),
            category_message_count=int(category_consumer_state.get("message_count") or 0),
            processed_articles=int(article_consumer_state.get("processed_articles") or 0),
            skipped_articles=int(article_consumer_state.get("skipped_articles") or 0),
            failed_articles=int(article_consumer_state.get("failed_articles") or 0),
            processed_categories=int(category_consumer_state.get("processed_categories") or 0),
            skipped_categories=int(category_consumer_state.get("skipped_categories") or 0),
            failed_categories=int(category_consumer_state.get("failed_categories") or 0),
            last_article_message_at=article_consumer_state.get("last_message_at"),
            last_category_message_at=category_consumer_state.get("last_message_at"),
            last_article_id=_optional_int(article_consumer_state.get("last_article_id")),
            last_category_id=_optional_str(category_consumer_state.get("last_category_id")),
            last_error=(
                category_consumer_state.get("last_error")
                or article_consumer_state.get("last_error")
                or self._provider.last_error
                or self._runtime_state.get("last_error")
            ),
        )

    def _wait_for_database(self) -> None:
        deadline = time.monotonic() + self.settings.database.startup_timeout_seconds
        attempt = 0
        self._pool.open(wait=False)
        while True:
            attempt += 1
            if self._repository.ping():
                self._runtime_state.update(database_ready=True, last_error=None)
                self._logger.info("Embedding database is ready")
                return
            if time.monotonic() >= deadline:
                raise RuntimeError("Timed out while waiting for the embedding database")
            self._runtime_state["last_error"] = "Embedding database is not ready yet"
            self._logger.warning(
                "Embedding database is not ready yet (attempt %s). Retrying in %.1fs.",
                attempt,
                self.settings.database.retry_delay_seconds,
            )
            time.sleep(self.settings.database.retry_delay_seconds)


def _optional_int(value: object) -> int | None:
    if value is None:
        return None
    return int(value)


def _optional_str(value: object) -> str | None:
    if value is None:
        return None
    return str(value)
