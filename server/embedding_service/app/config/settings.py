from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
import os


PGVECTOR_DIMENSIONS = 1536


def _string_env(key: str, default: str) -> str:
    value = os.getenv(key, "").strip()
    return value or default


def _optional_string_env(*keys: str) -> str | None:
    for key in keys:
        value = os.getenv(key, "").strip()
        if value:
            return value
    return None


def _int_env(key: str, default: int) -> int:
    value = os.getenv(key, "").strip()
    if not value:
        return default
    parsed = int(value)
    if parsed <= 0:
        raise ValueError(f"{key} must be greater than zero")
    return parsed


def _float_env(key: str, default: float) -> float:
    value = os.getenv(key, "").strip()
    if not value:
        return default
    parsed = float(value)
    if parsed <= 0:
        raise ValueError(f"{key} must be greater than zero")
    return parsed


def _csv_env(key: str, default: list[str]) -> list[str]:
    value = os.getenv(key, "").strip()
    if not value:
        return default
    items = [item.strip() for item in value.split(",") if item.strip()]
    return items or default


@dataclass(frozen=True)
class DatabaseSettings:
    url: str
    pool_min_size: int
    pool_max_size: int
    startup_timeout_seconds: int
    retry_delay_seconds: float


@dataclass(frozen=True)
class KafkaSettings:
    brokers: list[str]
    topic: str
    category_topic: str
    client_id: str
    consumer_group: str
    auto_offset_reset: str
    topic_partitions: int
    topic_replication_factor: int
    request_timeout_ms: int
    session_timeout_ms: int
    startup_timeout_seconds: int
    retry_delay_seconds: float


@dataclass(frozen=True)
class GeminiSettings:
    api_keys: list[str]
    embedding_model: str
    embedding_version: str
    base_url: str | None
    output_dimensions: int
    batch_size: int
    quota_retry_delay_seconds: float


@dataclass(frozen=True)
class ArticleChunkSettings:
    target_chars: int
    overlap_chars: int
    min_chunk_chars: int
    default_language_code: str

    @property
    def signature(self) -> str:
        raw = (
            f"target_chars={self.target_chars}|"
            f"overlap_chars={self.overlap_chars}|"
            f"min_chunk_chars={self.min_chunk_chars}|"
            f"default_language_code={self.default_language_code}"
        )
        return sha256(raw.encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class AppSettings:
    port: int
    log_level: str
    database: DatabaseSettings
    kafka: KafkaSettings
    gemini: GeminiSettings
    article_chunking: ArticleChunkSettings


def load_settings() -> AppSettings:
    auto_offset_reset = _string_env("KAFKA_AUTO_OFFSET_RESET", "earliest").lower()
    if auto_offset_reset not in {"earliest", "latest"}:
        raise ValueError("KAFKA_AUTO_OFFSET_RESET must be either earliest or latest")

    database_url = _optional_string_env("EMBEDDING_DATABASE_URL", "DATABASE_URL")
    if not database_url:
        raise ValueError("EMBEDDING_DATABASE_URL or DATABASE_URL is required")

    raw_api_keys: list[str] = []
    raw_api_keys.extend(_csv_env("EMBEDDING_GEMINI_API_KEYS", []))
    for key in ("GOOGLE_API_KEY", "GEMINI_API_KEY"):
        value = os.getenv(key, "").strip()
        if value:
            raw_api_keys.append(value)

    api_keys: list[str] = []
    seen: set[str] = set()
    for api_key in raw_api_keys:
        if api_key not in seen:
            api_keys.append(api_key)
            seen.add(api_key)

    settings = AppSettings(
        port=_int_env("PORT", 8088),
        log_level=_string_env("LOG_LEVEL", "INFO"),
        database=DatabaseSettings(
            url=database_url,
            pool_min_size=_int_env("DATABASE_POOL_MIN_SIZE", 1),
            pool_max_size=_int_env("DATABASE_POOL_MAX_SIZE", 5),
            startup_timeout_seconds=_int_env("DATABASE_STARTUP_TIMEOUT_SECONDS", 120),
            retry_delay_seconds=_float_env("DATABASE_RETRY_DELAY_SECONDS", 2.0),
        ),
        kafka=KafkaSettings(
            brokers=_csv_env("KAFKA_BROKERS", ["localhost:9092"]),
            topic=_string_env("KAFKA_TOPIC", "article.embedding.requested"),
            category_topic=_string_env("KAFKA_CATEGORY_TOPIC", "category.embedding.requested"),
            client_id=_string_env("KAFKA_CLIENT_ID", "embedding-service"),
            consumer_group=_string_env("KAFKA_CONSUMER_GROUP", "embedding-service"),
            auto_offset_reset=auto_offset_reset,
            topic_partitions=_int_env("KAFKA_TOPIC_PARTITIONS", 1),
            topic_replication_factor=_int_env("KAFKA_TOPIC_REPLICATION_FACTOR", 1),
            request_timeout_ms=_int_env("KAFKA_REQUEST_TIMEOUT_MS", 30000),
            session_timeout_ms=_int_env("KAFKA_SESSION_TIMEOUT_MS", 10000),
            startup_timeout_seconds=_int_env("KAFKA_STARTUP_TIMEOUT_SECONDS", 120),
            retry_delay_seconds=_float_env("KAFKA_RETRY_DELAY_SECONDS", 2.0),
        ),
        gemini=GeminiSettings(
            api_keys=api_keys,
            embedding_model=_string_env("GEMINI_EMBEDDING_MODEL", "gemini-embedding-001"),
            embedding_version=_string_env("EMBEDDING_VERSION", "v1"),
            base_url=_optional_string_env("EMBEDDING_GOOGLE_GENAI_BASE_URL"),
            output_dimensions=_int_env("EMBEDDING_OUTPUT_DIMENSIONS", PGVECTOR_DIMENSIONS),
            batch_size=_int_env("EMBEDDING_BATCH_SIZE", 16),
            quota_retry_delay_seconds=_float_env("EMBEDDING_GEMINI_QUOTA_RETRY_DELAY_SECONDS", 60.0),
        ),
        article_chunking=ArticleChunkSettings(
            target_chars=_int_env("ARTICLE_CHUNK_TARGET_CHARS", 1400),
            overlap_chars=_int_env("ARTICLE_CHUNK_OVERLAP_CHARS", 180),
            min_chunk_chars=_int_env("ARTICLE_CHUNK_MIN_CHARS", 250),
            default_language_code=_string_env("ARTICLE_DEFAULT_LANGUAGE_CODE", "vi"),
        ),
    )

    if not settings.kafka.brokers:
        raise ValueError("KAFKA_BROKERS is required")
    if not settings.kafka.topic.strip():
        raise ValueError("KAFKA_TOPIC is required")
    if not settings.kafka.category_topic.strip():
        raise ValueError("KAFKA_CATEGORY_TOPIC is required")
    if settings.kafka.request_timeout_ms <= settings.kafka.session_timeout_ms:
        raise ValueError(
            "KAFKA_REQUEST_TIMEOUT_MS must be greater than KAFKA_SESSION_TIMEOUT_MS"
        )
    if settings.article_chunking.overlap_chars >= settings.article_chunking.target_chars:
        raise ValueError(
            "ARTICLE_CHUNK_OVERLAP_CHARS must be smaller than ARTICLE_CHUNK_TARGET_CHARS"
        )
    if settings.gemini.output_dimensions != PGVECTOR_DIMENSIONS:
        raise ValueError(
            f"EMBEDDING_OUTPUT_DIMENSIONS must be exactly {PGVECTOR_DIMENSIONS} for pgvector storage"
        )

    return settings
