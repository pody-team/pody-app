from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True)
class ServiceOverviewResponse:
    """Response tong quan cau hinh va trang thai service."""

    name: str
    status: str
    article_topic: str
    consumer_group: str
    embedding_model: str
    configured_api_keys: int
    category_bootstrap_enabled: bool

    def to_dict(self) -> dict[str, Any]:
        """Chuyen dataclass thanh dict JSON."""
        return asdict(self)


@dataclass(frozen=True)
class HealthResponse:
    """Response health chi tiet cua database, provider, Kafka va bootstrap."""

    status: str
    database_ready: bool
    provider_ready: bool
    configured_api_keys: int
    article_topic: str
    consumer_group: str
    article_topic_ready: bool
    article_consumer_connected: bool
    article_message_count: int
    category_bootstrap_enabled: bool
    category_source_ready: bool
    category_bootstrap_completed: bool
    ready_category_embeddings: int
    processed_articles: int
    skipped_articles: int
    failed_articles: int
    processed_categories: int
    skipped_categories: int
    failed_categories: int
    last_article_message_at: str | None
    last_article_id: int | None
    last_error: str | None

    def to_dict(self) -> dict[str, Any]:
        """Chuyen dataclass thanh dict JSON."""
        return asdict(self)
