from __future__ import annotations

from datetime import datetime, timezone
from queue import Queue
import threading
from uuid import UUID, uuid4

from app.models import (
    AIHostDraft,
    AuthContext,
    ChatMessage,
    ProductionPlanSummary,
    ChatThreadSummary,
    ChatTurnResult,
    ChatThreadView,
    CreateThreadRequest,
    EpisodeDraft,
    GenerationJob,
    PlannerOutput,
    ProductionPlan,
    ShowDraft,
    VoiceProfile,
)
from app.service import AIService


class FakePlanner:
    def __init__(self) -> None:
        self.calls = 0

    def generate(
        self,
        *,
        prompt: str,
        requested_episode_count: int | None,
        voice_profiles: list[VoiceProfile],
        conversation: list[str],
        current_plan_summary: str | None = None,
    ) -> PlannerOutput:
        _ = requested_episode_count
        _ = voice_profiles
        _ = conversation
        _ = current_plan_summary
        self.calls += 1
        return PlannerOutput(
            thread_title="AI Builder Lab",
            assistant_reply="Mình đã dựng xong bản draft đầu tiên.",
            series_title="AI Builder Lab",
            series_description=f"Plan for {prompt}",
            primary_category="Cong nghe",
            categories=["Cong nghe"],
            language_code="vi",
            content_type="podcast",
            tone_style="sharp",
            tags=["ai"],
            hosts=[
                AIHostDraft(
                    display_name="Nova",
                    role="host",
                    bio="AI host",
                    voice_profile_id=UUID("71000000-0000-0000-0000-000000000001"),
                )
            ],
            episodes=[
                EpisodeDraft(
                    episode_number=1,
                    title="Tap 1",
                    description="desc",
                    estimated_duration_seconds=900,
                )
            ],
        )


class FakeCreateAgent:
    def __init__(self, result: str) -> None:
        self.result = result
        self.calls = 0

    def respond(
        self,
        *,
        prompt: str,
        requested_episode_count: int | None,
        voice_profiles: list[VoiceProfile],
        conversation: list[str],
        current_thread_title: str | None,
        current_plan: ProductionPlan | None,
        emit_event=None,
    ) -> ChatTurnResult:
        _ = requested_episode_count
        _ = voice_profiles
        _ = prompt
        _ = conversation
        _ = current_thread_title
        _ = current_plan
        _ = emit_event
        self.calls += 1
        if self.result == "chat":
            return ChatTurnResult(
                thread_title="Founder format brainstorm",
                assistant_reply=f"Chat reply for: {prompt}",
                plan_output=None,
            )
        output = FakePlanner().generate(
            prompt=prompt,
            requested_episode_count=requested_episode_count,
            voice_profiles=voice_profiles,
            conversation=conversation,
            current_plan_summary=None,
        )
        if emit_event is not None:
            emit_event(
                {
                    "event": "plan_updated",
                    "data": {
                        "plan": {
                            "series_title": output.series_title,
                        }
                    },
                }
            )
        return ChatTurnResult(
            thread_title="AI Builder Lab",
            assistant_reply="Mình đã dựng xong bản draft đầu tiên.",
            plan_output=output,
        )


class BlockingToolCreateAgent:
    def __init__(self) -> None:
        self.calls = 0
        self.tool_emitted = threading.Event()
        self.release = threading.Event()

    def respond(
        self,
        *,
        prompt: str,
        requested_episode_count: int | None,
        voice_profiles: list[VoiceProfile],
        conversation: list[str],
        current_thread_title: str | None,
        current_plan: ProductionPlan | None,
        emit_event=None,
    ) -> ChatTurnResult:
        _ = prompt
        _ = requested_episode_count
        _ = voice_profiles
        _ = conversation
        _ = current_thread_title
        _ = current_plan
        self.calls += 1

        if emit_event is not None:
            emit_event(
                {
                    "event": "status",
                    "data": {
                        "phase": "tool",
                        "tool": "brave_search",
                        "message": "Đang tìm kiếm thông tin liên quan...",
                    },
                }
            )
            self.tool_emitted.set()
            if not self.release.wait(timeout=2):
                raise TimeoutError("timed out waiting to finish create agent")

        return ChatTurnResult(
            thread_title="Founder format brainstorm",
            assistant_reply="Chat reply for: founder format",
            plan_output=None,
        )


