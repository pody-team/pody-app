import os
import sys
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ai_podcast.dependencies import get_ai_podcast_service
from ai_podcast.pipeline.research import build_research_pack
from ai_podcast.pipeline.validator import validate_script
from ai_podcast.repository import (
    AIPodcastRepository,
    MissingSelectedArticlesError,
    NoRecommendedArticlesError,
)
from ai_podcast.schemas import ScriptDraft
from main import NewscrawlerApplication


class FakeAIPodcastService:
    def __init__(self) -> None:
        now = datetime(2026, 4, 1, 10, 0, tzinfo=timezone.utc)
        self.created_at = now
        self.requests = []

    async def create_job(self, *, owner_user_id: str, request):
        self.requests.append(
            {
                "owner_user_id": owner_user_id,
                "article_ids": list(request.article_ids),
                "target_minutes": request.target_minutes,
                "voice": request.voice,
            }
        )
        if owner_user_id == "missing":
            raise ValueError("not used")
        return {
            "job_id": "job-1",
            "status": "queued",
            "created_at": self.created_at,
        }

    async def list_jobs(self, *, owner_user_id: str):
        _ = owner_user_id
        return {
            "jobs": [
                {
                    "job_id": "job-1",
                    "status": "completed",
                    "title": "Podcast bao chi: AI",
                    "audio_url": "http://localhost:9000/article-podcasts/u1/job-1/podcast.wav",
                    "created_at": self.created_at,
                    "updated_at": self.created_at,
                }
            ]
        }

    async def get_job_detail(self, *, owner_user_id: str, job_id: str):
        _ = owner_user_id
        if job_id != "job-1":
            raise Exception("should not be called with other ids in this fake")
        return {
            "job_id": "job-1",
            "status": "completed",
            "selected_articles": [
                {"article_id": 1, "title": "AI chip race", "summary": "Summary"}
            ],
            "research_summary": "Tong hop nhom bai bao nguoi dung da chon.",
            "podcast_title": "Podcast bao chi: AI",
            "podcast_description": "Ban tom tat audio ve AI.",
            "outline": ["Mo dau", "Noi dung chinh", "Ket lai"],
            "script_text": "Xin chao, day la ban tin audio ve AI.",
            "audio_url": "http://localhost:9000/article-podcasts/u1/job-1/podcast.wav",
            "duration_seconds": 120,
            "error": None,
            "created_at": self.created_at,
            "updated_at": self.created_at,
        }


def create_client():
    app = NewscrawlerApplication().api
    service = FakeAIPodcastService()

    async def override_ai_podcast_service():
        return service

    app.dependency_overrides[get_ai_podcast_service] = override_ai_podcast_service
    return TestClient(app), service


class AIPodcastRouteTests(unittest.TestCase):
    def test_create_podcast_job_requires_auth(self):
        client, _ = create_client()

        response = client.post("/api/v1/article/podcast-jobs", json={"article_ids": [1]})

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()["detail"], "missing auth user id")

    def test_create_podcast_job_returns_queued_response(self):
        client, service = create_client()

        response = client.post(
            "/api/v1/article/podcast-jobs",
            headers={"X-Auth-User-ID": "42"},
            json={"article_ids": [1, 2], "target_minutes": 7, "voice": "Kore"},
        )

        self.assertEqual(response.status_code, 202)
        payload = response.json()
        self.assertEqual(payload["job_id"], "job-1")
        self.assertEqual(payload["status"], "queued")
        self.assertEqual(service.requests[-1]["article_ids"], [1, 2])

    def test_create_podcast_job_accepts_empty_article_ids(self):
        client, service = create_client()

        response = client.post(
            "/api/v1/article/podcast-jobs",
            headers={"X-Auth-User-ID": "42"},
            json={"article_ids": []},
        )

        self.assertEqual(response.status_code, 202)
        self.assertEqual(service.requests[-1]["article_ids"], [])

    def test_list_podcast_jobs_returns_current_user_jobs(self):
        client, _ = create_client()

        response = client.get(
            "/api/v1/article/podcast-jobs",
            headers={"X-Auth-User-ID": "42"},
        )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["jobs"][0]["status"], "completed")
        self.assertIn("audio_url", payload["jobs"][0])

    def test_get_podcast_job_detail_returns_draft_and_audio(self):
        client, _ = create_client()

        response = client.get(
            "/api/v1/article/podcast-jobs/job-1",
            headers={"X-Auth-User-ID": "42"},
        )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["podcast_title"], "Podcast bao chi: AI")
        self.assertEqual(payload["selected_articles"][0]["article_id"], 1)
        self.assertEqual(payload["duration_seconds"], 120)


class AIPodcastValidatorTests(unittest.TestCase):
    def test_validator_flags_missing_script(self):
        report = validate_script(
            draft=ScriptDraft(
                podcast_title="",
                podcast_description="desc",
                outline=[],
                script_text="",
            ),
            target_minutes=6,
        )

        self.assertFalse(report.valid)
        self.assertTrue(report.errors)


