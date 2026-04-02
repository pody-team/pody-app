from __future__ import annotations

import asyncio
import logging

from fastapi import HTTPException, status

from ai_podcast.config import AIPodcastSettings, load_ai_podcast_settings
from ai_podcast.models import (
    ArticlePodcastAsset,
    ArticlePodcastDraft,
    ArticlePodcastJob,
    ArticlePodcastJobArticle,
)
from ai_podcast.pipeline.audio_worker import synthesize_audio
from ai_podcast.pipeline.research import build_research_pack, build_search_tool
from ai_podcast.pipeline.script_writer import build_script
from ai_podcast.pipeline.synthesis import build_synthesis
from ai_podcast.pipeline.validator import validate_script
from ai_podcast.providers.text_generation import build_text_generation_provider
from ai_podcast.providers.tts_generation import build_tts_generation_provider
from ai_podcast.repository import (
    AIPodcastRepository,
    MissingSelectedArticlesError,
    NoRecommendedArticlesError,
)
from ai_podcast.schemas import (
    ArticlePodcastCreateRequest,
    ArticlePodcastCreateResponse,
    ArticlePodcastJobDetailResponse,
    ArticlePodcastJobListResponse,
    ArticlePodcastJobSummary,
)
from ai_podcast.storage.minio_store import MinIOPodcastStore
from ai_podcast.utils.slug import slugify
from config.database import DatabaseManager, get_db_session

logger = logging.getLogger(__name__)


class AIPodcastService:
    def __init__(self, repository: AIPodcastRepository, runtime: "AIPodcastRuntime") -> None:
        self._repository = repository
        self._runtime = runtime

    async def create_job(self, *, owner_user_id: str, request: ArticlePodcastCreateRequest) -> ArticlePodcastCreateResponse:
        try:
            job = await self._repository.create_job(owner_user_id=owner_user_id, request=request)
        except MissingSelectedArticlesError as exc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
        except NoRecommendedArticlesError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        return ArticlePodcastCreateResponse(job_id=job.id, status=job.status, created_at=job.created_at)

    async def list_jobs(self, *, owner_user_id: str) -> ArticlePodcastJobListResponse:
        records = await self._repository.list_jobs(owner_user_id=owner_user_id)
        return ArticlePodcastJobListResponse(
            jobs=[
                ArticlePodcastJobSummary(
                    job_id=record["job"].id,
                    status=record["job"].status,
                    title=record["draft"].podcast_title if record["draft"] else None,
                    audio_url=record["asset"].audio_url if record["asset"] else None,
                    created_at=record["job"].created_at,
                    updated_at=record["job"].updated_at,
                )
                for record in records
            ]
        )

    async def get_job_detail(self, *, owner_user_id: str, job_id: str) -> ArticlePodcastJobDetailResponse:
        detail = await self._repository.get_job_detail(owner_user_id=owner_user_id, job_id=job_id)
        if detail is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Podcast job not found")
        draft = detail["draft"]
        asset = detail["asset"]
        return ArticlePodcastJobDetailResponse(
            job_id=detail["job"].id,
            status=detail["job"].status,
            selected_articles=[
                {
                    "article_id": article.article_id,
                    "title": article.title_snapshot,
                    "summary": article.summary_snapshot,
                }
                for article in detail["articles"]
            ],
            research_summary=draft.research_summary if draft else None,
            podcast_title=draft.podcast_title if draft else None,
            podcast_description=draft.podcast_description if draft else None,
            outline=list((draft.outline_json or {}).get("items") or []) if draft else [],
            script_text=draft.script_text if draft else None,
            audio_url=asset.audio_url if asset else None,
            duration_seconds=asset.duration_seconds if asset else None,
            error=detail["job"].error_message,
            created_at=detail["job"].created_at,
            updated_at=detail["job"].updated_at,
        )