class FakeRepository:
    def __init__(self) -> None:
        self.voice_profiles = [_voice_profile()]
        self.threads: dict[UUID, ChatThreadView] = {}
        self.jobs: dict[UUID, GenerationJob] = {}
        self.failed_jobs: dict[UUID, str] = {}

    def list_voice_profiles(self) -> list[VoiceProfile]:
        return self.voice_profiles

    def create_thread(self, auth: AuthContext, prompt: str, turn) -> ChatThreadView:
        _ = auth
        now = datetime.now(timezone.utc)
        thread_id = uuid4()
        thread = ChatThreadView(
            id=thread_id,
            title=turn.thread_title,
            status="active",
            created_at=now,
            updated_at=now,
            messages=[
                ChatMessage(id=uuid4(), role="user", text_content=prompt, created_at=now),
                ChatMessage(
                    id=uuid4(),
                    role="assistant",
                    text_content=turn.assistant_reply,
                    created_at=now,
                ),
            ],
            current_plan=_build_plan(thread_id, turn.plan_output) if turn.plan_output else None,
        )
        self.threads[thread_id] = thread
        return thread

    def get_thread(self, owner_user_id: UUID, thread_id: UUID) -> ChatThreadView:
        _ = owner_user_id
        return self.threads[thread_id]

    def list_threads(self, owner_user_id: UUID, limit: int = 30) -> list[ChatThreadSummary]:
        _ = owner_user_id
        threads = sorted(
            self.threads.values(),
            key=lambda thread: thread.updated_at,
            reverse=True,
        )[:limit]
        return [
            ChatThreadSummary(
                id=thread.id,
                title=thread.title,
                status=thread.status,
                created_at=thread.created_at,
                updated_at=thread.updated_at,
                last_message_preview=thread.messages[-1].text_content if thread.messages else None,
                has_current_plan=thread.current_plan is not None,
            )
            for thread in threads
        ]

    def list_drafts(self, owner_user_id: UUID, limit: int = 50) -> list[ProductionPlanSummary]:
        _ = owner_user_id
        threads = sorted(
            self.threads.values(),
            key=lambda thread: thread.updated_at,
            reverse=True,
        )[:limit]
        return [
            ProductionPlanSummary(
                id=thread.current_plan.id,
                thread_id=thread.id,
                status=thread.current_plan.status,
                series_title=thread.current_plan.series_title,
                content_type=thread.current_plan.show_draft.content_type,
                episode_count=len(thread.current_plan.episodes),
                created_at=thread.current_plan.created_at,
                updated_at=thread.current_plan.updated_at,
            )
            for thread in threads
            if thread.current_plan is not None
        ]

    def get_draft(self, owner_user_id: UUID, plan_id: UUID) -> ProductionPlan:
        _ = owner_user_id
        for thread in self.threads.values():
            if thread.current_plan is not None and thread.current_plan.id == plan_id:
                return thread.current_plan
        raise KeyError(plan_id)

    def add_thread_message(self, auth: AuthContext, thread_id: UUID, message: str, turn) -> ChatThreadView:
        _ = auth
        existing = self.threads[thread_id]
        now = datetime.now(timezone.utc)
        thread = ChatThreadView(
            id=existing.id,
            title=turn.thread_title,
            status=existing.status,
            created_at=existing.created_at,
            updated_at=now,
            messages=[
                *existing.messages,
                ChatMessage(id=uuid4(), role="user", text_content=message, created_at=now),
                ChatMessage(
                    id=uuid4(),
                    role="assistant",
                    text_content=turn.assistant_reply,
                    created_at=now,
                ),
            ],
            current_plan=_build_plan(existing.id, turn.plan_output)
            if turn.plan_output
            else existing.current_plan,
        )
        self.threads[thread_id] = thread
        return thread

    def queue_show_creation(self, auth: AuthContext, plan_id: UUID, provider: str) -> GenerationJob:
        _ = auth
        now = datetime.now(timezone.utc)
        job = GenerationJob(
            id=uuid4(),
            plan_id=plan_id,
            job_type="show_creation",
            status="queued",
            provider=provider,
            input_payload={},
            output_payload={},
            created_at=now,
        )
        self.jobs[job.id] = job
        return job

    def list_pending_show_creation_job_ids(self, limit: int = 100) -> list[UUID]:
        _ = limit
        return [
            job_id
            for job_id, job in self.jobs.items()
            if job.status == "queued" and job.job_type == "show_creation"
        ]

    def queue_transcript_generation(
        self,
        *,
        plan_id: UUID,
        episode_number: int,
        content_episode_id: str,
        language_code: str,
        provider: str,
    ) -> GenerationJob:
        now = datetime.now(timezone.utc)
        job = GenerationJob(
            id=uuid4(),
            plan_id=plan_id,
            job_type="transcript_generation",
            status="queued",
            provider=provider,
            input_payload={
                "content_episode_id": content_episode_id,
                "episode_number": episode_number,
                "language_code": language_code,
            },
            output_payload={},
            created_at=now,
        )
        self.jobs[job.id] = job
        return job

    def list_pending_transcript_job_ids(self, limit: int = 100) -> list[UUID]:
        _ = limit
        return [
            job_id
            for job_id, job in self.jobs.items()
            if job.status == "queued" and job.job_type == "transcript_generation"
        ]

    def start_show_creation_job(self, job_id: UUID):
        from app.repository import ShowCreationJobContext

        job = self.jobs[job_id]
        if job.status != "queued":
            return None
        running = job.model_copy(
            update={"status": "running", "started_at": datetime.now(timezone.utc)}
        )
        self.jobs[job_id] = running
        for thread in self.threads.values():
            if thread.current_plan is not None and thread.current_plan.id == job.plan_id:
                return ShowCreationJobContext(
                    job=running,
                    plan=thread.current_plan,
                    owner_user_id=_auth().user_id,
                    owner_email="creator@pody.vn",
                    owner_name="Creator",
                )
        raise KeyError(job.plan_id)

    def complete_show_creation_job(self, job_id: UUID, show_id: str, episode_count: int) -> None:
        current = self.jobs[job_id]
        self.jobs[job_id] = current.model_copy(
            update={
                "status": "completed",
                "finished_at": datetime.now(timezone.utc),
                "output_payload": {
                    "show_id": show_id,
                    "episode_count": episode_count,
                },
            }
        )

    def fail_show_creation_job(self, job_id: UUID, error_message: str) -> None:
        current = self.jobs[job_id]
        self.jobs[job_id] = current.model_copy(
            update={
                "status": "failed",
                "error_message": error_message,
                "finished_at": datetime.now(timezone.utc),
            }
        )
        self.failed_jobs[job_id] = error_message

    def get_job(self, owner_user_id: UUID, job_id: UUID) -> GenerationJob:
        _ = owner_user_id
        return self.jobs[job_id]

    def start_transcript_job(self, job_id: UUID):
        from app.repository import TranscriptJobContext

        job = self.jobs[job_id]
        if job.status != "queued":
            return None
        running = job.model_copy(
            update={"status": "running", "started_at": datetime.now(timezone.utc)}
        )
        self.jobs[job_id] = running
        return TranscriptJobContext(
            job=running,
            plan_id=running.plan_id,
            content_episode_id=running.input_payload["content_episode_id"],
            episode_number=running.input_payload["episode_number"],
            language_code=running.input_payload["language_code"],
        )

    def complete_transcript_job(self, job_id: UUID, *, content_episode_id: str, segment_count: int, alignment_method: str) -> None:
        current = self.jobs[job_id]
        self.jobs[job_id] = current.model_copy(
            update={
                "status": "completed",
                "finished_at": datetime.now(timezone.utc),
                "output_payload": {
                    "content_episode_id": content_episode_id,
                    "segment_count": segment_count,
                    "alignment_method": alignment_method,
                },
            }
        )

    def fail_transcript_job(self, job_id: UUID, error_message: str) -> None:
        current = self.jobs[job_id]
        self.jobs[job_id] = current.model_copy(
            update={
                "status": "failed",
                "error_message": error_message,
                "finished_at": datetime.now(timezone.utc),
            }
        )
        self.failed_jobs[job_id] = error_message


