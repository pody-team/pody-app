from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping


@dataclass(frozen=True)
class ArticleDocumentEmbedding:
    id: int
    document_id: int
    article_id: int
    model_name: str
    embedding_version: str
    dimensions: int
    embedding: list[float]
    created_at: datetime | None

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> "ArticleDocumentEmbedding":
        return cls(
            id=int(row["id"]),
            document_id=int(row["document_id"]),
            article_id=int(row["article_id"]),
            model_name=str(row.get("model_name") or ""),
            embedding_version=str(row.get("embedding_version") or ""),
            dimensions=int(row.get("dimensions") or 0),
            embedding=_coerce_embedding(row.get("embedding")),
            created_at=row.get("created_at"),
        )


def _coerce_embedding(value: object) -> list[float]:
    if isinstance(value, list):
        return [float(item) for item in value]
    if value is None:
        return []
    if isinstance(value, tuple):
        return [float(item) for item in value]
    return [float(item) for item in value]
