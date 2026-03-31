import html
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


def clean_text(value):
    if not value:
        return value
    return html.unescape(value)


class AuthenticatedUser(BaseModel):
    user_id: str
    email: Optional[str] = None
    name: Optional[str] = None


class ReactionRequest(BaseModel):
    type: str = Field(..., description="LIKE, LOVE, or DISLIKE")
    user_id: Optional[str] = Field(default=None, description="Legacy fallback when auth header is unavailable")


class MetricRequest(BaseModel):
    user_id: Optional[str] = Field(default=None, description="Legacy fallback when auth header is unavailable")
    reading_time_seconds: int = Field(..., ge=0)


class CommentCreateRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=5000)
    user_id: Optional[str] = Field(default=None, description="Legacy fallback when auth header is unavailable")
    user_name: Optional[str] = Field(default=None, max_length=255)


class CommentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    article_id: int
    user_id: str
    user_name: Optional[str]
    content: str
    created_at: datetime
    updated_at: datetime


class FavoriteCategoriesUpdateRequest(BaseModel):
    category_ids: list[str] = Field(..., description="Active article category ids to save as favorites")
