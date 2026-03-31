import unittest
from datetime import datetime, timezone
import os
import sys
from types import SimpleNamespace

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dependencies import get_article_engagement_service, get_article_query_service
from main import NewscrawlerApplication
from services import ArticleEngagementService, ArticleQueryService


class FakeArticleRepository:
    def __init__(self):
        self.article = SimpleNamespace(
            id=1,
            title="Sample article",
            content="<p>Body</p>",
            summary="Summary",
            author="Pody",
            thumbnail_url="https://example.com/image.jpg",
            original_url="https://example.com/article",
            published_at=datetime(2026, 3, 20, 10, 0, tzinfo=timezone.utc),
            source_id=9,
            status="PUBLISHED",
        )
        self.categories = [
            SimpleNamespace(
                id="205f73c5-8394-48e1-a0c9-bdbfa8245041",
                slug="tech",
                name="Tech",
                description="Cong nghe va san pham so",
            ),
            SimpleNamespace(
                id="1463d0e3-5dc9-4ea6-a08b-d1916c76bfdf",
                slug="business",
                name="Business",
                description="Kinh doanh",
            ),
        ]
        self.view_count = 3
        self.comments = []
        self.reactions_by_user = {}

    async def list_articles_with_extra(self, limit=20, offset=0, category=None, query=None):
        return [(self.article, "Tech", self.view_count)]

    async def get_by_id(self, article_id: int):
        return self.article if article_id == self.article.id else None

    async def get_article_detail(self, article_id: int):
        if article_id != self.article.id:
            return None
        return self.article, ["Tech"], self.view_count

    async def list_categories_with_counts(self):
        return [
            (self.categories[0], 12),
            (self.categories[1], 4),
        ]

    async def increment_view_count(self, article_id: int):
        self.view_count += 1

    async def add_interaction(self, article_id: int, user_id: int, interaction_type: str):
        current = self.reactions_by_user.get(user_id)
        if current == interaction_type:
            self.reactions_by_user.pop(user_id, None)
            return
        self.reactions_by_user[user_id] = interaction_type

    async def get_reaction_summary(self, article_id: int, user_id=None):
        values = list(self.reactions_by_user.values())
        return {
            "like_count": sum(1 for value in values if value == "LIKE"),
            "love_count": sum(1 for value in values if value == "LOVE"),
            "dislike_count": sum(1 for value in values if value == "DISLIKE"),
            "total_count": len(values),
            "current_user_reaction": self.reactions_by_user.get(user_id),
        }

    async def track_metric(self, article_id: int, user_id: int, reading_time_seconds: int):
        return None

    async def add_comment(self, article_id: int, user_id: int, content: str, user_name=None):
        comment = SimpleNamespace(
            id=len(self.comments) + 1,
            article_id=article_id,
            user_id=user_id,
            user_name=user_name,
            content=content,
            created_at=datetime(2026, 3, 20, 10, 1, tzinfo=timezone.utc),
            updated_at=datetime(2026, 3, 20, 10, 1, tzinfo=timezone.utc),
        )
        self.comments.insert(0, comment)
        return comment

    async def list_comments(self, article_id: int, limit: int = 20, offset: int = 0):
        return self.comments[offset : offset + limit]

    async def count_comments(self, article_id: int):
        return len(self.comments)


def create_client():
    repo = FakeArticleRepository()
    app = NewscrawlerApplication().api

    async def override_query_service():
        return ArticleQueryService(
            write_repository=repo,
            query_repository=repo,
            stats_repository=repo,
            reaction_repository=repo,
            comment_repository=repo,
        )

    async def override_engagement_service():
        return ArticleEngagementService(
            write_repository=repo,
            reaction_repository=repo,
            metric_repository=repo,
            comment_repository=repo,
        )

    app.dependency_overrides[get_article_query_service] = override_query_service
    app.dependency_overrides[get_article_engagement_service] = override_engagement_service
    return TestClient(app), repo


class ArticleAPIRouteTests(unittest.TestCase):
    def test_list_articles_returns_primary_category_string(self):
        client, _ = create_client()

        response = client.get("/api/v1/article")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["count"], 1)
        self.assertEqual(payload["articles"][0]["category"], "Tech")

    def test_get_article_detail_includes_reactions_and_comment_count(self):
        client, repo = create_client()
        repo.reactions_by_user["42"] = "LOVE"
        repo.comments.append(
            SimpleNamespace(
                id=1,
                article_id=1,
                user_id=7,
                user_name="Reader",
                content="Hay qua",
                created_at=datetime(2026, 3, 20, 10, 2, tzinfo=timezone.utc),
                updated_at=datetime(2026, 3, 20, 10, 2, tzinfo=timezone.utc),
            )
        )

        response = client.get("/api/v1/article/1", headers={"X-Auth-User-ID": "42"})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["comments_count"], 1)
        self.assertEqual(payload["categories"], ["Tech"])
        self.assertEqual(payload["reactions"]["love_count"], 1)
        self.assertEqual(payload["reactions"]["current_user_reaction"], "LOVE")
        self.assertTrue(payload["is_loved"])

    def test_list_categories_returns_real_category_payload(self):
        client, _ = create_client()

        response = client.get("/api/v1/article/categories")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["count"], 2)
        self.assertEqual(payload["categories"][0]["slug"], "tech")
        self.assertEqual(payload["categories"][0]["article_count"], 12)

    def test_list_categories_with_trailing_slash_returns_real_category_payload(self):
        client, _ = create_client()

        response = client.get("/api/v1/article/categories/")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["count"], 2)
        self.assertEqual(payload["categories"][1]["slug"], "business")

    def test_post_reaction_requires_auth_or_legacy_user_id(self):
        client, _ = create_client()

        response = client.post("/api/v1/article/1/reactions", json={"type": "LIKE"})

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()["detail"], "missing auth user id")

    def test_post_reaction_toggles_for_same_user(self):
        client, repo = create_client()

        first = client.post(
            "/api/v1/article/1/reactions",
            json={"type": "LIKE"},
            headers={"X-Auth-User-ID": "5"},
        )
        second = client.post(
            "/api/v1/article/1/reactions",
            json={"type": "LIKE"},
            headers={"X-Auth-User-ID": "5"},
        )

        self.assertEqual(first.status_code, 200)
        self.assertEqual(first.json()["reaction"], "LIKE")
        self.assertEqual(second.status_code, 200)
        self.assertIsNone(second.json()["reaction"])
        self.assertEqual(repo.reactions_by_user, {})

    def test_create_and_list_comments(self):
        client, _ = create_client()

        create_response = client.post(
            "/api/v1/article/1/comments",
            json={"content": "Bai viet rat huu ich"},
            headers={"X-Auth-User-ID": "8", "X-Auth-Name": "Thanh"},
        )

        self.assertEqual(create_response.status_code, 201)
        created = create_response.json()
        self.assertEqual(created["comment"]["user_name"], "Thanh")
        self.assertEqual(created["comments_count"], 1)

        list_response = client.get("/api/v1/article/1/comments")

        self.assertEqual(list_response.status_code, 200)
        payload = list_response.json()
        self.assertEqual(payload["total"], 1)
        self.assertEqual(payload["comments"][0]["content"], "Bai viet rat huu ich")


if __name__ == "__main__":
    unittest.main()
