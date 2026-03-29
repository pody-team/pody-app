from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ArticleProcessingResult:
    status: str
    article_id: int
    chunk_count: int
    job_id: int | None
    reason: str | None = None
