from __future__ import annotations

import json
import io
import logging
import re
import unicodedata
import wave
from dataclasses import dataclass
from typing import Any
from uuid import UUID

from google import genai
from google.cloud import storage
from google.genai import types
import httpx
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from psycopg_pool import ConnectionPool

from .models import AIHostDraft, EpisodeDraft, ProductionPlan, VoiceProfile
from .transcript_generation import EpisodeTranscriptSource, TranscriptArtifact, TranscriptSegment

logger = logging.getLogger(__name__)

TTS_PROMPT_INTRO = (
    "TTS the following Vietnamese podcast conversation with high expressiveness "
    "and natural emotions. Note the emotion and direction tags in brackets and "
    "perform accordingly.\n\n"
)
MAX_TTS_PROMPT_CHARACTERS = 4000


@dataclass(frozen=True)
class ScriptTurn:
    speaker: str
    text: str
    emotion: str | None = None
    direction: str | None = None


@dataclass(frozen=True)
class EpisodeArtifact:
    audio_bytes: bytes
    duration_seconds: int
    script_text: str
    turns: tuple[ScriptTurn, ...] = ()


@dataclass(frozen=True)
class CreatedShow:
    show_id: str
    show_title: str
    episode_count: int


@dataclass(frozen=True)
class CreatedEpisode:
    episode_id: str
    episode_title: str
    episode_number: int
    audio_url: str
    audio_storage_key: str


@dataclass(frozen=True)
class EpisodeDialogueMemory:
    episode_number: int
    title: str
    description: str
    turns: tuple[ScriptTurn, ...] = ()


@dataclass(frozen=True)
class ShowCreationSession:
    show_id: str
    show_title: str
    cover_image_url: str
    primary_host_name: str
    inserted_host_ids: tuple[str, ...]


@dataclass(frozen=True)
class StoredAudioAsset:
    audio_url: str
    storage_key: str


@dataclass(frozen=True)
class StoredObjectAsset:
    url: str
    storage_key: str
    size_bytes: int


