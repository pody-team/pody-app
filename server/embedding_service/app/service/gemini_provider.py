from __future__ import annotations

import logging
import threading

from google import genai
from google.genai import types

from app.config.settings import GeminiSettings


class EmbeddingRateLimitError(RuntimeError):
    def __init__(self, message: str, *, retry_delay_seconds: float) -> None:
        super().__init__(message)
        self.retry_delay_seconds = retry_delay_seconds


class GeminiEmbeddingProvider:
    def __init__(self, settings: GeminiSettings, logger: logging.Logger) -> None:
        self._settings = settings
        self._logger = logger
        self._lock = threading.Lock()
        self._client_index = 0
        self._clients = [self._build_client(api_key) for api_key in settings.api_keys]
        self._probe_ready = False
        self._last_error: str | None = None

    @property
    def configured_api_keys(self) -> int:
        return len(self._clients)

    @property
    def is_ready(self) -> bool:
        return self._probe_ready

    @property
    def has_credentials(self) -> bool:
        return bool(self._clients)

    @property
    def last_error(self) -> str | None:
        return self._last_error

    def probe(self) -> bool:
        if not self._clients:
            self._probe_ready = False
            self._last_error = "No Gemini API key configured for embedding-service"
            return False

        last_error: Exception | None = None
        for _ in range(len(self._clients)):
            client_index, client = self._current_client()
            try:
                client.models.get(model=self._settings.embedding_model)
                self._probe_ready = True
                self._last_error = None
                self._logger.info(
                    "Gemini embedding provider is reachable with configured model %s using key #%s",
                    self._settings.embedding_model,
                    client_index + 1,
                )
                return True
            except Exception as exc:
                last_error = exc
                self._last_error = str(exc)
                self._probe_ready = False
                self._logger.warning(
                    "Gemini provider probe failed with key #%s: %s",
                    client_index + 1,
                    exc,
                )
                if len(self._clients) > 1:
                    self._rotate_client()

        return False

    def embed_texts(self, texts: list[str], *, task_type: str) -> list[list[float]]:
        if not texts:
            return []
        if not self._clients:
            self._probe_ready = False
            self._last_error = "No Gemini API key configured for embedding-service"
            raise RuntimeError("No Gemini API key configured for embedding-service")

        embeddings: list[list[float]] = []
        for batch in _chunked(texts, self._settings.batch_size):
            embeddings.extend(self._embed_batch(batch, task_type=task_type))
        return embeddings

    def _build_client(self, api_key: str) -> genai.Client:
        http_options = None
        if self._settings.base_url:
            http_options = types.HttpOptions(baseUrl=self._settings.base_url)
        return genai.Client(api_key=api_key, http_options=http_options)

    def _build_config(self, *, task_type: str) -> types.EmbedContentConfig:
        payload: dict[str, object] = {
            "task_type": task_type,
        }
        if self._settings.output_dimensions is not None:
            payload["output_dimensionality"] = self._settings.output_dimensions
        return types.EmbedContentConfig(**payload)

    def _current_client(self) -> tuple[int, genai.Client]:
        with self._lock:
            return self._client_index, self._clients[self._client_index]

    def _rotate_client(self) -> None:
        with self._lock:
            self._client_index = (self._client_index + 1) % len(self._clients)

    def _embed_batch(self, texts: list[str], *, task_type: str) -> list[list[float]]:
        last_error: Exception | None = None
        for _ in range(len(self._clients)):
            client_index, client = self._current_client()
            try:
                response = client.models.embed_content(
                    model=self._settings.embedding_model,
                    contents=texts,
                    config=self._build_config(task_type=task_type),
                )
                embeddings = [_extract_embedding_values(item) for item in response.embeddings]
                if len(embeddings) != len(texts):
                    raise RuntimeError(
                        f"Gemini returned {len(embeddings)} embeddings for {len(texts)} texts"
                    )
                self._probe_ready = True
                self._last_error = None
                return embeddings
            except Exception as exc:
                last_error = exc
                self._probe_ready = False
                self._last_error = str(exc)
                if self._should_rotate(exc):
                    self._rotate_client()
                    self._logger.warning(
                        "Gemini API key #%s is exhausted or rate-limited. Rotating to the next key.",
                        client_index + 1,
                    )
                    continue
                raise

        raise EmbeddingRateLimitError(
            (
                "All configured Gemini API keys are currently rate-limited or quota-exhausted. "
                f"Backing off for {self._settings.quota_retry_delay_seconds:.0f}s before retrying."
            ),
            retry_delay_seconds=self._settings.quota_retry_delay_seconds,
        ) from last_error

    @staticmethod
    def _should_rotate(exc: Exception) -> bool:
        message = str(exc).lower()
        if not message:
            return False
        markers = (
            "resource_exhausted",
            "quota",
            "rate limit",
            "429",
            "too many requests",
        )
        return any(marker in message for marker in markers)


def _extract_embedding_values(item: object) -> list[float]:
    values = getattr(item, "values", None)
    if values is None and isinstance(item, dict):
        values = item.get("values")
    if not isinstance(values, (list, tuple)):
        raise RuntimeError("Gemini embedding response item does not contain numeric values")
    return [float(value) for value in values]


def _chunked(items: list[str], size: int) -> list[list[str]]:
    return [items[index : index + size] for index in range(0, len(items), size)]