class FakeSpeechSynthesizer:
    enabled = True

    def __init__(self) -> None:
        self.dialogue_inputs: list[tuple[object, ...] | None] = []

    def synthesize_episode(self, *, plan, episode, primary_host, voice_profiles, dialogue_turns=None):
        _ = plan
        _ = primary_host
        _ = voice_profiles
        from app.show_creation import EpisodeArtifact

        self.dialogue_inputs.append(dialogue_turns)
        return EpisodeArtifact(
            audio_bytes=b"RIFF....fake-wav",
            duration_seconds=max(1, episode.estimated_duration_seconds),
            script_text=episode.description,
            turns=tuple(dialogue_turns or ()),
        )


class FakeDialogueAgent:
    def __init__(self) -> None:
        self.calls: list[dict[str, object]] = []

    def generate_dialogue(
        self,
        *,
        plan,
        episode,
        voice_profiles,
        previous_dialogues=None,
        emit_event=None,
    ):
        _ = plan
        _ = voice_profiles
        _ = emit_event
        from app.show_creation import ScriptTurn

        self.calls.append(
            {
                "episode_number": episode.episode_number,
                "previous_dialogues": list(previous_dialogues or []),
            }
        )
        return (
            ScriptTurn(speaker="Nova", text=f"{episode.title} mo dau"),
            ScriptTurn(speaker="Nova", text=episode.description),
            ScriptTurn(speaker="Nova", text=f"{episode.title} ket lai"),
        )


