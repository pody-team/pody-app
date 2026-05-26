from __future__ import annotations

import logging
from typing import TYPE_CHECKING

from app.config.settings import AppSettings
from app.model.entity import ArticleEmbeddingDocument
from app.model.request import (
    ArticleSearchRequest,
    InvalidArticleEventError,
    KafkaMessageContext,
    parse_article_event,
)
from app.model.response import (
    ArticleProcessingResult,
    ArticleSearchMatchResponse,
    ArticleSearchResponse,
)
from app.util.chunking import build_article_chunks
from app.util.hashing import sha256_text
from app.util.vector_math import build_weighted_document_embedding

if TYPE_CHECKING:
    from app.model.repository import EmbeddingRepository
    from app.service.gemini_provider import GeminiEmbeddingProvider


class PermanentArticleProcessingError(Exception):
    """Loi vinh vien: retry Kafka cung khong xu ly duoc payload bai bao."""

    pass


class ArticleEmbeddingService:
    """Service tao embedding cho bai bao va tim kiem semantic."""

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

    def process_message(self, payload: object, message: KafkaMessageContext) -> ArticleProcessingResult:
        """Xu ly event bai bao tu Kafka va dong bo embedding vao PostgreSQL/pgvector."""
        try:
            event = parse_article_event(payload)
        except InvalidArticleEventError as exc:
            raise PermanentArticleProcessingError(str(exc)) from exc

        document_text = self._build_document_text(event.title, event.summary, event.content)
        if not document_text:
            raise PermanentArticleProcessingError(
                f"Article {event.article_id} does not contain embeddable text"
            )

        content_hash = sha256_text(document_text)
        chunking_signature = self._settings.article_chunking.signature
        current_document = self._repository.get_document(article_id=event.article_id)
        current_embedding_is_reusable = self._is_document_current(
            current_document=current_document,
            content_hash=content_hash,
            chunking_signature=chunking_signature,
        )

        if not self._is_public_article(event.status):
            # Bai khong public khong duoc embed, dong thoi xoa match category semantic cu.
            if current_embedding_is_reusable:
                self._repository.sync_article_metadata(
                    event=event,
                    content_hash=content_hash,
                    chunking_signature=chunking_signature,
                    default_language_code=self._settings.article_chunking.default_language_code,
                )
            else:
                self._repository.upsert_article_document_without_embedding(
                    event=event,
                    content_hash=content_hash,
                    chunking_signature=chunking_signature,
                    default_language_code=self._settings.article_chunking.default_language_code,
                    sync_status="skipped",
                )
            self._repository.delete_article_category_matches_and_enqueue_sync_event(
                article_id=event.article_id,
                model_name=self._settings.gemini.embedding_model,
                embedding_version=self._settings.gemini.embedding_version,
            )
            self._logger.info(
                "Skipping article %s because status %s is not embeddable",
                event.article_id,
                event.status,
            )
            return ArticleProcessingResult(
                status="skipped",
                article_id=event.article_id,
                chunk_count=current_document.chunk_count if current_document is not None else 0,
                job_id=None,
                reason="non-public-status",
            )

        if current_embedding_is_reusable:
            # Noi dung va cau hinh embedding khong doi, chi can cap nhat metadata moi nhat.
            self._repository.sync_article_metadata(
                event=event,
                content_hash=content_hash,
                chunking_signature=chunking_signature,
                default_language_code=self._settings.article_chunking.default_language_code,
            )
            self._logger.info(
                "Skipping article %s because the latest embedding is already up to date",
                event.article_id,
            )
            return ArticleProcessingResult(
                status="skipped",
                article_id=event.article_id,
                chunk_count=current_document.chunk_count,
                job_id=None,
                reason="already-synced",
            )

        job_id = self._repository.enqueue_article_job(
            event=event,
            content_hash=content_hash,
            model_name=self._settings.gemini.embedding_model,
            embedding_version=self._settings.gemini.embedding_version,
            chunking_signature=chunking_signature,
            message=message,
            default_language_code=self._settings.article_chunking.default_language_code,
        ).id
        self._repository.mark_job_processing(job_id=job_id, article_id=event.article_id)

        try:
            # Tach bai bao thanh chunk, embed tung chunk roi tao vector tong hop cho document.
            chunks = build_article_chunks(
                title=event.title,
                summary=event.summary,
                content=event.content,
                target_chars=self._settings.article_chunking.target_chars,
                overlap_chars=self._settings.article_chunking.overlap_chars,
                min_chunk_chars=self._settings.article_chunking.min_chunk_chars,
            )
            embeddings = self._provider.embed_texts(
                [chunk.content for chunk in chunks],
                task_type="RETRIEVAL_DOCUMENT",
            )
            self._validate_embeddings(embeddings)
            document_embedding = build_weighted_document_embedding(chunks, embeddings)
            self._repository.replace_article_embedding(
                event=event,
                content_hash=content_hash,
                chunking_signature=chunking_signature,
                chunks=chunks,
                embeddings=embeddings,
                document_embedding=document_embedding,
                model_name=self._settings.gemini.embedding_model,
                embedding_version=self._settings.gemini.embedding_version,
                output_dimensions=self._settings.gemini.output_dimensions,
                max_matches=self._settings.article_category_mapping.max_matches,
                min_score=self._settings.article_category_mapping.min_score,
                default_language_code=self._settings.article_chunking.default_language_code,
                job_id=job_id,
            )
        except Exception as exc:
            self._repository.mark_job_failed(
                job_id=job_id,
                article_id=event.article_id,
                error_message=str(exc),
            )
            raise

        self._logger.info(
            "Embedded article %s into %s chunk(s) using %s",
            event.article_id,
            len(chunks),
            self._settings.gemini.embedding_model,
        )
        return ArticleProcessingResult(
            status="processed",
            article_id=event.article_id,
            chunk_count=len(chunks),
            job_id=job_id,
        )

    def search_articles(self, request: ArticleSearchRequest) -> ArticleSearchResponse:
        """Embed query tim kiem va truy van cac chunk bai bao gan nghia nhat."""
        query_embedding = self._provider.embed_texts(
            [request.query],
            task_type="RETRIEVAL_QUERY",
        )[0]
        self._validate_embeddings([query_embedding])

        rows = self._repository.search_article_chunks(
            query_embedding=query_embedding,
            model_name=self._settings.gemini.embedding_model,
            embedding_version=self._settings.gemini.embedding_version,
            output_dimensions=self._settings.gemini.output_dimensions,
            limit=request.limit,
        )
        matches = [
            ArticleSearchMatchResponse(
                article_id=int(row["article_id"]),
                title=str(row["title"] or ""),
                original_url=str(row["original_url"] or ""),
                chunk_index=int(row["chunk_index"] or 0),
                chunk_type=str(row["chunk_type"] or "body"),
                chunk_preview=str(row["chunk_preview"] or ""),
                score=float(row["score"] or 0.0),
            )
            for row in rows
        ]
        return ArticleSearchResponse(
            query=request.query,
            limit=request.limit,
            matches=matches,
        )

    @staticmethod
    def _build_document_text(title: str, summary: str | None, content: str | None) -> str:
        """Ghep title, summary va content thanh text dung de hash va validate."""
        parts = [title.strip()]
        if summary and summary.strip():
            parts.append(summary.strip())
        if content and content.strip():
            parts.append(content.strip())
        return "\n\n".join(part for part in parts if part)

    def _is_document_current(
        self,
        *,
        current_document: ArticleEmbeddingDocument | None,
        content_hash: str,
        chunking_signature: str,
    ) -> bool:
        """Kiem tra embedding hien co co dung noi dung/model/chunking hien tai khong."""
        if current_document is None:
            return False
        return bool(
            current_document.content_hash == content_hash
            and current_document.sync_status == "ready"
            and current_document.last_embedding_model == self._settings.gemini.embedding_model
            and current_document.last_embedding_version == self._settings.gemini.embedding_version
            and current_document.last_embedding_dimensions == self._settings.gemini.output_dimensions
            and current_document.last_chunking_signature == chunking_signature
        )

    def _validate_embeddings(self, embeddings: list[list[float]]) -> None:
        """Dam bao provider tra ve vector dung so chieu cau hinh."""
        expected_dimensions = self._settings.gemini.output_dimensions
        for index, embedding in enumerate(embeddings):
            if len(embedding) != expected_dimensions:
                raise RuntimeError(
                    f"Embedding #{index} returned {len(embedding)} dimensions instead of {expected_dimensions}"
                )

    @staticmethod
    def _is_public_article(status: str) -> bool:
        """Chi bai PUBLISHED moi duoc dua vao semantic search."""
        return status.strip().upper() == "PUBLISHED"
