from __future__ import annotations

from typing import Any

try:
    from google import genai
    from google.genai import types
except ImportError:  # pragma: no cover - optional dependency in tests
    genai = None
    types = None


def build_genai_client(*, api_key: str, base_url: str | None) -> Any | None:
    if genai is None:
        return None
    http_options = None
    if base_url and types is not None:
        http_options = types.HttpOptions(baseUrl=base_url)
    return genai.Client(api_key=api_key, http_options=http_options)
