"""
Helpers for canonical category naming inside article_service.
"""
import re
import unicodedata


def build_category_slug(name: str) -> str:
    normalized = unicodedata.normalize("NFKD", name or "")
    ascii_name = normalized.encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_name.lower()).strip("-")
    return slug or "category"
