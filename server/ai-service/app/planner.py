from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any, Protocol

import httpx
from google import genai
from google.genai import types

from .config import Settings
from .models import (
    AIHostDraft,
    ChatTurnResult,
    EpisodeDraft,
    PlannerOutput,
    ProductionPlan,
    VoiceProfile,
)


class PlannerError(Exception):
    pass


class Planner(Protocol):
    def generate(
        self,
        *,
        prompt: str,
        requested_episode_count: int | None,
        voice_profiles: list[VoiceProfile],
        conversation: list[str],
        current_plan_summary: str | None = None,
    ) -> PlannerOutput: ...


class CreateAgent(Protocol):
    def respond(
        self,
        *,
        prompt: str,
        requested_episode_count: int | None,
        voice_profiles: list[VoiceProfile],
        conversation: list[str],
        current_thread_title: str | None,
        current_plan: ProductionPlan | None,
    ) -> ChatTurnResult: ...


class SearchTool(Protocol):
    def search(self, *, query: str) -> str: ...


@dataclass
class PlanValidation:
    valid: bool
    errors: list[str]
    warnings: list[str]
    output: PlannerOutput | None
    normalized_json: str | None


@dataclass
class AgentPlanState:
    content: str | None = None
    output: PlannerOutput | None = None
    validation: PlanValidation | None = None


MAX_AGENT_ITERATIONS = 12

PLAN_SYSTEM_PROMPT = """Bạn là AI Producer Agent của Pody.

Mục tiêu của bạn là tạo production plan cho một podcast/show mới bằng cơ chế tool-calling, không phải trả JSON một phát rồi kết thúc.

Quy trình bắt buộc:
1. Nếu cần research chủ đề, trend, hoặc fact mới, gọi `brave_search`.
2. Nếu cần, gọi `list_voice_profiles` để xem danh sách giọng hợp lệ.
3. Gọi `write_plan` để viết plan JSON hoàn chỉnh.
4. Nếu `write_plan` hoặc `edit_plan` trả về `plan_valid=false`, bạn BẮT BUỘC sửa tiếp cho đến khi `plan_valid=true`.
5. Chỉ khi plan đã hợp lệ, bạn mới trả lời creator bằng một đoạn tiếng Việt ngắn, súc tích, tóm tắt concept vừa tạo.

Quy tắc plan:
- Host là thuộc tính ở cấp show (`hosts`), không lặp host theo từng episode.
- `storytelling` phải có đúng 1 host kiểu `narrator` hoặc `host`.
- `podcast` nên có từ 1 đến 3 host, tùy theo creator yêu cầu. Nếu creator không nói rõ và format là podcast, bạn có thể đề xuất 2 host để tạo cảm giác đối thoại.
- `voice_profile_id` phải lấy từ danh sách voice được phép.
- Khi chủ đề cần bám dữ kiện thật hoặc xu hướng hiện tại, ưu tiên search trước rồi mới viết plan.
- Nếu creator nêu rõ số tập thì số episode phải khớp yêu cầu đó. Nếu creator không nêu rõ, bạn tự đề xuất số tập hợp lý cho concept đầu tiên.
- `thread_title` ngắn gọn, rõ nghĩa.
- `assistant_reply` là câu trả lời tiếng Việt ngắn gọn cho creator.
- `series_title`, `series_description`, `primary_category`, `hosts`, `episodes` đều phải có dữ liệu thực sự dùng được.
- Episode nên nối tiếp nhau, không trùng ý tưởng.

JSON bạn phải viết qua tool `write_plan` hoặc `edit_plan` có shape:
{
  "thread_title": "AI Builder Lab",
  "assistant_reply": "Mình đã phác thảo xong concept show...",
  "series_title": "AI Builder Lab",
  "series_description": "Mô tả ngắn cho series",
  "primary_category": "Công nghệ",
  "categories": ["Công nghệ"],
  "language_code": "vi",
  "content_type": "podcast",
  "cover_image_url": null,
  "tone_style": "sharp, practical, optimistic",
  "tags": ["ai", "builder"],
  "hosts": [
    {
      "display_name": "Nova",
      "avatar_url": null,
      "voice_profile_id": "UUID from allowed voices",
      "role": "host",
      "bio": "Mô tả ngắn về host",
      "persona_summary": "Tóm tắt phong cách nói"
    }
  ],
  "episodes": [
    {
      "episode_number": 1,
      "title": "Tên tập",
      "description": "Mô tả tập",
      "estimated_duration_seconds": 900,
      "notes": "ghi chú sản xuất",
      "status": "draft",
      "cover_image_url": null
    }
  ]
}

Khi bạn kết thúc:
- Không gọi thêm tool.
- Trả lời creator bằng tiếng Việt, tối đa khoảng 100 từ.
"""

