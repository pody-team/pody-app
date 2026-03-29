import logging
import unittest
from datetime import datetime, timezone

from app.config.settings import (
    AppSettings,
    ArticleChunkSettings,
    DatabaseSettings,
    GeminiSettings,
    KafkaSettings,
)
from app.model.entity import ArticleEmbeddingDocument, EmbeddingJob
from app.model.request import ArticleSearchRequest, KafkaMessageContext
from app.model.response import ArticleSearchResponse
from app.service.article_embedding_service import ArticleEmbeddingService
from app.util.hashing import sha256_text


class FakeRepository:
    def __init__(self, document: ArticleEmbeddingDocument | None) -> None:
        self.document = document
        self.synced_metadata: list[dict[str, object]] = []
        self.upserted_without_embedding: list[dict[str, object]] = []
        self.enqueued_jobs: list[dict[str, object]] = []
        self.processing_marks: list[tuple[int, int]] = []
        self.replaced_embeddings: list[dict[str, object]] = []
        self.failed_jobs: list[tuple[int, int, str]] = []
        self.search_rows: list[dict[str, object]] = [
            {
                "article_id": 42,
                "title": "Tin moi nhat",
                "original_url": "https://example.com/article",
                "chunk_index": 1,
                "chunk_type": "body",
                "chunk_preview": "Doan van phu hop voi truy van.",
                "score": 0.93,
            }
        ]

    def get_document(self, *, article_id: int) -> ArticleEmbeddingDocument | None:
        return self.document

    def sync_article_metadata(self, **kwargs) -> None:
        self.synced_metadata.append(kwargs)

    def upsert_article_document_without_embedding(self, **kwargs) -> None:
        self.upserted_without_embedding.append(kwargs)

    def enqueue_article_job(self, **kwargs) -> EmbeddingJob:
        self.enqueued_jobs.append(kwargs)
        return EmbeddingJob(
            id=99,
            target_type="article",
            target_id=int(kwargs["event"].article_id),
            job_type="embed_article",
            source_topic="article.embedding.requested",
            source_partition=0,
            source_offset=0,
            source_key="42",
            content_hash=str(kwargs["content_hash"]),
            model_name=str(kwargs["model_name"]),
            embedding_version=str(kwargs["embedding_version"]),
            status="pending",
            attempts=0,
            error_message=None,
            payload={},
            scheduled_at=None,
            started_at=None,
            finished_at=None,
            created_at=None,
            updated_at=None,
        )

    def mark_job_processing(self, *, job_id: int, article_id: int) -> None:
        self.processing_marks.append((job_id, article_id))

    def replace_article_embedding(self, **kwargs) -> None:
        self.replaced_embeddings.append(kwargs)

    def mark_job_failed(self, *, job_id: int, article_id: int, error_message: str) -> None:
        self.failed_jobs.append((job_id, article_id, error_message))

    def search_article_chunks(self, **kwargs) -> list[dict[str, object]]:
        return list(self.search_rows)


class FakeProvider:
    def __init__(self) -> None:
        self.calls: list[tuple[list[str], str]] = []

    def embed_texts(self, texts: list[str], *, task_type: str) -> list[list[float]]:
        self.calls.append((list(texts), task_type))
        return [[0.1] * 1536 for _ in texts]


class ArticleEmbeddingServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.settings = AppSettings(
            port=8088,
            log_level="INFO",
            database=DatabaseSettings(
                url="postgresql://postgres:postgres@localhost:5434/pody_embedding",
                pool_min_size=1,
                pool_max_size=5,
                startup_timeout_seconds=120,
                retry_delay_seconds=2.0,
            ),
            kafka=KafkaSettings(
                brokers=["localhost:9092"],
                topic="article.embedding.requested",
                client_id="embedding-service",
                consumer_group="embedding-service",
                auto_offset_reset="earliest",
                topic_partitions=1,
                topic_replication_factor=1,
                request_timeout_ms=30000,
                session_timeout_ms=10000,
                startup_timeout_seconds=120,
                retry_delay_seconds=2.0,
            ),
            gemini=GeminiSettings(
                api_keys=["key-1"],
                embedding_model="gemini-embedding-001",
                embedding_version="v1",
                base_url=None,
                output_dimensions=1536,
                batch_size=16,
                quota_retry_delay_seconds=60.0,
            ),
            article_chunking=ArticleChunkSettings(
                target_chars=1400,
                overlap_chars=180,
                min_chunk_chars=250,
                default_language_code="vi",
            ),
        )
        self.logger = logging.getLogger("embedding-service-tests")
        self.message = KafkaMessageContext(
            topic="article.embedding.requested",
            partition=0,
            offset=12,
            key="42",
        )

    def test_metadata_only_update_skips_reembed_but_syncs_document(self):
        payload = self._article_payload(title="Bai bao", summary="Tom tat", author="Tac gia cu")
        content_hash = sha256_text("Bai bao\n\nTom tat\n\nNoi dung bai bao")
        current_document = self._document(
            title="Bai bao",
            author="Tac gia truoc do",
            content_hash=content_hash,
            chunking_signature=self.settings.article_chunking.signature,
        )
        repository = FakeRepository(current_document)
        provider = FakeProvider()
        service = ArticleEmbeddingService(repository, provider, self.settings, self.logger)

        result = service.process_message(payload, self.message)

        self.assertEqual(result.status, "skipped")
        self.assertEqual(len(repository.synced_metadata), 1)
        self.assertEqual(len(repository.enqueued_jobs), 0)
        self.assertEqual(provider.calls, [])
        self.assertEqual(repository.synced_metadata[0]["event"].author, "Tac gia cu")

    def test_chunking_signature_change_forces_reembed(self):
        payload = self._article_payload()
        content_hash = sha256_text("Bai bao\n\nTom tat\n\nNoi dung bai bao")
        current_document = self._document(
            title="Bai bao",
            author="Tac gia",
            content_hash=content_hash,
            chunking_signature="stale-signature",
        )
        repository = FakeRepository(current_document)
        provider = FakeProvider()
        service = ArticleEmbeddingService(repository, provider, self.settings, self.logger)

        result = service.process_message(payload, self.message)

        self.assertEqual(result.status, "processed")
        self.assertEqual(len(repository.enqueued_jobs), 1)
        self.assertEqual(len(repository.processing_marks), 1)
        self.assertEqual(len(repository.replaced_embeddings), 1)
        self.assertEqual(provider.calls[0][1], "RETRIEVAL_DOCUMENT")

    def test_non_public_article_is_skipped_without_calling_provider(self):
        payload = self._article_payload(status="DRAFT")
        repository = FakeRepository(None)
        provider = FakeProvider()
        service = ArticleEmbeddingService(repository, provider, self.settings, self.logger)

        result = service.process_message(payload, self.message)

        self.assertEqual(result.status, "skipped")
        self.assertEqual(result.reason, "non-public-status")
        self.assertEqual(len(repository.upserted_without_embedding), 1)
        self.assertEqual(len(repository.enqueued_jobs), 0)
        self.assertEqual(provider.calls, [])

    def test_search_articles_returns_public_match_shape(self):
        repository = FakeRepository(None)
        provider = FakeProvider()
        service = ArticleEmbeddingService(repository, provider, self.settings, self.logger)

        response = service.search_articles(ArticleSearchRequest(query="tin moi", limit=3))

        self.assertIsInstance(response, ArticleSearchResponse)
        self.assertEqual(response.limit, 3)
        self.assertEqual(len(response.matches), 1)
        self.assertEqual(response.matches[0].article_id, 42)
        self.assertEqual(provider.calls[0][1], "RETRIEVAL_QUERY")

    @staticmethod
    def _article_payload(
        *,
        title: str = "Bai bao",
        summary: str = "Tom tat",
        content: str = "Noi dung bai bao",
        author: str = "Tac gia",
        status: str = "PUBLISHED",
    ) -> dict[str, object]:
        now = datetime(2026, 3, 29, 10, 0, 0, tzinfo=timezone.utc).isoformat()
        return {
            "id": 42,
            "source_id": 7,
            "title": title,
            "author": author,
            "summary": summary,
            "content": content,
            "original_url": "https://example.com/article",
            "thumbnail_url": "https://example.com/thumb.jpg",
            "published_at": now,
            "status": status,
            "created_at": now,
            "updated_at": now,
            "op": "u",
            "table": "articles",
            "source.ts_ms": 1711706400000,
        }

    @staticmethod
    def _document(
        *,
        title: str,
        author: str,
        content_hash: str,
        chunking_signature: str,
    ) -> ArticleEmbeddingDocument:
        now = datetime(2026, 3, 29, 10, 0, 0, tzinfo=timezone.utc)
        return ArticleEmbeddingDocument(
            id=1,
            article_id=42,
            source_id=7,
            article_status="PUBLISHED",
            title=title,
            author=author,
            summary="Tom tat",
            content="Noi dung bai bao",
            original_url="https://example.com/article",
            thumbnail_url="https://example.com/thumb.jpg",
            language_code="vi",
            published_at=now,
            content_hash=content_hash,
            chunk_count=3,
            sync_status="ready",
            last_error=None,
            last_embedding_model="gemini-embedding-001",
            last_embedding_version="v1",
            last_embedding_dimensions=1536,
            last_chunking_signature=chunking_signature,
            last_synced_at=now,
            created_at=now,
            updated_at=now,
        )


if __name__ == "__main__":
    unittest.main()
