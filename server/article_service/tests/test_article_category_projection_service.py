import logging
import os
import sys
import unittest
from datetime import datetime, timezone
from uuid import uuid4

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from category_sync_event import (
    InvalidArticleCategoryMatchesEventError,
    parse_article_category_matches_event,
)
from services.article_category_projection_service import ArticleCategoryProjectionService


class FakeRepository:
    def __init__(self) -> None:
        self.processed_events: set[str] = set()
        self.article_exists_value = True
        self.active_category_ids: set[str] = set()
        self.replaced_calls: list[dict[str, object]] = []
        self.marked_events: list[tuple[str, str, str]] = []

    async def has_processed_event(self, *, event_id):
        return str(event_id) in self.processed_events

    async def mark_event_processed(self, *, event_id, source_service, event_type):
        self.processed_events.add(str(event_id))
        self.marked_events.append((str(event_id), source_service, event_type))

    async def article_exists(self, *, article_id: int):
        return self.article_exists_value

    async def list_active_category_ids(self, *, category_ids: list[str]):
        return set(category_id for category_id in category_ids if category_id in self.active_category_ids)

    async def replace_semantic_category_links(self, **kwargs):
        self.replaced_calls.append(kwargs)


class ArticleCategoryProjectionServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_apply_event_replaces_semantic_rows_with_valid_matches(self):
        repository = FakeRepository()
        repository.active_category_ids = {
            "205f73c5-8394-48e1-a0c9-bdbfa8245041",
            "1463d0e3-5dc9-4ea6-a08b-d1916c76bfdf",
        }
        service = ArticleCategoryProjectionService(repository, logging.getLogger("category-sync-tests"))
        event = parse_article_category_matches_event(
            {
                "event_id": str(uuid4()),
                "idempotency_key": "article-category-sync:42:hash:model:v1",
                "event_type": "article.category.matches.generated.v1",
                "occurred_at": datetime(2026, 3, 29, 10, 0, 0, tzinfo=timezone.utc).isoformat(),
                "source_service": "embedding-service",
                "article_id": 42,
                "article_status": "PUBLISHED",
                "content_hash": "hash",
                "model_name": "gemini-embedding-001",
                "embedding_version": "v1",
                "matches": [
                    {
                        "category_id": "205f73c5-8394-48e1-a0c9-bdbfa8245041",
                        "rank": 1,
                        "score": 0.91,
                        "is_primary": True,
                    },
                    {
                        "category_id": "1463d0e3-5dc9-4ea6-a08b-d1916c76bfdf",
                        "rank": 2,
                        "score": 0.73,
                        "is_primary": False,
                    },
                ],
            }
        )

        result = await service.apply_event(event)

        self.assertEqual(result, "applied")
        self.assertEqual(len(repository.replaced_calls), 1)
        self.assertEqual(repository.replaced_calls[0]["article_id"], 42)
        self.assertEqual(
            repository.replaced_calls[0]["matches"],
            [
                {
                    "category_id": "205f73c5-8394-48e1-a0c9-bdbfa8245041",
                    "match_rank": 1,
                    "score": 0.91,
                    "is_primary": True,
                },
                {
                    "category_id": "1463d0e3-5dc9-4ea6-a08b-d1916c76bfdf",
                    "match_rank": 2,
                    "score": 0.73,
                    "is_primary": False,
                },
            ],
        )
        self.assertEqual(len(repository.marked_events), 1)

    async def test_apply_event_skips_duplicate_event(self):
        repository = FakeRepository()
        event_id = str(uuid4())
        repository.processed_events.add(event_id)
        service = ArticleCategoryProjectionService(repository, logging.getLogger("category-sync-tests"))
        event = parse_article_category_matches_event(self._payload(event_id=event_id))

        result = await service.apply_event(event)

        self.assertEqual(result, "duplicate")
        self.assertEqual(repository.replaced_calls, [])
        self.assertEqual(repository.marked_events, [])

    async def test_apply_event_clears_semantic_rows_when_matches_empty(self):
        repository = FakeRepository()
        service = ArticleCategoryProjectionService(repository, logging.getLogger("category-sync-tests"))
        event = parse_article_category_matches_event(self._payload(matches=[]))

        result = await service.apply_event(event)

        self.assertEqual(result, "applied")
        self.assertEqual(repository.replaced_calls[0]["matches"], [])
        self.assertEqual(len(repository.marked_events), 1)

    async def test_apply_event_marks_missing_article_as_processed(self):
        repository = FakeRepository()
        repository.article_exists_value = False
        service = ArticleCategoryProjectionService(repository, logging.getLogger("category-sync-tests"))
        event = parse_article_category_matches_event(self._payload())

        result = await service.apply_event(event)

        self.assertEqual(result, "missing-article")
        self.assertEqual(repository.replaced_calls, [])
        self.assertEqual(len(repository.marked_events), 1)

    def test_parse_article_category_matches_event_rejects_invalid_payload(self):
        with self.assertRaises(InvalidArticleCategoryMatchesEventError):
            parse_article_category_matches_event("not-a-json-object")

    @staticmethod
    def _payload(*, event_id: str | None = None, matches=None):
        return {
            "event_id": event_id or str(uuid4()),
            "idempotency_key": "article-category-sync:42:hash:model:v1",
            "event_type": "article.category.matches.generated.v1",
            "occurred_at": datetime(2026, 3, 29, 10, 0, 0, tzinfo=timezone.utc).isoformat(),
            "source_service": "embedding-service",
            "article_id": 42,
            "article_status": "PUBLISHED",
            "content_hash": "hash",
            "model_name": "gemini-embedding-001",
            "embedding_version": "v1",
            "matches": matches
            if matches is not None
            else [
                {
                    "category_id": "205f73c5-8394-48e1-a0c9-bdbfa8245041",
                    "rank": 1,
                    "score": 0.91,
                    "is_primary": True,
                }
            ],
        }


if __name__ == "__main__":
    unittest.main()
