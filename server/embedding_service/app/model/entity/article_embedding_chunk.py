from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping


@dataclass(frozen=True)
class ArticleEmbeddingChunk:
    id: int
    document_id: int
    article_id: int
    chunk_index: int
    chunk_type: str
    content: str
    token_count_estimate: int
    char_count: int
    content_hash: str
    created_at: datetime | None

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> "ArticleEmbeddingChunk":
        return cls(
            id=int(row["id"]),
            document_id=int(row["document_id"]),
            article_id=int(row["article_id"]),
            chunk_index=int(row["chunk_index"]),
            chunk_type=str(row.get("chunk_type") or "body"),
            content=str(row.get("content") or ""),
            token_count_estimate=int(row.get("token_count_estimate") or 0),
            char_count=int(row.get("char_count") or 0),
            content_hash=str(row.get("content_hash") or ""),
            created_at=row.get("created_at"),
        )
