from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping


@dataclass(frozen=True)
class ArticleEmbeddingDocument:
    """Entity anh xa bang article_embedding_documents."""

    id: int
    article_id: int
    source_id: int
    article_status: str
    title: str
    author: str | None
    summary: str | None
    content: str
    original_url: str
    thumbnail_url: str | None
    language_code: str
    published_at: datetime | None
    content_hash: str
    chunk_count: int
    sync_status: str
    last_error: str | None
    last_embedding_model: str | None
    last_embedding_version: str | None
    last_embedding_dimensions: int | None
    last_chunking_signature: str
    last_synced_at: datetime | None
    created_at: datetime | None
    updated_at: datetime | None

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> "ArticleEmbeddingDocument":
        """Tao entity tu row PostgreSQL."""
        return cls(
            id=int(row["id"]),
            article_id=int(row["article_id"]),
            source_id=int(row.get("source_id") or 0),
            article_status=str(row.get("article_status") or "PUBLISHED"),
            title=str(row.get("title") or ""),
            author=_optional_str(row.get("author")),
            summary=_optional_str(row.get("summary")),
            content=str(row.get("content") or ""),
            original_url=str(row.get("original_url") or ""),
            thumbnail_url=_optional_str(row.get("thumbnail_url")),
            language_code=str(row.get("language_code") or "vi"),
            published_at=row.get("published_at"),
            content_hash=str(row.get("content_hash") or ""),
            chunk_count=int(row.get("chunk_count") or 0),
            sync_status=str(row.get("sync_status") or "pending"),
            last_error=_optional_str(row.get("last_error")),
            last_embedding_model=_optional_str(row.get("last_embedding_model")),
            last_embedding_version=_optional_str(row.get("last_embedding_version")),
            last_embedding_dimensions=_optional_int(row.get("last_embedding_dimensions")),
            last_chunking_signature=str(row.get("last_chunking_signature") or ""),
            last_synced_at=row.get("last_synced_at"),
            created_at=row.get("created_at"),
            updated_at=row.get("updated_at"),
        )


def _optional_str(value: object) -> str | None:
    """Chuan hoa chuoi rong thanh None."""
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _optional_int(value: object) -> int | None:
    """Chuan hoa gia tri int tuy chon tu DB."""
    if value is None:
        return None
    return int(value)
