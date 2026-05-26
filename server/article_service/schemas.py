import html
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


def clean_text(value):
    """Giai ma HTML entity truoc khi tra text cho mobile/API client."""
    if not value:
        return value
    return html.unescape(value)


class AuthenticatedUser(BaseModel):
    """Danh tinh nguoi dung lay tu header xac thuc cua API Gateway."""

    user_id: str
    email: Optional[str] = None
    name: Optional[str] = None


class ReactionRequest(BaseModel):
    """Request body de them hoac toggle reaction cua bai bao."""

    type: str = Field(..., description="LIKE, LOVE, or DISLIKE")


class MetricRequest(BaseModel):
    """Request body de ghi nhan thoi gian doc bai bao."""

    reading_time_seconds: int = Field(..., ge=0)


class CommentCreateRequest(BaseModel):
    """Request body de tao comment moi cho bai bao."""

    content: str = Field(..., min_length=1, max_length=5000)
    user_name: Optional[str] = Field(default=None, max_length=255)


class CommentResponse(BaseModel):
    """Comment da serialize duoc tra ve boi API list va create comment."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    article_id: int
    user_id: str
    user_name: Optional[str]
    content: str
    created_at: datetime
    updated_at: datetime


class FavoriteCategoriesUpdateRequest(BaseModel):
    """Request body de thay the category bai bao yeu thich cua nguoi dung."""

    category_ids: list[str] = Field(..., description="Active article category ids to save as favorites")
