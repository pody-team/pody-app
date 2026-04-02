from __future__ import annotations

import logging
import re
from typing import Any

import httpx

from ai_podcast.schemas import ResearchPack

logger = logging.getLogger(__name__)

_MAX_QUERY_LENGTH = 180
_MAX_SOURCE_TITLE_LENGTH = 180
_MAX_SOURCE_SUMMARY_LENGTH = 360
_MAX_SOURCE_CONTENT_LENGTH = 1200
_MAX_TOTAL_PRIMARY_CONTENT_CHARS = 12000
_MAX_EXTERNAL_DESCRIPTION_LENGTH = 240


class DisabledSearchTool:
    def search(self, *, query: str) -> dict[str, Any]:
        return {"query": query, "results": [], "error": "Brave search is not configured"}


class BraveSearchTool:
    def __init__(self, *, api_key: str, base_url: str) -> None:
        self._api_key = api_key
        self._base_url = base_url

    def search(self, *, query: str) -> dict[str, Any]:
        response = httpx.get(
            self._base_url,
            params={
                "q": query,
                "count": 5,
                "country": "ALL",
                "search_lang": "vi",
                "text_decorations": "false",
            },
            headers={
                "Accept": "application/json",
                "X-Subscription-Token": self._api_key,
            },
            timeout=15.0,
        )
        response.raise_for_status()
        payload = response.json()
        results = []
        for item in (payload.get("web", {}) or {}).get("results", [])[:5]:
            if not isinstance(item, dict):
                continue
            results.append(
                {
                    "title": str(item.get("title") or "").strip(),
                    "url": str(item.get("url") or "").strip(),
                    "description": _compact_text(
                        str(item.get("description") or "").strip(),
                        _MAX_EXTERNAL_DESCRIPTION_LENGTH,
                    ),
                }
            )
        return {"query": query, "results": results}


def build_search_tool(*, api_key: str | None, base_url: str):
    if not api_key:
        return DisabledSearchTool()
    return BraveSearchTool(api_key=api_key, base_url=base_url)


def _normalize_topic_fragment(value: str) -> str:
    normalized = re.sub(r"\s+", " ", (value or "").strip())
    normalized = normalized.replace('"', " ").replace("'", " ")
    normalized = re.sub(r"\s+", " ", normalized).strip(" ,.-")
    return normalized


def _compact_text(value: str, max_length: int) -> str:
    normalized = re.sub(r"\s+", " ", (value or "").strip())
    if len(normalized) <= max_length:
        return normalized
    shortened = normalized[:max_length]
    last_space = shortened.rfind(" ")
    if last_space >= max_length // 2:
        shortened = shortened[:last_space]
    return shortened.rstrip(" ,.-") + "..."


def _compact_selected_articles(selected_articles: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], int]:
    compacted_articles: list[dict[str, Any]] = []
    remaining_content_budget = _MAX_TOTAL_PRIMARY_CONTENT_CHARS
    truncated_count = 0

    for article in selected_articles:
        summary = _compact_text(
            str(article.get("summary") or ""),
            _MAX_SOURCE_SUMMARY_LENGTH,
        )
        content_limit = min(_MAX_SOURCE_CONTENT_LENGTH, max(240, remaining_content_budget))
        content = _compact_text(
            str(article.get("content") or ""),
            content_limit,
        )
        title = _compact_text(
            str(article.get("title") or ""),
            _MAX_SOURCE_TITLE_LENGTH,
        )

        original_content = re.sub(r"\s+", " ", str(article.get("content") or "").strip())
        original_summary = re.sub(r"\s+", " ", str(article.get("summary") or "").strip())
        if content != original_content or summary != original_summary or title != str(article.get("title") or "").strip():
            truncated_count += 1

        compacted_articles.append(
            {
                "article_id": article.get("article_id"),
                "title": title,
                "summary": summary,
                "content": content,
                "original_url": str(article.get("original_url") or "").strip(),
                "published_at": article.get("published_at"),
            }
        )
        remaining_content_budget = max(240, remaining_content_budget - len(content))

    return compacted_articles, truncated_count


def _build_topic_hint(selected_articles: list[dict[str, Any]]) -> str:
    fragments: list[str] = []
    for article in selected_articles:
        title = _normalize_topic_fragment(str(article.get("title") or ""))
        summary = _normalize_topic_fragment(str(article.get("summary") or ""))
        if title:
            fragments.append(title)
        elif summary:
            fragments.append(summary)
        if len(fragments) >= 2:
            break

    topic_hint = " ".join(fragments).strip() or "tin tuc duoc chon"
    if len(topic_hint) <= _MAX_QUERY_LENGTH:
        return topic_hint

    shortened = topic_hint[:_MAX_QUERY_LENGTH]
    last_space = shortened.rfind(" ")
    if last_space >= 80:
        shortened = shortened[:last_space]
    return shortened.strip(" ,.-") or "tin tuc duoc chon"


def build_research_pack(
    *,
    selected_articles: list[dict[str, Any]],
    search_tool: Any,
) -> ResearchPack:
    compacted_articles, truncated_count = _compact_selected_articles(selected_articles)
    topic_hint = _build_topic_hint(compacted_articles)
    search_payload: dict[str, Any]
    try:
        search_payload = search_tool.search(
            query=f"boi canh moi nhat va xu huong lien quan den {topic_hint}"
        )
    except Exception as exc:
        logger.warning("external podcast research failed: %s", exc)
        search_payload = {
            "query": topic_hint,
            "results": [],
            "error": f"External research unavailable: {exc}",
        }
    external_sources = search_payload.get("results") or []
    summary_parts = [
        "Tong hop nhom bai bao nguoi dung da chon.",
        f"So bai goc: {len(selected_articles)}.",
    ]
    if truncated_count:
        summary_parts.append(
            f"Da rut gon noi dung cua {truncated_count} bai de phu hop gioi han xu ly khi tong hop podcast."
        )
    if external_sources:
        summary_parts.append(f"Da bo sung {len(external_sources)} nguon web de mo rong boi canh.")
    if search_payload.get("error"):
        summary_parts.append(str(search_payload["error"]))
    return ResearchPack(
        primary_sources=compacted_articles,
        external_context_sources=external_sources,
        research_summary=" ".join(summary_parts),
    )
