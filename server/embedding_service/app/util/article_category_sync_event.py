from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from app.model.entity import ArticleCategoryMatch


EVENT_TYPE = "article.category.matches.generated.v1"
SOURCE_SERVICE = "embedding-service"


def build_article_category_sync_payload(
    *,
    article_id: int,
    article_status: str,
    content_hash: str,
    model_name: str,
    embedding_version: str,
    matches: list[ArticleCategoryMatch],
) -> dict[str, object]:
    """Tao payload Kafka gui ket qua category semantic ve article_service."""
    occurred_at = datetime.now(timezone.utc).isoformat()
    return {
        "event_id": str(uuid4()),
        "idempotency_key": build_idempotency_key(
            article_id=article_id,
            content_hash=content_hash,
            model_name=model_name,
            embedding_version=embedding_version,
        ),
        "event_type": EVENT_TYPE,
        "occurred_at": occurred_at,
        "source_service": SOURCE_SERVICE,
        "article_id": article_id,
        "article_status": article_status,
        "content_hash": content_hash,
        "model_name": model_name,
        "embedding_version": embedding_version,
        "matches": [
            {
                "category_id": match.category_id,
                "rank": match.rank,
                "score": match.score,
                "is_primary": match.rank == 1,
            }
            for match in matches
        ],
    }


def build_idempotency_key(
    *,
    article_id: int,
    content_hash: str,
    model_name: str,
    embedding_version: str,
) -> str:
    """Tao khoa idempotency dua tren article, content hash va version embedding."""
    return f"article-category-sync:{article_id}:{content_hash}:{model_name}:{embedding_version}"
