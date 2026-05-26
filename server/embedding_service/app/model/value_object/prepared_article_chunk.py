from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class PreparedArticleChunk:
    """Value object bieu dien mot chunk bai bao da san sang de embed."""

    chunk_index: int
    chunk_type: str
    content: str
    token_count_estimate: int
    char_count: int
    content_hash: str