CREATE_AGENT_SYSTEM_PROMPT = """Bạn là Pody Create Agent.

Bạn là MỘT agent duy nhất cho màn Create, không tách riêng chatbot và planner.

Mỗi lượt hội thoại, bạn phải tự quyết định một trong hai cách hành xử:
1. Chỉ trả lời như creative copilot nếu creator đang hỏi, brainstorm, xin góp ý, so sánh phương án, hoặc chưa muốn cập nhật draft chính thức.
2. Gọi tool để tạo/cập nhật production plan khi creator thực sự muốn dựng draft show hoặc sửa draft hiện có.

Nguyên tắc:
- Không tự động tạo plan chỉ vì tin nhắn nhắc đến show/podcast.
- Nếu creator chỉ muốn trò chuyện, bạn KHÔNG gọi tool nào và chỉ trả lời ngắn gọn, hữu ích bằng tiếng Việt.
- Nếu creator muốn tạo hoặc cập nhật draft chính thức, bạn có thể dùng tool.
- Khi đã dùng `write_plan` hoặc `edit_plan`, bạn PHẢI đảm bảo plan hợp lệ (`plan_valid=true`) trước khi kết thúc.
- Nếu cần research facts/trends, gọi `brave_search`.
- Nếu cần biết voice hợp lệ, gọi `list_voice_profiles`.
- Nếu đã có draft hiện tại, `read_plan` sẽ đọc bản draft đó và `edit_plan` sẽ chỉnh nó.
- Khi bạn không cần cập nhật draft, không được trả JSON.
- Khi bạn cần cập nhật draft, bạn phải dùng tool thay vì chèn plan JSON thô vào câu trả lời.

Khi kết thúc:
- nếu không cập nhật draft: trả lời tự nhiên như copilot
- nếu có cập nhật draft: trả lời ngắn gọn, tóm tắt những gì vừa thay đổi trong draft
"""

PLAN_TOOLS = [
    types.Tool(
        function_declarations=[
            types.FunctionDeclaration(
                name="brave_search",
                description=(
                    "Search the web for topic research, trends, factual context, or examples before writing the show plan."
                ),
                parameters_json_schema={
                    "type": "object",
                    "required": ["query"],
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "Search query in Vietnamese or English",
                        }
                    },
                },
            ),
            types.FunctionDeclaration(
                name="list_voice_profiles",
                description="Read the list of allowed AI voice profiles for this show plan.",
                parameters_json_schema={
                    "type": "object",
                    "properties": {},
                },
            ),
            types.FunctionDeclaration(
                name="write_plan",
                description=(
                    "Write the full show production plan JSON as a string. "
                    "The tool validates the structure and tells you whether the plan is valid."
                ),
                parameters_json_schema={
                    "type": "object",
                    "required": ["content"],
                    "properties": {
                        "content": {
                            "type": "string",
                            "description": "Complete production plan JSON string",
                        }
                    },
                },
            ),
            types.FunctionDeclaration(
                name="read_plan",
                description="Read the current plan JSON that was last written.",
                parameters_json_schema={
                    "type": "object",
                    "properties": {},
                },
            ),
            types.FunctionDeclaration(
                name="edit_plan",
                description=(
                    "Edit the current plan JSON. Use replace for targeted fixes or rewrite to replace the whole JSON."
                ),
                parameters_json_schema={
                    "type": "object",
                    "required": ["operation"],
                    "properties": {
                        "operation": {
                            "type": "string",
                            "enum": ["replace", "rewrite"],
                        },
                        "search": {
                            "type": "string",
                            "description": "Text to find when operation is replace",
                        },
                        "replacement": {
                            "type": "string",
                            "description": "Replacement text when operation is replace",
                        },
                        "content": {
                            "type": "string",
                            "description": "Full JSON string when operation is rewrite",
                        },
                    },
                },
            ),
        ]
    )
]