class GeminiTTSSynthesizer:
    def __init__(
        self,
        *,
        project: str | None,
        location: str,
        model: str,
    ) -> None:
        self._project = (project or "").strip()
        self._location = location.strip() or "us-central1"
        self._model = model.strip() or "gemini-2.5-flash-tts"
        self._client = (
            genai.Client(
                vertexai=True,
                project=self._project,
                location=self._location,
            )
            if self._project
            else None
        )

    @property
    def enabled(self) -> bool:
        return self._client is not None

    def synthesize_episode(
        self,
        *,
        plan: ProductionPlan,
        episode: EpisodeDraft,
        primary_host: AIHostDraft | None,
        voice_profiles: list[VoiceProfile],
        dialogue_turns: tuple[ScriptTurn, ...] | None = None,
    ) -> EpisodeArtifact:
        _ = primary_host
        dialogue_hosts = _select_dialogue_hosts(plan)
        turns = dialogue_turns or _build_episode_turns(plan, episode, dialogue_hosts)
        script_text = _render_episode_script(turns)
        if self._client is None:
            return EpisodeArtifact(
                audio_bytes=b"",
                duration_seconds=max(1, episode.estimated_duration_seconds),
                script_text=script_text,
                turns=turns,
            )

        speech_config = _build_speech_config(
            plan=plan,
            hosts=dialogue_hosts,
            voice_profiles=voice_profiles,
        )
        pcm_chunks: list[bytes] = []
        for prompt_chunk in _build_tts_prompt_chunks(turns):
            response = self._client.models.generate_content(
                model=self._model,
                contents=prompt_chunk,
                config=types.GenerateContentConfig(
                    response_modalities=[types.Modality.AUDIO],
                    speech_config=speech_config,
                ),
            )
            pcm_bytes = _extract_audio_bytes(response)
            if not pcm_bytes:
                raise RuntimeError("gemini tts returned empty audio payload")
            pcm_chunks.append(pcm_bytes)

        pcm_bytes = b"".join(pcm_chunks)
        wav_bytes = _pcm16_to_wav(pcm_bytes)
        duration_seconds = max(1, len(pcm_bytes) // (24000 * 2))
        return EpisodeArtifact(
            audio_bytes=wav_bytes,
            duration_seconds=duration_seconds,
            script_text=script_text,
            turns=turns,
        )


class GoogleCloudAudioStore:
    def __init__(
        self,
        *,
        project: str | None,
        bucket_name: str | None,
        public_base_url: str | None,
    ) -> None:
        self._project = (project or "").strip()
        self._bucket_name = (bucket_name or "").strip()
        self._public_base_url = (public_base_url or "").rstrip("/")
        self._client = (
            storage.Client(project=self._project or None)
            if self._bucket_name
            else None
        )

    @property
    def enabled(self) -> bool:
        return self._client is not None and bool(self._bucket_name)

    def upload_episode_audio(
        self,
        *,
        show_id: str,
        episode_slug: str,
        audio_bytes: bytes,
    ) -> StoredAudioAsset:
        if not self.enabled:
            raise RuntimeError("audio storage is not configured")
        if not audio_bytes:
            raise RuntimeError("audio payload is empty")

        storage_key = f"shows/{show_id}/episodes/{episode_slug}.wav"
        bucket = self._client.bucket(self._bucket_name)
        blob = bucket.blob(storage_key)
        blob.cache_control = "public, max-age=31536000, immutable"
        blob.content_type = "audio/wav"
        blob.upload_from_string(audio_bytes, content_type="audio/wav")
        public_base_url = self._public_base_url or f"https://storage.googleapis.com/{self._bucket_name}"
        return StoredAudioAsset(
            audio_url=f"{public_base_url}/{storage_key}",
            storage_key=storage_key,
        )

    def upload_episode_transcript(
        self,
        *,
        show_id: str,
        episode_slug: str,
        transcript_json: str,
    ) -> StoredObjectAsset:
        if not self.enabled:
            raise RuntimeError("audio storage is not configured")
        payload = transcript_json.encode("utf-8")
        storage_key = f"shows/{show_id}/episodes/{episode_slug}.transcript.json"
        bucket = self._client.bucket(self._bucket_name)
        blob = bucket.blob(storage_key)
        blob.cache_control = "public, max-age=31536000, immutable"
        blob.content_type = "application/json; charset=utf-8"
        blob.upload_from_string(payload, content_type="application/json; charset=utf-8")
        public_base_url = self._public_base_url or f"https://storage.googleapis.com/{self._bucket_name}"
        return StoredObjectAsset(
            url=f"{public_base_url}/{storage_key}",
            storage_key=storage_key,
            size_bytes=len(payload),
        )

    def download_audio_bytes(
        self,
        *,
        audio_storage_key: str | None,
        audio_url: str,
    ) -> bytes:
        if audio_storage_key and self.enabled:
            bucket = self._client.bucket(self._bucket_name)
            blob = bucket.blob(audio_storage_key)
            return blob.download_as_bytes()
        if not audio_url.strip():
            raise RuntimeError("audio source is missing")
        response = httpx.get(audio_url, timeout=60.0)
        response.raise_for_status()
        return response.content


class ContentCreationStore:
    def __init__(
        self,
        pool: ConnectionPool,
        *,
        audio_store: GoogleCloudAudioStore | None = None,
    ) -> None:
        self._pool = pool
        self._audio_store = audio_store

    @property
    def enabled(self) -> bool:
        return self._audio_store is not None and self._audio_store.enabled

    def list_plan_episode_dialogues(self, plan_id: UUID) -> list[EpisodeDialogueMemory]:
        with self._pool.connection() as conn:
            conn.row_factory = dict_row
            rows = conn.execute(
                """
                WITH ranked_episodes AS (
                  SELECT
                    e.id,
                    e.episode_number,
                    e.title,
                    e.description,
                    ROW_NUMBER() OVER (
                      PARTITION BY e.episode_number
                      ORDER BY e.published_at DESC NULLS LAST, e.created_at DESC, e.id DESC
                    ) AS rn
                  FROM episodes e
                  WHERE e.source_plan_id = %s::uuid
                    AND e.deleted_at IS NULL
                )
                SELECT
                  re.id::text AS episode_id,
                  re.episode_number,
                  re.title,
                  re.description,
                  es.segment_index,
                  es.speaker_label,
                  es.text_content
                FROM ranked_episodes re
                LEFT JOIN episode_segments es
                  ON es.episode_id = re.id
                WHERE re.rn = 1
                ORDER BY re.episode_number ASC, es.segment_index ASC
                """,
                (plan_id,),
            ).fetchall()

        dialogues: dict[str, EpisodeDialogueMemory] = {}
        turns_by_episode_id: dict[str, list[ScriptTurn]] = {}
        for row in rows:
            episode_id = row["episode_id"]
            if episode_id not in dialogues:
                dialogues[episode_id] = EpisodeDialogueMemory(
                    episode_number=int(row["episode_number"] or 0),
                    title=str(row["title"] or ""),
                    description=str(row["description"] or ""),
                    turns=(),
                )
                turns_by_episode_id[episode_id] = []
            speaker = str(row.get("speaker_label") or "").strip()
            text = str(row.get("text_content") or "").strip()
            if speaker and text:
                turns_by_episode_id[episode_id].append(
                    ScriptTurn(
                        speaker=speaker,
                        text=text,
                    )
                )

        memories: list[EpisodeDialogueMemory] = []
        for episode_id, dialogue in dialogues.items():
            memories.append(
                EpisodeDialogueMemory(
                    episode_number=dialogue.episode_number,
                    title=dialogue.title,
                    description=dialogue.description,
                    turns=tuple(turns_by_episode_id.get(episode_id, [])),
                )
            )
        return sorted(memories, key=lambda item: item.episode_number)

    def get_episode_transcript_source(
        self,
        *,
        episode_id: str,
        language_code: str | None = None,
    ) -> EpisodeTranscriptSource:
        if self._audio_store is None:
            raise RuntimeError("audio storage is not configured")

        with self._pool.connection() as conn:
            conn.row_factory = dict_row
            episode_row = conn.execute(
                """
                SELECT
                  e.id::text AS episode_id,
                  e.show_id::text AS show_id,
                  e.slug::text AS episode_slug,
                  COALESCE(e.audio_url, '') AS audio_url,
                  COALESCE(e.audio_storage_key, '') AS audio_storage_key,
                  COALESCE(s.language_code, 'vi') AS language_code
                FROM episodes e
                JOIN shows s ON s.id = e.show_id
                WHERE e.id = %s::uuid
                LIMIT 1
                """,
                (episode_id,),
            ).fetchone()
            if episode_row is None:
                raise ValueError("episode not found for transcript generation")

            segment_rows = conn.execute(
                """
                SELECT speaker_label, text_content
                FROM episode_segments
                WHERE episode_id = %s::uuid
                ORDER BY segment_index ASC
                """,
                (episode_id,),
            ).fetchall()

        turns = tuple(
            ScriptTurn(
                speaker=str(row["speaker_label"] or "").strip() or "AI host",
                text=str(row["text_content"] or "").strip(),
            )
            for row in segment_rows
            if str(row["text_content"] or "").strip()
        )
        if not turns:
            raise RuntimeError("episode does not have dialogue segments to align")

        audio_bytes = self._audio_store.download_audio_bytes(
            audio_storage_key=str(episode_row["audio_storage_key"] or "").strip() or None,
            audio_url=str(episode_row["audio_url"] or ""),
        )
        return EpisodeTranscriptSource(
            episode_id=str(episode_row["episode_id"]),
            show_id=str(episode_row["show_id"]),
            episode_slug=str(episode_row["episode_slug"]),
            language_code=(language_code or str(episode_row["language_code"] or "vi")).strip() or "vi",
            audio_bytes=audio_bytes,
            turns=turns,
        )

    def mark_episode_transcript_failed(self, *, episode_id: str, error_message: str) -> None:
        with self._pool.connection() as conn, conn.transaction():
            conn.execute(
                """
                INSERT INTO episode_assets (
                  episode_id,
                  asset_type,
                  sort_order,
                  mime_type,
                  metadata
                )
                VALUES (
                  %s::uuid,
                  'transcript',
                  0,
                  'application/json; charset=utf-8',
                  %s
                )
                ON CONFLICT (episode_id, asset_type, sort_order)
                DO UPDATE SET
                  mime_type = EXCLUDED.mime_type,
                  metadata = episode_assets.metadata || EXCLUDED.metadata
                """,
                (
                    episode_id,
                    Jsonb(
                        {
                            "status": "failed",
                            "error": error_message,
                        }
                    ),
                ),
            )

    def save_episode_transcript(
        self,
        *,
        episode_id: str,
        artifact: TranscriptArtifact,
    ) -> None:
        if self._audio_store is None or not self._audio_store.enabled:
            raise RuntimeError("audio storage is not configured")

        with self._pool.connection() as conn, conn.transaction():
            conn.row_factory = dict_row
            episode_row = conn.execute(
                """
                SELECT e.id::text AS episode_id,
                       e.show_id::text AS show_id,
                       e.slug::text AS episode_slug,
                       COALESCE(sh.id::text, '') AS fallback_show_host_id
                FROM episodes e
                LEFT JOIN LATERAL (
                  SELECT id
                  FROM show_hosts
                  WHERE show_id = e.show_id
                  ORDER BY sort_order ASC
                  LIMIT 1
                ) sh ON true
                WHERE e.id = %s::uuid
                LIMIT 1
                """,
                (episode_id,),
            ).fetchone()
            if episode_row is None:
                raise ValueError("episode not found for transcript save")

            host_rows = conn.execute(
                """
                SELECT id::text AS id, display_name
                FROM show_hosts
                WHERE show_id = %s::uuid
                ORDER BY sort_order ASC
                """,
                (episode_row["show_id"],),
            ).fetchall()
            host_ids_by_name = {
                str(row["display_name"] or "").strip(): str(row["id"])
                for row in host_rows
                if str(row["display_name"] or "").strip()
            }
            fallback_show_host_id = str(episode_row["fallback_show_host_id"] or "").strip() or None

            transcript_asset = self._audio_store.upload_episode_transcript(
                show_id=str(episode_row["show_id"]),
                episode_slug=str(episode_row["episode_slug"]),
                transcript_json=artifact.raw_json,
            )

            conn.execute(
                """
                DELETE FROM episode_segments
                WHERE episode_id = %s::uuid
                """,
                (episode_id,),
            )
            for index, segment in enumerate(artifact.segments):
                speaker_label = (segment.speaker or "").strip() or "AI host"
                conn.execute(
                    """
                    INSERT INTO episode_segments (
                      episode_id,
                      show_host_id,
                      segment_index,
                      speaker_label,
                      start_ms,
                      end_ms,
                      text_content
                    )
                    VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s)
                    """,
                    (
                        episode_id,
                        host_ids_by_name.get(speaker_label) or fallback_show_host_id,
                        index,
                        speaker_label,
                        max(0, round(segment.start_seconds * 1000)),
                        max(0, round(segment.end_seconds * 1000)),
                        segment.text.strip(),
                    ),
                )

            conn.execute(
                """
                INSERT INTO episode_assets (
                  episode_id,
                  asset_type,
                  url,
                  storage_key,
                  mime_type,
                  size_bytes,
                  sort_order,
                  metadata
                )
                VALUES (
                  %s::uuid,
                  'transcript',
                  %s,
                  %s,
                  'application/json; charset=utf-8',
                  %s,
                  0,
                  %s
                )
                ON CONFLICT (episode_id, asset_type, sort_order)
                DO UPDATE SET
                  url = EXCLUDED.url,
                  storage_key = EXCLUDED.storage_key,
                  mime_type = EXCLUDED.mime_type,
                  size_bytes = EXCLUDED.size_bytes,
                  metadata = EXCLUDED.metadata
                """,
                (
                    episode_id,
                    transcript_asset.url,
                    transcript_asset.storage_key,
                    transcript_asset.size_bytes,
                    Jsonb(
                        {
                            "status": "completed",
                            "language": artifact.language,
                            "duration_seconds": artifact.duration_seconds,
                            "alignment_method": artifact.alignment_method,
                            "text": artifact.text,
                            "segment_count": len(artifact.segments),
                        }
                    ),
                ),
            )

    def create_show_from_plan(
        self,
        *,
        owner_user_id: UUID,
        owner_display_name: str | None,
        owner_email: str | None,
        plan: ProductionPlan,
        episodes: list[EpisodeArtifact],
    ) -> CreatedShow:
        session = self.create_show_shell(
            owner_user_id=owner_user_id,
            owner_display_name=owner_display_name,
            owner_email=owner_email,
            plan=plan,
        )
        created_episodes: list[CreatedEpisode] = []
        for index, episode in enumerate(plan.episodes):
            artifact = (
                episodes[index]
                if index < len(episodes)
                else EpisodeArtifact(
                    audio_bytes=b"",
                    duration_seconds=max(1, episode.estimated_duration_seconds),
                    script_text=_build_episode_script(
                        plan,
                        episode,
                        plan.show_draft.primary_host,
                    ),
                )
            )
            created_episodes.append(
                self.create_episode_from_plan(
                    show=session,
                    plan=plan,
                    episode=episode,
                    artifact=artifact,
                )
            )

        logger.info(
            "show creation completed",
            extra={"show_id": session.show_id, "episode_count": len(created_episodes)},
        )
        return CreatedShow(
            show_id=session.show_id,
            show_title=session.show_title,
            episode_count=len(created_episodes),
        )

    def create_show_shell(
        self,
        *,
        owner_user_id: UUID,
        owner_display_name: str | None,
        owner_email: str | None,
        plan: ProductionPlan,
    ) -> ShowCreationSession:
        with self._pool.connection() as conn, conn.transaction():
            conn.row_factory = dict_row
            title = plan.series_title.strip()
            description = plan.series_description.strip()
            primary_category = plan.show_draft.primary_category.strip()
            if not title or not primary_category:
                raise ValueError("plan is missing title or primary category")

            _, category_id = _resolve_category(
                conn,
                primary_category,
            )
            slug = _ensure_unique_show_slug(conn, _slugify(title))
            cover_image_url = (
                (plan.show_draft.cover_image_url or "").strip()
                or _fallback_show_cover_url(slug)
            )
            content_type = _sanitize_content_type(plan.show_draft.content_type)
            language_code = _sanitize_language_code(plan.target_language_code)
            resolved_hosts = _normalize_hosts(
                content_type=content_type,
                hosts=plan.show_draft.hosts,
                slug=slug,
            )
            owner_name = (
                (owner_display_name or "").strip()
                or _fallback_owner_display_name(owner_email or "")
            )
            owner_avatar_url = _fallback_owner_avatar_url(str(owner_user_id))

            show_row = conn.execute(
                """
                INSERT INTO shows (
                  owner_user_id,
                  owner_display_name_snapshot,
                  owner_avatar_url_snapshot,
                  title,
                  slug,
                  description,
                  content_type,
                  language_code,
                  cover_image_url,
                  publish_status,
                  visibility,
                  monetization_type,
                  credit_cost,
                  subscriber_count,
                  episode_count,
                  total_listen_count,
                  published_at
                )
                VALUES (
                  %s, %s, %s, %s, %s, %s, %s, %s, %s,
                  'published', 'public', 'free', 0, 0, 0, 0, now()
                )
                RETURNING id::text
                """,
                (
                    owner_user_id,
                    owner_name,
                    owner_avatar_url,
                    title,
                    slug,
                    description,
                    content_type,
                    language_code,
                    cover_image_url,
                ),
            ).fetchone()

            show_id = show_row["id"]
            conn.execute(
                """
                INSERT INTO show_categories (show_id, category_id, is_primary)
                VALUES (%s::uuid, %s::uuid, true)
                """,
                (show_id, category_id),
            )

            inserted_hosts: list[str] = []
            for index, host in enumerate(resolved_hosts):
                host_row = conn.execute(
                    """
                    INSERT INTO show_hosts (
                      show_id,
                      linked_voice_profile_id,
                      display_name,
                      avatar_url,
                      role,
                      persona_type,
                      sort_order,
                      bio
                    )
                    VALUES (
                      %s::uuid,
                      %s::uuid,
                      %s,
                      NULLIF(%s, ''),
                      %s,
                      'ai',
                      %s,
                      %s
                    )
                    RETURNING id::text
                    """,
                    (
                        show_id,
                        host.voice_profile_id,
                        host.display_name,
                        host.avatar_url or "",
                        host.role,
                        index,
                        host.bio or "",
                    ),
                ).fetchone()
                inserted_hosts.append(host_row["id"])

            primary_host_name = resolved_hosts[0].display_name if resolved_hosts else ""
            return ShowCreationSession(
                show_id=show_id,
                show_title=title,
                cover_image_url=cover_image_url,
                primary_host_name=primary_host_name,
                inserted_host_ids=tuple(inserted_hosts),
            )

    def create_episode_from_plan(
        self,
        *,
        show: ShowCreationSession,
        plan: ProductionPlan,
        episode: EpisodeDraft,
        artifact: EpisodeArtifact,
    ) -> CreatedEpisode:
        with self._pool.connection() as conn, conn.transaction():
            conn.row_factory = dict_row
            episode_slug = _ensure_unique_episode_slug(
                conn,
                show.show_id,
                _slugify(episode.title or f"tap-{episode.episode_number}"),
            )
            audio_asset = self._store_episode_audio(
                show_id=show.show_id,
                episode_slug=episode_slug,
                artifact=artifact,
            )
            episode_row = conn.execute(
                """
                INSERT INTO episodes (
                  show_id,
                  source_plan_id,
                  title,
                  slug,
                  description,
                  episode_number,
                  audio_url,
                  audio_storage_key,
                  cover_image_url,
                  duration_seconds,
                  publish_status,
                  visibility,
                  is_ai_generated,
                  published_at
                )
                VALUES (
                  %s::uuid,
                  %s::uuid,
                  %s,
                  %s,
                  %s,
                  %s,
                  NULLIF(%s, ''),
                  NULLIF(%s, ''),
                  NULLIF(%s, ''),
                  %s,
                  'published',
                  'public',
                  true,
                  now()
                )
                RETURNING id::text
                """,
                (
                    show.show_id,
                    plan.id,
                    episode.title.strip(),
                    episode_slug,
                    episode.description.strip(),
                    episode.episode_number,
                    audio_asset.audio_url,
                    audio_asset.storage_key,
                    (episode.cover_image_url or "").strip() or show.cover_image_url,
                    artifact.duration_seconds,
                ),
            ).fetchone()

            for segment in _build_episode_segments(
                show=show,
                plan=plan,
                artifact=artifact,
            ):
                conn.execute(
                    """
                    INSERT INTO episode_segments (
                      episode_id,
                      show_host_id,
                      segment_index,
                      speaker_label,
                      start_ms,
                      end_ms,
                      text_content
                    )
                    VALUES (%s::uuid, %s::uuid, %s, %s, %s, %s, %s)
                    """,
                    (
                        episode_row["id"],
                        segment["show_host_id"],
                        segment["segment_index"],
                        segment["speaker_label"],
                        segment["start_ms"],
                        segment["end_ms"],
                        segment["text_content"],
                    ),
                )
            conn.execute(
                """
                INSERT INTO episode_assets (
                  episode_id,
                  asset_type,
                  mime_type,
                  sort_order,
                  metadata
                )
                VALUES (
                  %s::uuid,
                  'transcript',
                  'application/json; charset=utf-8',
                  0,
                  %s
                )
                ON CONFLICT (episode_id, asset_type, sort_order)
                DO UPDATE SET
                  mime_type = EXCLUDED.mime_type,
                  metadata = EXCLUDED.metadata
                """,
                (
                    episode_row["id"],
                    Jsonb(
                        {
                            "status": "pending",
                            "language": _sanitize_language_code(plan.target_language_code),
                            "segment_count": len(artifact.turns),
                        }
                    ),
                ),
            )
            conn.execute(
                """
                UPDATE shows
                SET episode_count = episode_count + 1
                WHERE id = %s::uuid
                """,
                (show.show_id,),
            )

            return CreatedEpisode(
                episode_id=episode_row["id"],
                episode_title=episode.title.strip(),
                episode_number=episode.episode_number,
                audio_url=audio_asset.audio_url,
                audio_storage_key=audio_asset.storage_key,
            )

    def _store_episode_audio(
        self,
        *,
        show_id: str,
        episode_slug: str,
        artifact: EpisodeArtifact,
    ) -> StoredAudioAsset:
        if self._audio_store is None or not self._audio_store.enabled:
            raise RuntimeError("audio storage is not configured")
        return self._audio_store.upload_episode_audio(
            show_id=show_id,
            episode_slug=episode_slug,
            audio_bytes=artifact.audio_bytes,
        )


def create_content_pool(database_url: str) -> ConnectionPool:
    return ConnectionPool(
        conninfo=database_url,
        min_size=1,
        max_size=3,
        open=True,
        kwargs={"row_factory": dict_row},
    )


def _build_episode_script(
    plan: ProductionPlan,
    episode: EpisodeDraft,
    primary_host: AIHostDraft | None,
) -> str:
    turns = _build_episode_turns(
        plan,
        episode,
        _select_dialogue_hosts(plan) if primary_host is None else (primary_host,),
    )
    return _render_episode_script(turns)


def _select_dialogue_hosts(plan: ProductionPlan) -> tuple[AIHostDraft, ...]:
    hosts = tuple(
        host
        for host in plan.show_draft.hosts
        if host.display_name.strip()
    )
    if not hosts:
        return ()
    if plan.show_draft.content_type == "podcast":
        return hosts[:2]
    return hosts[:1]


def _build_episode_turns(
    plan: ProductionPlan,
    episode: EpisodeDraft,
    hosts: tuple[AIHostDraft, ...],
) -> tuple[ScriptTurn, ...]:
    if len(hosts) >= 2 and plan.show_draft.content_type == "podcast":
        primary = hosts[0]
        co_host = hosts[1]
        turns = [
            ScriptTurn(
                speaker=primary.display_name.strip(),
                text=(
                    f"Xin chao, day la {primary.display_name.strip()} va "
                    f"{co_host.display_name.strip()} trong series {plan.series_title.strip()}. "
                    f"Hom nay chung ta mo ra tap {episode.episode_number}: {episode.title.strip()}."
                ),
                emotion="confident",
                direction="ro rang, vao thang chu de",
            ),
            ScriptTurn(
                speaker=co_host.display_name.strip(),
                text=(
                    f"Chu de nay rat sat voi founder va product manager. "
                    f"Minh muon bat dau tu y chinh: {episode.description.strip()}"
                ),
                emotion="curious",
                direction="goi mo, hoi thoai tu nhien",
            ),
            ScriptTurn(
                speaker=primary.display_name.strip(),
                text=_episode_detail_text(episode),
                emotion="thoughtful",
                direction="giai thich mach lac, co nhan nhip",
            ),
            ScriptTurn(
                speaker=co_host.display_name.strip(),
                text=_episode_close_text(plan, episode),
                emotion="encouraging",
                direction="tong ket gon, giu nhip doi thoai",
            ),
        ]
        return tuple(turns)

    host_name = hosts[0].display_name.strip() if hosts else "AI host"
    turns = [
        ScriptTurn(
            speaker=host_name,
            text=(
                f"Xin chao, day la {host_name} trong series {plan.series_title.strip()}. "
                f"Tap {episode.episode_number}: {episode.title.strip()}."
            ),
            emotion="confident",
            direction="mo dau ro rang",
        ),
        ScriptTurn(
            speaker=host_name,
            text=_episode_detail_text(episode),
            emotion="thoughtful",
            direction="ke chuyen tu nhien, de nghe",
        ),
        ScriptTurn(
            speaker=host_name,
            text=_episode_close_text(plan, episode),
            emotion="encouraging",
            direction="ket lai suc tich",
        ),
    ]
    return tuple(turns)


def _episode_detail_text(episode: EpisodeDraft) -> str:
    detail = episode.description.strip()
    notes = episode.notes.strip() if episode.notes else ""
    if notes:
        return f"{detail} {notes}".strip()
    return detail


def _episode_close_text(plan: ProductionPlan, episode: EpisodeDraft) -> str:
    if episode.episode_number < len(plan.episodes):
        next_episode = plan.episodes[episode.episode_number]
        return (
            f"Do la diem chot cua tap nay. O tap tiep theo, chung ta se di tiep vao "
            f"{next_episode.title.strip().lower()}."
        )
    return "Do la buc tranh day du cua chu de hom nay. Hen gap lai trong series nay."


def _render_episode_script(turns: tuple[ScriptTurn, ...]) -> str:
    return "\n".join(
        f"{turn.speaker}: {turn.text.strip()}"
        for turn in turns
        if turn.speaker.strip() and turn.text.strip()
    )


def _build_tts_prompt(turns: tuple[ScriptTurn, ...]) -> str:
    return TTS_PROMPT_INTRO + "\n".join(_format_tts_turn_line(turn) for turn in turns)


def _build_tts_prompt_chunks(turns: tuple[ScriptTurn, ...]) -> tuple[str, ...]:
    normalized_turns = tuple(
        ScriptTurn(
            speaker=turn.speaker.strip(),
            text=re.sub(r"\s+", " ", turn.text).strip(),
            emotion=(turn.emotion or "").strip() or None,
            direction=(turn.direction or "").strip() or None,
        )
        for turn in turns
        if turn.speaker.strip() and turn.text.strip()
    )
    if not normalized_turns:
        return (TTS_PROMPT_INTRO.strip(),)

    chunks: list[str] = []
    current_lines: list[str] = []
    current_body_length = 0
    for turn in normalized_turns:
        for turn_piece in _split_turn_for_tts_chunks(turn):
            line = _format_tts_turn_line(turn_piece)
            line_length = len(line)
            if line_length + len(TTS_PROMPT_INTRO) > MAX_TTS_PROMPT_CHARACTERS:
                raise RuntimeError("tts prompt line exceeds maximum character limit")
            separator_length = 1 if current_lines else 0
            if current_body_length + separator_length + line_length > (MAX_TTS_PROMPT_CHARACTERS - len(TTS_PROMPT_INTRO)):
                chunks.append(TTS_PROMPT_INTRO + "\n".join(current_lines))
                current_lines = [line]
                current_body_length = line_length
                continue
            current_lines.append(line)
            current_body_length += separator_length + line_length

    if current_lines:
        chunks.append(TTS_PROMPT_INTRO + "\n".join(current_lines))
    return tuple(chunks)


def _split_turn_for_tts_chunks(turn: ScriptTurn) -> tuple[ScriptTurn, ...]:
    prefix_length = len(_format_tts_turn_line(turn, text_override=""))
    max_text_length = MAX_TTS_PROMPT_CHARACTERS - len(TTS_PROMPT_INTRO) - prefix_length
    if max_text_length <= 0:
        raise RuntimeError("tts prompt overhead exceeds maximum character limit")

    normalized_text = re.sub(r"\s+", " ", turn.text).strip()
    if len(normalized_text) <= max_text_length:
        return (ScriptTurn(turn.speaker, normalized_text, turn.emotion, turn.direction),)

    pieces: list[str] = []
    for sentence in _split_text_into_sentences(normalized_text):
        if len(sentence) <= max_text_length:
            pieces.append(sentence)
            continue
        pieces.extend(_split_text_by_words(sentence, max_text_length))

    grouped_pieces: list[str] = []
    current = ""
    for piece in pieces:
        candidate = f"{current} {piece}".strip() if current else piece
        if len(candidate) <= max_text_length:
            current = candidate
            continue
        if current:
            grouped_pieces.append(current)
        current = piece
    if current:
        grouped_pieces.append(current)

    return tuple(
        ScriptTurn(
            speaker=turn.speaker,
            text=piece,
            emotion=turn.emotion,
            direction=turn.direction,
        )
        for piece in grouped_pieces
        if piece
    )


def _split_text_into_sentences(text: str) -> list[str]:
    if not text:
        return []
    normalized = text.replace("\n", " ").strip()
    sentences = [
        piece.strip()
        for piece in re.split(r"(?<=[.!?…;:])\s+", normalized)
        if piece.strip()
    ]
    return sentences or [normalized]


def _split_text_by_words(text: str, max_length: int) -> list[str]:
    words = [word for word in text.split(" ") if word]
    if not words:
        return []
    pieces: list[str] = []
    current = ""
    for word in words:
        if len(word) > max_length:
            if current:
                pieces.append(current)
                current = ""
            for start in range(0, len(word), max_length):
                pieces.append(word[start : start + max_length])
            continue
        candidate = f"{current} {word}".strip() if current else word
        if len(candidate) <= max_length:
            current = candidate
            continue
        if current:
            pieces.append(current)
        current = word
    if current:
        pieces.append(current)
    return pieces


def _format_tts_turn_line(turn: ScriptTurn, *, text_override: str | None = None) -> str:
    tags = [
        value.strip()
        for value in (turn.emotion or "", turn.direction or "")
        if value.strip()
    ]
    prefix = f"[{', '.join(tags)}] " if tags else ""
    text = turn.text.strip() if text_override is None else text_override
    return f"{prefix}{turn.speaker}: {text}"


def _build_speech_config(
    *,
    plan: ProductionPlan,
    hosts: tuple[AIHostDraft, ...],
    voice_profiles: list[VoiceProfile],
) -> types.SpeechConfig:
    language_code = _speech_language_code(plan.target_language_code)
    speaker_voices = _resolve_speaker_voices(hosts, voice_profiles)
    if len(speaker_voices) <= 1:
        voice_name = speaker_voices[0][1] if speaker_voices else "Kore"
        return types.SpeechConfig(
            language_code=language_code,
            voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(
                    voice_name=voice_name,
                )
            ),
        )

    return types.SpeechConfig(
        language_code=language_code,
        multi_speaker_voice_config=types.MultiSpeakerVoiceConfig(
            speaker_voice_configs=[
                types.SpeakerVoiceConfig(
                    speaker=speaker,
                    voice_config=types.VoiceConfig(
                        prebuilt_voice_config=types.PrebuiltVoiceConfig(
                            voice_name=voice_name,
                        )
                    ),
                )
                for speaker, voice_name in speaker_voices
            ]
        ),
    )


