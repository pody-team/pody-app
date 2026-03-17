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
    port: int
    google_api_key: str | None
    google_model: str
    google_base_url: str | None
    brave_search_api_key: str | None
    brave_search_base_url: str
    provider_mode: str

    @property
    def use_google_provider(self) -> bool:
        if self.provider_mode == "google":
            return True
        if self.provider_mode == "stub":
            return False
        return bool(self.google_api_key or self.google_base_url)


def load_settings() -> Settings:
    provider_mode = os.getenv("AI_PROVIDER_MODE", "auto").strip().lower() or "auto"
    if provider_mode not in {"auto", "google", "stub"}:
        raise ValueError("AI_PROVIDER_MODE must be one of auto, google, stub")

    return Settings(
        database_url=_required_env("DATABASE_URL"),
        port=int(os.getenv("PORT", "8085")),
        google_api_key=_optional_env("GOOGLE_API_KEY", "GEMINI_API_KEY"),
        google_model=os.getenv("GOOGLE_GENAI_MODEL", "gemini-2.5-flash").strip() or "gemini-2.5-flash",
        google_base_url=_optional_env("GOOGLE_GENAI_BASE_URL"),
        brave_search_api_key=_optional_env("BRAVE_SEARCH_API_KEY"),
        brave_search_base_url=os.getenv(
            "BRAVE_SEARCH_BASE_URL",
            "https://api.search.brave.com/res/v1/web/search",
        ).strip()
        or "https://api.search.brave.com/res/v1/web/search",
        provider_mode=provider_mode,
    )
