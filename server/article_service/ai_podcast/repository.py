from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession

from ai_podcast.models import (
    ArticlePodcastAsset,
    ArticlePodcastDraft,
    ArticlePodcastJob,
    ArticlePodcastJobArticle,
)
from ai_podcast.schemas import ArticlePodcastCreateRequest
from models import Article


class AIPodcastRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create_job(self, *, owner_user_id: str, request: ArticlePodcastCreateRequest) -> ArticlePodcastJob:
        articles = await self._load_articles(request.article_ids)
        if len(articles) != len(request.article_ids):
            raise ValueError("One or more selected articles do not exist")

        job = ArticlePodcastJob(
            id=str(uuid4()),
            owner_user_id=owner_user_id,
            status="queued",
            voice=(request.voice or "").strip() or None,
            target_minutes=int(request.target_minutes or 6),
            language_code=(request.language_code or "vi").strip() or "vi",
        )
        self.session.add(job)
        for index, article in enumerate(articles):
            self.session.add(
                ArticlePodcastJobArticle(
                    job_id=job.id,
                    article_id=int(article.id),
                    sort_order=index,
                    title_snapshot=str(article.title or "").strip(),
                    summary_snapshot=(str(article.summary or "").strip() or None),
                )
            )
        await self.session.flush()
        return job

    async def list_jobs(self, *, owner_user_id: str) -> list[dict]:
        stmt = (
            select(ArticlePodcastJob, ArticlePodcastDraft, ArticlePodcastAsset)
            .outerjoin(ArticlePodcastDraft, ArticlePodcastDraft.job_id == ArticlePodcastJob.id)
            .outerjoin(ArticlePodcastAsset, ArticlePodcastAsset.job_id == ArticlePodcastJob.id)
            .where(ArticlePodcastJob.owner_user_id == owner_user_id)
            .order_by(ArticlePodcastJob.created_at.desc())
        )
        rows = (await self.session.execute(stmt)).all()
        return [{"job": row[0], "draft": row[1], "asset": row[2]} for row in rows]

    async def get_job_detail(self, *, owner_user_id: str, job_id: str) -> dict | None:
        job = await self.session.get(ArticlePodcastJob, job_id)
        if job is None or job.owner_user_id != owner_user_id:
            return None

        articles_stmt = (
            select(ArticlePodcastJobArticle)
            .where(ArticlePodcastJobArticle.job_id == job_id)
            .order_by(ArticlePodcastJobArticle.sort_order.asc())
        )
        articles = list((await self.session.execute(articles_stmt)).scalars().all())
        draft = await self.session.get(ArticlePodcastDraft, job_id)
        asset = await self.session.get(ArticlePodcastAsset, job_id)
        return {"job": job, "articles": articles, "draft": draft, "asset": asset}

    async def claim_next_job_id(self) -> str | None:
        stmt = (
            select(ArticlePodcastJob.id)
            .where(ArticlePodcastJob.status.in_(["queued", "researching", "drafting", "validating", "synthesizing", "uploading"]))
            .order_by(ArticlePodcastJob.created_at.asc())
            .limit(1)
        )
        row = (await self.session.execute(stmt)).first()
        return row[0] if row else None

    async def get_processing_bundle(self, *, job_id: str) -> dict | None:
        job = await self.session.get(ArticlePodcastJob, job_id)
        if job is None:
            return None
        selected_stmt = (
            select(ArticlePodcastJobArticle, Article)
            .join(Article, Article.id == ArticlePodcastJobArticle.article_id)
            .where(ArticlePodcastJobArticle.job_id == job_id)
            .order_by(ArticlePodcastJobArticle.sort_order.asc())
        )
        selected_rows = (await self.session.execute(selected_stmt)).all()
        return {
            "job": job,
            "selected_articles": [
                {
                    "article_id": int(article.id),
                    "title": str(article.title or "").strip(),
                    "summary": str(article.summary or "").strip(),
                    "content": str(article.content or "").strip(),
                    "original_url": str(article.original_url or "").strip(),
                    "published_at": article.published_at.isoformat() if article.published_at else None,
                }
                for _, article in selected_rows
            ],
        }

    async def update_job_status(self, *, job_id: str, status: str, error_message: str | None = None) -> ArticlePodcastJob:
        job = await self.session.get(ArticlePodcastJob, job_id)
        if job is None:
            raise ValueError("podcast job not found")
        job.status = status
        job.error_message = error_message
        if status == "researching" and job.started_at is None:
            job.started_at = datetime.utcnow()
        if status in {"completed", "failed"}:
            job.finished_at = datetime.utcnow()
        await self.session.flush()
        return job

    async def save_draft(
        self,
        *,
        job_id: str,
        podcast_title: str,
        podcast_description: str,
        research_summary: str,
        outline: list[str],
        script_text: str,
        source_pack_json: dict,
        related_sources_json: dict,
        validation_report_json: dict,
    ) -> None:
        draft = await self.session.get(ArticlePodcastDraft, job_id)
        if draft is None:
            draft = ArticlePodcastDraft(job_id=job_id)
            self.session.add(draft)
        draft.podcast_title = podcast_title
        draft.podcast_description = podcast_description
        draft.research_summary = research_summary
        draft.outline_json = {"items": outline}
        draft.script_text = script_text
        draft.source_pack_json = source_pack_json
        draft.related_sources_json = related_sources_json
        draft.validation_report_json = validation_report_json
        await self.session.flush()

    async def save_asset(
        self,
        *,
        job_id: str,
        audio_url: str,
        storage_key: str,
        mime_type: str,
        duration_seconds: int,
        transcript_url: str | None,
        transcript_storage_key: str | None,
        metadata_json: dict,
    ) -> None:
        asset = await self.session.get(ArticlePodcastAsset, job_id)
        if asset is None:
            asset = ArticlePodcastAsset(job_id=job_id)
            self.session.add(asset)
        asset.audio_url = audio_url
        asset.storage_key = storage_key
        asset.mime_type = mime_type
        asset.duration_seconds = duration_seconds
        asset.transcript_url = transcript_url
        asset.transcript_storage_key = transcript_storage_key
        asset.metadata_json = metadata_json
        await self.session.flush()

    async def _load_articles(self, article_ids: list[int]) -> list[Article]:
        if not article_ids:
            return []
        stmt: Select = select(Article).where(Article.id.in_(article_ids))
        articles = list((await self.session.execute(stmt)).scalars().all())
        by_id = {int(article.id): article for article in articles}
        return [by_id[article_id] for article_id in article_ids if article_id in by_id]
