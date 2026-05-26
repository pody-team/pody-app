from __future__ import annotations

from dataclasses import dataclass
from typing import Any


class InvalidArticleSearchRequestError(ValueError):
    """Loi request search khong dung contract."""

    pass


@dataclass(frozen=True)
class ArticleSearchRequest:
    """Request semantic search bai bao."""

    query: str
    limit: int


def parse_article_search_request(payload: Any) -> ArticleSearchRequest:
    """Validate request JSON va gioi han limit trong khoang an toan."""
    if not isinstance(payload, dict):
        raise InvalidArticleSearchRequestError("Search payload must be a JSON object")

    query = payload.get("query")
    if not isinstance(query, str) or not query.strip():
        raise InvalidArticleSearchRequestError("Field query must be a non-empty string")

    raw_limit = payload.get("limit", 5)
    if isinstance(raw_limit, bool):
        raise InvalidArticleSearchRequestError("Field limit must be an integer")
    try:
        limit = int(raw_limit)
    except (TypeError, ValueError) as exc:
        raise InvalidArticleSearchRequestError("Field limit must be an integer") from exc

    return ArticleSearchRequest(query=query.strip(), limit=max(1, min(limit, 20)))