class FakeShowCreationStore:
    def __init__(self) -> None:
        self.calls = 0
        self.enabled = True
        self.created_episodes: list[dict[str, object]] = []
        self.persisted_dialogues: list[object] = []
        self.saved_transcripts: list[dict[str, object]] = []
        self.failed_transcripts: list[dict[str, object]] = []

    def create_show_from_plan(self, *, owner_user_id, owner_display_name, owner_email, plan, episodes):
        _ = owner_user_id
        _ = owner_display_name
        _ = owner_email
        _ = episodes
        self.calls += 1
        from app.show_creation import CreatedShow

        return CreatedShow(
            show_id="show-created-1",
            show_title=plan.series_title,
            episode_count=len(plan.episodes),
        )

    def create_show_shell(self, *, owner_user_id, owner_display_name, owner_email, plan):
        _ = owner_user_id
        _ = owner_display_name
        _ = owner_email
        self.calls += 1
        from app.show_creation import ShowCreationSession

        return ShowCreationSession(
            show_id="show-created-1",
            show_title=plan.series_title,
            cover_image_url="https://example.com/show-cover.jpg",
            primary_host_name=plan.show_draft.hosts[0].display_name if plan.show_draft.hosts else "",
            inserted_host_ids=("host-1",),
        )

    def create_episode_from_plan(self, *, show, plan, episode, artifact):
        _ = plan
        _ = artifact
        from app.show_creation import CreatedEpisode

        created = CreatedEpisode(
            episode_id=f"{show.show_id}-episode-{episode.episode_number}",
            episode_title=episode.title,
            episode_number=episode.episode_number,
            audio_url=f"https://example.com/{show.show_id}-episode-{episode.episode_number}.wav",
            audio_storage_key=f"shows/{show.show_id}/episodes/{episode.episode_number}.wav",
        )
        self.created_episodes.append(
            {
                "show_id": show.show_id,
                "episode_id": created.episode_id,
                "episode_number": created.episode_number,
                "episode_title": created.episode_title,
            }
        )
        return created

    def list_plan_episode_dialogues(self, plan_id):
        _ = plan_id
        return list(self.persisted_dialogues)

    def get_episode_transcript_source(self, *, episode_id, language_code=None):
        _ = language_code
        from app.transcript_generation import EpisodeTranscriptSource
        from app.show_creation import ScriptTurn

        return EpisodeTranscriptSource(
            episode_id=episode_id,
            show_id="show-created-1",
            episode_slug=episode_id,
            language_code="vi",
            audio_bytes=b"RIFF....fake-wav",
            turns=(
                ScriptTurn(speaker="Nova", text="Mo dau"),
                ScriptTurn(speaker="Nova", text="Noi dung chinh"),
            ),
        )

    def save_episode_transcript(self, *, episode_id, artifact):
        self.saved_transcripts.append(
            {
                "episode_id": episode_id,
                "segment_count": len(artifact.segments),
                "alignment_method": artifact.alignment_method,
            }
        )

    def mark_episode_transcript_failed(self, *, episode_id, error_message):
        self.failed_transcripts.append(
            {
                "episode_id": episode_id,
                "error_message": error_message,
            }
        )


