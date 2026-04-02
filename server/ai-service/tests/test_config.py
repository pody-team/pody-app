from __future__ import annotations

import pytest

import app.planner as planner_module
from app.config import load_settings
from app.planner import _build_genai_client


def _set_minimal_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/pody_ai")
    monkeypatch.setenv(
        "CONTENT_DATABASE_URL",
        "postgresql://postgres:postgres@localhost:5432/pody_content",
    )
    for key in (
        "AI_PROVIDER_MODE",
        "GOOGLE_CLOUD_PROJECT",
        "GOOGLE_CLOUD_LOCATION",
        "GOOGLE_GENAI_BASE_URL",
        "GOOGLE_API_KEY",
        "GEMINI_API_KEY",
    ):
        monkeypatch.delenv(key, raising=False)


def test_load_settings_uses_vertex_provider_when_project_is_configured(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _set_minimal_env(monkeypatch)
    monkeypatch.setenv("GOOGLE_CLOUD_PROJECT", "pody-dev")
    monkeypatch.setenv("GOOGLE_CLOUD_LOCATION", "asia-southeast1")
    monkeypatch.setenv("GOOGLE_GENAI_BASE_URL", "http://host.docker.internal:3030")

    settings = load_settings()

    assert settings.use_google_provider is True
    assert settings.google_cloud_project == "pody-dev"
    assert settings.google_cloud_location == "asia-southeast1"


def test_load_settings_ignores_proxy_only_configuration_in_auto_mode(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _set_minimal_env(monkeypatch)
    monkeypatch.setenv("GOOGLE_GENAI_BASE_URL", "http://host.docker.internal:3030")
    monkeypatch.setenv("GOOGLE_API_KEY", "proxy-placeholder")

    settings = load_settings()

    assert settings.use_google_provider is False


def test_load_settings_requires_vertex_project_when_google_mode_is_forced(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _set_minimal_env(monkeypatch)
    monkeypatch.setenv("AI_PROVIDER_MODE", "google")

    with pytest.raises(ValueError, match="GOOGLE_CLOUD_PROJECT is required"):
        load_settings()


def test_build_genai_client_uses_vertex_ai(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, object] = {}

    class FakeClient:
        def __init__(self, **kwargs) -> None:
            captured.update(kwargs)

    monkeypatch.setattr(planner_module.genai, "Client", FakeClient)

    client = _build_genai_client(project="pody-dev", location="asia-southeast1")

    assert isinstance(client, FakeClient)
    assert captured == {
        "vertexai": True,
        "project": "pody-dev",
        "location": "asia-southeast1",
    }
