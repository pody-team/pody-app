from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class ArticlePodcastCreateRequest(BaseModel):
    article_ids: list[int] = Field(default_factory=list)
    voice: str | None = None
    target_minutes: int | None = Field(default=6, ge=1, le=30)
    language_code: str | None = Field(default="vi", min_length=2, max_length=16)


class ArticlePodcastJobSummary(BaseModel):
    job_id: str
    status: str
    title: str | None = None
    audio_url: str | None = None
    created_at: datetime
    updated_at: datetime


class ArticlePodcastCreateResponse(BaseModel):
    job_id: str
    status: str
    created_at: datetime


class ArticlePodcastJobListResponse(BaseModel):
    jobs: list[ArticlePodcastJobSummary] = Field(default_factory=list)


class ArticlePodcastJobDetailResponse(BaseModel):
    job_id: str
    status: str
    selected_articles: list[dict[str, Any]] = Field(default_factory=list)
    research_summary: str | None = None
    podcast_title: str | None = None
    podcast_description: str | None = None
    outline: list[str] = Field(default_factory=list)
    script_text: str | None = None
    audio_url: str | None = None
    duration_seconds: int | None = None
    error: str | None = None
    created_at: datetime
    updated_at: datetime


class ResearchPack(BaseModel):
    primary_sources: list[dict[str, Any]] = Field(default_factory=list)
    external_context_sources: list[dict[str, Any]] = Field(default_factory=list)
    research_summary: str = ""


class SynthesisDraft(BaseModel):
    topic: str
    key_insights: list[str] = Field(default_factory=list)
    overlap_points: list[str] = Field(default_factory=list)
    external_context: list[str] = Field(default_factory=list)
    research_summary: str


class ScriptDraft(BaseModel):
    podcast_title: str
    podcast_description: str
    outline: list[str] = Field(default_factory=list)
    script_text: str


class ValidationReport(BaseModel):
    valid: bool
    errors: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)
    estimated_duration_seconds: int = 0
    word_count: int = 0
