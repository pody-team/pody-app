from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CategoryProcessingResult:
    status: str
    category_id: str
    job_id: int | None
    reason: str | None = None
