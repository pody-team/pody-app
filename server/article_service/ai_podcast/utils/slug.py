from __future__ import annotations

import re
import unicodedata


def slugify(value: str) -> str:
    normalized = (
        unicodedata.normalize("NFKD", (value or "").strip())
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )
    return re.sub(r"[^a-z0-9]+", "-", normalized).strip("-") or "podcast"
