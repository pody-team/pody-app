from __future__ import annotations

__all__ = ["CategoryCatalogRepository", "EmbeddingRepository"]


def __getattr__(name: str):
    if name == "CategoryCatalogRepository":
        from .category_catalog_repository import CategoryCatalogRepository

        return CategoryCatalogRepository
    if name == "EmbeddingRepository":
        from .embedding_repository import EmbeddingRepository

        return EmbeddingRepository
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
