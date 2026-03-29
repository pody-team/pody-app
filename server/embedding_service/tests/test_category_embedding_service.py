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
from app.model.entity import CategoryEmbeddingDocument, EmbeddingJob
from app.model.request import KafkaMessageContext
from app.service.category_embedding_service import CategoryEmbeddingService
from app.util.hashing import sha256_text


class FakeCategoryRepository:
    def __init__(self, document: CategoryEmbeddingDocument | None) -> None:
        self.document = document
        self.synced_metadata: list[dict[str, object]] = []
        self.upserted_without_embedding: list[dict[str, object]] = []
        self.enqueued_jobs: list[dict[str, object]] = []
        self.processing_marks: list[tuple[int, str]] = []
        self.replaced_embeddings: list[dict[str, object]] = []
        self.failed_jobs: list[tuple[int, str, str]] = []

    def get_category_document(self, *, category_id: str) -> CategoryEmbeddingDocument | None:
        return self.document

    def sync_category_metadata(self, **kwargs) -> None:
        self.synced_metadata.append(kwargs)

    def upsert_category_document_without_embedding(self, **kwargs) -> None:
        self.upserted_without_embedding.append(kwargs)

    def enqueue_category_job(self, **kwargs) -> EmbeddingJob:
        self.enqueued_jobs.append(kwargs)
        return EmbeddingJob(
            id=101,
            target_type="category",
            target_id=11,
            job_type="embed_category",
            source_topic="category.embedding.requested",
            source_partition=0,
            source_offset=0,
            source_key="category-key",
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

    def mark_category_job_processing(self, *, job_id: int, category_id: str) -> None:
        self.processing_marks.append((job_id, category_id))

    def replace_category_embedding(self, **kwargs) -> None:
        self.replaced_embeddings.append(kwargs)

    def mark_category_job_failed(self, *, job_id: int, category_id: str, error_message: str) -> None:
        self.failed_jobs.append((job_id, category_id, error_message))


class FakeProvider:
    def __init__(self) -> None:
        self.calls: list[tuple[list[str], str]] = []

    def embed_texts(self, texts: list[str], *, task_type: str) -> list[list[float]]:
        self.calls.append((list(texts), task_type))
        return [[0.2] * 1536 for _ in texts]


class CategoryEmbeddingServiceTests(unittest.TestCase):
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
                category_topic="category.embedding.requested",
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
        self.logger = logging.getLogger("embedding-service-category-tests")
        self.message = KafkaMessageContext(
            topic="category.embedding.requested",
            partition=0,
            offset=9,
            key="category-key",
        )

    def test_metadata_only_update_skips_reembed_but_syncs_document(self):
        payload = self._category_payload(name="Cong nghe", description="Tin tuc moi")
        content_hash = sha256_text("Cong nghe\n\nTin tuc moi")
        repository = FakeCategoryRepository(
            self._document(
                content_hash=content_hash,
                name="Cong nghe",
                description="Tin tuc cu",
            )
        )
        provider = FakeProvider()
        service = CategoryEmbeddingService(repository, provider, self.settings, self.logger)

        result = service.process_message(payload, self.message)

        self.assertEqual(result.status, "skipped")
        self.assertEqual(len(repository.synced_metadata), 1)
        self.assertEqual(provider.calls, [])

    def test_inactive_category_is_skipped_without_embedding(self):
        repository = FakeCategoryRepository(None)
        provider = FakeProvider()
        service = CategoryEmbeddingService(repository, provider, self.settings, self.logger)

        result = service.process_message(self._category_payload(is_active=False), self.message)

        self.assertEqual(result.status, "skipped")
        self.assertEqual(result.reason, "inactive-category")
        self.assertEqual(len(repository.upserted_without_embedding), 1)
        self.assertEqual(provider.calls, [])

    def test_category_change_enqueues_and_replaces_embedding(self):
        repository = FakeCategoryRepository(None)
        provider = FakeProvider()
        service = CategoryEmbeddingService(repository, provider, self.settings, self.logger)

        result = service.process_message(self._category_payload(), self.message)

        self.assertEqual(result.status, "processed")
        self.assertEqual(len(repository.enqueued_jobs), 1)
        self.assertEqual(len(repository.processing_marks), 1)
        self.assertEqual(len(repository.replaced_embeddings), 1)
        self.assertEqual(provider.calls[0][1], "RETRIEVAL_DOCUMENT")

    @staticmethod
    def _category_payload(
        *,
        name: str = "Cong nghe",
        description: str = "Tin tuc cong nghe va AI",
        is_active: bool = True,
    ) -> dict[str, object]:
        now = datetime(2026, 3, 29, 12, 0, 0, tzinfo=timezone.utc).isoformat()
        return {
            "event_id": "72c2584f-6356-40d9-acb5-e6703660055c",
            "idempotency_key": "category:88f7fc9d-dc97-4e47-a2b1-f610a7a5f3f8:abc123",
            "event_type": "category.embedding.requested.v1",
            "occurred_at": now,
            "source_service": "article-service",
            "category_id": "88f7fc9d-dc97-4e47-a2b1-f610a7a5f3f8",
            "slug": "cong-nghe",
            "name": name,
            "description": description,
            "is_active": is_active,
            "created_at": now,
            "updated_at": now,
        }

    @staticmethod
    def _document(
        *,
        content_hash: str,
        name: str,
        description: str,
    ) -> CategoryEmbeddingDocument:
        now = datetime(2026, 3, 29, 12, 0, 0, tzinfo=timezone.utc)
        return CategoryEmbeddingDocument(
            id=11,
            category_id="88f7fc9d-dc97-4e47-a2b1-f610a7a5f3f8",
            slug="cong-nghe",
            name=name,
            description=description,
            is_active=True,
            semantic_text=f"{name}\n\n{description}",
            content_hash=content_hash,
            sync_status="ready",
            last_error=None,
            last_embedding_model="gemini-embedding-001",
            last_embedding_version="v1",
            last_embedding_dimensions=1536,
            last_synced_at=now,
            created_at=now,
            updated_at=now,
        )


if __name__ == "__main__":
    unittest.main()
