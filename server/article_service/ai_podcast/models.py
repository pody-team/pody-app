from __future__ import annotations

from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from models.base import Base


class ArticlePodcastJob(Base):
    __tablename__ = "article_podcast_jobs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    owner_user_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="queued", index=True)
    voice: Mapped[str | None] = mapped_column(String(64), nullable=True)
    target_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=6)
    language_code: Mapped[str] = mapped_column(String(16), nullable=False, default="vi")
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class ArticlePodcastJobArticle(Base):
    __tablename__ = "article_podcast_job_articles"

    job_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("article_podcast_jobs.id", ondelete="CASCADE"), primary_key=True
    )
    article_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("articles.id", ondelete="CASCADE"), primary_key=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    title_snapshot: Mapped[str] = mapped_column(Text, nullable=False)
    summary_snapshot: Mapped[str | None] = mapped_column(Text, nullable=True)


class ArticlePodcastDraft(Base):
    __tablename__ = "article_podcast_drafts"

    job_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("article_podcast_jobs.id", ondelete="CASCADE"), primary_key=True
    )
    podcast_title: Mapped[str | None] = mapped_column(String(255), nullable=True)
    podcast_description: Mapped[str | None] = mapped_column(Text, nullable=True)
    research_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    outline_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=list)
    script_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_pack_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    related_sources_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    validation_report_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)


class ArticlePodcastAsset(Base):
    __tablename__ = "article_podcast_assets"

    job_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("article_podcast_jobs.id", ondelete="CASCADE"), primary_key=True
    )
    audio_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    storage_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    mime_type: Mapped[str | None] = mapped_column(String(120), nullable=True)
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    transcript_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    transcript_storage_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