def _resolve_speaker_voices(
    hosts: tuple[AIHostDraft, ...],
    voice_profiles: list[VoiceProfile],
) -> list[tuple[str, str]]:
    used: set[str] = set()
    resolved: list[tuple[str, str]] = []
    for index, host in enumerate(hosts):
        speaker = host.display_name.strip()
        if not speaker:
            continue
        voice_name = _resolve_voice_name(host, voice_profiles)
        unique_voice = _ensure_unique_voice_name(voice_name, used, index)
        used.add(unique_voice)
        resolved.append((speaker, unique_voice))
    return resolved


def _ensure_unique_voice_name(voice_name: str, used: set[str], index: int) -> str:
    if voice_name not in used:
        return voice_name
    for fallback in _TTS_FALLBACK_VOICES:
        if fallback not in used:
            return fallback
    return _TTS_FALLBACK_VOICES[index % len(_TTS_FALLBACK_VOICES)]


def _build_episode_segments(
    *,
    show: ShowCreationSession,
    plan: ProductionPlan,
    artifact: EpisodeArtifact,
) -> list[dict[str, Any]]:
    turns = list(artifact.turns)
    if not turns:
        turns = [
            ScriptTurn(
                speaker=show.primary_host_name or "AI host",
                text=artifact.script_text,
            )
        ]

    host_ids_by_name: dict[str, str] = {}
    for index, host in enumerate(plan.show_draft.hosts):
        if index >= len(show.inserted_host_ids):
            break
        display_name = host.display_name.strip()
        if display_name:
            host_ids_by_name[display_name] = show.inserted_host_ids[index]

    total_ms = max(1, artifact.duration_seconds * 1000)
    weights = [_turn_weight(turn.text) for turn in turns]
    total_weight = sum(weights) or len(turns)
    segments: list[dict[str, Any]] = []
    start_ms = 0
    cumulative_weight = 0
    for index, turn in enumerate(turns):
        cumulative_weight += weights[index]
        end_ms = total_ms
        if index < len(turns) - 1:
            end_ms = max(
                start_ms + 1,
                min(total_ms - (len(turns) - index - 1), round(total_ms * cumulative_weight / total_weight)),
            )
        segments.append(
            {
                "show_host_id": host_ids_by_name.get(turn.speaker.strip())
                or (show.inserted_host_ids[0] if show.inserted_host_ids else None),
                "segment_index": index,
                "speaker_label": turn.speaker.strip() or show.primary_host_name or "AI host",
                "start_ms": start_ms,
                "end_ms": end_ms,
                "text_content": turn.text.strip() or artifact.script_text,
            }
        )
        start_ms = end_ms
    return segments


