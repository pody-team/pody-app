from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any


class InvalidArticleEventError(ValueError):
    """Loi payload Kafka article khong dung contract can thiet."""

    pass


@dataclass(frozen=True)
class ArticleEvent:
    """Event bai bao nhan tu Debezium sau khi unwrap record PostgreSQL."""

    article_id: int
    source_id: int
    title: str
    author: str | None
    summary: str | None
    content: str | None
    original_url: str
    thumbnail_url: str | None
    published_at: datetime | None
    status: str
    created_at: datetime | None
    updated_at: datetime | None
    operation: str | None
    table: str | None
    source_ts_ms: int | None
    raw_payload: dict[str, Any]


def parse_article_event(payload: Any) -> ArticleEvent:
    """Validate payload Kafka va chuyen thanh ArticleEvent co kieu ro rang."""
    if not isinstance(payload, dict):
        raise InvalidArticleEventError("Kafka payload must be a JSON object")

    return ArticleEvent(
        article_id=_required_int(payload, "id"),
        source_id=_required_int(payload, "source_id"),
        title=_required_string(payload, "title"),
        author=_optional_string(payload, "author"),
        summary=_optional_string(payload, "summary"),
        content=_optional_string(payload, "content"),
        original_url=_required_string(payload, "original_url"),
        thumbnail_url=_optional_string(payload, "thumbnail_url"),
        published_at=_optional_datetime(payload, "published_at"),
        status=_optional_string(payload, "status") or "PUBLISHED",
        created_at=_optional_datetime(payload, "created_at"),
        updated_at=_optional_datetime(payload, "updated_at"),
        operation=_optional_string(payload, "__op", "op"),
        table=_optional_string(payload, "__table", "table"),
        source_ts_ms=_optional_int(payload, "__source_ts_ms", "source.ts_ms"),
        raw_payload=payload,
    )


def _required_int(payload: dict[str, Any], key: str) -> int:
    """Doc truong int bat buoc tu payload."""
    value = payload.get(key)
    if value is None:
        raise InvalidArticleEventError(f"Missing required field: {key}")
    return _coerce_int(value, key)


def _optional_int(payload: dict[str, Any], *keys: str) -> int | None:
    """Doc truong int tuy chon, ho tro nhieu ten field Debezium."""
    for key in keys:
        if key in payload and payload[key] is not None:
            return _coerce_int(payload[key], key)
    return None


def _required_string(payload: dict[str, Any], key: str) -> str:
    """Doc truong string bat buoc tu payload."""
    value = _optional_string(payload, key)
    if value is None:
        raise InvalidArticleEventError(f"Missing required field: {key}")
    return value


def _optional_string(payload: dict[str, Any], *keys: str) -> str | None:
    """Doc string tuy chon va trim khoang trang."""
    for key in keys:
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _optional_datetime(payload: dict[str, Any], key: str) -> datetime | None:
    """Parse datetime ISO tu payload Debezium neu field ton tai."""
    value = payload.get(key)
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        return value
    if not isinstance(value, str):
        raise InvalidArticleEventError(f"Field {key} must be an ISO datetime string")
    normalized = value.strip().replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise InvalidArticleEventError(f"Field {key} must be an ISO datetime string") from exc


def _coerce_int(value: Any, key: str) -> int:
    """Ep kieu so nguyen va chan bool vi bool cung la int trong Python."""
    if isinstance(value, bool):
        raise InvalidArticleEventError(f"Field {key} must be an integer")
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise InvalidArticleEventError(f"Field {key} must be an integer") from exc
