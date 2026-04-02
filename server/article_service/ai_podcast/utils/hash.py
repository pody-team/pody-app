from __future__ import annotations

import hashlib


def stable_content_hash(*parts: str) -> str:
    digest = hashlib.sha256()
    for part in parts:
        digest.update((part or "").encode("utf-8"))
        digest.update(b"\n")
    return digest.hexdigest()