def _turn_weight(text: str) -> int:
    words = re.findall(r"\w+", text, flags=re.UNICODE)
    return max(1, len(words))


def _resolve_voice_name(
    primary_host: AIHostDraft | None,
    voice_profiles: list[VoiceProfile],
) -> str:
    if primary_host is not None and primary_host.voice_profile_id:
        for voice in voice_profiles:
            if str(voice.id) != str(primary_host.voice_profile_id):
                continue
            metadata = voice.metadata or {}
            configured = metadata.get("tts_voice_name")
            if isinstance(configured, str) and configured.strip():
                return configured.strip()
            provider_voice_id = voice.provider_voice_id.strip().lower()
            if provider_voice_id == "gemini-atlas-vi-001":
                return "Puck"
            if provider_voice_id == "gemini-minh-tra-vi-001":
                return "Charon"
            if provider_voice_id == "gemini-lumi-vi-001":
                return "Sulafat"
            return "Kore"
    return "Kore"


def _speech_language_code(language_code: str) -> str:
    normalized = language_code.strip().lower()
    if normalized == "vi":
        return "vi-VN"
    return language_code.strip() or "vi-VN"


def _pcm16_to_wav(
    pcm_bytes: bytes,
    *,
    sample_rate: int = 24000,
    channels: int = 1,
    sample_width: int = 2,
) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav_file:
        wav_file.setnchannels(channels)
        wav_file.setsampwidth(sample_width)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(pcm_bytes)
    return buffer.getvalue()


