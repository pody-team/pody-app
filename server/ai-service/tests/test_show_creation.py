from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID, uuid4

from app.models import AIHostDraft, EpisodeDraft, ProductionPlan, ShowDraft, VoiceProfile
from app.show_creation import (
    EpisodeArtifact,
    MAX_TTS_PROMPT_CHARACTERS,
    ScriptTurn,
    ShowCreationSession,
    _build_tts_prompt_chunks,
    _build_episode_segments,
    _build_episode_turns,
    _build_speech_config,
    _normalize_hosts,
    _resolve_voice_name,
    _resolve_category,
)


def _voice_profile(
    id_value: str,
    name: str,
    provider_voice_id: str,
    *,
    tts_voice_name: str,
) -> VoiceProfile:
    now = datetime.now(timezone.utc)
    return VoiceProfile(
        id=UUID(id_value),
        name=name,
        provider="google",
        provider_voice_id=provider_voice_id,
        language_code="vi",
        gender="neutral",
        metadata={"tts_voice_name": tts_voice_name},
        created_at=now,
        updated_at=now,
    )


def _plan_with_two_hosts() -> ProductionPlan:
    now = datetime.now(timezone.utc)
    return ProductionPlan(
        id=uuid4(),
        status="draft",
        series_title="Tech Pulse",
        series_description="Ban tin cong nghe cho founder.",
        target_language_code="vi",
        show_draft=ShowDraft(
            slug="tech-pulse",
            title="Tech Pulse",
            description="Ban tin cong nghe cho founder.",
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
                title="AI Agents cho Product",
                description="Phan tich cach PM dung AI agents de giam viec lap lai.",
                notes="Dua them mot goc nhin thuc chien ve van hanh va uu tien.",
            )
        ],
        created_at=now,
        updated_at=now,
    )


def test_build_episode_turns_creates_two_host_dialogue_for_podcast() -> None:
    plan = _plan_with_two_hosts()
    turns = _build_episode_turns(plan, plan.episodes[0], tuple(plan.show_draft.hosts))

    assert len(turns) == 4
    assert turns[0].speaker == "Atlas"
    assert turns[1].speaker == "Mira"
    assert turns[2].speaker == "Atlas"
    assert turns[3].speaker == "Mira"
    assert "AI Agents cho Product" in turns[0].text


def test_normalize_hosts_does_not_invent_avatar_urls() -> None:
    hosts = _normalize_hosts(
        content_type="podcast",
        hosts=[
            AIHostDraft(
                display_name="Atlas",
                role="host",
            ),
            AIHostDraft(
                display_name="Mira",
                role="co_host",
                avatar_url="https://cdn.pody.vn/hosts/mira.png",
            ),
        ],
    )

    assert hosts[0].avatar_url is None
    assert hosts[1].avatar_url == "https://cdn.pody.vn/hosts/mira.png"


def test_build_speech_config_uses_multi_speaker_for_two_hosts() -> None:
    plan = _plan_with_two_hosts()
    voice_profiles = [
        _voice_profile(
            "71000000-0000-0000-0000-000000000005",
            "Atlas",
            "gemini-atlas-vi-001",
            tts_voice_name="Puck",
        ),
        _voice_profile(
            "71000000-0000-0000-0000-000000000006",
            "Mira",
            "gemini-minh-tra-vi-001",
            tts_voice_name="Charon",
        ),
    ]

    speech_config = _build_speech_config(
        plan=plan,
        hosts=tuple(plan.show_draft.hosts),
        voice_profiles=voice_profiles,
    )

    assert speech_config.multi_speaker_voice_config is not None
    configs = speech_config.multi_speaker_voice_config.speaker_voice_configs
    assert [config.speaker for config in configs] == ["Atlas", "Mira"]
    assert configs[0].voice_config.prebuilt_voice_config.voice_name == "Puck"
    assert configs[1].voice_config.prebuilt_voice_config.voice_name == "Charon"


def test_resolve_voice_name_uses_tts_voice_name_from_metadata() -> None:
    host = AIHostDraft(
        display_name="Atlas",
        role="host",
        voice_profile_id=UUID("71000000-0000-0000-0000-000000000005"),
    )
    voice_profiles = [
        _voice_profile(
            "71000000-0000-0000-0000-000000000005",
            "Atlas",
            "gemini-atlas-vi-001",
            tts_voice_name="Puck",
        )
    ]

    assert _resolve_voice_name(host, voice_profiles) == "Puck"


def test_resolve_voice_name_raises_when_metadata_tts_voice_name_is_missing() -> None:
    host = AIHostDraft(
        display_name="Atlas",
        role="host",
        voice_profile_id=UUID("71000000-0000-0000-0000-000000000005"),
    )
    now = datetime.now(timezone.utc)
    voice_profiles = [
        VoiceProfile(
            id=UUID("71000000-0000-0000-0000-000000000005"),
            name="Atlas",
            provider="google",
            provider_voice_id="gemini-atlas-vi-001",
            language_code="vi",
            gender="neutral",
            metadata={},
            created_at=now,
            updated_at=now,
        )
    ]

    try:
        _resolve_voice_name(host, voice_profiles)
    except ValueError as exc:
        assert "metadata.tts_voice_name" in str(exc)
    else:
        raise AssertionError("expected ValueError when tts_voice_name metadata is missing")