class StubPlanner:
    def generate(
        self,
        *,
        prompt: str,
        requested_episode_count: int | None,
        voice_profiles: list[VoiceProfile],
        conversation: list[str],
        current_plan_summary: str | None = None,
    ) -> PlannerOutput:
        _ = current_plan_summary
        prompt_lower = prompt.lower()
        selected_voice = voice_profiles[0] if voice_profiles else None

        if "sleep" in prompt_lower or "calm" in prompt_lower or "reset" in prompt_lower:
            title = "Midnight Reset"
            category = "Cham soc ban than"
            tags = ["sleep", "mindfulness", "daily-routine"]
            tone = "calm, reflective, encouraging"
            host_name = "Lumi"
        elif "crime" in prompt_lower or "mystery" in prompt_lower or "dieu tra" in prompt_lower:
            title = "Ho So Giai Ma"
            category = "Dieu tra"
            tags = ["mystery", "analysis", "storytelling"]
            tone = "curious, dramatic, investigative"
            host_name = "Minh Tra"
        elif "news" in prompt_lower or "digest" in prompt_lower or "tin" in prompt_lower:
            title = "Ban Tin De Hieu"
            category = "Giai thich de hieu"
            tags = ["news", "digest", "explainer"]
            tone = "clear, concise, modern"
            host_name = "Atlas"
        else:
            title = "AI Builder Lab"
            category = "Cong nghe"
            tags = ["ai", "builder", "startup"]
            tone = "sharp, practical, optimistic"
            host_name = "Nova"

        if selected_voice is None:
            hosts = [
                AIHostDraft(
                    display_name=host_name,
                    role="narrator" if "sleep" in prompt_lower or "story" in prompt_lower else "host",
                    bio="AI host for Pody creators.",
                )
            ]
        else:
            secondary_voice = voice_profiles[1] if len(voice_profiles) > 1 else selected_voice
            if "sleep" in prompt_lower or "calm" in prompt_lower or "reset" in prompt_lower:
                hosts = [
                    AIHostDraft(
                        display_name=selected_voice.name,
                        avatar_url=_avatar_url(selected_voice),
                        voice_profile_id=selected_voice.id,
                        role="narrator",
                        bio=f"AI persona optimized for {category.lower()} shows on Pody.",
                        persona_summary=f"{selected_voice.name} speaks in a {tone} style.",
                    )
                ]
            else:
                hosts = [
                    AIHostDraft(
                        display_name=selected_voice.name,
                        avatar_url=_avatar_url(selected_voice),
                        voice_profile_id=selected_voice.id,
                        role="host",
                        bio=f"AI persona optimized for {category.lower()} shows on Pody.",
                        persona_summary=f"{selected_voice.name} speaks in a {tone} style.",
                    ),
                    AIHostDraft(
                        display_name=secondary_voice.name if secondary_voice else f"{host_name} 2",
                        avatar_url=_avatar_url(secondary_voice) if secondary_voice else None,
                        voice_profile_id=secondary_voice.id if secondary_voice else None,
                        role="co_host",
                        bio=f"AI co-host bo sung goc nhin cho show {category.lower()}.",
                        persona_summary="Phong cach bo tro, dat cau hoi va giu nhip doi thoai.",
                    ),
                ]

        content_type = (
            "storytelling"
            if "sleep" in prompt_lower or "calm" in prompt_lower or "reset" in prompt_lower or "story" in prompt_lower
            else "podcast"
        )

        default_episode_count = 5 if content_type == "storytelling" else 6
        episode_count = requested_episode_count if requested_episode_count is not None else default_episode_count

        episodes = []
        for index in range(episode_count):
            episode_number = index + 1
            episodes.append(
                EpisodeDraft(
                    episode_number=episode_number,
                    title=f"{title} #{episode_number}",
                    description=f"Tap {episode_number} khai thac chu de '{prompt.strip() or title}' theo goc nhin {category.lower()}.",
                    estimated_duration_seconds=900 + index * 120,
                    notes="Draft generated locally while Google GenAI key is not configured.",
                    status="draft",
                )
            )

        return PlannerOutput(
            thread_title=title,
            assistant_reply=(
                "Mình đã phác thảo một concept show với cấu hình host ở cấp show, "
                "cùng danh sách tập nháp để bạn tiếp tục refine."
            ),
            series_title=title,
            series_description=f"Mot show {category.lower()} duoc thiet ke tu prompt: {prompt.strip() or title}.",
            primary_category=category,
            categories=[category],
            content_type=content_type,
            language_code="vi",
            cover_image_url=None,
            tone_style=tone,
            tags=tags,
            hosts=hosts,
            episodes=episodes,
        )


class GoogleGenAIPlanner:
    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        base_url: str | None = None,
        search_tool: SearchTool | None = None,
    ) -> None:
        self._client = _build_genai_client(api_key=api_key, base_url=base_url)
        self._model = model
        self._search_tool = search_tool or DisabledSearchTool()

    def generate(
        self,
        *,
        prompt: str,
        requested_episode_count: int | None,
        voice_profiles: list[VoiceProfile],
        conversation: list[str],
        current_plan_summary: str | None = None,
    ) -> PlannerOutput:
        contents = [
            types.Content(
                role="user",
                parts=[
                    types.Part.from_text(
                        text=_build_create_agent_prompt(
                            prompt=prompt,
                            requested_episode_count=requested_episode_count,
                            voice_profiles=voice_profiles,
                            conversation=conversation,
                            current_plan_summary=current_plan_summary,
                        )
                    )
                ],
            )
        ]
        state = AgentPlanState()

        for _ in range(MAX_AGENT_ITERATIONS):
            response = self._client.models.generate_content(
                model=self._model,
                contents=contents,
                config=types.GenerateContentConfig(
                    temperature=0.7,
                    system_instruction=PLAN_SYSTEM_PROMPT,
                    tools=PLAN_TOOLS,
                    automatic_function_calling=types.AutomaticFunctionCallingConfig(
                        disable=True
                    ),
                ),
            )

            candidate = (response.candidates or [None])[0]
            if candidate is None or candidate.content is None:
                raise PlannerError("Google GenAI returned no candidate content")

            parts = candidate.content.parts or []
            function_calls = [
                part.function_call
                for part in parts
                if getattr(part, "function_call", None) is not None
            ]
            text = "".join(part.text or "" for part in parts if part.text).strip()

            if function_calls:
                contents.append(types.Content(role="model", parts=parts))
                function_response_parts: list[types.Part] = []
                for function_call in function_calls:
                    args = dict(function_call.args or {})
                    try:
                        result = _execute_plan_tool(
                            function_call.name,
                            args,
                            state=state,
                            voice_profiles=voice_profiles,
                            requested_episode_count=requested_episode_count,
                            search_tool=self._search_tool,
                        )
                    except Exception as exc:
                        result = json.dumps({"error": str(exc)}, ensure_ascii=False)
                    function_response_parts.append(
                        types.Part.from_function_response(
                            name=function_call.name,
                            response={"result": result},
                        )
                    )

                contents.append(
                    types.Content(role="user", parts=function_response_parts)
                )
                continue

            if state.output is None and text:
                extracted = _extract_json_object(text)
                if extracted is not None:
                    validation = _validate_planner_content(
                        extracted,
                        voice_profiles=voice_profiles,
                        requested_episode_count=requested_episode_count,
                    )
                    state.validation = validation
                    if validation.valid and validation.output is not None:
                        state.output = validation.output
                        state.content = validation.normalized_json

            if state.output is None:
                raise PlannerError(
                    "Agent finished without producing a valid production plan"
                )

            final_output = state.output.model_copy(deep=True)
            if text:
                final_output.assistant_reply = text
            elif not final_output.assistant_reply.strip():
                final_output.assistant_reply = _default_assistant_reply(final_output)
            if not final_output.thread_title.strip():
                final_output.thread_title = final_output.series_title
            return final_output

        if state.output is None:
            raise PlannerError("Agent reached max iterations without a valid plan")

        final_output = state.output.model_copy(deep=True)
        if not final_output.assistant_reply.strip():
            final_output.assistant_reply = _default_assistant_reply(final_output)
        if not final_output.thread_title.strip():
            final_output.thread_title = final_output.series_title
        return final_output