class AIPodcastResearchTests(unittest.TestCase):
    def test_research_pack_truncates_long_topic_hint(self):
        class RecordingSearchTool:
            def __init__(self) -> None:
                self.query = ""

            def search(self, *, query: str):
                self.query = query
                return {"query": query, "results": []}

        search_tool = RecordingSearchTool()
        selected_articles = [
            {
                "title": (
                    "Quan mi Michelin gia 50.000 dong khien khach xep hang o Bangkok "
                    "Nguoi Viet o My lan dau tac nghiep o tran derby nong nhat Texas "
                    "Thang 4 Nguoi Viet duoc chiem nguong 2 sao choi va mua sao bang cung xuat hien"
                ),
                "summary": "summary",
            }
        ]

        build_research_pack(
            selected_articles=selected_articles,
            search_tool=search_tool,
        )

        self.assertLessEqual(len(search_tool.query), 240)
        self.assertIn("boi canh moi nhat", search_tool.query)

    def test_research_pack_falls_back_when_external_search_fails(self):
        class FailingSearchTool:
            def search(self, *, query: str):
                raise RuntimeError(f"boom: {query}")

        research_pack = build_research_pack(
            selected_articles=[
                {
                    "title": "AI chip race",
                    "summary": "summary",
                }
            ],
            search_tool=FailingSearchTool(),
        )

        self.assertEqual(research_pack.primary_sources[0]["title"], "AI chip race")
        self.assertEqual(research_pack.external_context_sources, [])
        self.assertIn("External research unavailable", research_pack.research_summary)


class _FakeSession:
    def __init__(self) -> None:
        self.added = []

    def add(self, instance):
        self.added.append(instance)

    async def flush(self):
        return None


class _FakeRepository(AIPodcastRepository):
    def __init__(self, selected_articles=None, recommended_articles=None):
        super().__init__(_FakeSession())
        self._selected_articles = selected_articles or {}
        self._recommended_articles = recommended_articles or []

    async def _load_articles(self, article_ids):
        return [self._selected_articles[article_id] for article_id in article_ids if article_id in self._selected_articles]

    async def _load_recommended_articles(self, *, owner_user_id: str, limit: int):
        _ = owner_user_id
        return list(self._recommended_articles[:limit])


class AIPodcastRepositoryTests(unittest.IsolatedAsyncioTestCase):
    @staticmethod
    def _article(article_id: int):
        return SimpleNamespace(
            id=article_id,
            title=f"Article {article_id}",
            summary=f"Summary {article_id}",
        )

    async def test_create_job_auto_fills_from_recommended_articles(self):
        repository = _FakeRepository(recommended_articles=[self._article(index) for index in range(1, 21)])

        job = await repository.create_job(
            owner_user_id="u1",
            request=SimpleNamespace(article_ids=[], voice=None, target_minutes=6, language_code="vi"),
        )

        job_articles = [item for item in repository.session.added if item.__class__.__name__ == "ArticlePodcastJobArticle"]
        self.assertEqual(len(job_articles), 20)
        self.assertEqual(job.target_minutes, 12)
        self.assertEqual(job_articles[0].article_id, 1)
        self.assertEqual(job_articles[-1].article_id, 20)

    async def test_create_job_trims_to_last_twenty_selected_articles(self):
        selected_articles = {index: self._article(index) for index in range(1, 26)}
        repository = _FakeRepository(selected_articles=selected_articles)

        await repository.create_job(
            owner_user_id="u1",
            request=SimpleNamespace(article_ids=list(range(1, 26)), voice=None, target_minutes=6, language_code="vi"),
        )

        job_articles = [item for item in repository.session.added if item.__class__.__name__ == "ArticlePodcastJobArticle"]
        self.assertEqual([item.article_id for item in job_articles], list(range(6, 26)))

    async def test_create_job_deduplicates_before_trimming(self):
        selected_articles = {index: self._article(index) for index in range(1, 23)}
        repository = _FakeRepository(selected_articles=selected_articles)

        await repository.create_job(
            owner_user_id="u1",
            request=SimpleNamespace(
                article_ids=[1, 2, 2, 3, 4, 4] + list(range(5, 23)),
                voice=None,
                target_minutes=6,
                language_code="vi",
            ),
        )

        job_articles = [item for item in repository.session.added if item.__class__.__name__ == "ArticlePodcastJobArticle"]
        self.assertEqual([item.article_id for item in job_articles], list(range(3, 23)))

    async def test_create_job_raises_when_explicit_article_missing(self):
        repository = _FakeRepository(selected_articles={1: self._article(1)})

        with self.assertRaises(MissingSelectedArticlesError):
            await repository.create_job(
                owner_user_id="u1",
                request=SimpleNamespace(article_ids=[1, 2], voice=None, target_minutes=6, language_code="vi"),
            )

    async def test_create_job_raises_when_no_recommended_articles_exist(self):
        repository = _FakeRepository(recommended_articles=[])

        with self.assertRaises(NoRecommendedArticlesError):
            await repository.create_job(
                owner_user_id="u1",
                request=SimpleNamespace(article_ids=[], voice=None, target_minutes=6, language_code="vi"),
            )

    async def test_target_minutes_are_derived_from_resolved_article_count(self):
        repository = _FakeRepository(selected_articles={index: self._article(index) for index in range(1, 16)})

        job = await repository.create_job(
            owner_user_id="u1",
            request=SimpleNamespace(article_ids=list(range(1, 16)), voice=None, target_minutes=1, language_code="vi"),
        )

        self.assertEqual(job.target_minutes, 9)


if __name__ == "__main__":
    unittest.main()
