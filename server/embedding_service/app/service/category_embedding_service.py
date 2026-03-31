from __future__ import annotations

import logging
from typing import TYPE_CHECKING, Sequence

from app.config.settings import AppSettings
from app.model.entity import CategoryCatalogItem, CategoryEmbeddingDocument
from app.model.response import CategorySyncResult
from app.util.hashing import sha256_text

if TYPE_CHECKING:
    from app.model.repository import EmbeddingRepository
    from app.service.gemini_provider import GeminiEmbeddingProvider


class CategoryEmbeddingService:
    def __init__(
        self,
        repository: EmbeddingRepository,
        provider: GeminiEmbeddingProvider,
        settings: AppSettings,
        logger: logging.Logger,
    ) -> None:
        self._repository = repository
        self._provider = provider
        self._settings = settings
        self._logger = logger

    def sync_categories(self, categories: Sequence[CategoryCatalogItem]) -> CategorySyncResult:
        pending_embeddings: list[tuple[CategoryCatalogItem, str, str]] = []
        processed_count = 0
        skipped_count = 0
        should_refresh_matches = False

        for category in categories:
            semantic_text = self._build_semantic_text(category.name, category.description)
            if not semantic_text:
                skipped_count += 1
                self._logger.warning(
                    "Skipping category %s because it does not contain embeddable text",
                    category.category_id,
                )
                continue

            content_hash = sha256_text(semantic_text)
            current_document = self._repository.get_category_document(category_id=category.category_id)
            current_embedding_is_reusable = self._is_document_current(
                current_document=current_document,
                content_hash=content_hash,
            )

            if not category.is_active:
                active_state_changed = current_document is not None and current_document.is_active
                if current_embedding_is_reusable:
                    self._repository.sync_category_metadata(
                        category=category,
                        content_hash=content_hash,
                        semantic_text=semantic_text,
                    )
                else:
                    self._repository.upsert_category_document_without_embedding(
                        category=category,
                        content_hash=content_hash,
                        semantic_text=semantic_text,
                        sync_status="skipped",
                    )
                skipped_count += 1
                should_refresh_matches = should_refresh_matches or active_state_changed
                continue

            if current_embedding_is_reusable:
                self._repository.sync_category_metadata(
                    category=category,
                    content_hash=content_hash,
                    semantic_text=semantic_text,
                )
                skipped_count += 1
                continue

            pending_embeddings.append((category, semantic_text, content_hash))

        if pending_embeddings:
            embeddings = self._provider.embed_texts(
                [semantic_text for _, semantic_text, _ in pending_embeddings],
                task_type="RETRIEVAL_DOCUMENT",
            )
            if len(embeddings) != len(pending_embeddings):
                raise RuntimeError(
                    f"Expected {len(pending_embeddings)} category embeddings but received {len(embeddings)}"
                )

            for (category, semantic_text, content_hash), embedding in zip(
                pending_embeddings,
                embeddings,
                strict=True,
            ):
                self._validate_embedding(embedding)
                self._repository.replace_category_embedding(
                    category=category,
                    content_hash=content_hash,
                    semantic_text=semantic_text,
                    embedding=embedding,
                    model_name=self._settings.gemini.embedding_model,
                    embedding_version=self._settings.gemini.embedding_version,
                    output_dimensions=self._settings.gemini.output_dimensions,
                )
                processed_count += 1

            should_refresh_matches = True

        if should_refresh_matches:
            self._repository.refresh_article_category_matches_for_all_articles(
                model_name=self._settings.gemini.embedding_model,
                embedding_version=self._settings.gemini.embedding_version,
                output_dimensions=self._settings.gemini.output_dimensions,
                max_matches=self._settings.article_category_mapping.max_matches,
                min_score=self._settings.article_category_mapping.min_score,
            )
            for article_id in self._repository.list_ready_public_article_ids():
                self._repository.enqueue_article_category_sync_event(
                    article_id=article_id,
                    model_name=self._settings.gemini.embedding_model,
                    embedding_version=self._settings.gemini.embedding_version,
                )

        self._logger.info(
            "Category bootstrap completed | processed=%s skipped=%s refreshed_matches=%s",
            processed_count,
            skipped_count,
            should_refresh_matches,
        )
        return CategorySyncResult(
            processed_count=processed_count,
            skipped_count=skipped_count,
            matches_refreshed=should_refresh_matches,
        )

    def _is_document_current(
        self,
        *,
        current_document: CategoryEmbeddingDocument | None,
        content_hash: str,
    ) -> bool:
        if current_document is None:
            return False
        return bool(
            current_document.content_hash == content_hash
            and current_document.is_active
            and current_document.sync_status == "ready"
            and current_document.last_embedding_model == self._settings.gemini.embedding_model
            and current_document.last_embedding_version == self._settings.gemini.embedding_version
            and current_document.last_embedding_dimensions == self._settings.gemini.output_dimensions
        )

    def _validate_embedding(self, embedding: list[float]) -> None:
        expected_dimensions = self._settings.gemini.output_dimensions
        if len(embedding) != expected_dimensions:
            raise RuntimeError(
                f"Category embedding returned {len(embedding)} dimensions instead of {expected_dimensions}"
            )

    @staticmethod
    def _build_semantic_text(name: str, description: str | None) -> str:
        parts = [name.strip()]
        if description and description.strip():
            parts.append(description.strip())
        return "\n\n".join(part for part in parts if part)