class StubCreateAgent:
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
        should_plan = _should_create_or_update_plan(
            prompt=prompt,
            conversation=conversation,
            current_plan=current_plan,
        )
        if should_plan:
            output = StubPlanner().generate(
                prompt=prompt,
                requested_episode_count=requested_episode_count,
                voice_profiles=voice_profiles,
                conversation=conversation,
                current_plan_summary=_current_plan_summary(current_plan),
            )
            return ChatTurnResult(
                thread_title=output.thread_title.strip() or output.series_title,
                assistant_reply=output.assistant_reply,
                plan_output=output,
            )

        return ChatTurnResult(
            thread_title=_derive_thread_title(prompt, current_thread_title),
            assistant_reply=_default_chat_reply(current_plan),
            plan_output=None,
        )


class GoogleGenAICreateAgent:
    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        base_url: str | None = None,
        search_tool: SearchTool | None = None,
    ) -> None:
        self._client = _build_genai_client(api_key=api_key, base_url=base_url)
        self._model = model
        self._search_tool = search_tool or DisabledSearchTool()
        self._planner_fallback = GoogleGenAIPlanner(
            api_key=api_key,
            model=model,
            base_url=base_url,
            search_tool=self._search_tool,
        )

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
        contents = [
            types.Content(
                role="user",
                parts=[
                    types.Part.from_text(
                        text=_build_create_agent_prompt(
                            prompt=prompt,
                            requested_episode_count=requested_episode_count,
                            voice_profiles=voice_profiles,
                            conversation=conversation,
                            current_plan_summary=_current_plan_summary(current_plan),
                        )
                    )
                ],
            )
        ]
        state = _seed_agent_state(
            current_plan=current_plan,
            voice_profiles=voice_profiles,
            requested_episode_count=requested_episode_count,
        )

        for _ in range(MAX_AGENT_ITERATIONS):
            response = self._client.models.generate_content(
                model=self._model,
                contents=contents,
                config=types.GenerateContentConfig(
                    temperature=0.7,
                    system_instruction=CREATE_AGENT_SYSTEM_PROMPT,
                    tools=PLAN_TOOLS,
                    automatic_function_calling=types.AutomaticFunctionCallingConfig(
                        disable=True
                    ),
                ),
            )

            candidate = (response.candidates or [None])[0]
            if candidate is None or candidate.content is None:
                raise PlannerError("Google GenAI returned no candidate content")

            parts = candidate.content.parts or []
            function_calls = [
                part.function_call
                for part in parts
                if getattr(part, "function_call", None) is not None
            ]
            text = "".join(part.text or "" for part in parts if part.text).strip()

            if function_calls:
                contents.append(types.Content(role="model", parts=parts))
                function_response_parts: list[types.Part] = []
                for function_call in function_calls:
                    args = dict(function_call.args or {})
                    try:
                        result = _execute_plan_tool(
                            function_call.name,
                            args,
                            state=state,
                            voice_profiles=voice_profiles,
                            requested_episode_count=requested_episode_count,
                            search_tool=self._search_tool,
                        )
                    except Exception as exc:
                        result = json.dumps({"error": str(exc)}, ensure_ascii=False)
                    function_response_parts.append(
                        types.Part.from_function_response(
                            name=function_call.name,
                            response={"result": result},
                        )
                    )

                contents.append(types.Content(role="user", parts=function_response_parts))
                continue

            if state.output is not None:
                final_output = state.output.model_copy(deep=True)
                if text:
                    final_output.assistant_reply = text
                elif not final_output.assistant_reply.strip():
                    final_output.assistant_reply = _default_assistant_reply(final_output)
                if not final_output.thread_title.strip():
                    final_output.thread_title = final_output.series_title
                return ChatTurnResult(
                    thread_title=final_output.thread_title,
                    assistant_reply=final_output.assistant_reply,
                    plan_output=final_output,
                )

            if text:
                if _should_create_or_update_plan(
                    prompt=prompt,
                    conversation=conversation,
                    current_plan=current_plan,
                ):
                    fallback_output = self._planner_fallback.generate(
                        prompt=prompt,
                        requested_episode_count=requested_episode_count,
                        voice_profiles=voice_profiles,
                        conversation=conversation,
                        current_plan_summary=_current_plan_summary(current_plan),
                    )
                    return ChatTurnResult(
                        thread_title=fallback_output.thread_title.strip()
                        or fallback_output.series_title,
                        assistant_reply=fallback_output.assistant_reply,
                        plan_output=fallback_output,
                    )
                return ChatTurnResult(
                    thread_title=_derive_thread_title(prompt, current_thread_title),
                    assistant_reply=text,
                    plan_output=None,
                )

        if state.output is not None:
            final_output = state.output.model_copy(deep=True)
            if not final_output.assistant_reply.strip():
                final_output.assistant_reply = _default_assistant_reply(final_output)
            if not final_output.thread_title.strip():
                final_output.thread_title = final_output.series_title
            return ChatTurnResult(
                thread_title=final_output.thread_title,
                assistant_reply=final_output.assistant_reply,
                plan_output=final_output,
            )

        raise PlannerError("Agent reached max iterations without producing a reply")