class FakeTranscriptGenerator:
    enabled = True

    def __init__(self, *, should_fail: bool = False) -> None:
        self.should_fail = should_fail
        self.calls: list[str] = []

    def generate_transcript(self, source):
        if self.should_fail:
            raise RuntimeError("alignment failed")
        self.calls.append(source.episode_id)
        from app.transcript_generation import TranscriptArtifact, TranscriptSegment

        return TranscriptArtifact(
            text="Nova mo dau. Nova noi dung chinh.",
            language="vi",
            duration_seconds=12.5,
            alignment_method="proportional",
            segments=(
                TranscriptSegment(
                    speaker="Nova",
                    start_seconds=0.0,
                    end_seconds=6.0,
                    text="Mo dau",
                ),
                TranscriptSegment(
                    speaker="Nova",
                    start_seconds=6.0,
                    end_seconds=12.5,
                    text="Noi dung chinh",
                ),
            ),
            raw_json='{"segments":[]}',
        )


class FakeNotificationClient:
    def __init__(self, *, should_fail: bool = False) -> None:
        self.show_sent: list[dict[str, object]] = []
        self.episode_sent: list[dict[str, object]] = []
        self.should_fail = should_fail

    def send_show_created(self, *, user_id: str, show_id: str, show_title: str, episode_count: int) -> None:
        if self.should_fail:
            raise RuntimeError("notification service unavailable")
        self.show_sent.append(
            {
                "user_id": user_id,
                "show_id": show_id,
                "show_title": show_title,
                "episode_count": episode_count,
            }
        )

    def send_episode_created(
        self,
        *,
        user_id: str,
        show_id: str,
        show_title: str,
        episode_id: str,
        episode_title: str,
        episode_number: int,
    ) -> None:
        if self.should_fail:
            raise RuntimeError("notification service unavailable")
        self.episode_sent.append(
            {
                "user_id": user_id,
                "show_id": show_id,
                "show_title": show_title,
                "episode_id": episode_id,
                "episode_title": episode_title,
                "episode_number": episode_number,
            }
        )


def _voice_profile() -> VoiceProfile:
    now = datetime.now(timezone.utc)
    return VoiceProfile(
        id=UUID("71000000-0000-0000-0000-000000000001"),
        name="Nova",
        provider="google",
        provider_voice_id="gemini-nova-vi-001",
        language_code="vi",
        gender="neutral",
        created_at=now,
        updated_at=now,
    )


def _build_plan(thread_id: UUID, output: PlannerOutput) -> ProductionPlan:
    now = datetime.now(timezone.utc)
    return ProductionPlan(
        id=uuid4(),
        thread_id=thread_id,
        status="draft",
        series_title=output.series_title,
        series_description=output.series_description,
        tone_style=output.tone_style,
        target_language_code=output.language_code,
        show_draft=ShowDraft(
            slug="ai-builder-lab",
            title=output.series_title,
            description=output.series_description,
            primary_category=output.primary_category,
            categories=output.categories,
            language_code=output.language_code,
            content_type=output.content_type,
            hosts=output.hosts,
            tags=output.tags,
        ),
        episodes=output.episodes,
        tags=output.tags,
        created_at=now,
        updated_at=now,
    )


def _auth() -> AuthContext:
    return AuthContext(user_id=uuid4(), email="creator@pody.vn")


