from __future__ import annotations

import json
import re
import unicodedata
from dataclasses import dataclass
from typing import Any, Callable, Protocol

from google.genai import types

from .config import Settings
from .models import EpisodeDraft, ProductionPlan, VoiceProfile
from .planner import (
    DisabledSearchTool,
    SearchTool,
    _build_genai_client,
    _reference_date_context,
    build_search_tool,
)
from .show_creation import EpisodeDialogueMemory, ScriptTurn, _build_episode_turns, _build_tts_prompt


class DialogueAgentError(Exception):
    pass


class DialogueAgent(Protocol):
    def generate_dialogue(
        self,
        *,
        plan: ProductionPlan,
        episode: EpisodeDraft,
        voice_profiles: list[VoiceProfile],
        previous_dialogues: list[EpisodeDialogueMemory] | None = None,
        emit_event: Callable[[dict[str, Any]], None] | None = None,
    ) -> tuple[ScriptTurn, ...]: ...


@dataclass
class DialogueValidation:
    valid: bool
    errors: list[str]
    warnings: list[str]
    turns: tuple[ScriptTurn, ...]
    normalized_json: str | None


@dataclass
class DialogueAgentState:
    has_searched: bool = False
    content: str | None = None
    turns: tuple[ScriptTurn, ...] = ()
    validation: DialogueValidation | None = None
    finalized_reply: str | None = None


MAX_DIALOGUE_AGENT_ITERATIONS = 10
WORDS_PER_MINUTE = 280
MAX_DIALOGUE_CHARACTERS = 4000

_DIALOGUE_FUNCTION_DECLARATIONS = [
    types.FunctionDeclaration(
        name="brave_search",
        description="Search the web for facts, examples, or recent context before writing the episode dialogue.",
        parameters_json_schema={
            "type": "object",
            "required": ["query"],
            "properties": {
                "query": {"type": "string"},
            },
        },
    ),
    types.FunctionDeclaration(
        name="read_plan",
        description="Read the current show plan and episode context you are writing from.",
        parameters_json_schema={
            "type": "object",
            "properties": {},
        },
    ),
    types.FunctionDeclaration(
        name="list_voice_profiles",
        description="Read the allowed AI voice profiles for the hosts in this show.",
        parameters_json_schema={
            "type": "object",
            "properties": {},
        },
    ),
    types.FunctionDeclaration(
        name="write_dialogue",
        description="Write the episode dialogue JSON string. The tool validates the structure and speaker mapping.",
        parameters_json_schema={
            "type": "object",
            "required": ["content"],
            "properties": {
                "content": {"type": "string"},
            },
        },
    ),
    types.FunctionDeclaration(
        name="read_dialogue",
        description="Read the current dialogue draft JSON.",
        parameters_json_schema={
            "type": "object",
            "properties": {},
        },
    ),
    types.FunctionDeclaration(
        name="edit_dialogue",
        description="Edit the current dialogue JSON using replace or rewrite.",
        parameters_json_schema={
            "type": "object",
            "required": ["operation"],
            "properties": {
                "operation": {"type": "string", "enum": ["replace", "rewrite"]},
                "search": {"type": "string"},
                "replacement": {"type": "string"},
                "content": {"type": "string"},
            },
        },
    ),
    types.FunctionDeclaration(
        name="finalize_turn",
        description="Finalize the dialogue draft once it is valid.",
        parameters_json_schema={
            "type": "object",
            "required": ["message"],
            "properties": {
                "message": {"type": "string"},
            },
        },
    ),
]

DIALOGUE_TOOLS = [types.Tool(function_declarations=_DIALOGUE_FUNCTION_DECLARATIONS)]

