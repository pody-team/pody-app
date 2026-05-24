import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ai_podcast.config import load_ai_podcast_settings


class AIPodcastConfigTests(unittest.TestCase):
    def test_auto_mode_uses_vertex_when_cloud_project_present(self):
        with patch.dict(
            os.environ,
            {
                "GOOGLE_CLOUD_PROJECT": "tryapi-489314",
                "GOOGLE_CLOUD_LOCATION": "global",
                "AI_PROVIDER_MODE": "auto",
            },
            clear=False,
        ):
            settings = load_ai_podcast_settings()

        self.assertTrue(settings.use_google_provider)
        self.assertEqual(settings.google_cloud_project, "tryapi-489314")
        self.assertEqual(settings.google_cloud_location, "global")

    def test_auto_mode_does_not_enable_google_provider_from_proxy_base_url_alone(self):
        with patch.dict(
            os.environ,
            {
                "GOOGLE_CLOUD_PROJECT": "",
                "GOOGLE_GENAI_BASE_URL": "http://host.docker.internal:3030",
                "AI_PROVIDER_MODE": "auto",
            },
            clear=False,
        ):
            settings = load_ai_podcast_settings()

        self.assertFalse(settings.use_google_provider)

    def test_google_mode_requires_cloud_project(self):
        with patch.dict(
            os.environ,
            {
                "GOOGLE_CLOUD_PROJECT": "",
                "AI_PROVIDER_MODE": "google",
            },
            clear=False,
        ):
            with self.assertRaisesRegex(ValueError, "GOOGLE_CLOUD_PROJECT is required"):
                load_ai_podcast_settings()