def build_planner(settings: Settings) -> Planner:
    if settings.use_google_provider:
        api_key = settings.google_api_key or "proxy-placeholder"
        return GoogleGenAIPlanner(
            api_key=api_key,
            model=settings.google_model,
            base_url=settings.google_base_url,
            search_tool=build_search_tool(settings),
        )
    return StubPlanner()


def build_create_agent(settings: Settings) -> CreateAgent:
    if settings.use_google_provider:
        api_key = settings.google_api_key or "proxy-placeholder"
        return GoogleGenAICreateAgent(
            api_key=api_key,
            model=settings.google_model,
            base_url=settings.google_base_url,
            search_tool=build_search_tool(settings),
        )
    return StubCreateAgent()


class DisabledSearchTool:
    def search(self, *, query: str) -> str:
        return json.dumps(
            {
                "error": "Brave search is not configured. Set BRAVE_SEARCH_API_KEY to enable research.",
                "query": query,
            },
            ensure_ascii=False,
        )


class BraveSearchTool:
    def __init__(self, *, api_key: str, base_url: str) -> None:
        self._api_key = api_key
        self._base_url = base_url

    def search(self, *, query: str) -> str:
        response = httpx.get(
            self._base_url,
            params={
                "q": query,
                "count": 5,
                "country": "VN",
                "search_lang": "vi",
                "text_decorations": "false",
            },
            headers={
                "Accept": "application/json",
                "X-Subscription-Token": self._api_key,
            },
            timeout=15.0,
        )
        response.raise_for_status()
        payload = response.json()
        results = []
        for item in (payload.get("web", {}) or {}).get("results", [])[:5]:
            if not isinstance(item, dict):
                continue
            results.append(
                {
                    "title": str(item.get("title") or "").strip(),
                    "url": str(item.get("url") or "").strip(),
                    "description": str(item.get("description") or "").strip(),
                }
            )
        return json.dumps({"query": query, "results": results}, ensure_ascii=False, indent=2)


def build_search_tool(settings: Settings) -> SearchTool:
    if not settings.brave_search_api_key:
        return DisabledSearchTool()
    return BraveSearchTool(
        api_key=settings.brave_search_api_key,
        base_url=settings.brave_search_base_url,
    )


def _build_genai_client(*, api_key: str, base_url: str | None) -> genai.Client:
    http_options = None
    if base_url:
        http_options = types.HttpOptions(baseUrl=base_url)
    return genai.Client(api_key=api_key, http_options=http_options)


def _build_create_agent_prompt(
    *,
    prompt: str,
    requested_episode_count: int | None,
    voice_profiles: list[VoiceProfile],
    conversation: list[str],
    current_plan_summary: str | None,
) -> str:
    voice_lines = []
    for voice in voice_profiles:
        voice_lines.append(
            json.dumps(
                {
                    "id": str(voice.id),
                    "name": voice.name,
                    "provider_voice_id": voice.provider_voice_id,
                    "language_code": voice.language_code,
                    "gender": voice.gender,
                    "avatar_url": _avatar_url(voice),
                },
                ensure_ascii=False,
            )
        )

    conversation_block = "\n".join(conversation[-8:]) if conversation else "(khong co lich su hoi thoai)"

    requested_episode_count_block = (
        str(requested_episode_count)
        if requested_episode_count is not None
        else "(khong chi dinh, ban tu de xuat so tap hop ly)"
    )

    return f"""
Creator prompt:
{prompt.strip()}

So episode creator yeu cau:
{requested_episode_count_block}

Lich su hoi thoai gan day:
{conversation_block}

Production plan hien tai:
{current_plan_summary or "(chua co production plan hien tai)"}

Danh sach voice profiles duoc phep dung:
{chr(10).join(voice_lines) if voice_lines else "(khong co voice profile nao)"}
""".strip()

