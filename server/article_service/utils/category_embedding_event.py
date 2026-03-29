"""
Helpers for category embedding event payloads.
"""
from __future__ import annotations

from datetime import datetime, timezone
from hashlib import sha256
from uuid import uuid4

from models import Category


CATEGORY_EMBEDDING_EVENT_TYPE = "category.embedding.requested.v1"
CATEGORY_EMBEDDING_PAYLOAD_VERSION = 1


def build_category_embedding_event_payload(category: Category) -> dict[str, object]:
    description = (category.description or "").strip() or None
    fingerprint = _content_fingerprint(
        category_id=str(category.id),
        slug=category.slug,
        name=category.name,
        description=description,
        is_active=bool(category.is_active),
    )
    return {
        "event_id": str(uuid4()),
        "idempotency_key": f"category:{category.id}:{fingerprint}",
        "event_type": CATEGORY_EMBEDDING_EVENT_TYPE,
        "occurred_at": _isoformat(category.updated_at or category.created_at or datetime.now(timezone.utc)),
        "source_service": "article-service",
        "category_id": str(category.id),
        "slug": category.slug,
        "name": category.name,
        "description": description,
        "is_active": bool(category.is_active),
        "created_at": _isoformat(category.created_at) if category.created_at else None,
        "updated_at": _isoformat(category.updated_at) if category.updated_at else None,
    }


def build_category_embedding_idempotency_key(
    *,
    category_id: str,
    slug: str,
    name: str,
    description: str | None,
    is_active: bool,
) -> str:
    return f"category:{category_id}:{_content_fingerprint(category_id, slug, name, description, is_active)}"


def _content_fingerprint(
    category_id: str,
    slug: str,
    name: str,
    description: str | None,
    is_active: bool,
) -> str:
    raw = "|".join(
        [
            category_id.strip(),
            slug.strip(),
            name.strip(),
            (description or "").strip(),
            "1" if is_active else "0",
        ]
    )
    return sha256(raw.encode("utf-8")).hexdigest()


def _isoformat(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()
