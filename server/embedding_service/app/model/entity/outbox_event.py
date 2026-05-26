from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping


@dataclass(frozen=True)
class OutboxEvent:
    """Entity anh xa bang outbox_events dung de publish Kafka an toan."""

    id: str
    aggregate_type: str
    aggregate_id: str
    event_type: str
    payload_version: int
    payload: dict[str, Any]
    attempts: int
    last_error: str | None
    status: str
    available_at: datetime | None
    published_at: datetime | None
    created_at: datetime | None
    updated_at: datetime | None

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> "OutboxEvent":
        """Tao outbox event entity tu row PostgreSQL."""
        return cls(
            id=str(row.get("id") or ""),
            aggregate_type=str(row.get("aggregate_type") or ""),
            aggregate_id=str(row.get("aggregate_id") or ""),
            event_type=str(row.get("event_type") or ""),
            payload_version=int(row.get("payload_version") or 1),
            payload=dict(row.get("payload") or {}),
            attempts=int(row.get("attempts") or 0),
            last_error=_optional_str(row.get("last_error")),
            status=str(row.get("status") or "pending"),
            available_at=row.get("available_at"),
            published_at=row.get("published_at"),
            created_at=row.get("created_at"),
            updated_at=row.get("updated_at"),
        )


def _optional_str(value: object) -> str | None:
    """Chuan hoa chuoi rong thanh None."""
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None
