from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID, uuid4

from app.dialogue_agent import (
    MAX_DIALOGUE_CHARACTERS,
    StubDialogueAgent,
    _build_dialogue_prompt,
    _dialogue_validation_payload,
    _validate_dialogue_content,
)
from app.models import AIHostDraft, EpisodeDraft, ProductionPlan, ShowDraft, VoiceProfile
from app.show_creation import EpisodeDialogueMemory, ScriptTurn


def _voice_profile(id_value: str, name: str) -> VoiceProfile:
    now = datetime.now(timezone.utc)
    return VoiceProfile(
        id=UUID(id_value),
        name=name,
        provider="google",
        provider_voice_id=name.lower(),
        language_code="vi",
        gender="neutral",
        metadata={},
        created_at=now,
        updated_at=now,
    )


def _podcast_plan() -> ProductionPlan:
    now = datetime.now(timezone.utc)
    return ProductionPlan(
        id=uuid4(),
        status="draft",
        series_title="Founder Signal",
        series_description="Goc nhin founder va PM.",
        target_language_code="vi",
        tone_style="sharp, practical",
        show_draft=ShowDraft(
            slug="founder-signal",
            title="Founder Signal",
            description="Goc nhin founder va PM.",
            primary_category="Cong nghe",
            language_code="vi",
            content_type="podcast",
            hosts=[
                AIHostDraft(
                    display_name="Atlas",
                    role="host",
                    voice_profile_id=UUID("71000000-0000-0000-0000-000000000005"),
                ),
                AIHostDraft(
                    display_name="Mira",
                    role="co_host",
                    voice_profile_id=UUID("71000000-0000-0000-0000-000000000006"),
                ),
            ],
        ),
        episodes=[
            EpisodeDraft(
                episode_number=1,
                title="AI agents cho startup",
                description="Founder can uu tien dieu gi khi dua AI vao van hanh?",
                estimated_duration_seconds=900,
            )
        ],
        created_at=now,
        updated_at=now,
    )


def test_validate_dialogue_content_accepts_two_host_podcast_dialogue() -> None:
    plan = _podcast_plan()
    validation = _validate_dialogue_content(
        """
        {
          "dialogue": [
            {"speaker": "Atlas", "text": "Hom nay minh ban ve AI agents.", "emotion": "confident"},
            {"speaker": "Mira", "text": "Va quan trong hon la tac dong toi PM.", "emotion": "curious"},
            {"speaker": "Atlas", "text": "Neu khong co use case ro, team se dot thoi gian."},
            {"speaker": "Mira", "text": "Nen minh se tach bai toan theo workflow cu the."}
          ]
        }
        """,
        plan=plan,
        episode=plan.episodes[0],
    )

    assert validation.valid is True
    assert len(validation.turns) == 4


def test_validate_dialogue_content_rejects_unknown_speaker() -> None:
    plan = _podcast_plan()
    validation = _validate_dialogue_content(
        """
        {
          "dialogue": [
            {"speaker": "Atlas", "text": "Mo dau"},
            {"speaker": "Linh", "text": "Day la nguoi khong co trong plan"},
            {"speaker": "Atlas", "text": "Tie p tuc"},
            {"speaker": "Atlas", "text": "Ket lai"}
          ]
        }
        """,
        plan=plan,
        episode=plan.episodes[0],
    )

    assert validation.valid is False
    assert any("not in allowed hosts" in error for error in validation.errors)


def test_stub_dialogue_agent_returns_dialogue_turns() -> None:
    plan = _podcast_plan()
    agent = StubDialogueAgent()

    turns = agent.generate_dialogue(
        plan=plan,
        episode=plan.episodes[0],
        voice_profiles=[
            _voice_profile("71000000-0000-0000-0000-000000000005", "Atlas"),
            _voice_profile("71000000-0000-0000-0000-000000000006", "Mira"),
        ],
    )

    assert len(turns) >= 4
    assert turns[0].speaker == "Atlas"


def test_build_dialogue_prompt_includes_full_previous_context_and_teaser() -> None:
    plan = _podcast_plan()
    plan.episodes.append(
        EpisodeDraft(
            episode_number=2,
            title="Doanh thu tu AI agents",
            description="Cach bien AI thanh revenue that su.",
        )
    )
    prompt = _build_dialogue_prompt(
        plan=plan,
        episode=plan.episodes[0],
        voice_profiles=[
            _voice_profile("71000000-0000-0000-0000-000000000005", "Atlas"),
            _voice_profile("71000000-0000-0000-0000-000000000006", "Mira"),
        ],
        previous_dialogues=[
            EpisodeDialogueMemory(
                episode_number=0,
                title="Prologue",
                description="Nen canh truoc khi vao series",
                turns=(
                    ScriptTurn(speaker="Atlas", text="Day la mo dau cua series."),
                    ScriptTurn(speaker="Mira", text="Va minh da dat ky vong cho tap 1."),
                ),
            )
        ],
    )

    assert "Series continuity requirements" in prompt
    assert "Tập 0: Prologue" in prompt
    assert "Atlas: Day la mo dau cua series." in prompt
    assert "Cuối tập này phải có teaser ngắn cho tập tiếp theo: “Doanh thu tu AI agents”." in prompt
    assert "Thời lượng mục tiêu tối thiểu" in prompt
    assert "Hard cap:" not in prompt


def test_validate_dialogue_content_warns_when_tts_character_limit_is_exceeded() -> None:
    plan = _podcast_plan()
    oversized_text = " ".join(["noi dung rat dai"] * 220)
    validation = _validate_dialogue_content(
        f"""
        {{
          "dialogue": [
            {{"speaker": "Atlas", "text": "Tap truoc chung ta da mo bai. {oversized_text}", "emotion": "confident"}},
            {{"speaker": "Mira", "text": "{oversized_text}", "emotion": "curious"}},
            {{"speaker": "Atlas", "text": "{oversized_text}", "emotion": "thoughtful"}},
            {{"speaker": "Mira", "text": "Tap sau chung ta se mo rong them. {oversized_text}", "emotion": "encouraging"}}
          ]
        }}
        """,
        plan=plan,
        episode=plan.episodes[0],
    )

    assert validation.valid is True
    assert any("backend will split it automatically" in warning for warning in validation.warnings)
    payload = _dialogue_validation_payload(validation)
    assert payload["character_count"] > MAX_DIALOGUE_CHARACTERS
