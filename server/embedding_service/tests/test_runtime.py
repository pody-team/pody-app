import importlib
import logging
import sys
import types
import unittest
from types import SimpleNamespace
from unittest.mock import patch


def _install_runtime_import_stubs():
    database_module = types.ModuleType("app.config.database")
    database_module.create_pool = lambda settings: None

    controller_module = types.ModuleType("app.controller")
    controller_module.ArticleSearchController = type("ArticleSearchController", (), {})
    controller_module.ArticleEventController = type("ArticleEventController", (), {})
    controller_module.KafkaArticleConsumerController = type("KafkaArticleConsumerController", (), {})
    controller_module.KafkaArticleCategorySyncPublisher = type(
        "KafkaArticleCategorySyncPublisher", (), {}
    )
    controller_module.SystemController = type("SystemController", (), {})

    repository_module = types.ModuleType("app.model.repository")
    repository_module.CategoryCatalogRepository = type("CategoryCatalogRepository", (), {})
    repository_module.EmbeddingRepository = type("EmbeddingRepository", (), {})

    response_module = types.ModuleType("app.model.response")
    response_module.HealthResponse = type("HealthResponse", (), {})
    response_module.ServiceOverviewResponse = type("ServiceOverviewResponse", (), {})

    article_service_module = types.ModuleType("app.service.article_embedding_service")
    article_service_module.ArticleEmbeddingService = type("ArticleEmbeddingService", (), {})

    category_service_module = types.ModuleType("app.service.category_embedding_service")
    category_service_module.CategoryEmbeddingService = type("CategoryEmbeddingService", (), {})

    gemini_module = types.ModuleType("app.service.gemini_provider")
    gemini_module.GeminiEmbeddingProvider = type("GeminiEmbeddingProvider", (), {})

    return {
        "app.config.database": database_module,
        "app.controller": controller_module,
        "app.model.repository": repository_module,
        "app.model.response": response_module,
        "app.service.article_embedding_service": article_service_module,
        "app.service.category_embedding_service": category_service_module,
        "app.service.gemini_provider": gemini_module,
    }


with patch.dict(sys.modules, _install_runtime_import_stubs()):
    EmbeddingRuntime = importlib.import_module("app.runtime").EmbeddingRuntime


class _ProviderStub:
    def __init__(self, results, errors):
        self._results = list(results)
        self._errors = list(errors)
        self._index = 0
        self.last_error = None

    def probe(self):
        index = min(self._index, len(self._results) - 1)
        result = self._results[index]
        self.last_error = self._errors[index]
        self._index += 1
        return result


class RuntimeProviderProbeTests(unittest.TestCase):
    def _build_runtime(self, provider, *, startup_timeout_seconds=10, retry_delay_seconds=0.5):
        runtime = EmbeddingRuntime.__new__(EmbeddingRuntime)
        runtime.settings = SimpleNamespace(
            gemini=SimpleNamespace(
                startup_timeout_seconds=startup_timeout_seconds,
                retry_delay_seconds=retry_delay_seconds,
            )
        )
        runtime._provider = provider
        runtime._runtime_state = {}
        runtime._logger = logging.getLogger("embedding-service-runtime-tests")
        return runtime

    def test_wait_for_provider_retries_until_probe_succeeds(self):
        runtime = self._build_runtime(
            _ProviderStub(
                results=[False, False, True],
                errors=["403 Forbidden", "403 Forbidden", None],
            )
        )

        with patch("app.runtime.time.monotonic", side_effect=[0.0, 0.0, 1.0, 2.0]), patch(
            "app.runtime.time.sleep"
        ) as sleep_mock:
            ready = runtime._wait_for_provider()

        self.assertTrue(ready)
        self.assertTrue(runtime._runtime_state["provider_ready"])
        self.assertIsNone(runtime._runtime_state["last_error"])
        self.assertEqual(sleep_mock.call_count, 2)

    def test_wait_for_provider_stops_after_startup_timeout(self):
        runtime = self._build_runtime(
            _ProviderStub(
                results=[False, False],
                errors=["403 Forbidden", "403 Forbidden"],
            ),
            startup_timeout_seconds=1,
            retry_delay_seconds=0.25,
        )

        with patch("app.runtime.time.monotonic", side_effect=[0.0, 0.0, 1.5]), patch(
            "app.runtime.time.sleep"
        ) as sleep_mock:
            ready = runtime._wait_for_provider()

        self.assertFalse(ready)
        self.assertFalse(runtime._runtime_state["provider_ready"])
        self.assertEqual(runtime._runtime_state["last_error"], "403 Forbidden")
        sleep_mock.assert_called_once_with(0.25)


if __name__ == "__main__":
    unittest.main()