DIALOGUE_SYSTEM_PROMPT = """Bạn là Pody Dialogue Agent.

Nhiệm vụ của bạn là viết dialogue cho một episode duy nhất của show đã có production plan.

Bạn chỉ được tạo JSON qua tool `write_dialogue` hoặc `edit_dialogue` với shape:
{
  "dialogue": [
    {
      "speaker": "Ten host co san trong plan",
      "text": "Noi dung cau thoai bang tieng Viet",
      "emotion": "optional",
      "direction": "optional"
    }
  ]
}

Quy trình bắt buộc:
1. Luôn gọi `brave_search` ít nhất một lần trước khi kết thúc.
2. Dùng `read_plan` nếu cần xem lại context show, host, episode và mạch liên tập.
3. Dùng `list_voice_profiles` nếu cần biết rõ giọng hợp lệ của host.
4. Gọi `write_dialogue` để viết draft JSON.
5. Nếu `write_dialogue` hoặc `edit_dialogue` trả `valid=false`, bạn BẮT BUỘC sửa tiếp cho đến khi hợp lệ.
6. Chỉ được kết thúc bằng `finalize_turn`.

Ràng buộc:
- Chỉ viết dialogue.
- Dùng đúng tên host có trong plan.
- Nếu format là podcast có 2 host, dialogue phải thật sự là hội thoại giữa 2 người, không phải monologue trá hình.
- Nếu format là storytelling hoặc chỉ có 1 host, dialogue có thể là độc thoại.
- Giữ nội dung bám episode đang viết và mạch của series.
- Nếu không phải tập đầu, mở đầu phải recap cực ngắn gọn tập trước một cách tự nhiên.
- Nếu không phải tập cuối, cuối tập phải teaser ngắn cho tập tiếp theo.
- Tốc độ đọc tham chiếu là 280 từ/phút. Dùng estimated duration của episode để canh độ dài thoại.
"""


def _build_dialogue_system_prompt() -> str:
    return f"{DIALOGUE_SYSTEM_PROMPT.strip()}\n\n{_reference_date_context()}"


class StubDialogueAgent:
    def generate_dialogue(
        self,
        *,
        plan: ProductionPlan,
        episode: EpisodeDraft,
        voice_profiles: list[VoiceProfile],
        previous_dialogues: list[EpisodeDialogueMemory] | None = None,
        emit_event: Callable[[dict[str, Any]], None] | None = None,
    ) -> tuple[ScriptTurn, ...]:
        _ = voice_profiles
        _ = previous_dialogues
        if emit_event is not None:
            emit_event(
                {
                    "event": "status",
                    "data": {
                        "phase": "tool",
                        "tool": "write_dialogue",
                        "message": "Đang dựng thoại cho episode...",
                    },
                }
            )
        return _build_episode_turns(plan, episode, tuple(plan.show_draft.hosts[:2]))


