from __future__ import annotations

from typing import Any

try:
    from google import genai
except ImportError:  # pragma: no cover - optional dependency in tests
    genai = None


def build_genai_client(*, project: str | None, location: str) -> Any | None:
    project_id = (project or "").strip()
    if genai is None or not project_id:
        return None
    return genai.Client(
        vertexai=True,
        project=project_id,
        location=(location or "global").strip() or "global",
    )
