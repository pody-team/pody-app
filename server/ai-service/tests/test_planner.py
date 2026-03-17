from __future__ import annotations

import json
from datetime import datetime, timezone
from uuid import UUID

from app.models import VoiceProfile
from app.planner import (
    AgentPlanState,
    DisabledSearchTool,
    _execute_plan_tool,
    _validate_planner_content,
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
        metadata={"avatar_url": "https://example.com/nova.png"},
        created_at=now,
        updated_at=now,
    )


def test_validate_planner_content_normalizes_role_and_voice() -> None:
    content = json.dumps(
        {
            "thread_title": "AI Builder Lab",
            "assistant_reply": "",
            "series_title": "AI Builder Lab",
            "series_description": "Show for builders",
            "primary_category": "Cong nghe",
            "categories": [],
            "language_code": "vi",
            "content_type": "podcast",
            "tone_style": "sharp",
            "tags": ["ai"],
            "hosts": [
                {
                    "display_name": "Nova",
                    "role": "Nguoi dan chuong trinh",
                    "bio": "AI host",
                },
                {
                    "display_name": "Atlas",
                    "role": "Dong host",
                    "bio": "Co-host",
                },
            ],
            "episodes": [
                {
                    "episode_number": 1,
                    "title": "Tap 1",
                    "description": "desc 1",
                    "estimated_duration_seconds": 900,
                    "status": "draft",
                },
                {
                    "episode_number": 2,
                    "title": "Tap 2",
                    "description": "desc 2",
                    "estimated_duration_seconds": 900,
                    "status": "draft",
                },
            ],
        },
        ensure_ascii=False,
    )

    validation = _validate_planner_content(
        content,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
    )

    assert validation.valid is True
    assert validation.output is not None
    assert validation.output.hosts[0].role == "host"
    assert validation.output.hosts[1].role == "co_host"
    assert str(validation.output.hosts[0].voice_profile_id) == str(_voice_profile().id)
    assert validation.output.categories == ["Cong nghe"]
    assert validation.output.assistant_reply


def test_validate_planner_content_rejects_wrong_requested_episode_count() -> None:
    content = json.dumps(
        {
            "thread_title": "AI Builder Lab",
            "assistant_reply": "done",
            "series_title": "AI Builder Lab",
            "series_description": "Show for builders",
            "primary_category": "Cong nghe",
            "categories": ["Cong nghe"],
            "language_code": "vi",
            "content_type": "podcast",
            "tone_style": "sharp",
            "tags": ["ai"],
            "hosts": [
                {
                    "display_name": "Nova",
                    "voice_profile_id": str(_voice_profile().id),
                    "role": "host",
                    "bio": "AI host",
                }
            ],
            "episodes": [
                {
                    "episode_number": 1,
                    "title": "Tap 1",
                    "description": "desc 1",
                    "estimated_duration_seconds": 900,
                    "status": "draft",
                }
            ],
        },
        ensure_ascii=False,
    )

    validation = _validate_planner_content(
        content,
        voice_profiles=[_voice_profile()],
        requested_episode_count=3,
    )

    assert validation.valid is False
    assert validation.output is None
    assert any("Expected exactly 3 episodes" in error for error in validation.errors)


def test_validate_planner_content_rejects_storytelling_with_multiple_hosts() -> None:
    content = json.dumps(
        {
            "thread_title": "Midnight Reset",
            "assistant_reply": "done",
            "series_title": "Midnight Reset",
            "series_description": "Calm night stories",
            "primary_category": "Cham soc ban than",
            "categories": ["Cham soc ban than"],
            "language_code": "vi",
            "content_type": "storytelling",
            "tone_style": "calm",
            "tags": ["sleep"],
            "hosts": [
                {"display_name": "Lumi", "role": "narrator", "bio": "Narrator"},
                {"display_name": "Nova", "role": "co_host", "bio": "Should not exist"},
            ],
            "episodes": [
                {
                    "episode_number": 1,
                    "title": "Tap 1",
                    "description": "desc 1",
                    "estimated_duration_seconds": 900,
                    "status": "draft",
                }
            ],
        },
        ensure_ascii=False,
    )

    validation = _validate_planner_content(
        content,
        voice_profiles=[_voice_profile()],
        requested_episode_count=1,
    )

    assert validation.valid is False
    assert any("Storytelling shows must have exactly 1 host" in error for error in validation.errors)


def test_brave_search_tool_returns_soft_error_when_not_configured() -> None:
    result = _execute_plan_tool(
        "brave_search",
        {"query": "podcast xu huong AI 2026"},
        state=AgentPlanState(),
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
    )

    payload = json.loads(result)
    assert "error" in payload
    assert "BRAVE_SEARCH_API_KEY" in payload["error"]


def test_validate_planner_content_accepts_agent_decided_episode_count() -> None:
    content = json.dumps(
        {
            "thread_title": "Ban Tin De Hieu",
            "assistant_reply": "done",
            "series_title": "Ban Tin De Hieu",
            "series_description": "Show tin tuc giai thich ngan gon",
            "primary_category": "Cong nghe",
            "categories": ["Cong nghe"],
            "language_code": "vi",
            "content_type": "podcast",
            "tone_style": "clear",
            "tags": ["news"],
            "hosts": [
                {
                    "display_name": "Nova",
                    "voice_profile_id": str(_voice_profile().id),
                    "role": "host",
                    "bio": "AI host",
                }
            ],
            "episodes": [
                {
                    "episode_number": 1,
                    "title": "Tap 1",
                    "description": "desc 1",
                    "estimated_duration_seconds": 900,
                    "status": "draft",
                },
                {
                    "episode_number": 2,
                    "title": "Tap 2",
                    "description": "desc 2",
                    "estimated_duration_seconds": 900,
                    "status": "draft",
                },
                {
                    "episode_number": 3,
                    "title": "Tap 3",
                    "description": "desc 3",
                    "estimated_duration_seconds": 900,
                    "status": "draft",
                },
                {
                    "episode_number": 4,
                    "title": "Tap 4",
                    "description": "desc 4",
                    "estimated_duration_seconds": 900,
                    "status": "draft",
                },
            ],
        },
        ensure_ascii=False,
    )

    validation = _validate_planner_content(
        content,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
    )

    assert validation.valid is True
    assert validation.output is not None
    assert len(validation.output.episodes) == 4
