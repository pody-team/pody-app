from __future__ import annotations

import logging
import re
from typing import Any

import httpx

from ai_podcast.schemas import ResearchPack

logger = logging.getLogger(__name__)

_MAX_QUERY_LENGTH = 180


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
                    "description": str(item.get("description") or "").strip(),
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
    topic_hint = _build_topic_hint(selected_articles)
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
    if external_sources:
        summary_parts.append(f"Da bo sung {len(external_sources)} nguon web de mo rong boi canh.")
    if search_payload.get("error"):
        summary_parts.append(str(search_payload["error"]))
    return ResearchPack(
        primary_sources=selected_articles,
        external_context_sources=external_sources,
        research_summary=" ".join(summary_parts),
    )