def test_create_thread_uses_basic_chat_when_user_is_brainstorming() -> None:
    repository = FakeRepository()
    create_agent = FakeCreateAgent("chat")
    planner = FakePlanner()
    service = AIService(repository, create_agent, planner, "stub")

    thread = service.create_thread(
        _auth(),
        CreateThreadRequest(prompt="Format nao hop hon cho show danh cho founder?"),
    )

    assert create_agent.calls == 1
    assert thread.current_plan is None
    assert thread.messages[-1].text_content.startswith("Chat reply for:")


def test_create_thread_generates_plan_when_user_explicitly_asks_to_create_show() -> None:
    repository = FakeRepository()
    create_agent = FakeCreateAgent("plan")
    planner = FakePlanner()
    service = AIService(repository, create_agent, planner, "stub")

    thread = service.create_thread(
        _auth(),
        CreateThreadRequest(prompt="Tạo một podcast AI cho founder và product manager"),
    )

    assert create_agent.calls == 1
    assert thread.current_plan is not None
    assert thread.current_plan.show_draft.content_type == "podcast"


def test_list_drafts_returns_saved_plans() -> None:
    repository = FakeRepository()
    create_agent = FakeCreateAgent("plan")
    planner = FakePlanner()
    service = AIService(repository, create_agent, planner, "stub")

    thread = service.create_thread(
        _auth(),
        CreateThreadRequest(prompt="Tạo một podcast AI cho founder và product manager"),
    )

    drafts = service.list_drafts(_auth(), 20)

    assert len(drafts) == 1
    assert drafts[0].series_title == thread.current_plan.series_title
    assert drafts[0].episode_count == 1


def test_show_creation_keeps_completed_status_when_notification_send_fails() -> None:
    repository = FakeRepository()
    create_agent = FakeCreateAgent("plan")
    planner = FakePlanner()
    show_store = FakeShowCreationStore()
    notification_client = FakeNotificationClient(should_fail=True)
    service = AIService(
        repository,
        create_agent,
        planner,
        "google-genai",
        show_creation_store=show_store,
        speech_synthesizer=FakeSpeechSynthesizer(),
        notification_client=notification_client,
    )

    thread = service.create_thread(
        _auth(),
        CreateThreadRequest(prompt="Tạo một podcast AI cho founder và product manager"),
    )

    job = service.create_show_from_plan(_auth(), thread.current_plan.id)
    service._process_show_creation_job(job.id)

    assert repository.jobs[job.id].status == "completed"
    assert show_store.calls == 1
    assert notification_client.show_sent == []
    assert notification_client.episode_sent == []


def test_stream_create_thread_emits_plan_preview_before_thread() -> None:
    repository = FakeRepository()
    create_agent = FakeCreateAgent("plan")
    planner = FakePlanner()
    service = AIService(repository, create_agent, planner, "stub")

    events = list(
        service.stream_create_thread(
            _auth(),
            CreateThreadRequest(prompt="Tạo một podcast AI cho founder và product manager"),
        )
    )

    event_names = [event["event"] for event in events]
    assert "plan_updated" in event_names
    assert "thread" in event_names
    assert event_names.index("plan_updated") < event_names.index("thread")


def test_stream_create_thread_emits_tool_status_while_turn_is_still_running() -> None:
    repository = FakeRepository()
    create_agent = BlockingToolCreateAgent()
    planner = FakePlanner()
    service = AIService(repository, create_agent, planner, "stub")

    stream = service.stream_create_thread(
        _auth(),
        CreateThreadRequest(prompt="Format nao hop hon cho show danh cho founder?"),
    )

    first_event = next(stream)
    assert first_event["event"] == "status"
    assert first_event["data"]["phase"] == "thinking"

    next_event_queue: Queue[dict[str, object]] = Queue()
    error_queue: Queue[BaseException] = Queue()

    def read_next_event() -> None:
        try:
            next_event_queue.put(next(stream))
        except BaseException as exc:
            error_queue.put(exc)

    reader = threading.Thread(target=read_next_event, daemon=True)
    reader.start()

    assert create_agent.tool_emitted.wait(timeout=1)
    second_event = next_event_queue.get(timeout=1)
    assert second_event["event"] == "status"
    assert second_event["data"]["tool"] == "brave_search"

    create_agent.release.set()
    reader.join(timeout=1)

    assert error_queue.empty()
    remaining_event_names = [event["event"] for event in stream]
    assert "thread" in remaining_event_names


