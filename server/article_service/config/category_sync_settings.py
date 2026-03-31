from __future__ import annotations

from dataclasses import dataclass
import os


def _string_env(key: str, default: str) -> str:
    value = os.getenv(key, "").strip()
    return value or default


def _bool_env(key: str, default: bool) -> bool:
    value = os.getenv(key, "").strip().lower()
    if not value:
        return default
    return value in {"1", "true", "yes", "on"}


def _int_env(key: str, default: int) -> int:
    value = os.getenv(key, "").strip()
    if not value:
        return default
    parsed = int(value)
    if parsed <= 0:
        raise ValueError(f"{key} must be greater than zero")
    return parsed


def _float_env(key: str, default: float) -> float:
    value = os.getenv(key, "").strip()
    if not value:
        return default
    parsed = float(value)
    if parsed <= 0:
        raise ValueError(f"{key} must be greater than zero")
    return parsed


def _csv_env(key: str, default: list[str]) -> list[str]:
    value = os.getenv(key, "").strip()
    if not value:
        return default
    items = [item.strip() for item in value.split(",") if item.strip()]
    return items or default


@dataclass(frozen=True)
class ArticleCategorySyncConsumerSettings:
    enabled: bool
    brokers: list[str]
    topic: str
    client_id: str
    consumer_group: str
    auto_offset_reset: str
    topic_partitions: int
    topic_replication_factor: int
    request_timeout_ms: int
    session_timeout_ms: int
    startup_timeout_seconds: int
    retry_delay_seconds: float


def load_article_category_sync_consumer_settings() -> ArticleCategorySyncConsumerSettings:
    auto_offset_reset = _string_env("ARTICLE_CATEGORY_SYNC_AUTO_OFFSET_RESET", "earliest").lower()
    if auto_offset_reset not in {"earliest", "latest"}:
        raise ValueError(
            "ARTICLE_CATEGORY_SYNC_AUTO_OFFSET_RESET must be either earliest or latest"
        )

    settings = ArticleCategorySyncConsumerSettings(
        enabled=_bool_env("ARTICLE_CATEGORY_SYNC_ENABLED", True),
        brokers=_csv_env("KAFKA_BROKERS", ["localhost:9092"]),
        topic=_string_env("ARTICLE_CATEGORY_SYNC_TOPIC", "article.category.matches.generated"),
        client_id=_string_env("ARTICLE_CATEGORY_SYNC_CLIENT_ID", "article-service-category-sync"),
        consumer_group=_string_env(
            "ARTICLE_CATEGORY_SYNC_CONSUMER_GROUP",
            "article-service-category-sync",
        ),
        auto_offset_reset=auto_offset_reset,
        topic_partitions=_int_env("ARTICLE_CATEGORY_SYNC_TOPIC_PARTITIONS", 1),
        topic_replication_factor=_int_env("ARTICLE_CATEGORY_SYNC_TOPIC_REPLICATION_FACTOR", 1),
        request_timeout_ms=_int_env("ARTICLE_CATEGORY_SYNC_REQUEST_TIMEOUT_MS", 30000),
        session_timeout_ms=_int_env("ARTICLE_CATEGORY_SYNC_SESSION_TIMEOUT_MS", 10000),
        startup_timeout_seconds=_int_env("ARTICLE_CATEGORY_SYNC_STARTUP_TIMEOUT_SECONDS", 120),
        retry_delay_seconds=_float_env("ARTICLE_CATEGORY_SYNC_RETRY_DELAY_SECONDS", 2.0),
    )
    if settings.request_timeout_ms <= settings.session_timeout_ms:
        raise ValueError(
            "ARTICLE_CATEGORY_SYNC_REQUEST_TIMEOUT_MS must be greater than "
            "ARTICLE_CATEGORY_SYNC_SESSION_TIMEOUT_MS"
        )
    return settings