def test_resolve_voice_name_raises_when_host_missing_voice_profile_id() -> None:
    host = AIHostDraft(
        display_name="Atlas",
        role="host",
    )
    voice_profiles = [
        _voice_profile(
            "71000000-0000-0000-0000-000000000005",
            "Atlas",
            "gemini-atlas-vi-001",
            tts_voice_name="Puck",
        )
    ]

    try:
        _resolve_voice_name(host, voice_profiles)
    except ValueError as exc:
        assert "missing voice_profile_id" in str(exc)
    else:
        raise AssertionError("expected ValueError when host has no voice_profile_id")


def test_build_episode_segments_maps_turns_to_matching_hosts() -> None:
    plan = _plan_with_two_hosts()
    show = ShowCreationSession(
        show_id="show-1",
        show_title=plan.series_title,
        cover_image_url="https://example.com/show.png",
        primary_host_name="Atlas",
        inserted_host_ids=("host-1", "host-2"),
    )
    artifact = EpisodeArtifact(
        audio_bytes=b"wav",
        duration_seconds=12,
        script_text="Atlas: Xin chao\nMira: Chao ban",
        turns=(
            ScriptTurn(speaker="Atlas", text="Xin chao"),
            ScriptTurn(speaker="Mira", text="Chao ban"),
        ),
    )

    segments = _build_episode_segments(show=show, plan=plan, artifact=artifact)

    assert len(segments) == 2
    assert segments[0]["show_host_id"] == "host-1"
    assert segments[1]["show_host_id"] == "host-2"
    assert segments[0]["speaker_label"] == "Atlas"
    assert segments[1]["speaker_label"] == "Mira"
    assert segments[0]["start_ms"] == 0
    assert segments[1]["end_ms"] == 12000


def test_build_tts_prompt_chunks_splits_long_dialogue_without_truncating_text() -> None:
    oversized_text = " ".join(["day la mot doan rat dai"] * 180)
    turns = (
        ScriptTurn(speaker="Atlas", text=f"Mo dau. {oversized_text}", emotion="confident"),
        ScriptTurn(speaker="Mira", text=oversized_text, emotion="curious"),
        ScriptTurn(speaker="Atlas", text=oversized_text, emotion="thoughtful"),
        ScriptTurn(speaker="Mira", text=f"Ket lai va teaser. {oversized_text}", emotion="encouraging"),
    )

    chunks = _build_tts_prompt_chunks(turns)

    assert len(chunks) > 1
    assert all(len(chunk) <= MAX_TTS_PROMPT_CHARACTERS for chunk in chunks)
    assert "..." not in "".join(chunks)
    assert chunks[0].startswith("TTS the following Vietnamese podcast conversation")
    assert "Atlas:" in "".join(chunks)
    assert "Mira:" in "".join(chunks)


def test_resolve_category_matches_exact_db_name() -> None:
    class FakeResult:
        def fetchall(self):
            return [
                {
                    "id": "51000000-0000-0000-0000-000000000001",
                    "slug": "cong-nghe",
                    "name": "Cong nghe",
                }
            ]

    class FakeConn:
        def execute(self, _query, _params=None):
            return FakeResult()

    category_name, category_id = _resolve_category(FakeConn(), "Cong nghe")

    assert category_name == "Cong nghe"
    assert category_id == "51000000-0000-0000-0000-000000000001"


def test_resolve_category_matches_vietnamese_name_via_slugified_lookup() -> None:
    class FakeResult:
        def fetchall(self):
            return [
                {
                    "id": "51000000-0000-0000-0000-000000000001",
                    "slug": "cong-nghe",
                    "name": "Cong nghe",
                }
            ]

    class FakeConn:
        def execute(self, _query, _params=None):
            return FakeResult()

    category_name, category_id = _resolve_category(FakeConn(), "Công nghệ")

    assert category_name == "Cong nghe"
    assert category_id == "51000000-0000-0000-0000-000000000001"
def test_resolve_category_raises_for_unknown_value() -> None:
    class FakeResult:
        def fetchall(self):
            return [
                {
                    "id": "51000000-0000-0000-0000-000000000004",
                    "slug": "giai-thich-de-hieu",
                    "name": "Giai thich de hieu",
                }
            ]

    class FakeConn:
        def execute(self, _query, _params=None):
            return FakeResult()

    try:
        _resolve_category(FakeConn(), "Unknown taxonomy bucket")
    except ValueError as exc:
        assert "primary category was not found" in str(exc)
    else:
        raise AssertionError("expected ValueError for unknown category")
