from __future__ import annotations

__all__ = ["ArticleEmbeddingService", "GeminiEmbeddingProvider"]


def __getattr__(name: str):
    if name == "ArticleEmbeddingService":
        from .article_embedding_service import ArticleEmbeddingService

        return ArticleEmbeddingService
    if name == "CategoryEmbeddingService":
        from .category_embedding_service import CategoryEmbeddingService

        return CategoryEmbeddingService
    if name == "GeminiEmbeddingProvider":
        from .gemini_provider import GeminiEmbeddingProvider

        return GeminiEmbeddingProvider
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
