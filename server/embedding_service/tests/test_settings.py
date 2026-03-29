import os
import unittest
from unittest.mock import patch

from app.config.settings import ArticleChunkSettings, load_settings


class SettingsTests(unittest.TestCase):
    def test_load_settings_collects_multiple_gemini_keys(self):
        with patch.dict(
            os.environ,
            {
                "EMBEDDING_DATABASE_URL": "postgresql://postgres:postgres@localhost:5434/pody_embedding",
                "EMBEDDING_GEMINI_API_KEYS": "key-a,key-b",
                "GOOGLE_API_KEY": "key-c",
                "KAFKA_REQUEST_TIMEOUT_MS": "30000",
                "KAFKA_SESSION_TIMEOUT_MS": "10000",
            },
            clear=True,
        ):
            settings = load_settings()

        self.assertEqual(settings.gemini.api_keys, ["key-a", "key-b", "key-c"])
        self.assertEqual(settings.kafka.topic, "article.embedding.requested")
        self.assertEqual(settings.kafka.category_topic, "category.embedding.requested")
        self.assertEqual(
            settings.database.url,
            "postgresql://postgres:postgres@localhost:5434/pody_embedding",
        )
        self.assertEqual(settings.gemini.output_dimensions, 1536)
        self.assertIsNone(settings.gemini.base_url)
        self.assertEqual(settings.gemini.quota_retry_delay_seconds, 60.0)

    def test_load_settings_prefers_embedding_database_url(self):
        with patch.dict(
            os.environ,
            {
                "EMBEDDING_DATABASE_URL": "postgresql://postgres:postgres@embedding-postgres:5432/pody_embedding",
                "DATABASE_URL": "postgresql://postgres:postgres@legacy-host:5432/legacy",
            },
            clear=True,
        ):
            settings = load_settings()

        self.assertEqual(
            settings.database.url,
            "postgresql://postgres:postgres@embedding-postgres:5432/pody_embedding",
        )

    def test_load_settings_uses_embedding_specific_base_url_only(self):
        with patch.dict(
            os.environ,
            {
                "EMBEDDING_DATABASE_URL": "postgresql://postgres:postgres@embedding-postgres:5432/pody_embedding",
                "GOOGLE_GENAI_BASE_URL": "http://host.docker.internal:3030",
                "EMBEDDING_GOOGLE_GENAI_BASE_URL": "http://embedding-proxy:3031",
            },
            clear=True,
        ):
            settings = load_settings()

        self.assertEqual(settings.gemini.base_url, "http://embedding-proxy:3031")

    def test_load_settings_does_not_fallback_to_shared_google_base_url(self):
        with patch.dict(
            os.environ,
            {
                "EMBEDDING_DATABASE_URL": "postgresql://postgres:postgres@embedding-postgres:5432/pody_embedding",
                "GOOGLE_GENAI_BASE_URL": "http://host.docker.internal:3030",
            },
            clear=True,
        ):
            settings = load_settings()

        self.assertIsNone(settings.gemini.base_url)

    def test_load_settings_reads_quota_retry_delay(self):
        with patch.dict(
            os.environ,
            {
                "EMBEDDING_DATABASE_URL": "postgresql://postgres:postgres@embedding-postgres:5432/pody_embedding",
                "EMBEDDING_GEMINI_QUOTA_RETRY_DELAY_SECONDS": "180",
            },
            clear=True,
        ):
            settings = load_settings()

        self.assertEqual(settings.gemini.quota_retry_delay_seconds, 180.0)

    def test_load_settings_reads_category_topic_override(self):
        with patch.dict(
            os.environ,
            {
                "EMBEDDING_DATABASE_URL": "postgresql://postgres:postgres@embedding-postgres:5432/pody_embedding",
                "KAFKA_CATEGORY_TOPIC": "taxonomy.category.embedding.requested",
            },
            clear=True,
        ):
            settings = load_settings()

        self.assertEqual(settings.kafka.category_topic, "taxonomy.category.embedding.requested")

    def test_load_settings_rejects_non_pgvector_dimensions(self):
        with patch.dict(
            os.environ,
            {
                "EMBEDDING_DATABASE_URL": "postgresql://postgres:postgres@localhost:5434/pody_embedding",
                "EMBEDDING_OUTPUT_DIMENSIONS": "768",
            },
            clear=True,
        ):
            with self.assertRaises(ValueError) as ctx:
                load_settings()

        self.assertIn("EMBEDDING_OUTPUT_DIMENSIONS", str(ctx.exception))

    def test_load_settings_rejects_invalid_timeout(self):
        with patch.dict(
            os.environ,
            {
                "KAFKA_REQUEST_TIMEOUT_MS": "10000",
                "KAFKA_SESSION_TIMEOUT_MS": "10000",
                "EMBEDDING_GEMINI_API_KEYS": "",
                "GOOGLE_API_KEY": "",
                "GEMINI_API_KEY": "",
            },
            clear=True,
        ):
            with self.assertRaises(ValueError) as ctx:
                load_settings()

        self.assertIn("EMBEDDING_DATABASE_URL", str(ctx.exception))

    def test_article_chunk_signature_changes_when_config_changes(self):
        baseline = ArticleChunkSettings(
            target_chars=1400,
            overlap_chars=180,
            min_chunk_chars=250,
            default_language_code="vi",
        )
        changed = ArticleChunkSettings(
            target_chars=1500,
            overlap_chars=180,
            min_chunk_chars=250,
            default_language_code="vi",
        )

        self.assertNotEqual(baseline.signature, changed.signature)


if __name__ == "__main__":
    unittest.main()
