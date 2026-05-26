from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping


@dataclass(frozen=True)
class CategoryEmbeddingDocument:
    """Entity anh xa bang category_embedding_documents."""

    id: int
    category_id: str
    slug: str
    name: str
    description: str | None
    is_active: bool
    semantic_text: str
    content_hash: str
    sync_status: str
    last_error: str | None
    last_embedding_model: str | None
    last_embedding_version: str | None
    last_embedding_dimensions: int | None
    last_synced_at: datetime | None
    created_at: datetime | None
    updated_at: datetime | None

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> "CategoryEmbeddingDocument":
        """Tao entity category embedding tu row PostgreSQL."""
        return cls(
            id=int(row["id"]),
            category_id=str(row.get("category_id") or ""),
            slug=str(row.get("slug") or ""),
            name=str(row.get("name") or ""),
            description=_optional_str(row.get("description")),
            is_active=bool(row.get("is_active")),
            semantic_text=str(row.get("semantic_text") or ""),
            content_hash=str(row.get("content_hash") or ""),
            sync_status=str(row.get("sync_status") or "pending"),
            last_error=_optional_str(row.get("last_error")),
            last_embedding_model=_optional_str(row.get("last_embedding_model")),
            last_embedding_version=_optional_str(row.get("last_embedding_version")),
            last_embedding_dimensions=_optional_int(row.get("last_embedding_dimensions")),
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
