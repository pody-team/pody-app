from __future__ import annotations

import json
from datetime import datetime, timezone
from uuid import UUID

from app.models import VoiceProfile
from app.planner import (
    AgentPlanState,
    DisabledSearchTool,
    _build_create_agent_system_prompt_for_mode,
    _build_plan_system_prompt,
    _execute_plan_tool,
    _reference_date_context,
    _tool_status_message,
    _validate_planner_content,
)


class SuccessfulSearchTool:
    def search(self, *, query: str) -> str:
        return json.dumps(
            {
                "query": query,
                "results": [
                    {
                        "title": "Founder podcast trends",
                        "url": "https://example.com/founder-podcast-trends",
                        "description": "Research result for founders.",
                    }
                ],
            },
            ensure_ascii=False,
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


def _voice_profile_two() -> VoiceProfile:
    now = datetime.now(timezone.utc)
    return VoiceProfile(
        id=UUID("71000000-0000-0000-0000-000000000002"),
        name="Atlas",
        provider="google",
        provider_voice_id="gemini-atlas-vi-001",
        language_code="vi",
        gender="male",
        metadata={"avatar_url": "https://example.com/atlas.png"},
        created_at=now,
        updated_at=now,
    )


def _categories() -> list[tuple[str, str]]:
    return [
        ("Công nghệ", "cong-nghe"),
        ("Giải thích dễ hiểu", "giai-thich-de-hieu"),
    ]


def test_validate_planner_content_requires_voice_ids_from_allowed_profiles() -> None:
    content = json.dumps(
        {
            "thread_title": "AI Builder Lab",
            "assistant_reply": "",
            "series_title": "AI Builder Lab",
            "series_description": "Show for builders",
            "primary_category": "Công nghệ",
            "categories": [],
            "language_code": "vi",
            "content_type": "podcast",
            "tone_style": "sharp",
            "tags": ["ai"],
            "hosts": [
                {
                    "display_name": "Nova",
                    "voice_profile_id": str(_voice_profile().id),
                    "role": "Nguoi dan chuong trinh",
                    "bio": "AI host",
                },
                {
                    "display_name": "Atlas",
                    "voice_profile_id": str(_voice_profile_two().id),
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
        voice_profiles=[_voice_profile(), _voice_profile_two()],
        categories=_categories(),
        requested_episode_count=None,
    )

    assert validation.valid is True
    assert validation.output is not None
    assert validation.output.hosts[0].role == "host"
    assert validation.output.hosts[1].role == "co_host"
    assert str(validation.output.hosts[0].voice_profile_id) == str(_voice_profile().id)
    assert str(validation.output.hosts[1].voice_profile_id) == str(_voice_profile_two().id)
    assert validation.output.categories == ["Công nghệ"]
    assert validation.output.assistant_reply
    assert "2 host" in validation.output.assistant_reply
    assert "Nova, Atlas" in validation.output.assistant_reply


def test_validate_planner_content_rejects_missing_or_invalid_voice_ids() -> None:
    content = json.dumps(
        {
            "thread_title": "AI Builder Lab",
            "assistant_reply": "",
            "series_title": "AI Builder Lab",
            "series_description": "Show for builders",
            "primary_category": "Công nghệ",
            "categories": ["Công nghệ"],
            "language_code": "vi",
            "content_type": "podcast",
            "tone_style": "sharp",
            "tags": ["ai"],
            "hosts": [
                {
                    "display_name": "Nova",
                    "role": "host",
                    "bio": "AI host",
                },
                {
                    "display_name": "Atlas",
                    "voice_profile_id": "00000000-0000-0000-0000-000000000099",
                    "role": "co_host",
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
                }
            ],
        },
        ensure_ascii=False,
    )

    validation = _validate_planner_content(
        content,
        voice_profiles=[_voice_profile()],
        categories=_categories(),
        requested_episode_count=None,
    )

    assert validation.valid is False
    assert any('missing "voice_profile_id"' in error for error in validation.errors)
    assert any('is not in allowed voice profiles' in error for error in validation.errors)


def test_validate_planner_content_rejects_category_outside_content_db() -> None:
    content = json.dumps(
        {
            "thread_title": "AI Builder Lab",
            "assistant_reply": "",
            "series_title": "AI Builder Lab",
            "series_description": "Show for builders",
            "primary_category": "Kinh doanh",
            "categories": ["Kinh doanh"],
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
        categories=_categories(),
        requested_episode_count=None,
    )

    assert validation.valid is False
    assert any('"primary_category" must match a category from content DB' in error for error in validation.errors)


def test_plan_system_prompt_injects_allowed_categories_and_voices() -> None:
    prompt = _build_plan_system_prompt(
        voice_profiles=[_voice_profile()],
        categories=_categories(),
    )

    assert _reference_date_context() in prompt
    assert 'Danh sach category show hop le' in prompt
    assert '"Công nghệ" (slug: cong-nghe)' in prompt
    assert 'Danh sach voice profile duoc phep dung' in prompt
    assert str(_voice_profile().id) in prompt
    assert _voice_profile().provider_voice_id in prompt


def test_create_agent_system_prompt_injects_allowed_categories_and_voices() -> None:
    prompt = _build_create_agent_system_prompt_for_mode(
        "edit",
        voice_profiles=[_voice_profile()],
        categories=_categories(),
    )

    assert _reference_date_context() in prompt
    assert 'Danh sach category show hop le' in prompt
    assert '"Giải thích dễ hiểu" (slug: giai-thich-de-hieu)' in prompt
    assert 'Danh sach voice profile duoc phep dung' in prompt
    assert _voice_profile().name in prompt


def test_brave_search_status_message_stays_generic() -> None:
    message = _tool_status_message(
        "brave_search",
        query="tin cong nghe cho founder o dong nam a nam 2026",
    )

    assert message == "Đang tìm kiếm thông tin liên quan..."
    assert "founder" not in message


def test_validate_planner_content_rejects_wrong_requested_episode_count() -> None:
    content = json.dumps(
        {
            "thread_title": "AI Builder Lab",
            "assistant_reply": "done",
            "series_title": "AI Builder Lab",
            "series_description": "Show for builders",
            "primary_category": "Công nghệ",
            "categories": ["Công nghệ"],
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
            "primary_category": "Chăm sóc bản thân",
            "categories": ["Chăm sóc bản thân"],
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


def test_validate_planner_content_rejects_when_prompt_requires_two_hosts() -> None:
    content = json.dumps(
        {
            "thread_title": "Go Builder Lab",
            "assistant_reply": "Atlas va Lumi se dong hanh cung ban.",
            "series_title": "Go Builder Lab",
            "series_description": "Hoc Go co he thong",
            "primary_category": "Công nghệ",
            "categories": ["Công nghệ"],
            "language_code": "vi",
            "content_type": "podcast",
            "tone_style": "practical",
            "tags": ["golang"],
            "hosts": [
                {
                    "display_name": "Atlas",
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
        requested_episode_count=None,
        requested_host_count=2,
    )

    assert validation.valid is False
    assert any("Expected exactly 2 hosts" in error for error in validation.errors)


def test_brave_search_tool_returns_soft_error_when_not_configured() -> None:
    state = AgentPlanState()
    result = _execute_plan_tool(
        "brave_search",
        {"query": "podcast xu huong AI 2026"},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
    )

    payload = json.loads(result)
    assert "error" in payload
    assert "BRAVE_SEARCH_API_KEY" in payload["error"]
    assert state.has_searched is False


def test_brave_search_tool_marks_state_only_after_success() -> None:
    state = AgentPlanState()

    result = _execute_plan_tool(
        "brave_search",
        {"query": "podcast xu huong AI 2026"},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=SuccessfulSearchTool(),
    )

    payload = json.loads(result)
    assert payload["results"]
    assert state.has_searched is True


def test_brave_search_tool_emits_tool_specific_status() -> None:
    events: list[dict[str, object]] = []
    state = AgentPlanState()

    _execute_plan_tool(
        "brave_search",
        {"query": "podcast xu huong AI 2026"},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
        emit_event=events.append,
    )

    assert events[0]["event"] == "status"
    assert events[0]["data"]["tool"] == "brave_search"
    assert "Đang tìm kiếm thông tin" in events[0]["data"]["message"]
    assert state.has_searched is False


def test_write_plan_validates_without_requiring_search_first() -> None:
    state = AgentPlanState()

    result = _execute_plan_tool(
        "write_plan",
        {"content": "{}"},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
    )

    payload = json.loads(result)
    assert payload["success"] is True
    assert payload["plan_valid"] is False
    assert payload["plan_errors"]


def test_edit_plan_validates_without_requiring_search_first() -> None:
    state = AgentPlanState(content='{"series_title":"AI Builder Lab"}')

    result = _execute_plan_tool(
        "edit_plan",
        {"operation": "rewrite", "content": "{}"},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
    )

    payload = json.loads(result)
    assert payload["success"] is True
    assert payload["plan_valid"] is False
    assert payload["plan_errors"]


def test_edit_plan_returns_plan_valid_false_when_replace_search_missing() -> None:
    state = AgentPlanState(
        has_searched=True,
        content='{"series_title":"AI Builder Lab"}',
    )

    result = _execute_plan_tool(
        "edit_plan",
        {"operation": "replace", "replacement": "Go Builder Lab"},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
    )

    payload = json.loads(result)
    assert payload["success"] is False
    assert payload["plan_valid"] is False
    assert "search is required" in payload["error"]


def test_edit_plan_returns_plan_valid_false_for_unknown_operation() -> None:
    state = AgentPlanState(
        has_searched=True,
        content='{"series_title":"AI Builder Lab"}',
    )

    result = _execute_plan_tool(
        "edit_plan",
        {"operation": "append"},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
    )

    payload = json.loads(result)
    assert payload["success"] is False
    assert payload["plan_valid"] is False
    assert "Unknown edit_plan operation" in payload["error"]


def test_validate_planner_content_accepts_agent_decided_episode_count() -> None:
    content = json.dumps(
        {
            "thread_title": "Ban Tin De Hieu",
            "assistant_reply": "done",
            "series_title": "Ban Tin De Hieu",
            "series_description": "Show tin tuc giai thich ngan gon",
            "primary_category": "Công nghệ",
            "categories": ["Công nghệ"],
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


def test_begin_edit_session_switches_state_and_returns_plan() -> None:
    content = json.dumps(
        {
            "thread_title": "AI Builder Lab",
            "assistant_reply": "done",
            "series_title": "AI Builder Lab",
            "series_description": "Show for builders",
            "primary_category": "Công nghệ",
            "categories": ["Công nghệ"],
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
        requested_episode_count=None,
    )
    assert validation.valid is True

    state = AgentPlanState(
        content=validation.normalized_json,
        output=validation.output,
        validation=validation,
    )

    result = _execute_plan_tool(
        "begin_edit_session",
        {"focus": "show.title"},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
    )

    payload = json.loads(result)
    assert payload["success"] is True
    assert payload["mode"] == "edit"
    assert payload["focus"] == "show.title"
    assert payload["plan"]["series_title"] == "AI Builder Lab"
    assert state.mode == "edit"
    assert state.edit_focus == "show.title"


def test_finalize_turn_emits_reply_status() -> None:
    events: list[dict[str, object]] = []
    state = AgentPlanState(has_searched=True)

    result = _execute_plan_tool(
        "finalize_turn",
        {"message": "Minh da cap nhat xong draft."},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
        emit_event=events.append,
    )

    payload = json.loads(result)
    assert payload["finalized"] is True
    assert state.finalized_reply == "Minh da cap nhat xong draft."
    assert events[0]["data"]["tool"] == "finalize_turn"
    assert "Đang hoàn thiện phản hồi" in events[0]["data"]["message"]


def test_finalize_turn_does_not_require_search_first() -> None:
    state = AgentPlanState()

    result = _execute_plan_tool(
        "finalize_turn",
        {"message": "Minh da cap nhat xong draft."},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
    )

    payload = json.loads(result)
    assert payload["success"] is True
    assert payload["finalized"] is True


def test_finalize_turn_does_not_require_draft() -> None:
    state = AgentPlanState()

    result = _execute_plan_tool(
        "finalize_turn",
        {"message": "Minh da cap nhat xong draft."},
        state=state,
        voice_profiles=[_voice_profile()],
        requested_episode_count=None,
        search_tool=DisabledSearchTool(),
    )

    payload = json.loads(result)
    assert payload["success"] is True
    assert payload["finalized"] is True
