from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Any
from uuid import UUID


class InvalidCategoryEventError(ValueError):
    pass


@dataclass(frozen=True)
class CategoryEvent:
    event_id: str
    idempotency_key: str
    event_type: str
    occurred_at: datetime
    category_id: str
    slug: str
    name: str
    description: str | None
    is_active: bool
    created_at: datetime | None
    updated_at: datetime | None
    source_service: str | None
    raw_payload: dict[str, Any]


def parse_category_event(payload: Any) -> CategoryEvent:
    if not isinstance(payload, dict):
        raise InvalidCategoryEventError("Kafka payload must be a JSON object")

    category_id = _required_uuid_string(payload, "category_id")
    return CategoryEvent(
        event_id=_required_uuid_string(payload, "event_id"),
        idempotency_key=_required_string(payload, "idempotency_key"),
        event_type=_required_string(payload, "event_type"),
        occurred_at=_required_datetime(payload, "occurred_at"),
        category_id=category_id,
        slug=_required_string(payload, "slug"),
        name=_required_string(payload, "name"),
        description=_optional_string(payload, "description"),
        is_active=_required_bool(payload, "is_active"),
        created_at=_optional_datetime(payload, "created_at"),
        updated_at=_optional_datetime(payload, "updated_at"),
        source_service=_optional_string(payload, "source_service"),
        raw_payload=payload,
    )


def _required_uuid_string(payload: dict[str, Any], key: str) -> str:
    value = _required_string(payload, key)
    try:
        return str(UUID(value))
    except ValueError as exc:
        raise InvalidCategoryEventError(f"Field {key} must be a UUID string") from exc


def _required_string(payload: dict[str, Any], key: str) -> str:
    value = _optional_string(payload, key)
    if value is None:
        raise InvalidCategoryEventError(f"Missing required field: {key}")
    return value


def _optional_string(payload: dict[str, Any], *keys: str) -> str | None:
    for key in keys:
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return None


def _required_bool(payload: dict[str, Any], key: str) -> bool:
    value = payload.get(key)
    if isinstance(value, bool):
        return value
    raise InvalidCategoryEventError(f"Field {key} must be a boolean")


def _required_datetime(payload: dict[str, Any], key: str) -> datetime:
    value = _optional_datetime(payload, key)
    if value is None:
        raise InvalidCategoryEventError(f"Missing required field: {key}")
    return value


def _optional_datetime(payload: dict[str, Any], key: str) -> datetime | None:
    value = payload.get(key)
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        return value
    if not isinstance(value, str):
        raise InvalidCategoryEventError(f"Field {key} must be an ISO datetime string")
    normalized = value.strip().replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise InvalidCategoryEventError(f"Field {key} must be an ISO datetime string") from exc