class GoogleGenAIDialogueAgent:
    def __init__(
        self,
        *,
        project: str,
        location: str,
        model: str,
        search_tool: SearchTool | None = None,
    ) -> None:
        self._client = _build_genai_client(project=project, location=location)
        self._model = model
        self._search_tool = search_tool or DisabledSearchTool()

    def generate_dialogue(
        self,
        *,
        plan: ProductionPlan,
        episode: EpisodeDraft,
        voice_profiles: list[VoiceProfile],
        previous_dialogues: list[EpisodeDialogueMemory] | None = None,
        emit_event: Callable[[dict[str, Any]], None] | None = None,
    ) -> tuple[ScriptTurn, ...]:
        contents = [
            types.Content(
                role="user",
                parts=[
                    types.Part.from_text(
                        text=_build_dialogue_prompt(
                            plan=plan,
                            episode=episode,
                            voice_profiles=voice_profiles,
                            previous_dialogues=previous_dialogues or [],
                        )
                    )
                ],
            )
        ]
        state = DialogueAgentState()

        for _ in range(MAX_DIALOGUE_AGENT_ITERATIONS):
            response = self._client.models.generate_content(
                model=self._model,
                contents=contents,
                config=types.GenerateContentConfig(
                    temperature=0.8,
                    system_instruction=_build_dialogue_system_prompt(),
                    tools=DIALOGUE_TOOLS,
                    automatic_function_calling=types.AutomaticFunctionCallingConfig(
                        disable=True
                    ),
                ),
            )
            candidate = (response.candidates or [None])[0]
            if candidate is None or candidate.content is None:
                raise DialogueAgentError("Google GenAI returned no candidate content")

            parts = candidate.content.parts or []
            function_calls = [
                part.function_call
                for part in parts
                if getattr(part, "function_call", None) is not None
            ]
            text = "".join(part.text or "" for part in parts if part.text).strip()

            if function_calls:
                contents.append(types.Content(role="model", parts=parts))
                responses: list[types.Part] = []
                for function_call in function_calls:
                    args = dict(function_call.args or {})
                    try:
                        result = _execute_dialogue_tool(
                            function_call.name,
                            args,
                            state=state,
                            plan=plan,
                            episode=episode,
                            previous_dialogues=previous_dialogues or [],
                            voice_profiles=voice_profiles,
                            search_tool=self._search_tool,
                            emit_event=emit_event,
                        )
                    except Exception as exc:
                        result = json.dumps({"error": str(exc)}, ensure_ascii=False)
                    responses.append(
                        types.Part.from_function_response(
                            name=function_call.name,
                            response={"result": result},
                        )
                    )
                contents.append(types.Content(role="user", parts=responses))
                if state.finalized_reply is not None and state.turns:
                    return state.turns
                continue

            if state.turns:
                return state.turns

            if text:
                extracted = _extract_json_object(text)
                if extracted is not None:
                    validation = _validate_dialogue_content(
                        extracted,
                        plan=plan,
                        episode=episode,
                    )
                    if validation.valid:
                        return validation.turns

            raise DialogueAgentError("Dialogue agent finished without producing valid dialogue")

        if state.turns:
            return state.turns
        raise DialogueAgentError("Dialogue agent reached max iterations without valid dialogue")


def build_dialogue_agent(settings: Settings) -> DialogueAgent:
    if settings.use_google_provider:
        project = (settings.google_cloud_project or "").strip()
        if not project:
            raise DialogueAgentError("GOOGLE_CLOUD_PROJECT is required to use Vertex AI")
        return GoogleGenAIDialogueAgent(
            project=project,
            location=settings.google_cloud_location,
            model=settings.google_model,
            search_tool=build_search_tool(settings),
        )
    return StubDialogueAgent()


