from __future__ import annotations

from dataclasses import dataclass
import os


def _optional_env(*keys: str) -> str | None:
    for key in keys:
        value = os.getenv(key, "").strip()
        if value:
            return value
    return None


@dataclass(frozen=True)
class AIPodcastSettings:
    google_model: str
    google_tts_model: str
    google_cloud_project: str | None
    google_cloud_location: str
    brave_search_api_key: str | None
    brave_search_base_url: str
    provider_mode: str
    minio_endpoint: str | None
    minio_access_key: str | None
    minio_secret_key: str | None
    minio_region: str
    minio_public_base_url: str | None
    minio_use_ssl: bool
    article_podcast_bucket: str
    worker_poll_interval_seconds: float

    @property
    def use_google_provider(self) -> bool:
        if self.provider_mode == "google":
            return True
        if self.provider_mode == "stub":
            return False
        return bool(self.google_cloud_project)


def load_ai_podcast_settings() -> AIPodcastSettings:
    provider_mode = os.getenv("AI_PROVIDER_MODE", "auto").strip().lower() or "auto"
    if provider_mode not in {"auto", "google", "stub"}:
        raise ValueError("AI_PROVIDER_MODE must be one of auto, google, stub")

    settings = AIPodcastSettings(
        google_model=os.getenv("GOOGLE_GENAI_MODEL", "gemini-2.5-flash").strip() or "gemini-2.5-flash",
        google_tts_model=os.getenv("GOOGLE_TTS_MODEL", "gemini-2.5-flash-tts").strip() or "gemini-2.5-flash-tts",
        google_cloud_project=_optional_env("GOOGLE_CLOUD_PROJECT"),
        google_cloud_location=os.getenv("GOOGLE_CLOUD_LOCATION", "global").strip() or "global",
        brave_search_api_key=_optional_env("BRAVE_SEARCH_API_KEY"),
        brave_search_base_url=os.getenv(
            "BRAVE_SEARCH_BASE_URL",
            "https://api.search.brave.com/res/v1/web/search",
        ).strip()
        or "https://api.search.brave.com/res/v1/web/search",
        provider_mode=provider_mode,
        minio_endpoint=_optional_env("MINIO_ENDPOINT", "ARTICLE_PODCAST_MINIO_ENDPOINT"),
        minio_access_key=_optional_env("MINIO_ROOT_USER", "ARTICLE_PODCAST_MINIO_ACCESS_KEY"),
        minio_secret_key=_optional_env("MINIO_ROOT_PASSWORD", "ARTICLE_PODCAST_MINIO_SECRET_KEY"),
        minio_region=os.getenv("MINIO_REGION", "us-east-1").strip() or "us-east-1",
        minio_public_base_url=_optional_env("MINIO_PUBLIC_BASE_URL", "ARTICLE_PODCAST_MINIO_PUBLIC_BASE_URL"),
        minio_use_ssl=os.getenv("MINIO_USE_SSL", "false").strip().lower() in {"1", "true", "yes"},
        article_podcast_bucket=os.getenv("ARTICLE_PODCAST_BUCKET", "article-podcasts").strip() or "article-podcasts",
        worker_poll_interval_seconds=float(os.getenv("ARTICLE_PODCAST_WORKER_POLL_SECONDS", "1.0")),
    )

    if settings.provider_mode == "google" and not settings.google_cloud_project:
        raise ValueError("GOOGLE_CLOUD_PROJECT is required when AI_PROVIDER_MODE=google")

    return settings
