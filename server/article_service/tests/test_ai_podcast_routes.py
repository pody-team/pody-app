import os
import sys
import unittest
from datetime import datetime, timezone

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ai_podcast.dependencies import get_ai_podcast_service
from ai_podcast.pipeline.research import build_research_pack
from ai_podcast.pipeline.validator import validate_script
from ai_podcast.schemas import ScriptDraft
from main import NewscrawlerApplication


class FakeAIPodcastService:
    def __init__(self) -> None:
        now = datetime(2026, 4, 1, 10, 0, tzinfo=timezone.utc)
        self.created_at = now

    async def create_job(self, *, owner_user_id: str, request):
        _ = request
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

    async def override_ai_podcast_service():
        return FakeAIPodcastService()

    app.dependency_overrides[get_ai_podcast_service] = override_ai_podcast_service
    return TestClient(app)


class AIPodcastRouteTests(unittest.TestCase):
    def test_create_podcast_job_requires_auth(self):
        client = create_client()

        response = client.post("/api/v1/article/podcast-jobs", json={"article_ids": [1]})

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()["detail"], "missing auth user id")

    def test_create_podcast_job_returns_queued_response(self):
        client = create_client()

        response = client.post(
            "/api/v1/article/podcast-jobs",
            headers={"X-Auth-User-ID": "42"},
            json={"article_ids": [1, 2], "target_minutes": 7, "voice": "Kore"},
        )

        self.assertEqual(response.status_code, 202)
        payload = response.json()
        self.assertEqual(payload["job_id"], "job-1")
        self.assertEqual(payload["status"], "queued")

    def test_list_podcast_jobs_returns_current_user_jobs(self):
        client = create_client()

        response = client.get(
            "/api/v1/article/podcast-jobs",
            headers={"X-Auth-User-ID": "42"},
        )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["jobs"][0]["status"], "completed")
        self.assertIn("audio_url", payload["jobs"][0])

    def test_get_podcast_job_detail_returns_draft_and_audio(self):
        client = create_client()

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


if __name__ == "__main__":
    unittest.main()
