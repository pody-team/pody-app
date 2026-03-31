from __future__ import annotations

import logging
import time
import threading
from collections.abc import Callable, Iterator
from dataclasses import dataclass
from queue import Empty, Queue
from typing import Any
from uuid import UUID

from .models import (
    AddThreadMessageRequest,
    AuthContext,
    ChatTurnResult,
    ProductionPlanSummary,
    ChatThreadSummary,
    ChatThreadView,
    CreateThreadRequest,
    GeneratePlanRequest,
    GenerationJob,
    VoiceProfile,
)
from .dialogue_agent import DialogueAgent
from .notifications import NotificationClient
from .planner import CreateAgent, Planner
from .repository import AIRepository
from .show_creation import ContentCreationStore, EpisodeDialogueMemory, GeminiTTSSynthesizer
from .transcript_generation import SubprocessTranscriptGenerator

logger = logging.getLogger(__name__)


class AIService:
    def __init__(
        self,
        repository: AIRepository,
        create_agent: CreateAgent,
        planner: Planner,
        provider_name: str,
        show_creation_store: ContentCreationStore | None = None,
        speech_synthesizer: GeminiTTSSynthesizer | None = None,
        dialogue_agent: DialogueAgent | None = None,
        transcript_generator: SubprocessTranscriptGenerator | None = None,
        notification_client: NotificationClient | None = None,
    ) -> None:
        self._repository = repository
        self._create_agent = create_agent
        self._planner = planner
        self._provider_name = provider_name
        self._show_creation_store = show_creation_store
        self._speech_synthesizer = speech_synthesizer
        self._dialogue_agent = dialogue_agent
        self._transcript_generator = transcript_generator
        self._notification_client = notification_client
        self._show_creation_queue: Queue[UUID | None] = Queue()
        self._transcript_queue: Queue[UUID | None] = Queue()
        self._show_creation_stop = threading.Event()
        self._show_creation_thread: threading.Thread | None = None
        self._transcript_thread: threading.Thread | None = None

    def list_voice_profiles(self) -> list[VoiceProfile]:
        return self._repository.list_voice_profiles()

    def create_thread(self, auth: AuthContext, request: CreateThreadRequest) -> ChatThreadView:
        voices = self._repository.list_voice_profiles()
        turn = self._build_turn_result(
            prompt=request.prompt,
            requested_episode_count=_normalize_requested_episode_count(request.episode_count),
            voice_profiles=voices,
            conversation=[],
            existing_thread=None,
        )
        return self._repository.create_thread(auth, request.prompt, turn)

    def list_threads(self, auth: AuthContext, limit: int = 30) -> list[ChatThreadSummary]:
        return self._repository.list_threads(auth.user_id, limit)

    def list_drafts(self, auth: AuthContext, limit: int = 50) -> list[ProductionPlanSummary]:
        return self._repository.list_drafts(auth.user_id, limit)

    def stream_create_thread(
        self,
        auth: AuthContext,
        request: CreateThreadRequest,
    ) -> Iterator[dict[str, Any]]:
        voices = self._repository.list_voice_profiles()
        yield from self._stream_turn_with_live_events(
            build_turn=lambda emit_event: self._build_turn_result(
                prompt=request.prompt,
                requested_episode_count=_normalize_requested_episode_count(request.episode_count),
                voice_profiles=voices,
                conversation=[],
                existing_thread=None,
                emit_event=emit_event,
            ),
            persist_thread=lambda turn: self._repository.create_thread(auth, request.prompt, turn),
        )

    def get_thread(self, auth: AuthContext, thread_id: UUID) -> ChatThreadView:
        return self._repository.get_thread(auth.user_id, thread_id)

    def get_draft(self, auth: AuthContext, plan_id: UUID):
        return self._repository.get_draft(auth.user_id, plan_id)

    def add_thread_message(self, auth: AuthContext, thread_id: UUID, request: AddThreadMessageRequest) -> ChatThreadView:
        existing_thread = self._repository.get_thread(auth.user_id, thread_id)
        conversation = [f"{message.role}: {message.text_content}" for message in existing_thread.messages]
        voices = self._repository.list_voice_profiles()
        turn = self._build_turn_result(
            prompt=request.message,
            requested_episode_count=_normalize_requested_episode_count(request.episode_count),
            voice_profiles=voices,
            conversation=conversation,
            existing_thread=existing_thread,
        )
        return self._repository.add_thread_message(auth, thread_id, request.message, turn)

    def stream_add_thread_message(
        self,
        auth: AuthContext,
        thread_id: UUID,
        request: AddThreadMessageRequest,
    ) -> Iterator[dict[str, Any]]:
        existing_thread = self._repository.get_thread(auth.user_id, thread_id)
        conversation = [
            f"{message.role}: {message.text_content}" for message in existing_thread.messages
        ]
        voices = self._repository.list_voice_profiles()
        yield from self._stream_turn_with_live_events(
            build_turn=lambda emit_event: self._build_turn_result(
                prompt=request.message,
                requested_episode_count=_normalize_requested_episode_count(request.episode_count),
                voice_profiles=voices,
                conversation=conversation,
                existing_thread=existing_thread,
                emit_event=emit_event,
            ),
            persist_thread=lambda turn: self._repository.add_thread_message(
                auth,
                thread_id,
                request.message,
                turn,
            ),
        )

    def generate_episode_plan(self, auth: AuthContext, request: GeneratePlanRequest):
        voices = self._repository.list_voice_profiles()
        output = self._planner.generate(
            prompt=request.prompt,
            requested_episode_count=_normalize_requested_episode_count(request.episode_count),
            voice_profiles=voices,
            conversation=[],
            current_plan_summary=None,
        )
        return self._repository.generate_episode_plan(auth, request, output, self._provider_name)

    def get_job(self, auth: AuthContext, job_id: UUID) -> GenerationJob:
        return self._repository.get_job(auth.user_id, job_id)

    def create_show_from_plan(self, auth: AuthContext, plan_id: UUID) -> GenerationJob:
        job = self._repository.queue_show_creation(
            auth,
            plan_id,
            self._provider_name,
        )
        self._show_creation_queue.put(job.id)
        return job

    def start_background_workers(self) -> None:
        show_creation_alive = self._show_creation_thread is not None and self._show_creation_thread.is_alive()
        transcript_alive = self._transcript_thread is not None and self._transcript_thread.is_alive()
        if show_creation_alive and transcript_alive:
            return

        self._show_creation_stop.clear()
        for job_id in self._repository.list_pending_show_creation_job_ids():
            self._show_creation_queue.put(job_id)
        for job_id in self._repository.list_pending_transcript_job_ids():
            self._transcript_queue.put(job_id)

        if not show_creation_alive:
            self._show_creation_thread = threading.Thread(
                target=self._run_show_creation_worker,
                name="show-creation-worker",
                daemon=True,
            )
            self._show_creation_thread.start()
        if not transcript_alive:
            self._transcript_thread = threading.Thread(
                target=self._run_transcript_worker,
                name="transcript-worker",
                daemon=True,
            )
            self._transcript_thread.start()

    def shutdown_background_workers(self) -> None:
        self._show_creation_stop.set()
        self._show_creation_queue.put(None)
        self._transcript_queue.put(None)
        if self._show_creation_thread is not None:
            self._show_creation_thread.join(timeout=1)
            self._show_creation_thread = None
        if self._transcript_thread is not None:
            self._transcript_thread.join(timeout=1)
            self._transcript_thread = None

    def _stream_thread_result(self, thread: ChatThreadView) -> Iterator[dict[str, Any]]:
        assistant_message = next(
            (message for message in reversed(thread.messages) if message.role == "assistant"),
            None,
        )
        if assistant_message is not None:
            for chunk in _chunk_text(assistant_message.text_content):
                yield _stream_event("assistant_delta", {"text": chunk})
                time.sleep(0.02)

        yield _stream_event("thread", {"thread": thread.model_dump(mode="json")})
        yield _stream_event("done", {"thread_id": str(thread.id)})

    def _stream_turn_with_live_events(
        self,
        *,
        build_turn: Callable[[Callable[[dict[str, Any]], None]], ChatTurnResult],
        persist_thread: Callable[[ChatTurnResult], ChatThreadView],
    ) -> Iterator[dict[str, Any]]:
        for event in _build_status_events():
            yield event

        queue: Queue[object] = Queue()
        sentinel = object()
        turn_result: ChatTurnResult | None = None

        def worker() -> None:
            try:
                turn = build_turn(queue.put)
            except Exception as exc:
                queue.put(_QueuedStreamError(exc))
            else:
                queue.put(_QueuedTurnResult(turn))
            finally:
                queue.put(sentinel)

        worker_thread = threading.Thread(target=worker, daemon=True)
        worker_thread.start()

        try:
            while True:
                item = queue.get()
                if item is sentinel:
                    break
                if isinstance(item, dict):
                    yield item
                    continue
                if isinstance(item, _QueuedTurnResult):
                    turn_result = item.turn
                    continue
                if isinstance(item, _QueuedStreamError):
                    raise item.error

            if turn_result is None:
                raise RuntimeError("create agent finished without a turn result")

            thread = persist_thread(turn_result)
            yield from self._stream_thread_result(thread)
        finally:
            worker_thread.join(timeout=0.1)

    def _build_turn_result(
        self,
        *,
        prompt: str,
        requested_episode_count: int | None,
        voice_profiles: list[VoiceProfile],
        conversation: list[str],
        existing_thread: ChatThreadView | None,
        emit_event: Any | None = None,
    ) -> ChatTurnResult:
        current_plan = existing_thread.current_plan if existing_thread is not None else None
        return self._create_agent.respond(
            prompt=prompt,
            requested_episode_count=requested_episode_count,
            voice_profiles=voice_profiles,
            conversation=conversation,
            current_thread_title=existing_thread.title if existing_thread is not None else None,
            current_plan=current_plan,
            emit_event=emit_event,
        )

    def _run_show_creation_worker(self) -> None:
        while not self._show_creation_stop.is_set():
            try:
                job_id = self._show_creation_queue.get(timeout=0.5)
            except Empty:
                continue

            if job_id is None:
                self._show_creation_queue.task_done()
                break

            try:
                self._process_show_creation_job(job_id)
            except Exception:
                logger.exception("show creation worker crashed", extra={"job_id": str(job_id)})
            finally:
                self._show_creation_queue.task_done()

    def _run_transcript_worker(self) -> None:
        while not self._show_creation_stop.is_set():
            try:
                job_id = self._transcript_queue.get(timeout=0.5)
            except Empty:
                continue

            if job_id is None:
                self._transcript_queue.task_done()
                break

            try:
                self._process_transcript_job(job_id)
            except Exception:
                logger.exception("transcript worker crashed", extra={"job_id": str(job_id)})
            finally:
                self._transcript_queue.task_done()

    def _process_show_creation_job(self, job_id: UUID) -> None:
        job_context = self._repository.start_show_creation_job(job_id)
        if job_context is None:
            return

        if (
            self._show_creation_store is None
            or not getattr(self._show_creation_store, "enabled", True)
            or self._speech_synthesizer is None
            or not self._speech_synthesizer.enabled
        ):
            self._repository.fail_show_creation_job(job_id, "show creation worker is not configured")
            return

        try:
            voice_profiles = self._repository.list_voice_profiles()
            primary_host = job_context.plan.show_draft.primary_host
            dialogue_history: dict[int, EpisodeDialogueMemory] = {}
            if self._show_creation_store is not None:
                for memory in self._show_creation_store.list_plan_episode_dialogues(job_context.plan.id):
                    if memory.episode_number >= 1:
                        dialogue_history[memory.episode_number] = memory
            created_show = self._show_creation_store.create_show_shell(
                owner_user_id=job_context.owner_user_id,
                owner_display_name=job_context.owner_name,
                owner_email=job_context.owner_email,
                plan=job_context.plan,
            )
            completed_episode_count = 0
            for episode in job_context.plan.episodes:
                previous_dialogues = [
                    dialogue_history[number]
                    for number in sorted(dialogue_history)
                    if number < episode.episode_number
                ]
                dialogue_turns = (
                    self._dialogue_agent.generate_dialogue(
                        plan=job_context.plan,
                        episode=episode,
                        voice_profiles=voice_profiles,
                        previous_dialogues=previous_dialogues,
                    )
                    if self._dialogue_agent is not None
                    else None
                )
                artifact = self._speech_synthesizer.synthesize_episode(
                    plan=job_context.plan,
                    episode=episode,
                    primary_host=primary_host,
                    voice_profiles=voice_profiles,
                    dialogue_turns=dialogue_turns,
                )
                dialogue_history[episode.episode_number] = EpisodeDialogueMemory(
                    episode_number=episode.episode_number,
                    title=episode.title,
                    description=episode.description,
                    turns=artifact.turns,
                )
                created_episode = self._show_creation_store.create_episode_from_plan(
                    show=created_show,
                    plan=job_context.plan,
                    episode=episode,
                    artifact=artifact,
                )
                completed_episode_count += 1
                if self._notification_client is not None:
                    try:
                        self._notification_client.send_episode_created(
                            user_id=str(job_context.owner_user_id),
                            show_id=created_show.show_id,
                            show_title=created_show.show_title,
                            episode_id=created_episode.episode_id,
                            episode_title=created_episode.episode_title,
                            episode_number=created_episode.episode_number,
                        )
                    except Exception:
                        logger.exception(
                            "episode created but app notification failed",
                            extra={
                                "job_id": str(job_id),
                                "show_id": created_show.show_id,
                                "episode_id": created_episode.episode_id,
                                "owner_user_id": str(job_context.owner_user_id),
                            },
                        )
                transcript_job = self._repository.queue_transcript_generation(
                    plan_id=job_context.plan.id,
                    episode_number=created_episode.episode_number,
                    content_episode_id=created_episode.episode_id,
                    language_code=job_context.plan.target_language_code,
                    provider=self._provider_name,
                )
                self._transcript_queue.put(transcript_job.id)
            self._repository.complete_show_creation_job(
                job_id,
                created_show.show_id,
                completed_episode_count,
            )
            if self._notification_client is not None:
                try:
                    self._notification_client.send_show_created(
                        user_id=str(job_context.owner_user_id),
                        show_id=created_show.show_id,
                        show_title=created_show.show_title,
                        episode_count=completed_episode_count,
                    )
                except Exception:
                    logger.exception(
                        "show created but app notification failed",
                        extra={
                            "job_id": str(job_id),
                            "show_id": created_show.show_id,
                            "owner_user_id": str(job_context.owner_user_id),
                        },
                    )
        except Exception as exc:
            self._repository.fail_show_creation_job(job_id, str(exc))
            raise

    def _process_transcript_job(self, job_id: UUID) -> None:
        job_context = self._repository.start_transcript_job(job_id)
        if job_context is None:
            return

        if (
            self._show_creation_store is None
            or self._transcript_generator is None
            or not self._transcript_generator.enabled
        ):
            error_message = "transcript worker is not configured"
            if self._show_creation_store is not None:
                self._show_creation_store.mark_episode_transcript_failed(
                    episode_id=job_context.content_episode_id,
                    error_message=error_message,
                )
            self._repository.fail_transcript_job(job_id, error_message)
            return

        try:
            source = self._show_creation_store.get_episode_transcript_source(
                episode_id=job_context.content_episode_id,
                language_code=job_context.language_code,
            )
            artifact = self._transcript_generator.generate_transcript(source)
            self._show_creation_store.save_episode_transcript(
                episode_id=job_context.content_episode_id,
                artifact=artifact,
            )
            self._repository.complete_transcript_job(
                job_id,
                content_episode_id=job_context.content_episode_id,
                segment_count=len(artifact.segments),
                alignment_method=artifact.alignment_method,
            )
        except Exception as exc:
            self._show_creation_store.mark_episode_transcript_failed(
                episode_id=job_context.content_episode_id,
                error_message=str(exc),
            )
            self._repository.fail_transcript_job(job_id, str(exc))
            raise


def _normalize_requested_episode_count(value: int | None) -> int | None:
    if value is None:
        return None
    return max(1, value)


def _stream_event(event: str, data: dict[str, Any]) -> dict[str, Any]:
    return {"event": event, "data": data}


@dataclass(frozen=True)
class _QueuedTurnResult:
    turn: ChatTurnResult


@dataclass(frozen=True)
class _QueuedStreamError:
    error: Exception


def _chunk_text(text: str, chunk_size: int = 22) -> list[str]:
    normalized = (text or "").strip()
    if not normalized:
        return []

    words = normalized.split()
    chunks: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        if len(candidate) <= chunk_size:
            current = candidate
            continue
        if current:
            chunks.append(f"{current} ")
        current = word

    if current:
        chunks.append(current)

    return chunks


def _build_status_events() -> list[dict[str, Any]]:
    return [
        _stream_event(
            "status",
            {"phase": "thinking", "message": "Đang suy nghĩ..."},
        ),
    ]
