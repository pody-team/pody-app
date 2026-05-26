from __future__ import annotations

from app.model.response import ArticleSearchResponse


class ArticleSearchView:
    """View chuyen response semantic search thanh dict JSON."""

    def render_search_results(self, response: ArticleSearchResponse) -> dict[str, object]:
        """Render ket qua tim kiem bai bao cho FastAPI."""
        return response.to_dict()
