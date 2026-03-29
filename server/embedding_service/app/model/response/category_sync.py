from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CategorySyncResult:
    processed_count: int
    skipped_count: int
    matches_refreshed: bool
