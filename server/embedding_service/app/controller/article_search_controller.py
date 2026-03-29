from __future__ import annotations

from app.model.request import ArticleSearchRequest
from app.model.response import ArticleSearchResponse
from app.service.article_embedding_service import ArticleEmbeddingService


class ArticleSearchController:
    def __init__(self, service: ArticleEmbeddingService) -> None:
        self._service = service

    def search_articles(self, request: ArticleSearchRequest) -> ArticleSearchResponse:
        return self._service.search_articles(request)