def _build_dialogue_prompt(
    *,
    plan: ProductionPlan,
    episode: EpisodeDraft,
    voice_profiles: list[VoiceProfile],
    previous_dialogues: list[EpisodeDialogueMemory],
) -> str:
    host_lines = []
    for host in plan.show_draft.hosts[:3]:
        host_lines.append(
            json.dumps(
                {
                    "display_name": host.display_name,
                    "role": host.role,
                    "voice_profile_id": str(host.voice_profile_id) if host.voice_profile_id else None,
                    "bio": host.bio,
                    "persona_summary": host.persona_summary,
                },
                ensure_ascii=False,
            )
        )
    voice_lines = []
    for voice in voice_profiles:
        voice_lines.append(
            json.dumps(
                {
                    "id": str(voice.id),
                    "name": voice.name,
                    "provider_voice_id": voice.provider_voice_id,
                },
                ensure_ascii=False,
            )
        )
    previous_lines: list[str] = []
    for memory in previous_dialogues:
        previous_lines.append(f"Tập {memory.episode_number}: {memory.title}")
        if memory.description:
            previous_lines.append(f"Mô tả: {memory.description}")
        for turn in memory.turns:
            previous_lines.append(f"{turn.speaker}: {turn.text}")
        previous_lines.append("")

    episode_index, previous_episode, next_episode = _find_episode_neighbors(plan, episode)
    total_episodes = len(plan.episodes)
    continuity_lines = [
        f"Đây là tập {episode_index + 1}/{total_episodes}.",
        "Series phải có cảm giác là một mạch nội dung liên tục, không phải các tập rời rạc.",
        "Giữ nhất quán cách xưng hô, góc nhìn và nhịp trao đổi của host.",
        "Không lặp lại nguyên xi nội dung đã nói ở các tập trước.",
    ]
    estimated_seconds = max(1, episode.estimated_duration_seconds or 0)
    minimum_words = max(1, round((estimated_seconds / 60.0) * WORDS_PER_MINUTE))
    continuity_lines.append(
        f"Thời lượng mục tiêu tối thiểu: khoảng {_format_estimated_duration(estimated_seconds)} (~{minimum_words} từ ở {WORDS_PER_MINUTE} từ/phút)."
    )
    if previous_episode is not None:
        continuity_lines.append(
            f"Mở đầu tập này phải recap rất ngắn gọn nội dung tập trước: “{previous_episode.title}”."
        )
    else:
        continuity_lines.append("Đây là tập mở đầu nên vào thẳng vấn đề, không cần recap.")
    if next_episode is not None:
        continuity_lines.append(
            f"Cuối tập này phải có teaser ngắn cho tập tiếp theo: “{next_episode.title}”."
        )
        if next_episode.description.strip():
            continuity_lines.append(f"Teaser nên bám mô tả tập sau: {next_episode.description.strip()}")
    else:
        continuity_lines.append("Đây là tập cuối, kết tập gọn và trọn ý, không cần teaser.")

    return f"""
Series title:
{plan.series_title}

Series description:
{plan.series_description}

Format:
{plan.show_draft.content_type}

Primary category:
{plan.show_draft.primary_category}

Tone style:
{plan.tone_style or "(khong co tone style cu the)"}

Hosts:
{chr(10).join(host_lines) if host_lines else "(khong co host)"}

Allowed voice profiles:
{chr(10).join(voice_lines) if voice_lines else "(khong co voice profile)"}

Episode to write:
{json.dumps(
    {
        "episode_number": episode.episode_number,
        "title": episode.title,
        "description": episode.description,
        "estimated_duration_seconds": episode.estimated_duration_seconds,
        "notes": episode.notes,
    },
    ensure_ascii=False,
)}

Series continuity requirements:
{chr(10).join(f"- {line}" for line in continuity_lines)}

Full previous episode dialogues:
{chr(10).join(previous_lines).strip() if previous_lines else "(day la tap dau tien hoac chua co tap truoc)"}
""".strip()


