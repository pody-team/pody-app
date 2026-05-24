from __future__ import annotations

from dataclasses import dataclass
import os


def _required_env(key: str) -> str:
    value = os.getenv(key, "").strip()
    if not value:
        raise ValueError(f"{key} is required")
    return value


def _optional_env(*keys: str) -> str | None:
    for key in keys:
        value = os.getenv(key, "").strip()
        if value:
            return value
    return None


@dataclass(frozen=True)
class Settings:
    database_url: str
    content_database_url: str
    port: int
    google_model: str
    google_tts_model: str
    google_cloud_project: str | None
    google_cloud_location: str
    google_cloud_storage_bucket: str | None
    google_cloud_storage_public_base_url: str | None
    notification_service_url: str | None
    notification_internal_api_key: str | None
    brave_search_api_key: str | None
    brave_search_base_url: str
    transcript_alignment_mode: str
    transcript_timeout_seconds: int
    provider_mode: str

    @property
    def use_google_provider(self) -> bool:
        if self.provider_mode == "google":
            return True
        if self.provider_mode == "stub":
            return False
        return bool(self.google_cloud_project)


def load_settings() -> Settings:
    provider_mode = os.getenv("AI_PROVIDER_MODE", "auto").strip().lower() or "auto"
    if provider_mode not in {"auto", "google", "stub"}:
        raise ValueError("AI_PROVIDER_MODE must be one of auto, google, stub")

    settings = Settings(
        database_url=_required_env("DATABASE_URL"),
        content_database_url=_required_env("CONTENT_DATABASE_URL"),
        port=int(os.getenv("PORT", "8085")),
        google_model=os.getenv("GOOGLE_GENAI_MODEL", "gemini-3.5-flash").strip() or "gemini-3.5-flash",
        google_tts_model=os.getenv("GOOGLE_TTS_MODEL", "gemini-2.5-flash-tts").strip() or "gemini-2.5-flash-tts",
        google_cloud_project=_optional_env("GOOGLE_CLOUD_PROJECT"),
        google_cloud_location=os.getenv("GOOGLE_CLOUD_LOCATION", "global").strip() or "global",
        google_cloud_storage_bucket=_optional_env("GOOGLE_CLOUD_STORAGE_BUCKET"),
        google_cloud_storage_public_base_url=_optional_env("GOOGLE_CLOUD_STORAGE_PUBLIC_BASE_URL"),
        notification_service_url=_optional_env("NOTIFICATION_SERVICE_URL"),
        notification_internal_api_key=_optional_env("NOTIFICATION_INTERNAL_API_KEY"),
        brave_search_api_key=_optional_env("BRAVE_SEARCH_API_KEY"),
        brave_search_base_url=os.getenv(
            "BRAVE_SEARCH_BASE_URL",
            "https://api.search.brave.com/res/v1/web/search",
        ).strip()
        or "https://api.search.brave.com/res/v1/web/search",
        transcript_alignment_mode=os.getenv("TRANSCRIPT_ALIGNMENT_MODE", "auto").strip().lower() or "auto",
        transcript_timeout_seconds=int(os.getenv("TRANSCRIPT_TIMEOUT_SECONDS", "900")),
        provider_mode=provider_mode,
    )

    if settings.provider_mode == "google" and not settings.google_cloud_project:
        raise ValueError("GOOGLE_CLOUD_PROJECT is required when AI_PROVIDER_MODE=google")

    return settings