def test_list_threads_returns_recent_threads() -> None:
    repository = FakeRepository()
    create_agent = FakeCreateAgent("chat")
    planner = FakePlanner()
    service = AIService(repository, create_agent, planner, "stub")
    auth = _auth()

    first = service.create_thread(auth, CreateThreadRequest(prompt="Thread 1"))
    second = service.create_thread(auth, CreateThreadRequest(prompt="Thread 2"))

    summaries = service.list_threads(auth)

    assert len(summaries) >= 2
    assert summaries[0].id == second.id
    assert summaries[1].id == first.id


def test_create_show_from_plan_queues_and_worker_completes_with_notification() -> None:
    repository = FakeRepository()
    create_agent = FakeCreateAgent("plan")
    planner = FakePlanner()
    show_store = FakeShowCreationStore()
    notifier = FakeNotificationClient()
    speech = FakeSpeechSynthesizer()
    dialogue_agent = FakeDialogueAgent()
    transcript_generator = FakeTranscriptGenerator()
    service = AIService(
        repository,
        create_agent,
        planner,
        "google-genai",
        show_creation_store=show_store,
        speech_synthesizer=speech,
        dialogue_agent=dialogue_agent,
        transcript_generator=transcript_generator,
        notification_client=notifier,
    )
    auth = _auth()
    thread = service.create_thread(
        auth,
        CreateThreadRequest(prompt="Tạo một podcast AI cho founder và product manager"),
    )
    thread.current_plan.episodes = [
        EpisodeDraft(
            episode_number=1,
            title="Tap 1",
            description="desc",
            estimated_duration_seconds=900,
        ),
        EpisodeDraft(
            episode_number=2,
            title="Tap 2",
            description="desc 2",
            estimated_duration_seconds=900,
        ),
    ]

    job = service.create_show_from_plan(auth, thread.current_plan.id)
    service._process_show_creation_job(job.id)

    assert repository.jobs[job.id].status == "completed"
    assert show_store.calls == 1
    assert len(show_store.created_episodes) == 2
    assert len(dialogue_agent.calls) == 2
    assert dialogue_agent.calls[0]["episode_number"] == 1
    assert dialogue_agent.calls[1]["episode_number"] == 2
    assert len(dialogue_agent.calls[1]["previous_dialogues"]) == 1
    assert len(speech.dialogue_inputs) == 2
    assert speech.dialogue_inputs[0] is not None
    assert len(notifier.episode_sent) == 2
    assert notifier.episode_sent[0]["episode_number"] == 1
    assert notifier.episode_sent[1]["episode_number"] == 2
    assert len(notifier.show_sent) == 1
    assert notifier.show_sent[0]["episode_count"] == 2
    transcript_jobs = [job for job in repository.jobs.values() if job.job_type == "transcript_generation"]
    assert len(transcript_jobs) == 2


def test_transcript_job_runs_asynchronously_after_episode_audio_is_created() -> None:
    repository = FakeRepository()
    create_agent = FakeCreateAgent("plan")
    planner = FakePlanner()
    show_store = FakeShowCreationStore()
    speech = FakeSpeechSynthesizer()
    dialogue_agent = FakeDialogueAgent()
    transcript_generator = FakeTranscriptGenerator()
    service = AIService(
        repository,
        create_agent,
        planner,
        "google-genai",
        show_creation_store=show_store,
        speech_synthesizer=speech,
        dialogue_agent=dialogue_agent,
        transcript_generator=transcript_generator,
        notification_client=FakeNotificationClient(),
    )
    auth = _auth()
    thread = service.create_thread(
        auth,
        CreateThreadRequest(prompt="Tạo một podcast AI cho founder và product manager"),
    )

    job = service.create_show_from_plan(auth, thread.current_plan.id)
    service._process_show_creation_job(job.id)
    transcript_jobs = [job for job in repository.jobs.values() if job.job_type == "transcript_generation"]

    assert len(transcript_jobs) == 1
    assert transcript_jobs[0].status == "queued"
    assert show_store.saved_transcripts == []

    service._process_transcript_job(transcript_jobs[0].id)

    assert repository.jobs[transcript_jobs[0].id].status == "completed"
    assert transcript_generator.calls == ["show-created-1-episode-1"]
    assert show_store.saved_transcripts[0]["episode_id"] == "show-created-1-episode-1"
    assert show_store.saved_transcripts[0]["alignment_method"] == "proportional"


