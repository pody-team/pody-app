from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any, Mapping


@dataclass(frozen=True)
class EmbeddingJob:
    id: int
    target_type: str
    target_id: int
    job_type: str
    source_topic: str | None
    source_partition: int | None
    source_offset: int | None
    source_key: str | None
    content_hash: str
    model_name: str
    embedding_version: str
    status: str
    attempts: int
    error_message: str | None
    payload: dict[str, Any]
    scheduled_at: datetime | None
    started_at: datetime | None
    finished_at: datetime | None
    created_at: datetime | None
    updated_at: datetime | None

    @classmethod
    def from_row(cls, row: Mapping[str, Any]) -> "EmbeddingJob":
        return cls(
            id=int(row["id"]),
            target_type=str(row.get("target_type") or ""),
            target_id=int(row["target_id"]),
            job_type=str(row.get("job_type") or ""),
            source_topic=_optional_str(row.get("source_topic")),
            source_partition=_optional_int(row.get("source_partition")),
            source_offset=_optional_int(row.get("source_offset")),
            source_key=_optional_str(row.get("source_key")),
            content_hash=str(row.get("content_hash") or ""),
            model_name=str(row.get("model_name") or ""),
            embedding_version=str(row.get("embedding_version") or ""),
            status=str(row.get("status") or "pending"),
            attempts=int(row.get("attempts") or 0),
            error_message=_optional_str(row.get("error_message")),
            payload=dict(row.get("payload") or {}),
            scheduled_at=row.get("scheduled_at"),
            started_at=row.get("started_at"),
            finished_at=row.get("finished_at"),
            created_at=row.get("created_at"),
            updated_at=row.get("updated_at"),
        )


def _optional_str(value: object) -> str | None:
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _optional_int(value: object) -> int | None:
    if value is None:
        return None
    return int(value)
