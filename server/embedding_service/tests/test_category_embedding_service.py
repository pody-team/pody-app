import logging
import unittest
from datetime import datetime, timezone

from app.config.settings import (
    AppSettings,
    ArticleCategoryMappingSettings,
    ArticleChunkSettings,
    CategoryBootstrapSettings,
    DatabaseSettings,
    GeminiSettings,
    KafkaSettings,
)
from app.model.entity import CategoryCatalogItem, CategoryEmbeddingDocument
from app.service.category_embedding_service import CategoryEmbeddingService
from app.util.hashing import sha256_text


class FakeCategoryRepository:
    def __init__(self, documents: dict[str, CategoryEmbeddingDocument] | None = None) -> None:
        self.documents = documents or {}
        self.synced_metadata: list[dict[str, object]] = []
        self.upserted_without_embedding: list[dict[str, object]] = []
        self.replaced_embeddings: list[dict[str, object]] = []
        self.refreshed_matches_calls: list[dict[str, object]] = []
        self.ready_public_article_ids: list[int] = [42]
        self.enqueued_sync_events: list[dict[str, object]] = []

    def get_category_document(self, *, category_id: str) -> CategoryEmbeddingDocument | None:
        return self.documents.get(category_id)

    def sync_category_metadata(self, **kwargs) -> None:
        self.synced_metadata.append(kwargs)

    def upsert_category_document_without_embedding(self, **kwargs) -> None:
        self.upserted_without_embedding.append(kwargs)

    def replace_category_embedding(self, **kwargs) -> None:
        self.replaced_embeddings.append(kwargs)

    def refresh_article_category_matches_for_all_articles(self, **kwargs) -> None:
        self.refreshed_matches_calls.append(kwargs)

    def list_ready_public_article_ids(self) -> list[int]:
        return list(self.ready_public_article_ids)

    def enqueue_article_category_sync_event(self, **kwargs) -> None:
        self.enqueued_sync_events.append(kwargs)


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
            category_bootstrap=CategoryBootstrapSettings(
                enabled=True,
                source_database=DatabaseSettings(
                    url="postgresql://postgres:postgres@localhost:5433/pody_article",
                    pool_min_size=1,
                    pool_max_size=3,
                    startup_timeout_seconds=120,
                    retry_delay_seconds=2.0,
                ),
            ),
            kafka=KafkaSettings(
                brokers=["localhost:9092"],
                topic="article.embedding.requested",
                article_category_sync_topic="article.category.matches.generated",
                client_id="embedding-service",
                consumer_group="embedding-service",
                auto_offset_reset="earliest",
                topic_partitions=1,
                topic_replication_factor=1,
                request_timeout_ms=30000,
                session_timeout_ms=10000,
                startup_timeout_seconds=120,
                retry_delay_seconds=2.0,
                outbox_poll_interval_seconds=1.0,
                outbox_batch_size=20,
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
            article_category_mapping=ArticleCategoryMappingSettings(
                max_matches=3,
                min_score=0.2,
            ),
        )
        self.logger = logging.getLogger("embedding-service-category-tests")

    def test_sync_categories_skips_current_embeddings_and_syncs_document(self):
        category = self._category_item()
        content_hash = sha256_text("Cong nghe\n\nTin tuc cong nghe va AI")
        repository = FakeCategoryRepository(
            {
                category.category_id: self._document(
                    content_hash=content_hash,
                    name=category.name,
                    description=category.description or "",
                )
            }
        )
        provider = FakeProvider()
        service = CategoryEmbeddingService(repository, provider, self.settings, self.logger)

        result = service.sync_categories([category])

        self.assertEqual(result.processed_count, 0)
        self.assertEqual(result.skipped_count, 1)
        self.assertFalse(result.matches_refreshed)
        self.assertEqual(len(repository.synced_metadata), 1)
        self.assertEqual(repository.refreshed_matches_calls, [])
        self.assertEqual(provider.calls, [])

    def test_sync_categories_skips_inactive_categories_without_embedding(self):
        repository = FakeCategoryRepository()
        provider = FakeProvider()
        service = CategoryEmbeddingService(repository, provider, self.settings, self.logger)

        result = service.sync_categories([self._category_item(is_active=False)])

        self.assertEqual(result.processed_count, 0)
        self.assertEqual(result.skipped_count, 1)
        self.assertFalse(result.matches_refreshed)
        self.assertEqual(len(repository.upserted_without_embedding), 1)
        self.assertEqual(provider.calls, [])

    def test_sync_categories_embeds_only_missing_items_and_refreshes_matches_once(self):
        current = self._category_item(
            category_id="88f7fc9d-dc97-4e47-a2b1-f610a7a5f3f8",
            slug="cong-nghe",
            name="Cong nghe",
            description="Tin tuc cong nghe va AI",
        )
        missing = self._category_item(
            category_id="7eb28f3d-f9ca-4a28-b022-e91ce776f4a8",
            slug="kinh-doanh",
            name="Kinh doanh",
            description="Tin tuc doanh nghiep va thi truong",
        )
        repository = FakeCategoryRepository(
            {
                current.category_id: self._document(
                    content_hash=sha256_text("Cong nghe\n\nTin tuc cong nghe va AI"),
                    name=current.name,
                    description=current.description or "",
                )
            }
        )
        provider = FakeProvider()
        service = CategoryEmbeddingService(repository, provider, self.settings, self.logger)

        result = service.sync_categories([current, missing])

        self.assertEqual(result.processed_count, 1)
        self.assertEqual(result.skipped_count, 1)
        self.assertTrue(result.matches_refreshed)
        self.assertEqual(len(repository.replaced_embeddings), 1)
        self.assertEqual(repository.replaced_embeddings[0]["category"].category_id, missing.category_id)
        self.assertEqual(len(repository.refreshed_matches_calls), 1)
        self.assertEqual(
            repository.enqueued_sync_events,
            [
                {
                    "article_id": 42,
                    "model_name": "gemini-embedding-001",
                    "embedding_version": "v1",
                }
            ],
        )
        self.assertEqual(provider.calls[0][0], ["Kinh doanh\n\nTin tuc doanh nghiep va thi truong"])

    def test_inactive_category_that_was_previously_active_refreshes_matches(self):
        category = self._category_item(is_active=False)
        repository = FakeCategoryRepository(
            {
                category.category_id: self._document(
                    content_hash=sha256_text("Cong nghe\n\nTin tuc cong nghe va AI"),
                    name="Cong nghe",
                    description="Tin tuc cong nghe va AI",
                )
            }
        )
        provider = FakeProvider()
        service = CategoryEmbeddingService(repository, provider, self.settings, self.logger)

        result = service.sync_categories([category])

        self.assertEqual(result.processed_count, 0)
        self.assertEqual(result.skipped_count, 1)
        self.assertTrue(result.matches_refreshed)
        self.assertEqual(len(repository.refreshed_matches_calls), 1)
        self.assertEqual(len(repository.enqueued_sync_events), 1)
        self.assertEqual(provider.calls, [])

    @staticmethod
    def _category_item(
        *,
        category_id: str = "88f7fc9d-dc97-4e47-a2b1-f610a7a5f3f8",
        slug: str = "cong-nghe",
        name: str = "Cong nghe",
        description: str = "Tin tuc cong nghe va AI",
        is_active: bool = True,
    ) -> CategoryCatalogItem:
        now = datetime(2026, 3, 29, 12, 0, 0, tzinfo=timezone.utc)
        return CategoryCatalogItem(
            category_id=category_id,
            slug=slug,
            name=name,
            description=description,
            is_active=is_active,
            created_at=now,
            updated_at=now,
        )

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
