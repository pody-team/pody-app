from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True)
class ServiceOverviewResponse:
    name: str
    status: str
    article_topic: str
    category_topic: str
    consumer_group: str
    embedding_model: str
    configured_api_keys: int

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class HealthResponse:
    status: str
    database_ready: bool
    provider_ready: bool
    configured_api_keys: int
    article_topic: str
    category_topic: str
    consumer_group: str
    article_topic_ready: bool
    category_topic_ready: bool
    article_consumer_connected: bool
    category_consumer_connected: bool
    article_message_count: int
    category_message_count: int
    processed_articles: int
    skipped_articles: int
    failed_articles: int
    processed_categories: int
    skipped_categories: int
    failed_categories: int
    last_article_message_at: str | None
    last_category_message_at: str | None
    last_article_id: int | None
    last_category_id: str | None
    last_error: str | None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
