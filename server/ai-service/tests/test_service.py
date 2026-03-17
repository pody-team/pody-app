from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID, uuid4

from app.models import (
    AIHostDraft,
    AuthContext,
    ChatMessage,
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
    ) -> ChatTurnResult:
        _ = requested_episode_count
        _ = voice_profiles
        _ = prompt
        _ = conversation
        _ = current_thread_title
        _ = current_plan
        self.calls += 1
        if self.result == "chat":
            return ChatTurnResult(
                thread_title="Founder format brainstorm",
                assistant_reply=f"Chat reply for: {prompt}",
                plan_output=None,
            )
        return ChatTurnResult(
            thread_title="AI Builder Lab",
            assistant_reply="Mình đã dựng xong bản draft đầu tiên.",
            plan_output=FakePlanner().generate(
                prompt=prompt,
                requested_episode_count=requested_episode_count,
                voice_profiles=voice_profiles,
                conversation=conversation,
                current_plan_summary=None,
            ),
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