def _execute_dialogue_tool(
    name: str,
    args: dict[str, Any],
    *,
    state: DialogueAgentState,
    plan: ProductionPlan,
    episode: EpisodeDraft,
    previous_dialogues: list[EpisodeDialogueMemory],
    voice_profiles: list[VoiceProfile],
    search_tool: SearchTool,
    emit_event: Callable[[dict[str, Any]], None] | None = None,
) -> str:
    if name == "brave_search":
        query = str(args.get("query", "")).strip()
        if not query:
            raise DialogueAgentError("query is required for brave_search")
        _emit_tool_status(emit_event, name, query=query)
        result = search_tool.search(query=query)
        try:
            payload = json.loads(result)
        except json.JSONDecodeError:
            state.has_searched = True
            return result
        if not (isinstance(payload, dict) and payload.get("error")):
            state.has_searched = True
        return result

    if name == "read_plan":
        _emit_tool_status(emit_event, name)
        return json.dumps(
            {
                "series_title": plan.series_title,
                "series_description": plan.series_description,
                "content_type": plan.show_draft.content_type,
                "hosts": [
                    {
                        "display_name": host.display_name,
                        "role": host.role,
                        "persona_summary": host.persona_summary,
                    }
                    for host in plan.show_draft.hosts
                ],
                "episode": {
                    "episode_number": episode.episode_number,
                    "title": episode.title,
                    "description": episode.description,
                    "notes": episode.notes,
                },
                "previous_episodes": [
                    {
                        "episode_number": memory.episode_number,
                        "title": memory.title,
                        "description": memory.description,
                        "dialogue": [
                            {
                                "speaker": turn.speaker,
                                "text": turn.text,
                            }
                            for turn in memory.turns
                        ],
                    }
                    for memory in previous_dialogues
                ],
                "next_episode": _episode_summary(_find_episode_neighbors(plan, episode)[2]),
            },
            ensure_ascii=False,
        )

    if name == "list_voice_profiles":
        _emit_tool_status(emit_event, name)
        return json.dumps(
            [
                {
                    "id": str(voice.id),
                    "name": voice.name,
                    "provider_voice_id": voice.provider_voice_id,
                    "language_code": voice.language_code,
                }
                for voice in voice_profiles
            ],
            ensure_ascii=False,
            indent=2,
        )

    if name == "write_dialogue":
        if not state.has_searched:
            return json.dumps(
                {"success": False, "error": "You must call brave_search before writing the dialogue."},
                ensure_ascii=False,
            )
        _emit_tool_status(emit_event, name)
        validation = _validate_dialogue_content(
            str(args.get("content", "")),
            plan=plan,
            episode=episode,
        )
        state.validation = validation
        state.content = validation.normalized_json if validation.valid else str(args.get("content", ""))
        state.turns = validation.turns if validation.valid else ()
        return json.dumps(_dialogue_validation_payload(validation), ensure_ascii=False)

    if name == "read_dialogue":
        _emit_tool_status(emit_event, name)
        if not state.content:
            return json.dumps({"error": "No dialogue written yet. Use write_dialogue first."}, ensure_ascii=False)
        return state.content

    if name == "edit_dialogue":
        if not state.has_searched:
            return json.dumps(
                {"success": False, "error": "You must call brave_search before editing the dialogue."},
                ensure_ascii=False,
            )
        _emit_tool_status(emit_event, name)
        if not state.content:
            return json.dumps({"error": "No dialogue written yet. Use write_dialogue first."}, ensure_ascii=False)
        operation = str(args.get("operation", "")).strip().lower()
        content = state.content
        if operation == "replace":
            search = str(args.get("search", ""))
            replacement = str(args.get("replacement", ""))
            if not search:
                raise DialogueAgentError("search is required for replace")
            if search not in content:
                raise DialogueAgentError(f'Text not found: "{search[:80]}"')
            content = content.replace(search, replacement)
        elif operation == "rewrite":
            content = str(args.get("content", ""))
        else:
            raise DialogueAgentError(f"Unknown edit_dialogue operation: {operation}")
        validation = _validate_dialogue_content(content, plan=plan, episode=episode)
        state.validation = validation
        state.content = validation.normalized_json if validation.valid else content
        state.turns = validation.turns if validation.valid else ()
        return json.dumps(_dialogue_validation_payload(validation), ensure_ascii=False)

    if name == "finalize_turn":
        if not state.has_searched:
            return json.dumps(
                {"success": False, "error": "You must call brave_search before finalizing the turn."},
                ensure_ascii=False,
            )
        if not state.turns:
            return json.dumps(
                {"success": False, "error": "You must create a valid dialogue before finalizing."},
                ensure_ascii=False,
            )
        _emit_tool_status(emit_event, name)
        message = str(args.get("message", "")).strip()
        if not message:
            raise DialogueAgentError("message is required for finalize_turn")
        state.finalized_reply = message
        return json.dumps({"success": True, "finalized": True}, ensure_ascii=False)

    raise DialogueAgentError(f"Unknown tool: {name}")