def test_transcript_job_failure_marks_episode_transcript_failed() -> None:
    repository = FakeRepository()
    create_agent = FakeCreateAgent("plan")
    planner = FakePlanner()
    show_store = FakeShowCreationStore()
    speech = FakeSpeechSynthesizer()
    dialogue_agent = FakeDialogueAgent()
    transcript_generator = FakeTranscriptGenerator(should_fail=True)
    service = AIService(
        repository,
        create_agent,
        planner,
        "google-genai",
        show_creation_store=show_store,
        speech_synthesizer=speech,
        dialogue_agent=dialogue_agent,
        transcript_generator=transcript_generator,
        notification_client=FakeNotificationClient(),
    )
    auth = _auth()
    thread = service.create_thread(
        auth,
        CreateThreadRequest(prompt="Tạo một podcast AI cho founder và product manager"),
    )

    job = service.create_show_from_plan(auth, thread.current_plan.id)
    service._process_show_creation_job(job.id)
    transcript_jobs = [job for job in repository.jobs.values() if job.job_type == "transcript_generation"]

    try:
        service._process_transcript_job(transcript_jobs[0].id)
    except RuntimeError:
        pass

    assert repository.jobs[transcript_jobs[0].id].status == "failed"
    assert show_store.failed_transcripts[0]["episode_id"] == "show-created-1-episode-1"


def test_create_show_from_plan_seeds_dialogue_continuity_from_persisted_episodes() -> None:
    from app.show_creation import EpisodeDialogueMemory, ScriptTurn

    repository = FakeRepository()
    create_agent = FakeCreateAgent("plan")
    planner = FakePlanner()
    show_store = FakeShowCreationStore()
    show_store.persisted_dialogues = [
        EpisodeDialogueMemory(
            episode_number=1,
            title="Tap 1 cu",
            description="Mo dau cho series",
            turns=(
                ScriptTurn(speaker="Nova", text="Tap truoc minh da chot bai toan can giai."),
                ScriptTurn(speaker="Nova", text="Bay gio minh di tiep vao execution."),
            ),
        )
    ]
    notifier = FakeNotificationClient()
    speech = FakeSpeechSynthesizer()
    dialogue_agent = FakeDialogueAgent()
    service = AIService(
        repository,
        create_agent,
        planner,
        "google-genai",
        show_creation_store=show_store,
        speech_synthesizer=speech,
        dialogue_agent=dialogue_agent,
        notification_client=notifier,
    )
    auth = _auth()
    thread = service.create_thread(
        auth,
        CreateThreadRequest(prompt="Tạo một podcast AI cho founder và product manager"),
    )
    thread.current_plan.episodes = [
        EpisodeDraft(
            episode_number=2,
            title="Tap 2",
            description="desc 2",
            estimated_duration_seconds=900,
        ),
        EpisodeDraft(
            episode_number=3,
            title="Tap 3",
            description="desc 3",
            estimated_duration_seconds=900,
        ),
    ]

    job = service.create_show_from_plan(auth, thread.current_plan.id)
    service._process_show_creation_job(job.id)

    assert len(dialogue_agent.calls) == 2
    previous_for_episode_2 = dialogue_agent.calls[0]["previous_dialogues"]
    assert len(previous_for_episode_2) == 1
    assert previous_for_episode_2[0].episode_number == 1
    assert previous_for_episode_2[0].title == "Tap 1 cu"
