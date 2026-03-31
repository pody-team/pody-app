from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping


@dataclass(frozen=True)
class CategoryCatalogItem:
    category_id: str
    slug: str
    name: str
    description: str | None
    is_active: bool
    created_at: datetime | None
    updated_at: datetime | None

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> "CategoryCatalogItem":
        return cls(
            category_id=str(row.get("category_id") or row.get("id") or ""),
            slug=str(row.get("slug") or ""),
            name=str(row.get("name") or ""),
            description=_optional_str(row.get("description")),
            is_active=bool(row.get("is_active")),
            created_at=row.get("created_at"),
            updated_at=row.get("updated_at"),
        )


def _optional_str(value: object) -> str | None:
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None
