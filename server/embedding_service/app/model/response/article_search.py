from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True)
class ArticleSearchMatchResponse:
    """Mot ket qua chunk bai bao gan voi query semantic."""

    article_id: int
    title: str
    original_url: str
    chunk_index: int
    chunk_type: str
    chunk_preview: str
    score: float


@dataclass(frozen=True)
class ArticleSearchResponse:
    """Response semantic search gom query, limit va danh sach match."""

    query: str
    limit: int
    matches: list[ArticleSearchMatchResponse]

    def to_dict(self) -> dict[str, Any]:
        """Chuyen response thanh dict JSON."""
        return asdict(self)