def _extract_audio_bytes(response: Any) -> bytes:
    direct_bytes = getattr(response, "data", None)
    if isinstance(direct_bytes, bytes) and direct_bytes:
        return direct_bytes

    candidates = getattr(response, "candidates", None) or []
    for candidate in candidates:
        content = getattr(candidate, "content", None)
        parts = getattr(content, "parts", None) or []
        for part in parts:
            inline_data = getattr(part, "inline_data", None)
            data = getattr(inline_data, "data", None)
            if isinstance(data, bytes) and data:
                return data

    return b""


def _resolve_category(conn: Any, value: str) -> tuple[str, str]:
    normalized_value = value.strip()
    candidates = [
        normalized_value,
        _slugify(normalized_value),
    ]
    alias_slug = _CATEGORY_SLUG_ALIASES.get(normalized_value.strip().lower())
    if alias_slug:
        candidates.append(alias_slug)

    seen: set[str] = set()
    for candidate in candidates:
        candidate_value = candidate.strip()
        if not candidate_value or candidate_value in seen:
            continue
        seen.add(candidate_value)
        row = conn.execute(
            """
            SELECT id::text, name
            FROM categories
            WHERE is_active = true
              AND applies_to IN ('show', 'mixed')
              AND (slug = %s OR lower(name) = lower(%s))
            ORDER BY sort_order ASC, name ASC
            LIMIT 1
            """,
            (candidate_value, candidate_value),
        ).fetchone()
        if row is not None:
            return row["name"], row["id"]

    raise ValueError("primary category was not found")


