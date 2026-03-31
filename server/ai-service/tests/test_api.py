from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID, uuid4

from fastapi.testclient import TestClient

from app.main import create_app
from app.models import (
    AIHostDraft,
    ChatMessage,
    ProductionPlanSummary,
    ChatThreadSummary,
    ChatThreadView,
    EpisodeDraft,
    GenerationJob,
    ProductionPlan,
    ShowDraft,
    VoiceProfile,
)


class FakeAIService:
    def __init__(self) -> None:
        now = datetime.now(timezone.utc)
        self.voice_profiles = [
            VoiceProfile(
                id=UUID("71000000-0000-0000-0000-000000000001"),
                name="Nova",
                provider="google",
                provider_voice_id="gemini-nova-vi-001",
                language_code="vi",
                gender="neutral",
                metadata={"avatar_url": "https://example.com/nova.png"},
                created_at=now,
                updated_at=now,
            )
        ]

    def list_voice_profiles(self):
        return self.voice_profiles

    def create_thread(self, auth, request):
        _ = auth
        return self._thread(prompt=request.prompt)

    def list_threads(self, auth, limit=30):
        _ = auth
        _ = limit
        now = datetime.now(timezone.utc)
        return [
            ChatThreadSummary(
                id=uuid4(),
                title="Founder OS",
                status="active",
                created_at=now,
                updated_at=now,
                last_message_preview="Doi title ngan gon hon thanh Founder OS",
                has_current_plan=True,
            )
        ]

    def get_thread(self, auth, thread_id):
        _ = auth
        _ = thread_id
        return self._thread(prompt="thread")

    def list_drafts(self, auth, limit=50):
        _ = auth
        _ = limit
        now = datetime.now(timezone.utc)
        return [
            ProductionPlanSummary(
                id=uuid4(),
                thread_id=uuid4(),
                status="draft",
                series_title="Founder OS",
                content_type="podcast",
                episode_count=3,
                created_at=now,
                updated_at=now,
            )
        ]

    def get_draft(self, auth, plan_id):
        _ = auth
        _ = plan_id
        return self._thread(prompt="draft").current_plan

    def add_thread_message(self, auth, thread_id, request):
        _ = auth
        _ = thread_id
        return self._thread(prompt=request.message)

    def stream_create_thread(self, auth, request):
        _ = auth
        thread = self._thread(prompt=request.prompt)
        yield {"event": "status", "data": {"message": "Dang phan tich brief..."}}
        yield {"event": "assistant_delta", "data": {"text": "plan "}}
        yield {"event": "assistant_delta", "data": {"text": f"for {request.prompt}"}}
        yield {"event": "thread", "data": {"thread": thread.model_dump(mode="json")}}
        yield {"event": "done", "data": {"thread_id": str(thread.id)}}

    def stream_add_thread_message(self, auth, thread_id, request):
        _ = auth
        _ = thread_id
        thread = self._thread(prompt=request.message)
        yield {"event": "status", "data": {"message": "Dang cap nhat draft..."}}
        yield {"event": "thread", "data": {"thread": thread.model_dump(mode="json")}}
        yield {"event": "done", "data": {"thread_id": str(thread.id)}}

    def generate_episode_plan(self, auth, request):
        _ = auth
        now = datetime.now(timezone.utc)
        plan = self._thread(prompt=request.prompt).current_plan
        job = GenerationJob(
            id=uuid4(),
            plan_id=plan.id,
            job_type="plan_generation",
            status="completed",
            provider="stub",
            input_payload={"prompt": request.prompt},
            output_payload={"series_title": plan.series_title},
            created_at=now,
            started_at=now,
            finished_at=now,
        )
        return plan, job

    def get_job(self, auth, job_id):
        _ = auth
        now = datetime.now(timezone.utc)
        return GenerationJob(
            id=job_id,
            plan_id=uuid4(),
            job_type="plan_generation",
            status="completed",
            provider="stub",
            input_payload={},
            output_payload={},
            created_at=now,
            started_at=now,
            finished_at=now,
        )

    def create_show_from_plan(self, auth, plan_id):
        _ = auth
        now = datetime.now(timezone.utc)
        return GenerationJob(
            id=uuid4(),
            plan_id=plan_id,
            job_type="show_creation",
            status="queued",
            provider="google-genai",
            input_payload={},
            output_payload={},
            created_at=now,
        )

    def _thread(self, *, prompt: str) -> ChatThreadView:
        now = datetime.now(timezone.utc)
        show_draft = ShowDraft(
            slug="ai-builder-lab",
            title="AI Builder Lab",
            description="Show draft",
            primary_category="Cong nghe",
            categories=["Cong nghe"],
            hosts=[
                AIHostDraft(
                    display_name="Nova",
                    avatar_url="https://example.com/nova.png",
                    voice_profile_id=UUID("71000000-0000-0000-0000-000000000001"),
                    bio="AI host",
                ),
                AIHostDraft(
                    display_name="Atlas",
                    role="co_host",
                    bio="Co-host",
                ),
            ],
            tags=["ai", "builder"],
        )
        plan = ProductionPlan(
            id=uuid4(),
            status="completed",
            series_title=show_draft.title,
            series_description=show_draft.description,
            show_draft=show_draft,
            episodes=[
                EpisodeDraft(
                    id=uuid4(),
                    episode_number=1,
                    title="Tap 1",
                    description="desc",
                    estimated_duration_seconds=900,
                    created_at=now,
                    updated_at=now,
                )
            ],
            tags=show_draft.tags,
            created_at=now,
            updated_at=now,
        )
        return ChatThreadView(
            id=uuid4(),
            title="AI Builder Lab",
            status="active",
            created_at=now,
            updated_at=now,
            messages=[
                ChatMessage(
                    id=uuid4(),
                    role="assistant",
                    text_content=f"plan for {prompt}",
                    created_at=now,
                )
            ],
            current_plan=plan,
        )


