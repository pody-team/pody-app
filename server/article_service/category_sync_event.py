from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, ValidationError


EVENT_TYPE = "article.category.matches.generated.v1"


class InvalidArticleCategoryMatchesEventError(ValueError):
    pass


class ArticleCategoryMatchPayload(BaseModel):
    category_id: UUID
    rank: int = Field(..., ge=1)
    score: float
    is_primary: bool = False


class ArticleCategoryMatchesGeneratedEvent(BaseModel):
    event_id: UUID
    idempotency_key: str = Field(..., min_length=1)
    event_type: Literal[EVENT_TYPE]
    occurred_at: datetime
    source_service: str = Field(..., min_length=1)
    article_id: int = Field(..., ge=1)
    article_status: str = Field(..., min_length=1)
    content_hash: str = Field(..., min_length=1)
    model_name: str = Field(..., min_length=1)
    embedding_version: str = Field(..., min_length=1)
    matches: list[ArticleCategoryMatchPayload] = Field(default_factory=list)


def parse_article_category_matches_event(payload: object) -> ArticleCategoryMatchesGeneratedEvent:
    if not isinstance(payload, dict):
        raise InvalidArticleCategoryMatchesEventError("Kafka payload must be a JSON object")
    try:
        return ArticleCategoryMatchesGeneratedEvent.model_validate(payload)
    except ValidationError as exc:
        raise InvalidArticleCategoryMatchesEventError(str(exc)) from exc