def _current_plan_summary(plan: ProductionPlan | None) -> str | None:
    if plan is None:
        return None

    host_names = ", ".join(host.display_name for host in plan.show_draft.hosts[:3]) or "chua co host"
    episode_titles = ", ".join(episode.title for episode in plan.episodes[:3]) or "chua co episode"
    return (
        f"Series: {plan.series_title}\n"
        f"Format: {plan.show_draft.content_type}\n"
        f"Category: {plan.show_draft.primary_category}\n"
        f"Hosts: {host_names}\n"
        f"Episodes: {episode_titles}"
    )


def _seed_agent_state(
    *,
    current_plan: ProductionPlan | None,
    voice_profiles: list[VoiceProfile],
    requested_episode_count: int | None,
) -> AgentPlanState:
    if current_plan is None:
        return AgentPlanState()

    output = _planner_output_from_plan(current_plan)
    validation = _validate_planner_content(
        json.dumps(output.model_dump(mode="json", exclude_none=True), ensure_ascii=False),
        voice_profiles=voice_profiles,
        requested_episode_count=requested_episode_count,
    )
    return AgentPlanState(
        content=validation.normalized_json,
        output=validation.output or output,
        validation=validation,
    )


def _planner_output_from_plan(plan: ProductionPlan) -> PlannerOutput:
    return PlannerOutput(
        thread_title=plan.series_title,
        assistant_reply=_default_assistant_reply(
            PlannerOutput(
                thread_title=plan.series_title,
                assistant_reply="",
                series_title=plan.series_title,
                series_description=plan.series_description,
                primary_category=plan.show_draft.primary_category,
                categories=plan.show_draft.categories,
                language_code=plan.target_language_code,
                content_type=plan.show_draft.content_type,
                cover_image_url=plan.show_draft.cover_image_url,
                tone_style=plan.tone_style or "",
                tags=plan.tags,
                hosts=plan.show_draft.hosts,
                episodes=plan.episodes,
            )
        ),
        series_title=plan.series_title,
        series_description=plan.series_description,
        primary_category=plan.show_draft.primary_category,
        categories=plan.show_draft.categories,
        language_code=plan.target_language_code,
        content_type=plan.show_draft.content_type,
        cover_image_url=plan.show_draft.cover_image_url,
        tone_style=plan.tone_style or "",
        tags=plan.tags,
        hosts=plan.show_draft.hosts,
        episodes=plan.episodes,
    )


def _derive_thread_title(prompt: str, current_thread_title: str | None) -> str:
    if current_thread_title and current_thread_title.strip():
        return current_thread_title

    compact = re.sub(r"\s+", " ", (prompt or "")).strip(" \n\t.,!?;:-")
    if not compact:
        return "New Chat"
    if len(compact) > 60:
        return f"{compact[:57].rstrip()}..."
    return compact[:1].upper() + compact[1:]


def _default_chat_reply(current_plan: ProductionPlan | None) -> str:
    if current_plan is not None:
        return (
            "Mình đang giữ bản draft hiện tại cho bạn. "
            "Nếu muốn, mình có thể góp ý tiếp về format, host, tone hoặc audience trước khi mình cập nhật plan."
        )
    return (
        "Mình có thể brainstorm cùng bạn trước. "
        "Bạn muốn show này dành cho ai, theo format podcast hay storytelling, và cảm giác người nghe nhận được là gì?"
    )


_PLAN_ACTION_KEYWORDS = (
    "tao",
    "tạo",
    "build",
    "generate",
    "draft",
    "phac thao",
    "phác thảo",
    "len plan",
    "lên plan",
    "outline",
    "dung",
    "dựng",
    "lap plan",
    "lập plan",
    "viet concept",
    "viết concept",
    "tao show",
    "tạo show",
)

_PLAN_SUBJECT_KEYWORDS = (
    "show",
    "podcast",
    "storytelling",
    "series",
    "title",
    "tieu de",
    "tiêu đề",
    "description",
    "mo ta",
    "mô tả",
    "tone",
    "category",
    "episode",
    "tap",
    "tập",
    "host",
    "co-host",
    "co host",
    "lineup",
    "concept",
    "format",
    "season",
)

_PLAN_REVISE_KEYWORDS = (
    "doi",
    "đổi",
    "sua",
    "sửa",
    "them",
    "thêm",
    "bot",
    "bớt",
    "refine",
    "revise",
    "adjust",
    "cap nhat",
    "cập nhật",
    "rut gon",
    "rút gọn",
    "mo rong",
    "mở rộng",
)