class AIPodcastRuntime:
    def __init__(self, settings: AIPodcastSettings | None = None) -> None:
        self.settings = settings or load_ai_podcast_settings()
        self.text_provider = build_text_generation_provider(self.settings)
        self.tts_provider = build_tts_generation_provider(self.settings)
        self.search_tool = build_search_tool(
            api_key=self.settings.brave_search_api_key,
            base_url=self.settings.brave_search_base_url,
        )
        self.storage = MinIOPodcastStore(self.settings)
        self._worker_task: asyncio.Task | None = None
        self._stopping = asyncio.Event()

    async def ensure_tables(self) -> None:
        engine = DatabaseManager().engine
        async with engine.begin() as conn:
            for table in (
                ArticlePodcastJob.__table__,
                ArticlePodcastJobArticle.__table__,
                ArticlePodcastDraft.__table__,
                ArticlePodcastAsset.__table__,
            ):
                await conn.run_sync(lambda sync_conn, table=table: table.create(sync_conn, checkfirst=True))

    async def start(self) -> None:
        await self.ensure_tables()
        self.storage.ensure_bucket()
        if self._worker_task is None or self._worker_task.done():
            self._stopping = asyncio.Event()
            self._worker_task = asyncio.create_task(self._worker_loop(), name="article-ai-podcast-worker")

    async def stop(self) -> None:
        self._stopping.set()
        if self._worker_task is not None:
            await self._worker_task
            self._worker_task = None

    async def _worker_loop(self) -> None:
        while not self._stopping.is_set():
            try:
                async with get_db_session() as session:
                    repository = AIPodcastRepository(session)
                    job_id = await repository.claim_next_job_id()
                    if not job_id:
                        await asyncio.sleep(self.settings.worker_poll_interval_seconds)
                        continue
                    await self._process_job(repository=repository, job_id=job_id)
            except asyncio.CancelledError:
                raise
            except Exception:
                logger.exception("ai podcast worker loop failed")
                await asyncio.sleep(self.settings.worker_poll_interval_seconds)

    async def _process_job(self, *, repository: AIPodcastRepository, job_id: str) -> None:
        bundle = await repository.get_processing_bundle(job_id=job_id)
        if bundle is None:
            return

        job = bundle["job"]
        try:
            await repository.update_job_status(job_id=job.id, status="researching")
            research_pack = build_research_pack(
                selected_articles=bundle["selected_articles"],
                search_tool=self.search_tool,
            )

            await repository.update_job_status(job_id=job.id, status="drafting")
            synthesis = build_synthesis(
                research_pack=research_pack,
                text_provider=self.text_provider,
            )
            script_draft = build_script(
                research_pack=research_pack,
                synthesis=synthesis,
                text_provider=self.text_provider,
                target_minutes=job.target_minutes,
                language_code=job.language_code,
            )

            await repository.update_job_status(job_id=job.id, status="validating")
            validation = validate_script(draft=script_draft, target_minutes=job.target_minutes)
            if not validation.valid:
                raise RuntimeError("; ".join(validation.errors) or "podcast draft validation failed")

            await repository.save_draft(
                job_id=job.id,
                podcast_title=script_draft.podcast_title,
                podcast_description=script_draft.podcast_description,
                research_summary=synthesis.research_summary,
                outline=script_draft.outline,
                script_text=script_draft.script_text,
                source_pack_json=research_pack.model_dump(mode="json"),
                related_sources_json={"items": research_pack.external_context_sources},
                validation_report_json=validation.model_dump(mode="json"),
            )

            await repository.update_job_status(job_id=job.id, status="synthesizing")
            audio_artifact = synthesize_audio(
                draft=script_draft,
                voice=job.voice,
                language_code=job.language_code,
                tts_provider=self.tts_provider,
            )

            await repository.update_job_status(job_id=job.id, status="uploading")
            base_key = f"{job.owner_user_id}/{job.id}/{slugify(script_draft.podcast_title)}"
            audio_url, audio_storage_key = self.storage.upload_audio(
                object_key=f"{base_key}/podcast.wav",
                body=audio_artifact.audio_bytes,
                content_type=audio_artifact.mime_type,
            )
            transcript_url, transcript_storage_key = self.storage.upload_transcript(
                object_key=f"{base_key}/transcript.json",
                transcript_json=audio_artifact.transcript_json,
            )
            await repository.save_asset(
                job_id=job.id,
                audio_url=audio_url,
                storage_key=audio_storage_key,
                mime_type=audio_artifact.mime_type,
                duration_seconds=audio_artifact.duration_seconds,
                transcript_url=transcript_url,
                transcript_storage_key=transcript_storage_key,
                metadata_json={"voice": job.voice, "bucket": self.storage.bucket_name},
            )
            await repository.update_job_status(job_id=job.id, status="completed")
        except Exception as exc:
            await repository.update_job_status(job_id=job.id, status="failed", error_message=str(exc))
            logger.exception("ai podcast job failed", extra={"job_id": job.id})