def create_client() -> TestClient:
    app = create_app(service=FakeAIService())
    return TestClient(app)


def test_voice_profiles_require_auth_header() -> None:
    client = create_client()

    response = client.get("/api/v1/ai/voice-profiles")

    assert response.status_code == 401


def test_public_openapi_yaml_endpoint() -> None:
    client = create_client()

    response = client.get("/api/v1/public/ai/openapi.yaml")

    assert response.status_code == 200
    assert "openapi: 3.0.3" in response.text
    assert "/api/v1/ai/chat-create/threads:" in response.text
    assert "X-Auth-User-ID" in response.text
    assert "type: 'null'" not in response.text
    assert "\n  /healthz:\n" not in response.text


def test_public_swagger_ui_endpoint() -> None:
    client = create_client()

    response = client.get("/api/v1/public/ai/docs")

    assert response.status_code == 200
    assert "/api/v1/public/ai/openapi.yaml" in response.text
    assert "SwaggerUIBundle" in response.text


def test_create_thread_returns_show_level_hosts() -> None:
    client = create_client()

    response = client.post(
        "/api/v1/ai/chat-create/threads",
        headers={"X-Auth-User-ID": str(uuid4())},
        json={"prompt": "Build a podcast about AI builders"},
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["thread"]["current_plan"]["show_draft"]["hosts"][0]["display_name"] == "Nova"
    assert payload["thread"]["current_plan"]["show_draft"]["hosts"][1]["role"] == "co_host"
    assert payload["thread"]["current_plan"]["episodes"][0]["title"] == "Tap 1"


def test_list_threads_returns_history() -> None:
    client = create_client()

    response = client.get(
        "/api/v1/ai/chat-create/threads",
        headers={"X-Auth-User-ID": str(uuid4())},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["threads"][0]["title"] == "Founder OS"
    assert payload["threads"][0]["has_current_plan"] is True


def test_create_show_from_plan_returns_queued_job() -> None:
    client = create_client()
    plan_id = str(uuid4())

    response = client.post(
        f"/api/v1/ai/production-plans/{plan_id}/create-show",
        headers={"X-Auth-User-ID": str(uuid4())},
    )

    assert response.status_code == 202
    payload = response.json()
    assert payload["job"]["plan_id"] == plan_id
    assert payload["job"]["job_type"] == "show_creation"
    assert payload["job"]["status"] == "queued"


def test_list_drafts_returns_draft_history() -> None:
    client = create_client()

    response = client.get(
        "/api/v1/ai/production-plans",
        headers={"X-Auth-User-ID": str(uuid4())},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["drafts"][0]["series_title"] == "Founder OS"
    assert payload["drafts"][0]["episode_count"] == 3


def test_stream_create_thread_emits_sse_events() -> None:
    client = create_client()

    with client.stream(
        "POST",
        "/api/v1/ai/chat-create/threads/stream",
        headers={"X-Auth-User-ID": str(uuid4())},
        json={"prompt": "Build a podcast about AI builders"},
    ) as response:
        body = response.read().decode()

    assert response.status_code == 200
    assert "event: status" in body
    assert "event: assistant_delta" in body
    assert "event: thread" in body
    assert '"display_name": "Nova"' in body
