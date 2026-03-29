import os
import sys
import unittest
from datetime import datetime, timezone
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config.category_embedding_eventing import load_category_embedding_eventing_settings
from models.category import Category
from utils.category_embedding_event import (
    CATEGORY_EMBEDDING_EVENT_TYPE,
    build_category_embedding_event_payload,
)


class CategoryEmbeddingEventTests(unittest.TestCase):
    def test_build_category_embedding_event_payload_uses_stable_contract(self):
        now = datetime(2026, 3, 29, 12, 0, 0, tzinfo=timezone.utc)
        category = Category(
            id="88f7fc9d-dc97-4e47-a2b1-f610a7a5f3f8",
            slug="cong-nghe",
            name="Cong nghe",
            description="Tin tuc cong nghe va AI",
            is_active=True,
            created_at=now,
            updated_at=now,
        )

        payload_one = build_category_embedding_event_payload(category)
        payload_two = build_category_embedding_event_payload(category)

        self.assertEqual(payload_one["event_type"], CATEGORY_EMBEDDING_EVENT_TYPE)
        self.assertEqual(payload_one["category_id"], category.id)
        self.assertEqual(payload_one["slug"], "cong-nghe")
        self.assertEqual(payload_one["name"], "Cong nghe")
        self.assertEqual(payload_one["description"], "Tin tuc cong nghe va AI")
        self.assertEqual(payload_one["idempotency_key"], payload_two["idempotency_key"])
        self.assertNotEqual(payload_one["event_id"], payload_two["event_id"])

    def test_eventing_settings_default_to_disabled(self):
        with patch.dict(os.environ, {}, clear=True):
            settings = load_category_embedding_eventing_settings()

        self.assertFalse(settings.enabled)
        self.assertEqual(settings.topic, "category.embedding.requested")
        self.assertEqual(settings.brokers, ["localhost:9092"])


if __name__ == "__main__":
    unittest.main()
