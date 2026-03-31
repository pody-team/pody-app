from __future__ import annotations

from contextlib import contextmanager
from dataclasses import dataclass
from typing import Any
from uuid import UUID

from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from psycopg_pool import ConnectionPool

from .models import (
    AuthContext,
    ChatTurnResult,
    ChatMessage,
    ProductionPlanSummary,
    ChatThreadSummary,
    ChatThreadView,
    GeneratePlanRequest,
    GenerationJob,
    PlannerOutput,
    ProductionPlan,
    ShowDraft,
    VoiceProfile,
)


class RepositoryError(Exception):
    pass


class NotFoundError(RepositoryError):
    pass


@dataclass(frozen=True)
class ShowCreationJobContext:
    job: GenerationJob
    plan: ProductionPlan
    owner_user_id: UUID
    owner_email: str | None
    owner_name: str | None


@dataclass(frozen=True)
class TranscriptJobContext:
    job: GenerationJob
    plan_id: UUID
    content_episode_id: str
    episode_number: int
    language_code: str


class AIRepository:
    def __init__(self, pool: ConnectionPool) -> None:
        self._pool = pool

    @contextmanager
    def _connection(self):
        with self._pool.connection() as conn:
            conn.row_factory = dict_row
            yield conn

    def list_voice_profiles(self) -> list[VoiceProfile]:
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT id, name, provider, provider_voice_id, language_code, gender,
                       sample_audio_url, cost_credits_per_minute, is_active, metadata,
                       created_at, updated_at
                FROM voice_profiles
                WHERE is_active = true
                ORDER BY name ASC
                """
            ).fetchall()
        return [VoiceProfile.model_validate(row) for row in rows]

    def create_thread(self, auth: AuthContext, prompt: str, turn: ChatTurnResult) -> ChatThreadView:
        with self._connection() as conn, conn.transaction():
            thread_row = conn.execute(
                """
                INSERT INTO chat_threads (owner_user_id, title, status)
                VALUES (%s, %s, 'active')
                RETURNING id, title, status, created_at, updated_at
                """,
                (auth.user_id, turn.thread_title),
            ).fetchone()

            plan_id = None
            if turn.plan_output is not None:
                plan_id = self._insert_plan(
                    conn=conn,
                    owner_user_id=auth.user_id,
                    thread_id=thread_row["id"],
                    prompt=prompt,
                    output=turn.plan_output,
                )

            conn.execute(
                """
                INSERT INTO chat_messages (thread_id, role, text_content, plan_id)
                VALUES
                  (%s, 'user', %s, %s),
                  (%s, 'assistant', %s, %s)
                """,
                (
                    thread_row["id"],
                    prompt,
                    plan_id,
                    thread_row["id"],
                    turn.assistant_reply,
                    plan_id,
                ),
            )

            return self._get_thread(conn, auth.user_id, thread_row["id"])

    def get_thread(self, owner_user_id: UUID, thread_id: UUID) -> ChatThreadView:
        with self._connection() as conn:
            return self._get_thread(conn, owner_user_id, thread_id)

    def list_threads(self, owner_user_id: UUID, limit: int = 30) -> list[ChatThreadSummary]:
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT ct.id,
                       ct.title,
                       ct.status,
                       ct.created_at,
                       ct.updated_at,
                       last_message.text_content AS last_message_preview,
                       EXISTS (
                         SELECT 1
                         FROM production_plans pp
                         WHERE pp.thread_id = ct.id
                       ) AS has_current_plan
                FROM chat_threads ct
                LEFT JOIN LATERAL (
                  SELECT cm.text_content
                  FROM chat_messages cm
                  WHERE cm.thread_id = ct.id
                  ORDER BY cm.created_at DESC, cm.id DESC
                  LIMIT 1
                ) last_message ON true
                WHERE ct.owner_user_id = %s
                ORDER BY ct.updated_at DESC, ct.created_at DESC
                LIMIT %s
                """,
                (owner_user_id, limit),
            ).fetchall()

        return [ChatThreadSummary.model_validate(row) for row in rows]

    def list_drafts(self, owner_user_id: UUID, limit: int = 50) -> list[ProductionPlanSummary]:
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT pp.id,
                       pp.thread_id,
                       pp.status,
                       pp.series_title,
                       COALESCE(pp.metadata->>'content_type', 'podcast') AS content_type,
                       COUNT(pped.id)::int AS episode_count,
                       pp.created_at,
                       pp.updated_at
                FROM production_plans pp
                LEFT JOIN production_plan_episode_drafts pped ON pped.plan_id = pp.id
                WHERE pp.owner_user_id = %s
                GROUP BY pp.id
                ORDER BY pp.updated_at DESC, pp.created_at DESC
                LIMIT %s
                """,
                (owner_user_id, limit),
            ).fetchall()

        return [ProductionPlanSummary.model_validate(row) for row in rows]

    def get_draft(self, owner_user_id: UUID, plan_id: UUID) -> ProductionPlan:
        with self._connection() as conn:
            row = conn.execute(
                """
                SELECT id
                FROM production_plans
                WHERE id = %s AND owner_user_id = %s
                """,
                (plan_id, owner_user_id),
            ).fetchone()
            if row is None:
                raise NotFoundError("draft not found")
            return self._get_plan(conn, row["id"])

    def add_thread_message(
        self,
        auth: AuthContext,
        thread_id: UUID,
        message: str,
        turn: ChatTurnResult,
    ) -> ChatThreadView:
        with self._connection() as conn, conn.transaction():
            existing = conn.execute(
                """
                SELECT id
                FROM chat_threads
                WHERE id = %s AND owner_user_id = %s
                """,
                (thread_id, auth.user_id),
            ).fetchone()
            if existing is None:
                raise NotFoundError("thread not found")

            conn.execute(
                """
                UPDATE chat_threads
                SET title = %s, updated_at = now()
                WHERE id = %s
                """,
                (turn.thread_title, thread_id),
            )

            plan_id = None
            if turn.plan_output is not None:
                plan_id = self._insert_plan(
                    conn=conn,
                    owner_user_id=auth.user_id,
                    thread_id=thread_id,
                    prompt=message,
                    output=turn.plan_output,
                )

            conn.execute(
                """
                INSERT INTO chat_messages (thread_id, role, text_content, plan_id)
                VALUES
                  (%s, 'user', %s, %s),
                  (%s, 'assistant', %s, %s)
                """,
                (
                    thread_id,
                    message,
                    plan_id,
                    thread_id,
                    turn.assistant_reply,
                    plan_id,
                ),
            )

            return self._get_thread(conn, auth.user_id, thread_id)

    def generate_episode_plan(
        self,
        auth: AuthContext,
        request: GeneratePlanRequest,
        output: PlannerOutput,
        provider: str,
    ) -> tuple[ProductionPlan, GenerationJob]:
        with self._connection() as conn, conn.transaction():
            plan_id = self._insert_plan(
                conn=conn,
                owner_user_id=auth.user_id,
                thread_id=None,
                prompt=request.prompt,
                output=output,
            )

            plan = self._get_plan(conn, plan_id)

            job_row = conn.execute(
                """
                INSERT INTO generation_jobs (
                  plan_id,
                  job_type,
                  status,
                  provider,
                  input_payload,
                  output_payload,
                  started_at,
                  finished_at
                )
                VALUES (%s, 'plan_generation', 'completed', %s, %s, %s, now(), now())
                RETURNING id, plan_id, episode_draft_id, job_type, status, provider,
                          input_payload, output_payload, error_message,
                          started_at, finished_at, created_at
                """,
                (
                    plan_id,
                    provider,
                    Jsonb({"prompt": request.prompt, "episode_count": request.episode_count}),
                    Jsonb(
                        {
                            "series_title": output.series_title,
                            "episode_count": len(output.episodes),
                            "primary_category": output.primary_category,
                        }
                    ),
                ),
            ).fetchone()

            return plan, GenerationJob.model_validate(job_row)

    def queue_show_creation(
        self,
        auth: AuthContext,
        plan_id: UUID,
        provider: str,
    ) -> GenerationJob:
        with self._connection() as conn, conn.transaction():
            plan_row = conn.execute(
                """
                SELECT id
                FROM production_plans
                WHERE id = %s AND owner_user_id = %s
                """,
                (plan_id, auth.user_id),
            ).fetchone()
            if plan_row is None:
                raise NotFoundError("draft not found")

            existing_job = conn.execute(
                """
                SELECT id, plan_id, episode_draft_id, job_type, status, provider,
                       input_payload, output_payload, error_message,
                       started_at, finished_at, created_at
                FROM generation_jobs
                WHERE plan_id = %s
                  AND job_type = 'show_creation'
                  AND status IN ('queued', 'running')
                ORDER BY created_at DESC
                LIMIT 1
                """,
                (plan_id,),
            ).fetchone()
            if existing_job is not None:
                return GenerationJob.model_validate(existing_job)

            conn.execute(
                """
                UPDATE production_plans
                SET status = 'producing', updated_at = now()
                WHERE id = %s
                """,
                (plan_id,),
            )

            job_row = conn.execute(
                """
                INSERT INTO generation_jobs (
                  plan_id,
                  job_type,
                  status,
                  provider,
                  input_payload,
                  output_payload
                )
                VALUES (%s, 'show_creation', 'queued', %s, %s, '{}'::jsonb)
                RETURNING id, plan_id, episode_draft_id, job_type, status, provider,
                          input_payload, output_payload, error_message,
                          started_at, finished_at, created_at
                """,
                (
                    plan_id,
                    provider,
                    Jsonb(
                        {
                            "owner_email": auth.email,
                            "owner_name": auth.name,
                        }
                    ),
                ),
            ).fetchone()
            return GenerationJob.model_validate(job_row)

    def list_pending_show_creation_job_ids(self, limit: int = 100) -> list[UUID]:
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT id
                FROM generation_jobs
                WHERE job_type = 'show_creation'
                  AND status = 'queued'
                ORDER BY created_at ASC
                LIMIT %s
                """,
                (limit,),
            ).fetchall()
        return [row["id"] for row in rows]

    def queue_transcript_generation(
        self,
        *,
        plan_id: UUID,
        episode_number: int,
        content_episode_id: str,
        language_code: str,
        provider: str,
    ) -> GenerationJob:
        with self._connection() as conn, conn.transaction():
            existing_job = conn.execute(
                """
                SELECT id, plan_id, episode_draft_id, job_type, status, provider,
                       input_payload, output_payload, error_message,
                       started_at, finished_at, created_at
                FROM generation_jobs
                WHERE plan_id = %s
                  AND job_type = 'transcript_generation'
                  AND status IN ('queued', 'running')
                  AND input_payload->>'content_episode_id' = %s
                ORDER BY created_at DESC
                LIMIT 1
                """,
                (plan_id, content_episode_id),
            ).fetchone()
            if existing_job is not None:
                return GenerationJob.model_validate(existing_job)

            episode_draft_row = conn.execute(
                """
                SELECT id
                FROM production_plan_episode_drafts
                WHERE plan_id = %s
                  AND episode_number = %s
                LIMIT 1
                """,
                (plan_id, episode_number),
            ).fetchone()
            episode_draft_id = episode_draft_row["id"] if episode_draft_row is not None else None

            job_row = conn.execute(
                """
                INSERT INTO generation_jobs (
                  plan_id,
                  episode_draft_id,
                  job_type,
                  status,
                  provider,
                  input_payload,
                  output_payload
                )
                VALUES (
                  %s,
                  %s,
                  'transcript_generation',
                  'queued',
                  %s,
                  %s,
                  '{}'::jsonb
                )
                RETURNING id, plan_id, episode_draft_id, job_type, status, provider,
                          input_payload, output_payload, error_message,
                          started_at, finished_at, created_at
                """,
                (
                    plan_id,
                    episode_draft_id,
                    provider,
                    Jsonb(
                        {
                            "content_episode_id": content_episode_id,
                            "episode_number": episode_number,
                            "language_code": language_code,
                        }
                    ),
                ),
            ).fetchone()
            return GenerationJob.model_validate(job_row)

    def list_pending_transcript_job_ids(self, limit: int = 100) -> list[UUID]:
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT id
                FROM generation_jobs
                WHERE job_type = 'transcript_generation'
                  AND status = 'queued'
                ORDER BY created_at ASC
                LIMIT %s
                """,
                (limit,),
            ).fetchall()
        return [row["id"] for row in rows]

    def start_show_creation_job(self, job_id: UUID) -> ShowCreationJobContext | None:
        with self._connection() as conn, conn.transaction():
            job_row = conn.execute(
                """
                UPDATE generation_jobs
                SET status = 'running', started_at = now(), error_message = NULL
                WHERE id = %s
                  AND job_type = 'show_creation'
                  AND status = 'queued'
                RETURNING id, plan_id, episode_draft_id, job_type, status, provider,
                          input_payload, output_payload, error_message,
                          started_at, finished_at, created_at
                """,
                (job_id,),
            ).fetchone()
            if job_row is None:
                return None

            input_payload = job_row["input_payload"] or {}
            plan = self._get_plan(conn, job_row["plan_id"])

            conn.execute(
                """
                UPDATE production_plans
                SET status = 'producing', updated_at = now()
                WHERE id = %s
                """,
                (plan.id,),
            )

            return ShowCreationJobContext(
                job=GenerationJob.model_validate(job_row),
                plan=plan,
                owner_user_id=plan_row_owner_user_id(conn, plan.id),
                owner_email=_nullable_string(input_payload.get("owner_email")),
                owner_name=_nullable_string(input_payload.get("owner_name")),
            )

    def start_transcript_job(self, job_id: UUID) -> TranscriptJobContext | None:
        with self._connection() as conn, conn.transaction():
            job_row = conn.execute(
                """
                UPDATE generation_jobs
                SET status = 'running', started_at = now(), error_message = NULL
                WHERE id = %s
                  AND job_type = 'transcript_generation'
                  AND status = 'queued'
                RETURNING id, plan_id, episode_draft_id, job_type, status, provider,
                          input_payload, output_payload, error_message,
                          started_at, finished_at, created_at
                """,
                (job_id,),
            ).fetchone()
            if job_row is None:
                return None
            input_payload = job_row["input_payload"] or {}
            content_episode_id = _string_or_default(input_payload.get("content_episode_id"), "")
            if not content_episode_id:
                raise RepositoryError("transcript job is missing content_episode_id")
            episode_number = int(input_payload.get("episode_number") or 0)
            language_code = _string_or_default(input_payload.get("language_code"), "vi")
            return TranscriptJobContext(
                job=GenerationJob.model_validate(job_row),
                plan_id=job_row["plan_id"],
                content_episode_id=content_episode_id,
                episode_number=episode_number,
                language_code=language_code,
            )

    def complete_show_creation_job(
        self,
        job_id: UUID,
        show_id: str,
        episode_count: int,
    ) -> None:
        with self._connection() as conn, conn.transaction():
            row = conn.execute(
                """
                SELECT plan_id
                FROM generation_jobs
                WHERE id = %s
                  AND job_type = 'show_creation'
                """,
                (job_id,),
            ).fetchone()
            if row is None:
                raise NotFoundError("job not found")

            conn.execute(
                """
                UPDATE generation_jobs
                SET status = 'completed',
                    output_payload = %s,
                    finished_at = now(),
                    error_message = NULL
                WHERE id = %s
                """,
                (
                    Jsonb(
                        {
                            "show_id": show_id,
                            "episode_count": episode_count,
                        }
                    ),
                    job_id,
                ),
            )
            conn.execute(
                """
                UPDATE production_plans
                SET status = 'completed',
                    target_show_id = %s::uuid,
                    completed_at = COALESCE(completed_at, now()),
                    updated_at = now()
                WHERE id = %s
                """,
                (show_id, row["plan_id"]),
            )

    def fail_show_creation_job(self, job_id: UUID, error_message: str) -> None:
        with self._connection() as conn, conn.transaction():
            row = conn.execute(
                """
                SELECT plan_id
                FROM generation_jobs
                WHERE id = %s
                  AND job_type = 'show_creation'
                """,
                (job_id,),
            ).fetchone()
            if row is None:
                raise NotFoundError("job not found")

            conn.execute(
                """
                UPDATE generation_jobs
                SET status = 'failed',
                    error_message = %s,
                    finished_at = now()
                WHERE id = %s
                """,
                (error_message, job_id),
            )
            conn.execute(
                """
                UPDATE production_plans
                SET status = 'failed', updated_at = now()
                WHERE id = %s
                """,
                (row["plan_id"],),
            )

    def complete_transcript_job(
        self,
        job_id: UUID,
        *,
        content_episode_id: str,
        segment_count: int,
        alignment_method: str,
    ) -> None:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                UPDATE generation_jobs
                SET status = 'completed',
                    output_payload = %s,
                    finished_at = now(),
                    error_message = NULL
                WHERE id = %s
                  AND job_type = 'transcript_generation'
                """,
                (
                    Jsonb(
                        {
                            "content_episode_id": content_episode_id,
                            "segment_count": segment_count,
                            "alignment_method": alignment_method,
                        }
                    ),
                    job_id,
                ),
            )

    def fail_transcript_job(self, job_id: UUID, error_message: str) -> None:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                UPDATE generation_jobs
                SET status = 'failed',
                    error_message = %s,
                    finished_at = now()
                WHERE id = %s
                  AND job_type = 'transcript_generation'
                """,
                (error_message, job_id),
            )

    def get_job(self, owner_user_id: UUID, job_id: UUID) -> GenerationJob:
        with self._connection() as conn:
            row = conn.execute(
                """
                SELECT gj.id, gj.plan_id, gj.episode_draft_id, gj.job_type, gj.status,
                       gj.provider, gj.input_payload, gj.output_payload, gj.error_message,
                       gj.started_at, gj.finished_at, gj.created_at
                FROM generation_jobs gj
                JOIN production_plans pp ON pp.id = gj.plan_id
                WHERE gj.id = %s AND pp.owner_user_id = %s
                """,
                (job_id, owner_user_id),
            ).fetchone()
            if row is None:
                raise NotFoundError("job not found")
            return GenerationJob.model_validate(row)

    def _get_thread(self, conn, owner_user_id: UUID, thread_id: UUID) -> ChatThreadView:
        thread_row = conn.execute(
            """
            SELECT id, title, status, created_at, updated_at
            FROM chat_threads
            WHERE id = %s AND owner_user_id = %s
            """,
            (thread_id, owner_user_id),
        ).fetchone()
        if thread_row is None:
            raise NotFoundError("thread not found")

        message_rows = conn.execute(
            """
            SELECT id, role, text_content, created_at
            FROM chat_messages
            WHERE thread_id = %s
            ORDER BY created_at ASC,
                     CASE role WHEN 'user' THEN 0 ELSE 1 END ASC,
                     id ASC
            """,
            (thread_id,),
        ).fetchall()

        plan_row = conn.execute(
            """
            SELECT id
            FROM production_plans
            WHERE thread_id = %s
            ORDER BY updated_at DESC, created_at DESC
            LIMIT 1
            """,
            (thread_id,),
        ).fetchone()

        current_plan = self._get_plan(conn, plan_row["id"]) if plan_row else None

        return ChatThreadView(
            id=thread_row["id"],
            title=thread_row["title"],
            status=thread_row["status"],
            created_at=thread_row["created_at"],
            updated_at=thread_row["updated_at"],
            messages=[ChatMessage.model_validate(row) for row in message_rows],
            current_plan=current_plan,
        )

    def _get_plan(self, conn, plan_id: UUID) -> ProductionPlan:
        plan_row = conn.execute(
            """
            SELECT id, thread_id, status, series_title, series_description, tone_style,
                   target_language_code, metadata, created_at, updated_at, completed_at
            FROM production_plans
            WHERE id = %s
            """,
            (plan_id,),
        ).fetchone()
        if plan_row is None:
            raise NotFoundError("plan not found")

        tags = [
            row["tag_name"]
            for row in conn.execute(
                """
                SELECT tag_name
                FROM production_plan_tags
                WHERE plan_id = %s
                ORDER BY created_at ASC, tag_name ASC
                """,
                (plan_id,),
            ).fetchall()
        ]

        host_rows = conn.execute(
            """
            SELECT sort_order, voice_profile_id, display_name, avatar_url, role, notes
            FROM production_plan_hosts
            WHERE plan_id = %s
            ORDER BY sort_order ASC
            """,
            (plan_id,),
        ).fetchall()
        if not host_rows:
            raise NotFoundError("plan host not found")

        episode_rows = conn.execute(
            """
            SELECT id, episode_number, title, description, estimated_duration_seconds,
                   notes, status, created_at, updated_at
            FROM production_plan_episode_drafts
            WHERE plan_id = %s
            ORDER BY episode_number ASC
            """,
            (plan_id,),
        ).fetchall()

        metadata = plan_row["metadata"] or {}
        raw_metadata_hosts = metadata.get("hosts") if isinstance(metadata.get("hosts"), list) else []
        hosts = []
        for index, row in enumerate(host_rows):
            metadata_host = raw_metadata_hosts[index] if index < len(raw_metadata_hosts) and isinstance(raw_metadata_hosts[index], dict) else {}
            hosts.append(
                {
                    "display_name": row["display_name"],
                    "avatar_url": _string_or_none(metadata_host.get("avatar_url")) or _string_or_none(row["avatar_url"]),
                    "voice_profile_id": row["voice_profile_id"],
                    "role": row["role"],
                    "bio": _string_or_default(metadata_host.get("bio"), row["notes"] or ""),
                    "persona_summary": _string_or_none(metadata_host.get("persona_summary")),
                }
            )
        show_draft = ShowDraft(
            slug=_slugify(plan_row["series_title"]),
            title=plan_row["series_title"],
            description=plan_row["series_description"],
            cover_image_url=_string_or_none(metadata.get("cover_image_url")),
            primary_category=_string_or_default(metadata.get("primary_category"), "Cong nghe"),
            categories=_strings(metadata.get("categories")),
            language_code=plan_row["target_language_code"],
            content_type=_string_or_default(metadata.get("content_type"), "podcast"),
            hosts=hosts,
            tags=tags,
        )

        return ProductionPlan(
            id=plan_row["id"],
            thread_id=plan_row["thread_id"],
            status=plan_row["status"],
            series_title=plan_row["series_title"],
            series_description=plan_row["series_description"],
            tone_style=plan_row["tone_style"],
            target_language_code=plan_row["target_language_code"],
            show_draft=show_draft,
            episodes=[
                {
                    "id": row["id"],
                    "episode_number": row["episode_number"],
                    "title": row["title"],
                    "description": row["description"],
                    "estimated_duration_seconds": row["estimated_duration_seconds"],
                    "notes": row["notes"],
                    "status": row["status"],
                    "created_at": row["created_at"],
                    "updated_at": row["updated_at"],
                }
                for row in episode_rows
            ],
            tags=tags,
            created_at=plan_row["created_at"],
            updated_at=plan_row["updated_at"],
            completed_at=plan_row["completed_at"],
        )

    def _insert_plan(self, *, conn, owner_user_id: UUID, thread_id: UUID | None, prompt: str, output: PlannerOutput) -> UUID:
        plan_row = conn.execute(
            """
            INSERT INTO production_plans (
              owner_user_id,
              thread_id,
              series_title,
              series_description,
              tone_style,
              status,
              target_language_code,
              metadata,
              completed_at
            )
            VALUES (%s, %s, %s, %s, %s, 'completed', %s, %s, now())
            RETURNING id
            """,
            (
                owner_user_id,
                thread_id,
                output.series_title,
                output.series_description,
                output.tone_style,
                output.language_code,
                Jsonb(
                    {
                        "prompt": prompt,
                        "primary_category": output.primary_category,
                        "categories": output.categories,
                        "content_type": output.content_type,
                        "cover_image_url": output.cover_image_url,
                        "hosts": [
                            {
                                "display_name": host.display_name,
                                "avatar_url": host.avatar_url,
                                "bio": host.bio,
                                "persona_summary": host.persona_summary,
                            }
                            for host in output.hosts
                        ],
                    }
                ),
            ),
        ).fetchone()
        plan_id = plan_row["id"]

        for tag in output.tags:
            conn.execute(
                """
                INSERT INTO production_plan_tags (plan_id, tag_name)
                VALUES (%s, %s)
                ON CONFLICT (plan_id, tag_name) DO NOTHING
                """,
                (plan_id, tag),
            )

        for index, host in enumerate(output.hosts):
            conn.execute(
                """
                INSERT INTO production_plan_hosts (
                  plan_id,
                  voice_profile_id,
                  display_name,
                  avatar_url,
                  role,
                  persona_type,
                  sort_order,
                  notes
                )
                VALUES (%s, %s, %s, %s, %s, 'ai', %s, %s)
                """,
                (
                    plan_id,
                    host.voice_profile_id,
                    host.display_name,
                    host.avatar_url,
                    host.role,
                    index,
                    host.bio,
                ),
            )

        for episode in output.episodes:
            conn.execute(
                """
                INSERT INTO production_plan_episode_drafts (
                  plan_id,
                  episode_number,
                  title,
                  description,
                  estimated_duration_seconds,
                  notes,
                  status
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    plan_id,
                    episode.episode_number,
                    episode.title,
                    episode.description,
                    episode.estimated_duration_seconds,
                    episode.notes,
                    episode.status,
                ),
            )

        return plan_id


