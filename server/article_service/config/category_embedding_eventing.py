"""
Category embedding eventing configuration for article_service.
"""
from __future__ import annotations

import os
from dataclasses import dataclass


def _bool_env(key: str, default: bool) -> bool:
    value = os.getenv(key, "").strip().lower()
    if not value:
        return default
    return value in {"1", "true", "yes", "on"}


def _float_env(key: str, default: float) -> float:
    value = os.getenv(key, "").strip()
    if not value:
        return default
    parsed = float(value)
    if parsed <= 0:
        raise ValueError(f"{key} must be greater than zero")
    return parsed


def _int_env(key: str, default: int) -> int:
    value = os.getenv(key, "").strip()
    if not value:
        return default
    parsed = int(value)
    if parsed <= 0:
        raise ValueError(f"{key} must be greater than zero")
    return parsed


def _csv_env(key: str, default: list[str]) -> list[str]:
    value = os.getenv(key, "").strip()
    if not value:
        return default
    items = [item.strip() for item in value.split(",") if item.strip()]
    return items or default


def _string_env(key: str, default: str) -> str:
    value = os.getenv(key, "").strip()
    return value or default


@dataclass(frozen=True)
class CategoryEmbeddingEventingSettings:
    enabled: bool
    brokers: list[str]
    topic: str
    client_id: str
    poll_interval_seconds: float
    retry_delay_seconds: float
    batch_size: int
    max_attempts: int
    request_timeout_ms: int


def load_category_embedding_eventing_settings() -> CategoryEmbeddingEventingSettings:
    brokers = _csv_env("KAFKA_BROKERS", ["localhost:9092"])
    return CategoryEmbeddingEventingSettings(
        enabled=_bool_env("CATEGORY_EMBEDDING_OUTBOX_ENABLED", False),
        brokers=brokers,
        topic=_string_env("CATEGORY_EMBEDDING_EVENTS_TOPIC", "category.embedding.requested"),
        client_id=_string_env(
            "CATEGORY_EMBEDDING_KAFKA_CLIENT_ID",
            "article-service-category-events",
        ),
        poll_interval_seconds=_float_env("CATEGORY_EMBEDDING_OUTBOX_POLL_INTERVAL_SECONDS", 1.0),
        retry_delay_seconds=_float_env("CATEGORY_EMBEDDING_OUTBOX_RETRY_DELAY_SECONDS", 5.0),
        batch_size=_int_env("CATEGORY_EMBEDDING_OUTBOX_BATCH_SIZE", 20),
        max_attempts=_int_env("CATEGORY_EMBEDDING_OUTBOX_MAX_ATTEMPTS", 5),
        request_timeout_ms=_int_env("CATEGORY_EMBEDDING_KAFKA_REQUEST_TIMEOUT_MS", 10000),
    )
