from __future__ import annotations

from app.model.response import ArticleSearchResponse


class ArticleSearchView:
    def render_search_results(self, response: ArticleSearchResponse) -> dict[str, object]:
        return response.to_dict()