def create_pool(database_url: str) -> ConnectionPool:
    return ConnectionPool(
        conninfo=database_url,
        min_size=1,
        max_size=5,
        open=True,
        kwargs={"row_factory": dict_row},
    )


def _slugify(value: str) -> str:
    normalized = value.strip().lower()
    parts = []
    previous_dash = False
    for char in normalized:
        if char.isalnum():
            parts.append(char)
            previous_dash = False
        elif not previous_dash:
            parts.append("-")
            previous_dash = True
    slug = "".join(parts).strip("-")
    return slug or "new-show"


def _string_or_default(value: Any, fallback: str) -> str:
    if isinstance(value, str) and value.strip():
        return value.strip()
    return fallback


def _string_or_none(value: Any) -> str | None:
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _nullable_string(value: Any) -> str | None:
    return _string_or_none(value)


def plan_row_owner_user_id(conn: Any, plan_id: UUID) -> UUID:
    row = conn.execute(
        """
        SELECT owner_user_id
        FROM production_plans
        WHERE id = %s
        """,
        (plan_id,),
    ).fetchone()
    if row is None:
        raise NotFoundError("plan not found")
    return row["owner_user_id"]


def _strings(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    items: list[str] = []
    for item in value:
        if isinstance(item, str) and item.strip():
            items.append(item.strip())
    return items