def _ensure_unique_show_slug(conn: Any, base_slug: str) -> str:
    slug = base_slug or "show"
    suffix = 2
    while True:
        row = conn.execute(
            "SELECT EXISTS(SELECT 1 FROM shows WHERE slug = %s)",
            (slug,),
        ).fetchone()
        if row is None or not row["exists"]:
            return slug
        slug = f"{base_slug}-{suffix}"
        suffix += 1


def _ensure_unique_episode_slug(conn: Any, show_id: str, base_slug: str) -> str:
    slug = base_slug or "episode"
    suffix = 2
    while True:
        row = conn.execute(
            """
            SELECT EXISTS(
              SELECT 1
              FROM episodes
              WHERE show_id = %s::uuid AND slug = %s
            )
            """,
            (show_id, slug),
        ).fetchone()
        if row is None or not row["exists"]:
            return slug
        slug = f"{base_slug}-{suffix}"
        suffix += 1


def _normalize_hosts(
    *,
    content_type: str,
    hosts: list[AIHostDraft],
    slug: str,
) -> list[AIHostDraft]:
    if not hosts:
        raise ValueError("at least one host is required")
    if content_type == "storytelling" and len(hosts) != 1:
        raise ValueError("storytelling shows require exactly one host")
    if content_type == "podcast" and len(hosts) > 3:
        raise ValueError("podcast shows support at most 3 hosts in v1")

    normalized: list[AIHostDraft] = []
    for index, host in enumerate(hosts):
        display_name = host.display_name.strip()
        if not display_name:
            raise ValueError("each host must have a display name")
        normalized.append(
            AIHostDraft(
                display_name=display_name,
                role=_sanitize_host_role(content_type, host.role, index),
                avatar_url=(host.avatar_url or "").strip()
                or _fallback_host_avatar_url(f"{slug}-{index + 1}"),
                voice_profile_id=host.voice_profile_id,
                bio=(host.bio or host.persona_summary or "").strip(),
                persona_summary=host.persona_summary,
            )
        )
    return normalized