def _should_create_or_update_plan(
    *,
    prompt: str,
    conversation: list[str],
    current_plan: ProductionPlan | None,
) -> bool:
    normalized_prompt = re.sub(r"\s+", " ", (prompt or "").strip().lower())
    has_plan_subject = any(keyword in normalized_prompt for keyword in _PLAN_SUBJECT_KEYWORDS)
    has_plan_action = any(keyword in normalized_prompt for keyword in _PLAN_ACTION_KEYWORDS)
    has_revise_action = any(keyword in normalized_prompt for keyword in _PLAN_REVISE_KEYWORDS)

    if current_plan is not None and has_revise_action and (
        has_plan_subject or "draft" in normalized_prompt or "plan" in normalized_prompt
    ):
        return True

    if has_plan_action and has_plan_subject:
        return True

    if current_plan is not None and any(
        phrase in normalized_prompt
        for phrase in (
            "lam luon",
            "làm luôn",
            "chot ban nay",
            "chốt bản này",
            "tao ban draft",
            "tạo bản draft",
        )
    ):
        return True

    if not conversation and has_plan_subject and not has_plan_action:
        return False

    return False


def _execute_plan_tool(
    name: str,
    args: dict[str, Any],
    *,
    state: AgentPlanState,
    voice_profiles: list[VoiceProfile],
    requested_episode_count: int | None,
    search_tool: SearchTool,
) -> str:
    if name == "brave_search":
        query = str(args.get("query", "")).strip()
        if not query:
            raise PlannerError("query is required for brave_search")
        return search_tool.search(query=query)

    if name == "list_voice_profiles":
        payload = [
            {
                "id": str(voice.id),
                "name": voice.name,
                "provider_voice_id": voice.provider_voice_id,
                "language_code": voice.language_code,
                "gender": voice.gender,
                "avatar_url": _avatar_url(voice),
            }
            for voice in voice_profiles
        ]
        return json.dumps(payload, ensure_ascii=False, indent=2)

    if name == "write_plan":
        content = str(args.get("content", ""))
        validation = _validate_planner_content(
            content,
            voice_profiles=voice_profiles,
            requested_episode_count=requested_episode_count,
        )
        state.validation = validation
        state.content = validation.normalized_json if validation.valid else content
        state.output = validation.output if validation.valid else None
        return json.dumps(
            _validation_payload(validation),
            ensure_ascii=False,
        )

    if name == "read_plan":
        if not state.content:
            return json.dumps(
                {"error": "No plan written yet. Use write_plan first."},
                ensure_ascii=False,
            )
        return state.content

    if name == "edit_plan":
        if not state.content:
            return json.dumps(
                {"error": "No plan written yet. Use write_plan first."},
                ensure_ascii=False,
            )

        operation = str(args.get("operation", "")).strip().lower()
        content = state.content
        if operation == "replace":
            search = str(args.get("search", ""))
            replacement = str(args.get("replacement", ""))
            if not search:
                raise PlannerError("search is required for replace")
            if search not in content:
                raise PlannerError(f'Text not found: "{search[:80]}"')
            content = content.replace(search, replacement)
        elif operation == "rewrite":
            content = str(args.get("content", ""))
        else:
            raise PlannerError(f"Unknown edit_plan operation: {operation}")

        validation = _validate_planner_content(
            content,
            voice_profiles=voice_profiles,
            requested_episode_count=requested_episode_count,
        )
        state.validation = validation
        state.content = validation.normalized_json if validation.valid else content
        state.output = validation.output if validation.valid else None
        return json.dumps(
            _validation_payload(validation),
            ensure_ascii=False,
        )

    raise PlannerError(f"Unknown tool: {name}")


def _validation_payload(validation: PlanValidation) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "success": True,
        "plan_valid": validation.valid,
    }
    if validation.errors:
        payload["plan_errors"] = validation.errors
    if validation.warnings:
        payload["plan_warnings"] = validation.warnings
    return payload


