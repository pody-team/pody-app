from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping


@dataclass(frozen=True)
class ArticleCategoryMatch:
    id: int
    article_id: int
    category_id: str
    score: float
    rank: int
    source: str
    model_name: str
    embedding_version: str
    created_at: datetime | None
    updated_at: datetime | None

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> "ArticleCategoryMatch":
        return cls(
            id=int(row["id"]),
            article_id=int(row["article_id"]),
            category_id=str(row.get("category_id") or ""),
            score=float(row.get("score") or 0.0),
            rank=int(row.get("rank") or 0),
            source=str(row.get("source") or ""),
            model_name=str(row.get("model_name") or ""),
            embedding_version=str(row.get("embedding_version") or ""),
            created_at=row.get("created_at"),
            updated_at=row.get("updated_at"),
        )