def _sanitize_host_role(content_type: str, role: str, index: int) -> str:
    if role in {"host", "co_host", "guest", "narrator"}:
        return role
    if content_type == "storytelling":
        return "narrator"
    if index == 0:
        return "host"
    return "co_host"


def _sanitize_content_type(value: str) -> str:
    if value in {"podcast", "storytelling", "news_digest"}:
        return value
    return "podcast"


def _sanitize_language_code(value: str) -> str:
    return value.strip() or "vi"


def _slugify(value: str) -> str:
    normalized = (
        unicodedata.normalize("NFKD", value.strip())
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )
    pieces: list[str] = []
    previous_dash = False
    for char in normalized:
        if char.isalnum():
            pieces.append(char)
            previous_dash = False
            continue
        if not previous_dash and pieces:
            pieces.append("-")
            previous_dash = True
    slug = "".join(pieces).strip("-")
    return slug or "show"


def _fallback_show_cover_url(seed: str) -> str:
    return f"https://picsum.photos/seed/show-{seed}/800/800"


def _fallback_host_avatar_url(seed: str) -> str:
    return f"https://picsum.photos/seed/host-{seed}/200/200"


def _fallback_owner_avatar_url(seed: str) -> str:
    return f"https://picsum.photos/seed/owner-{seed}/200/200"


def _fallback_owner_display_name(email: str) -> str:
    normalized = email.strip().lower()
    if not normalized:
        return "Creator"
    if "@" in normalized:
        return normalized.split("@", 1)[0]
    return normalized


_TTS_FALLBACK_VOICES = (
    "Kore",
    "Puck",
    "Charon",
    "Sulafat",
    "Zephyr",
    "Fenrir",
    "Aoede",
)


_CATEGORY_SLUG_ALIASES = {
    "technology": "cong-nghe",
    "tech": "cong-nghe",
    "business": "cong-nghe",
    "investigation": "dieu-tra",
    "self care": "cham-soc-ban-than",
    "self-care": "cham-soc-ban-than",
    "explainer": "giai-thich-de-hieu",
    "explainers": "giai-thich-de-hieu",
    "storytelling": "chuyen-ke",
    "stories": "chuyen-ke",
    "parable": "ngu-ngon",
    "parables": "ngu-ngon",
}