def _validate_planner_content(
    content: str,
    *,
    voice_profiles: list[VoiceProfile],
    requested_episode_count: int | None,
) -> PlanValidation:
    errors: list[str] = []
    warnings: list[str] = []

    try:
        data = json.loads(content)
    except json.JSONDecodeError as exc:
        return PlanValidation(
            valid=False,
            errors=[f"JSON parse error: {exc.msg}"],
            warnings=[],
            output=None,
            normalized_json=None,
        )

    try:
        output = PlannerOutput.model_validate(data)
    except Exception as exc:
        return PlanValidation(
            valid=False,
            errors=[f"PlannerOutput validation error: {exc}"],
            warnings=[],
            output=None,
            normalized_json=None,
        )

    output = _normalize_output(output, voice_profiles)

    if not output.thread_title.strip():
        warnings.append('Missing "thread_title" -> defaulted from "series_title"')
        output.thread_title = output.series_title

    if not output.assistant_reply.strip():
        warnings.append('Missing "assistant_reply" -> auto generated')
        output.assistant_reply = _default_assistant_reply(output)

    if not output.series_title.strip():
        errors.append('Missing or empty "series_title"')
    if not output.series_description.strip():
        errors.append('Missing or empty "series_description"')
    if not output.primary_category.strip():
        errors.append('Missing or empty "primary_category"')
    if not output.hosts:
        errors.append('Missing or empty "hosts"')
    if output.content_type == "storytelling" and len(output.hosts) != 1:
        errors.append('Storytelling shows must have exactly 1 host')
    if output.content_type == "podcast" and len(output.hosts) > 3:
        errors.append('Podcast shows support at most 3 hosts in v1')

    if requested_episode_count is not None and len(output.episodes) != requested_episode_count:
        errors.append(
            f'Expected exactly {requested_episode_count} episodes, got {len(output.episodes)}'
        )
    if not output.episodes:
        errors.append('Missing or empty "episodes"')
    if len(output.episodes) > 12:
        errors.append('Episode count exceeds max 12 in v1')

    normalized_episodes = []
    for index, episode in enumerate(output.episodes):
        episode_number = index + 1
        if episode.episode_number != episode_number:
            warnings.append(
                f'Episode numbering normalized from {episode.episode_number} to {episode_number}'
            )
            episode.episode_number = episode_number

        if not episode.title.strip():
            errors.append(f'Episode {episode_number}: missing "title"')
        if not episode.description.strip():
            errors.append(f'Episode {episode_number}: missing "description"')
        if episode.estimated_duration_seconds <= 0:
            warnings.append(
                f'Episode {episode_number}: invalid duration -> defaulted to 900 seconds'
            )
            episode.estimated_duration_seconds = 900
        normalized_episodes.append(episode)
    output.episodes = normalized_episodes

    for index, host in enumerate(output.hosts):
        if not host.display_name.strip():
            errors.append(f'Host {index + 1}: missing "display_name"')
        if not host.role.strip():
            errors.append(f'Host {index + 1}: missing "role"')

    normalized_json = json.dumps(
        output.model_dump(mode="json", exclude_none=True),
        ensure_ascii=False,
        indent=2,
    )

    return PlanValidation(
        valid=not errors,
        errors=errors,
        warnings=warnings,
        output=output if not errors else None,
        normalized_json=normalized_json if not errors else None,
    )


def _extract_json_object(text: str) -> str | None:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match:
        return match.group(0)
    return None


def _default_assistant_reply(output: PlannerOutput) -> str:
    return (
        f"Mình đã dựng xong concept cho show \"{output.series_title}\" với "
        f"{len(output.hosts)} host ở cấp show và {len(output.episodes)} tập mở đầu để bạn tiếp tục refine."
    )


def _avatar_url(voice: VoiceProfile) -> str | None:
    value = voice.metadata.get("avatar_url")
    if isinstance(value, str) and value.strip():
        return value.strip()
    return None


def _normalize_output(output: PlannerOutput, voice_profiles: list[VoiceProfile]) -> PlannerOutput:
    role_map = {
        "host": "host",
        "co_host": "co_host",
        "co-host": "co_host",
        "guest": "guest",
        "narrator": "narrator",
        "nguoi dan chuong trinh": "host",
        "nguoi dan": "host",
        "host chinh": "host",
        "dong host": "co_host",
        "khach moi": "guest",
        "nguoi ke chuyen": "narrator",
    }
    allowed_voice_ids = {str(voice.id): voice for voice in voice_profiles}
    used_voice_ids: set[str] = set()
    normalized_hosts: list[AIHostDraft] = []
    default_role = "narrator" if output.content_type == "storytelling" else "host"

    for index, host in enumerate(output.hosts):
        role = (host.role or "").strip().lower()
        normalized_role = role_map.get(role, default_role if index == 0 else "co_host")

        voice_profile = None
        if host.voice_profile_id is not None:
            voice_profile = allowed_voice_ids.get(str(host.voice_profile_id))
        if voice_profile is None:
            for candidate in voice_profiles:
                candidate_id = str(candidate.id)
                if candidate_id not in used_voice_ids:
                    voice_profile = candidate
                    break
        if voice_profile is None and voice_profiles:
            voice_profile = voice_profiles[min(index, len(voice_profiles) - 1)]

        host.role = normalized_role
        if voice_profile is not None:
            host.voice_profile_id = voice_profile.id
            used_voice_ids.add(str(voice_profile.id))
            if not host.avatar_url:
                host.avatar_url = _avatar_url(voice_profile)
            if not host.display_name.strip():
                host.display_name = voice_profile.name
        normalized_hosts.append(host)

    if not normalized_hosts and voice_profiles:
        fallback_voice = voice_profiles[0]
        normalized_hosts = [
            AIHostDraft(
                display_name=fallback_voice.name,
                avatar_url=_avatar_url(fallback_voice),
                voice_profile_id=fallback_voice.id,
                role=default_role,
                bio="AI host generated from fallback voice profile.",
            )
        ]

    output.hosts = normalized_hosts

    if not output.categories:
        output.categories = [output.primary_category]

    return output