def _validate_dialogue_content(
    content: str,
    *,
    plan: ProductionPlan,
    episode: EpisodeDraft,
) -> DialogueValidation:
    errors: list[str] = []
    warnings: list[str] = []
    try:
        payload = json.loads(content)
    except json.JSONDecodeError as exc:
        return DialogueValidation(
            valid=False,
            errors=[f"JSON parse error: {exc}"],
            warnings=[],
            turns=(),
            normalized_json=None,
        )

    raw_dialogue = payload.get("dialogue")
    if not isinstance(raw_dialogue, list) or not raw_dialogue:
        return DialogueValidation(
            valid=False,
            errors=['Missing or empty "dialogue" array'],
            warnings=[],
            turns=(),
            normalized_json=None,
        )

    allowed_speakers = [
        host.display_name.strip()
        for host in plan.show_draft.hosts
        if host.display_name.strip()
    ]
    turns: list[ScriptTurn] = []
    speakers_used: set[str] = set()
    turns_with_emotion = 0
    for index, item in enumerate(raw_dialogue):
        if not isinstance(item, dict):
            errors.append(f"Turn {index + 1} must be an object")
            continue
        speaker = str(item.get("speaker", "")).strip()
        text = str(item.get("text", "")).strip()
        emotion = str(item.get("emotion", "")).strip() or None
        direction = str(item.get("direction", "")).strip() or None
        if not speaker:
            errors.append(f"Turn {index + 1}: missing speaker")
            continue
        if speaker not in allowed_speakers:
            errors.append(
                f'Turn {index + 1}: speaker "{speaker}" is not in allowed hosts: {", ".join(allowed_speakers)}'
            )
        if not text:
            errors.append(f"Turn {index + 1}: missing text")
            continue
        if emotion:
            turns_with_emotion += 1
        speakers_used.add(speaker)
        turns.append(
            ScriptTurn(
                speaker=speaker,
                text=text,
                emotion=emotion,
                direction=direction,
            )
        )

    if plan.show_draft.content_type == "podcast" and len(allowed_speakers) >= 2 and len(speakers_used) < 2:
        errors.append("Podcast dialogue must use at least 2 hosts when the show has 2 or more hosts")

    minimum_turns = 4 if plan.show_draft.content_type == "podcast" and len(allowed_speakers) >= 2 else 3
    if len(turns) < minimum_turns:
        errors.append(f"Dialogue is too short; expected at least {minimum_turns} turns for this episode")

    if turns and turns_with_emotion == 0:
        warnings.append("No emotion fields found; adding emotion or direction improves delivery")

    word_count = sum(len(re.findall(r"\w+", turn.text, flags=re.UNICODE)) for turn in turns)
    estimated_duration_seconds = round((word_count / WORDS_PER_MINUTE) * 60) if word_count > 0 else 0
    if (
        episode.estimated_duration_seconds > 0
        and estimated_duration_seconds < round(episode.estimated_duration_seconds * 0.85)
    ):
        warnings.append(
            f"Estimated duration looks short ({_format_estimated_duration(estimated_duration_seconds)}) vs target {_format_estimated_duration(episode.estimated_duration_seconds)}"
        )

    character_count = len(_build_tts_prompt(tuple(turns)))
    if character_count > MAX_DIALOGUE_CHARACTERS:
        warnings.append(
            f"Dialogue exceeds a single TTS prompt chunk ({character_count}/{MAX_DIALOGUE_CHARACTERS}); backend will split it automatically."
        )

    _, previous_episode, next_episode = _find_episode_neighbors(plan, episode)
    normalized_opening = _normalize_rule_text(" ".join(turn.text for turn in turns[:2]))
    normalized_closing = _normalize_rule_text(" ".join(turn.text for turn in turns[-2:]))
    if previous_episode is not None and not _contains_any(
        normalized_opening,
        ("tap truoc", "ky truoc", "truoc do", "vua roi", "phan truoc"),
    ):
        warnings.append("Opening turns do not seem to recap the previous episode")
    if next_episode is not None and not _contains_any(
        normalized_closing,
        ("tap sau", "ky toi", "lan toi", "phan tiep", "tiep theo"),
    ):
        warnings.append("Closing turns do not seem to tease the next episode")

    normalized_json = json.dumps(
        {
            "dialogue": [
                {
                    "speaker": turn.speaker,
                    "text": turn.text,
                    **({"emotion": turn.emotion} if turn.emotion else {}),
                    **({"direction": turn.direction} if turn.direction else {}),
                }
                for turn in turns
            ]
        },
        ensure_ascii=False,
        indent=2,
    )
    return DialogueValidation(
        valid=not errors,
        errors=errors,
        warnings=warnings,
        turns=tuple(turns),
        normalized_json=normalized_json,
    )


