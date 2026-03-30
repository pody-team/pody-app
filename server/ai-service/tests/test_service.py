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
