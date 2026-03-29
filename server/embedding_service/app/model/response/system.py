from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True)
class ServiceOverviewResponse:
    name: str
    status: str
    topic: str
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
    topic: str
    consumer_group: str
    topic_ready: bool
    consumer_connected: bool
    message_count: int
    processed_articles: int
    skipped_articles: int
    failed_articles: int
    last_message_at: str | None
    last_article_id: int | None
    last_error: str | None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