def _dialogue_validation_payload(validation: DialogueValidation) -> dict[str, Any]:
    word_count = sum(len(re.findall(r"\w+", turn.text, flags=re.UNICODE)) for turn in validation.turns)
    estimated_duration_seconds = round((word_count / WORDS_PER_MINUTE) * 60) if word_count > 0 else 0
    character_count = len(_build_tts_prompt(validation.turns)) if validation.turns else 0
    payload: dict[str, Any] = {
        "success": True,
        "valid": validation.valid,
        "word_count": word_count,
        "estimated_duration_seconds": estimated_duration_seconds,
        "estimated_duration_str": _format_estimated_duration(estimated_duration_seconds),
        "character_count": character_count,
        "max_character_count": MAX_DIALOGUE_CHARACTERS,
    }
    if validation.errors:
        payload["errors"] = validation.errors
    if validation.warnings:
        payload["warnings"] = validation.warnings
    if validation.valid:
        payload["turn_count"] = len(validation.turns)
    return payload


def _find_episode_neighbors(
    plan: ProductionPlan,
    episode: EpisodeDraft,
) -> tuple[int, EpisodeDraft | None, EpisodeDraft | None]:
    for index, current in enumerate(plan.episodes):
        if current is episode:
            return (
                index,
                plan.episodes[index - 1] if index > 0 else None,
                plan.episodes[index + 1] if index + 1 < len(plan.episodes) else None,
            )
        if current.episode_number == episode.episode_number:
            return (
                index,
                plan.episodes[index - 1] if index > 0 else None,
                plan.episodes[index + 1] if index + 1 < len(plan.episodes) else None,
            )
    return (0, None, plan.episodes[1] if len(plan.episodes) > 1 else None)


def _episode_summary(episode: EpisodeDraft | None) -> dict[str, Any] | None:
    if episode is None:
        return None
    return {
        "episode_number": episode.episode_number,
        "title": episode.title,
        "description": episode.description,
        "notes": episode.notes,
    }


def _format_estimated_duration(seconds: int) -> str:
    minutes, secs = divmod(max(0, seconds), 60)
    return f"{minutes}m {secs}s"


def _extract_json_object(text: str) -> str | None:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        return None
    return match.group(0)


def _normalize_rule_text(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text)
    normalized = "".join(ch for ch in normalized if not unicodedata.combining(ch))
    return re.sub(r"\s+", " ", normalized).strip().lower()


def _contains_any(text: str, needles: tuple[str, ...]) -> bool:
    return any(needle in text for needle in needles)


def _emit_tool_status(
    emit_event: Callable[[dict[str, Any]], None] | None,
    tool_name: str,
    *,
    query: str | None = None,
) -> None:
    if emit_event is None:
        return
    emit_event(
        {
            "event": "status",
            "data": {
                "phase": "tool",
                "tool": tool_name,
                "message": _tool_status_message(tool_name, query=query),
            },
        }
    )


def _tool_status_message(tool_name: str, *, query: str | None = None) -> str:
    if tool_name == "brave_search":
        return "Đang research để viết thoại..."
    if tool_name == "read_plan":
        return "Đang đọc lại context của show và episode..."
    if tool_name == "list_voice_profiles":
        return "Đang rà các voice hợp lệ cho host..."
    if tool_name == "write_dialogue":
        return "Đang viết dialogue cho episode..."
    if tool_name == "read_dialogue":
        return "Đang đọc lại draft dialogue..."
    if tool_name == "edit_dialogue":
        return "Đang chỉnh draft dialogue..."
    if tool_name == "finalize_turn":
        return "Đang chốt dialogue..."
    return "Đang xử lý bước tiếp theo..."
