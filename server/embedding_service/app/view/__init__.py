from __future__ import annotations

__all__ = ["ArticleSearchView", "SystemView"]


def __getattr__(name: str):
    if name == "ArticleSearchView":
        from .article_search_view import ArticleSearchView

        return ArticleSearchView
    if name == "SystemView":
        from .system_view import SystemView

        return SystemView
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
