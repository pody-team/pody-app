from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True)
class ArticleSearchMatchResponse:
    article_id: int
    title: str
    original_url: str
    chunk_index: int
    chunk_type: str
    chunk_preview: str
    score: float


@dataclass(frozen=True)
class ArticleSearchResponse:
    query: str
    limit: int
    matches: list[ArticleSearchMatchResponse]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
