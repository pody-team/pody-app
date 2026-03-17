from __future__ import annotations

import time
from collections.abc import Iterator
from typing import Any
from uuid import UUID

from .models import (
    AddThreadMessageRequest,
    AuthContext,
    ChatTurnResult,
    ChatThreadView,
    CreateThreadRequest,
    GeneratePlanRequest,
    GenerationJob,
    VoiceProfile,
)
from .planner import CreateAgent, Planner
from .repository import AIRepository


class AIService:
    def __init__(
        self,
        repository: AIRepository,
        create_agent: CreateAgent,
        planner: Planner,
        provider_name: str,
    ) -> None:
        self._repository = repository
        self._create_agent = create_agent
        self._planner = planner
        self._provider_name = provider_name

    def list_voice_profiles(self) -> list[VoiceProfile]:
        return self._repository.list_voice_profiles()

    def create_thread(self, auth: AuthContext, request: CreateThreadRequest) -> ChatThreadView:
        voices = self._repository.list_voice_profiles()
        turn = self._build_turn_result(
            prompt=request.prompt,
            requested_episode_count=_normalize_requested_episode_count(request.episode_count),
            voice_profiles=voices,
            conversation=[],
            existing_thread=None,
        )
        return self._repository.create_thread(auth, request.prompt, turn)

    def stream_create_thread(
        self,
        auth: AuthContext,
        request: CreateThreadRequest,
    ) -> Iterator[dict[str, Any]]:
        voices = self._repository.list_voice_profiles()
        for event in _build_status_events():
            yield event
        turn = self._build_turn_result(
            prompt=request.prompt,
            requested_episode_count=_normalize_requested_episode_count(request.episode_count),
            voice_profiles=voices,
            conversation=[],
            existing_thread=None,
        )
        thread = self._repository.create_thread(auth, request.prompt, turn)
        yield from self._stream_thread_result(thread)

    def get_thread(self, auth: AuthContext, thread_id: UUID) -> ChatThreadView:
        return self._repository.get_thread(auth.user_id, thread_id)

    def add_thread_message(self, auth: AuthContext, thread_id: UUID, request: AddThreadMessageRequest) -> ChatThreadView:
        existing_thread = self._repository.get_thread(auth.user_id, thread_id)
        conversation = [f"{message.role}: {message.text_content}" for message in existing_thread.messages]
        voices = self._repository.list_voice_profiles()
        turn = self._build_turn_result(
            prompt=request.message,
            requested_episode_count=_normalize_requested_episode_count(request.episode_count),
            voice_profiles=voices,
            conversation=conversation,
            existing_thread=existing_thread,
        )
        return self._repository.add_thread_message(auth, thread_id, request.message, turn)

    def stream_add_thread_message(
        self,
        auth: AuthContext,
        thread_id: UUID,
        request: AddThreadMessageRequest,
    ) -> Iterator[dict[str, Any]]:
        existing_thread = self._repository.get_thread(auth.user_id, thread_id)
        conversation = [
            f"{message.role}: {message.text_content}" for message in existing_thread.messages
        ]
        voices = self._repository.list_voice_profiles()
        for event in _build_status_events():
            yield event
        turn = self._build_turn_result(
            prompt=request.message,
            requested_episode_count=_normalize_requested_episode_count(request.episode_count),
            voice_profiles=voices,
            conversation=conversation,
            existing_thread=existing_thread,
        )
        thread = self._repository.add_thread_message(auth, thread_id, request.message, turn)
        yield from self._stream_thread_result(thread)

    def generate_episode_plan(self, auth: AuthContext, request: GeneratePlanRequest):
        voices = self._repository.list_voice_profiles()
        output = self._planner.generate(
            prompt=request.prompt,
            requested_episode_count=_normalize_requested_episode_count(request.episode_count),
            voice_profiles=voices,
            conversation=[],
            current_plan_summary=None,
        )
        return self._repository.generate_episode_plan(auth, request, output, self._provider_name)

    def get_job(self, auth: AuthContext, job_id: UUID) -> GenerationJob:
        return self._repository.get_job(auth.user_id, job_id)

    def _stream_thread_result(self, thread: ChatThreadView) -> Iterator[dict[str, Any]]:
        assistant_message = next(
            (message for message in reversed(thread.messages) if message.role == "assistant"),
            None,
        )
        if assistant_message is not None:
            for chunk in _chunk_text(assistant_message.text_content):
                yield _stream_event("assistant_delta", {"text": chunk})
                time.sleep(0.02)

        yield _stream_event("thread", {"thread": thread.model_dump(mode="json")})
        yield _stream_event("done", {"thread_id": str(thread.id)})

    def _build_turn_result(
        self,
        *,
        prompt: str,
        requested_episode_count: int | None,
        voice_profiles: list[VoiceProfile],
        conversation: list[str],
        existing_thread: ChatThreadView | None,
    ) -> ChatTurnResult:
        current_plan = existing_thread.current_plan if existing_thread is not None else None
        return self._create_agent.respond(
            prompt=prompt,
            requested_episode_count=requested_episode_count,
            voice_profiles=voice_profiles,
            conversation=conversation,
            current_thread_title=existing_thread.title if existing_thread is not None else None,
            current_plan=current_plan,
        )


def _normalize_requested_episode_count(value: int | None) -> int | None:
    if value is None:
        return None
    return max(1, value)


def _stream_event(event: str, data: dict[str, Any]) -> dict[str, Any]:
    return {"event": event, "data": data}


def _chunk_text(text: str, chunk_size: int = 22) -> list[str]:
    normalized = (text or "").strip()
    if not normalized:
        return []

    words = normalized.split()
    chunks: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        if len(candidate) <= chunk_size:
            current = candidate
            continue
        if current:
            chunks.append(f"{current} ")
        current = word

    if current:
        chunks.append(current)

    return chunks


def _build_status_events() -> list[dict[str, Any]]:
    return [
        _stream_event(
            "status",
            {"phase": "context", "message": "Dang doc y cua ban..."},
        ),
        _stream_event(
            "status",
            {"phase": "reasoning", "message": "Dang suy nghi va quyet dinh buoc tiep theo..."},
        ),
        _stream_event(
            "status",
            {"phase": "reply", "message": "Dang hoan thien phan hoi cho ban..."},
        ),
    ]
