from __future__ import annotations

import json
from typing import Any


def decode_optional_bytes(value: bytes | None) -> str | None:
    if value is None:
        return None
    try:
        return value.decode("utf-8")
    except UnicodeDecodeError:
        return value.decode("utf-8", errors="replace")


def normalize_payload(payload: str | None) -> Any:
    if payload is None:
        return None
    stripped = payload.strip()
    if not stripped:
        return ""
    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        return stripped


def format_payload(payload: Any) -> str:
    if payload is None:
        return "null"
    if isinstance(payload, (dict, list)):
        return json.dumps(payload, ensure_ascii=False, sort_keys=True)
    return str(payload)
