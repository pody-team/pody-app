from __future__ import annotations

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


# AuthContext chứa thông tin người dùng đã xác thực do API Gateway truyền xuống qua header.
class AuthContext(BaseModel):
    user_id: UUID
    email: str | None = None
    name: str | None = None


class HealthResponse(BaseModel):
    status: str


# VoiceProfile mô tả một giọng đọc AI có thể được chọn khi tạo host hoặc sinh audio podcast.
class VoiceProfile(BaseModel):
    id: UUID
    name: str
    provider: str
    provider_voice_id: str
    language_code: str
    gender: str
    sample_audio_url: str | None = None
    cost_credits_per_minute: int = 0
    is_active: bool = True
    metadata: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime | None = None
    updated_at: datetime | None = None


# AIHostDraft là bản nháp nhân vật host AI trong production plan.
class AIHostDraft(BaseModel):
    display_name: str
    avatar_url: str | None = None
    voice_profile_id: UUID | None = None
    role: str = "host"
    bio: str = ""
    persona_summary: str | None = None


# EpisodeDraft lưu thông tin bản nháp của từng tập podcast trước khi được tạo thành episode thật.
class EpisodeDraft(BaseModel):
    id: UUID | None = None
    episode_number: int
    title: str
    description: str
    estimated_duration_seconds: int = 900
    notes: str = ""
    status: str = "draft"
    cover_image_url: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


# ShowDraft chứa cấu trúc show/podcast do AI đề xuất trước khi ghi sang Content Service.
class ShowDraft(BaseModel):
    id: UUID | None = None
    slug: str
    title: str
    description: str
    cover_image_url: str | None = None
    primary_category: str
    categories: list[str] = Field(default_factory=list)
    language_code: str = "vi"
    content_type: str = "podcast"
    hosts: list[AIHostDraft] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)

    @property
    def primary_host(self) -> AIHostDraft | None:
        return self.hosts[0] if self.hosts else None


# ProductionPlan là kế hoạch sản xuất tổng thể gồm show draft, danh sách tập, host và metadata.
class ProductionPlan(BaseModel):
    id: UUID
    thread_id: UUID | None = None
    status: str
    series_title: str
    series_description: str
    tone_style: str = ""
    target_language_code: str = "vi"
    show_draft: ShowDraft
    episodes: list[EpisodeDraft] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime
    completed_at: datetime | None = None


# ChatMessage biểu diễn một tin nhắn user/assistant/system trong luồng tạo nội dung bằng AI.
class ChatMessage(BaseModel):
    id: UUID
    role: str
    text_content: str
    created_at: datetime


class ChatThreadView(BaseModel):
    id: UUID
    title: str
    status: str
    created_at: datetime
    updated_at: datetime
    messages: list[ChatMessage] = Field(default_factory=list)
    current_plan: ProductionPlan | None = None


class ChatThreadSummary(BaseModel):
    id: UUID
    title: str
    status: str
    created_at: datetime
    updated_at: datetime
    last_message_preview: str | None = None
    has_current_plan: bool = False


class ProductionPlanSummary(BaseModel):
    id: UUID
    thread_id: UUID | None = None
    status: str
    series_title: str
    content_type: str = "podcast"
    episode_count: int = 0
    created_at: datetime
    updated_at: datetime


# GenerationJob theo dõi trạng thái các tác vụ sinh plan, tạo show, sinh audio và transcript.
class GenerationJob(BaseModel):
    id: UUID
    plan_id: UUID
    episode_draft_id: UUID | None = None
    job_type: str
    status: str
    provider: str | None = None
    input_payload: dict[str, Any] = Field(default_factory=dict)
    output_payload: dict[str, Any] = Field(default_factory=dict)
    error_message: str | None = None
    started_at: datetime | None = None
    finished_at: datetime | None = None
    created_at: datetime


class CreateThreadRequest(BaseModel):
    prompt: str
    episode_count: int | None = None


class AddThreadMessageRequest(BaseModel):
    message: str
    episode_count: int | None = None


class GeneratePlanRequest(BaseModel):
    prompt: str
    episode_count: int | None = None


# PlannerOutput là JSON chuẩn mà AI Planner phải trả về sau khi xử lý prompt của creator.
class PlannerOutput(BaseModel):
    thread_title: str
    assistant_reply: str
    series_title: str
    series_description: str
    primary_category: str
    categories: list[str] = Field(default_factory=list)
    language_code: str = "vi"
    content_type: str = "podcast"
    cover_image_url: str | None = None
    tone_style: str = ""
    tags: list[str] = Field(default_factory=list)
    hosts: list[AIHostDraft] = Field(default_factory=list)
    episodes: list[EpisodeDraft] = Field(default_factory=list)


class ChatTurnResult(BaseModel):
    thread_title: str
    assistant_reply: str
    plan_output: PlannerOutput | None = None


class VoiceProfilesResponse(BaseModel):
    voice_profiles: list[VoiceProfile] = Field(default_factory=list)


class ChatThreadResponse(BaseModel):
    thread: ChatThreadView


class ChatThreadListResponse(BaseModel):
    threads: list[ChatThreadSummary] = Field(default_factory=list)


class ProductionPlanResponse(BaseModel):
    draft: ProductionPlan


class ProductionPlansResponse(BaseModel):
    drafts: list[ProductionPlanSummary] = Field(default_factory=list)


class GeneratePlanResponse(BaseModel):
    plan: ProductionPlan
    job: GenerationJob


class GenerationJobResponse(BaseModel):
    job: GenerationJob
