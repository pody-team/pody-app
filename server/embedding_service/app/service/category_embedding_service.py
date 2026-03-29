from __future__ import annotations

import logging
from typing import TYPE_CHECKING

from app.config.settings import AppSettings
from app.model.entity import CategoryEmbeddingDocument
from app.model.request import (
    InvalidCategoryEventError,
    KafkaMessageContext,
    parse_category_event,
)
from app.model.response.category_processing import CategoryProcessingResult
from app.util.hashing import sha256_text

if TYPE_CHECKING:
    from app.model.repository import EmbeddingRepository
    from app.service.gemini_provider import GeminiEmbeddingProvider


class PermanentCategoryProcessingError(Exception):
    pass


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

    def process_message(self, payload: object, message: KafkaMessageContext) -> CategoryProcessingResult:
        try:
            event = parse_category_event(payload)
        except InvalidCategoryEventError as exc:
            raise PermanentCategoryProcessingError(str(exc)) from exc

        semantic_text = self._build_semantic_text(event.name, event.description)
        if not semantic_text:
            raise PermanentCategoryProcessingError(
                f"Category {event.category_id} does not contain embeddable text"
            )

        content_hash = sha256_text(semantic_text)
        current_document = self._repository.get_category_document(category_id=event.category_id)
        current_embedding_is_reusable = self._is_document_current(
            current_document=current_document,
            content_hash=content_hash,
        )

        if not event.is_active:
            if current_embedding_is_reusable:
                self._repository.sync_category_metadata(
                    event=event,
                    content_hash=content_hash,
                    semantic_text=semantic_text,
                )
            else:
                self._repository.upsert_category_document_without_embedding(
                    event=event,
                    content_hash=content_hash,
                    semantic_text=semantic_text,
                    sync_status="skipped",
                )
            self._logger.info(
                "Skipping category %s because it is inactive",
                event.category_id,
            )
            return CategoryProcessingResult(
                status="skipped",
                category_id=event.category_id,
                job_id=None,
                reason="inactive-category",
            )

        if current_embedding_is_reusable:
            self._repository.sync_category_metadata(
                event=event,
                content_hash=content_hash,
                semantic_text=semantic_text,
            )
            self._logger.info(
                "Skipping category %s because the latest embedding is already up to date",
                event.category_id,
            )
            return CategoryProcessingResult(
                status="skipped",
                category_id=event.category_id,
                job_id=None,
                reason="already-synced",
            )

        job = self._repository.enqueue_category_job(
            event=event,
            content_hash=content_hash,
            semantic_text=semantic_text,
            model_name=self._settings.gemini.embedding_model,
            embedding_version=self._settings.gemini.embedding_version,
            message=message,
        )
        self._repository.mark_category_job_processing(
            job_id=job.id,
            category_id=event.category_id,
        )

        try:
            embedding = self._provider.embed_texts(
                [semantic_text],
                task_type="RETRIEVAL_DOCUMENT",
            )[0]
            self._validate_embedding(embedding)
            self._repository.replace_category_embedding(
                event=event,
                content_hash=content_hash,
                semantic_text=semantic_text,
                embedding=embedding,
                model_name=self._settings.gemini.embedding_model,
                embedding_version=self._settings.gemini.embedding_version,
                output_dimensions=self._settings.gemini.output_dimensions,
                job_id=job.id,
            )
        except Exception as exc:
            self._repository.mark_category_job_failed(
                job_id=job.id,
                category_id=event.category_id,
                error_message=str(exc),
            )
            raise

        self._logger.info(
            "Embedded category %s using %s",
            event.category_id,
            self._settings.gemini.embedding_model,
        )
        return CategoryProcessingResult(
            status="processed",
            category_id=event.category_id,
            job_id=job.id,
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
