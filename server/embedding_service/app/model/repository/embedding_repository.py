from __future__ import annotations

from contextlib import contextmanager

from psycopg.types.json import Jsonb
from psycopg_pool import ConnectionPool

from app.model.entity import ArticleEmbeddingDocument, CategoryEmbeddingDocument, EmbeddingJob
from app.model.request import ArticleEvent, CategoryEvent, KafkaMessageContext
from app.model.value_object import PreparedArticleChunk


class EmbeddingRepository:
    def __init__(self, pool: ConnectionPool) -> None:
        self._pool = pool

    @contextmanager
    def _connection(self):
        with self._pool.connection() as conn:
            yield conn

    def ping(self) -> bool:
        try:
            with self._connection() as conn:
                conn.execute("SELECT 1").fetchone()
            return True
        except Exception:
            return False

    def get_document(self, *, article_id: int) -> ArticleEmbeddingDocument | None:
        with self._connection() as conn:
            row = conn.execute(
                """
                SELECT *
                FROM article_embedding_documents
                WHERE article_id = %s
                """,
                (article_id,),
            ).fetchone()
        if row is None:
            return None
        return ArticleEmbeddingDocument.from_row(row)

    def get_category_document(self, *, category_id: str) -> CategoryEmbeddingDocument | None:
        with self._connection() as conn:
            row = conn.execute(
                """
                SELECT *
                FROM category_embedding_documents
                WHERE category_id = %s::uuid
                """,
                (category_id,),
            ).fetchone()
        if row is None:
            return None
        return CategoryEmbeddingDocument.from_row(row)

    def sync_article_metadata(
        self,
        *,
        event: ArticleEvent,
        content_hash: str,
        chunking_signature: str,
        default_language_code: str,
    ) -> None:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                UPDATE article_embedding_documents
                SET source_id = %s,
                    article_status = %s,
                    title = %s,
                    author = %s,
                    summary = %s,
                    content = %s,
                    original_url = %s,
                    thumbnail_url = %s,
                    published_at = %s,
                    language_code = %s,
                    content_hash = %s,
                    last_chunking_signature = %s,
                    last_error = NULL
                WHERE article_id = %s
                """,
                (
                    event.source_id,
                    event.status,
                    event.title,
                    event.author,
                    event.summary,
                    event.content or "",
                    event.original_url,
                    event.thumbnail_url,
                    event.published_at,
                    default_language_code,
                    content_hash,
                    chunking_signature,
                    event.article_id,
                ),
            )

    def upsert_article_document_without_embedding(
        self,
        *,
        event: ArticleEvent,
        content_hash: str,
        chunking_signature: str,
        default_language_code: str,
        sync_status: str,
    ) -> None:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                INSERT INTO article_embedding_documents (
                    article_id,
                    source_id,
                    article_status,
                    title,
                    author,
                    summary,
                    content,
                    original_url,
                    thumbnail_url,
                    published_at,
                    language_code,
                    content_hash,
                    sync_status,
                    last_error,
                    last_chunking_signature
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NULL, %s)
                ON CONFLICT (article_id) DO UPDATE SET
                    source_id = EXCLUDED.source_id,
                    article_status = EXCLUDED.article_status,
                    title = EXCLUDED.title,
                    author = EXCLUDED.author,
                    summary = EXCLUDED.summary,
                    content = EXCLUDED.content,
                    original_url = EXCLUDED.original_url,
                    thumbnail_url = EXCLUDED.thumbnail_url,
                    published_at = EXCLUDED.published_at,
                    language_code = EXCLUDED.language_code,
                    content_hash = EXCLUDED.content_hash,
                    sync_status = EXCLUDED.sync_status,
                    last_error = NULL,
                    last_chunking_signature = EXCLUDED.last_chunking_signature
                """,
                (
                    event.article_id,
                    event.source_id,
                    event.status,
                    event.title,
                    event.author,
                    event.summary,
                    event.content or "",
                    event.original_url,
                    event.thumbnail_url,
                    event.published_at,
                    default_language_code,
                    content_hash,
                    sync_status,
                    chunking_signature,
                ),
            )

    def enqueue_article_job(
        self,
        *,
        event: ArticleEvent,
        content_hash: str,
        model_name: str,
        embedding_version: str,
        chunking_signature: str,
        message: KafkaMessageContext,
        default_language_code: str,
    ) -> EmbeddingJob:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                INSERT INTO article_embedding_documents (
                    article_id,
                    source_id,
                    article_status,
                    title,
                    author,
                    summary,
                    content,
                    original_url,
                    thumbnail_url,
                    published_at,
                    language_code,
                    content_hash,
                    sync_status,
                    last_error,
                    last_chunking_signature
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'pending', NULL, %s)
                ON CONFLICT (article_id) DO UPDATE SET
                    source_id = EXCLUDED.source_id,
                    article_status = EXCLUDED.article_status,
                    title = EXCLUDED.title,
                    author = EXCLUDED.author,
                    summary = EXCLUDED.summary,
                    content = EXCLUDED.content,
                    original_url = EXCLUDED.original_url,
                    thumbnail_url = EXCLUDED.thumbnail_url,
                    published_at = EXCLUDED.published_at,
                    language_code = EXCLUDED.language_code,
                    content_hash = EXCLUDED.content_hash,
                    sync_status = 'pending',
                    last_error = NULL,
                    last_chunking_signature = EXCLUDED.last_chunking_signature
                """,
                (
                    event.article_id,
                    event.source_id,
                    event.status,
                    event.title,
                    event.author,
                    event.summary,
                    event.content or "",
                    event.original_url,
                    event.thumbnail_url,
                    event.published_at,
                    default_language_code,
                    content_hash,
                    chunking_signature,
                ),
            )
            row = conn.execute(
                """
                INSERT INTO embedding_jobs (
                    target_type,
                    target_id,
                    job_type,
                    source_topic,
                    source_partition,
                    source_offset,
                    source_key,
                    content_hash,
                    model_name,
                    embedding_version,
                    payload,
                    status
                )
                VALUES (
                    'article',
                    %s,
                    'embed_article',
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    'pending'
                )
                ON CONFLICT (target_type, target_id, job_type, content_hash, model_name, embedding_version)
                DO UPDATE SET
                    source_topic = EXCLUDED.source_topic,
                    source_partition = EXCLUDED.source_partition,
                    source_offset = EXCLUDED.source_offset,
                    source_key = EXCLUDED.source_key,
                    payload = EXCLUDED.payload,
                    status = 'pending',
                    error_message = NULL,
                    scheduled_at = now(),
                    started_at = NULL,
                    finished_at = NULL
                RETURNING *
                """,
                (
                    event.article_id,
                    message.topic,
                    message.partition,
                    message.offset,
                    message.key,
                    content_hash,
                    model_name,
                    embedding_version,
                    Jsonb(event.raw_payload),
                ),
            ).fetchone()
            return EmbeddingJob.from_row(row)

    def mark_job_processing(self, *, job_id: int, article_id: int) -> None:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                UPDATE embedding_jobs
                SET status = 'processing',
                    attempts = attempts + 1,
                    started_at = now(),
                    error_message = NULL
                WHERE id = %s
                """,
                (job_id,),
            )
            conn.execute(
                """
                UPDATE article_embedding_documents
                SET sync_status = 'processing',
                    last_error = NULL
                WHERE article_id = %s
                """,
                (article_id,),
            )

    def mark_category_job_processing(self, *, job_id: int, category_id: str) -> None:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                UPDATE embedding_jobs
                SET status = 'processing',
                    attempts = attempts + 1,
                    started_at = now(),
                    error_message = NULL
                WHERE id = %s
                """,
                (job_id,),
            )
            conn.execute(
                """
                UPDATE category_embedding_documents
                SET sync_status = 'processing',
                    last_error = NULL
                WHERE category_id = %s::uuid
                """,
                (category_id,),
            )

    def replace_article_embedding(
        self,
        *,
        event: ArticleEvent,
        content_hash: str,
        chunking_signature: str,
        chunks: list[PreparedArticleChunk],
        embeddings: list[list[float]],
        model_name: str,
        embedding_version: str,
        output_dimensions: int,
        default_language_code: str,
        job_id: int,
    ) -> None:
        if len(chunks) != len(embeddings):
            raise ValueError("chunks and embeddings must have the same length")

        with self._connection() as conn, conn.transaction():
            document_row = conn.execute(
                """
                UPDATE article_embedding_documents
                SET source_id = %s,
                    article_status = %s,
                    title = %s,
                    author = %s,
                    summary = %s,
                    content = %s,
                    original_url = %s,
                    thumbnail_url = %s,
                    published_at = %s,
                    language_code = %s,
                    content_hash = %s,
                    last_chunking_signature = %s
                WHERE article_id = %s
                RETURNING id
                """,
                (
                    event.source_id,
                    event.status,
                    event.title,
                    event.author,
                    event.summary,
                    event.content or "",
                    event.original_url,
                    event.thumbnail_url,
                    event.published_at,
                    default_language_code,
                    content_hash,
                    chunking_signature,
                    event.article_id,
                ),
            ).fetchone()
            if document_row is None:
                raise RuntimeError(
                    f"Document for article {event.article_id} was not prepared before embedding"
                )
            document_id = int(document_row["id"])

            conn.execute(
                "DELETE FROM article_chunk_embeddings WHERE document_id = %s",
                (document_id,),
            )
            conn.execute(
                "DELETE FROM article_embedding_chunks WHERE document_id = %s",
                (document_id,),
            )

            for chunk, embedding in zip(chunks, embeddings, strict=True):
                chunk_row = conn.execute(
                    """
                    INSERT INTO article_embedding_chunks (
                        document_id,
                        article_id,
                        chunk_index,
                        chunk_type,
                        content,
                        token_count_estimate,
                        char_count,
                        content_hash
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                    """,
                    (
                        document_id,
                        event.article_id,
                        chunk.chunk_index,
                        chunk.chunk_type,
                        chunk.content,
                        chunk.token_count_estimate,
                        chunk.char_count,
                        chunk.content_hash,
                    ),
                ).fetchone()
                chunk_id = int(chunk_row["id"])
                conn.execute(
                    """
                    INSERT INTO article_chunk_embeddings (
                        chunk_id,
                        document_id,
                        article_id,
                        model_name,
                        embedding_version,
                        dimensions,
                        embedding
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s::vector)
                    """,
                    (
                        chunk_id,
                        document_id,
                        event.article_id,
                        model_name,
                        embedding_version,
                        output_dimensions,
                        _to_pgvector_literal(embedding),
                    ),
                )

            conn.execute(
                """
                UPDATE article_embedding_documents
                SET chunk_count = %s,
                    sync_status = 'ready',
                    last_error = NULL,
                    last_embedding_model = %s,
                    last_embedding_version = %s,
                    last_embedding_dimensions = %s,
                    last_synced_at = now()
                WHERE id = %s
                """,
                (
                    len(chunks),
                    model_name,
                    embedding_version,
                    output_dimensions,
                    document_id,
                ),
            )
            conn.execute(
                """
                UPDATE embedding_jobs
                SET status = 'completed',
                    error_message = NULL,
                    finished_at = now()
                WHERE id = %s
                """,
                (job_id,),
            )

    def mark_job_failed(self, *, job_id: int, article_id: int, error_message: str) -> None:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                UPDATE embedding_jobs
                SET status = 'failed',
                    error_message = %s,
                    finished_at = now()
                WHERE id = %s
                """,
                (error_message, job_id),
            )
            conn.execute(
                """
                UPDATE article_embedding_documents
                SET sync_status = 'failed',
                    last_error = %s
                WHERE article_id = %s
                """,
                (error_message, article_id),
            )

    def sync_category_metadata(
        self,
        *,
        event: CategoryEvent,
        content_hash: str,
        semantic_text: str,
    ) -> None:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                UPDATE category_embedding_documents
                SET slug = %s,
                    name = %s,
                    description = %s,
                    is_active = %s,
                    semantic_text = %s,
                    content_hash = %s,
                    last_error = NULL
                WHERE category_id = %s::uuid
                """,
                (
                    event.slug,
                    event.name,
                    event.description,
                    event.is_active,
                    semantic_text,
                    content_hash,
                    event.category_id,
                ),
            )

    def upsert_category_document_without_embedding(
        self,
        *,
        event: CategoryEvent,
        content_hash: str,
        semantic_text: str,
        sync_status: str,
    ) -> None:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                INSERT INTO category_embedding_documents (
                    category_id,
                    slug,
                    name,
                    description,
                    is_active,
                    semantic_text,
                    content_hash,
                    sync_status,
                    last_error
                )
                VALUES (%s::uuid, %s, %s, %s, %s, %s, %s, %s, NULL)
                ON CONFLICT (category_id) DO UPDATE SET
                    slug = EXCLUDED.slug,
                    name = EXCLUDED.name,
                    description = EXCLUDED.description,
                    is_active = EXCLUDED.is_active,
                    semantic_text = EXCLUDED.semantic_text,
                    content_hash = EXCLUDED.content_hash,
                    sync_status = EXCLUDED.sync_status,
                    last_error = NULL
                """,
                (
                    event.category_id,
                    event.slug,
                    event.name,
                    event.description,
                    event.is_active,
                    semantic_text,
                    content_hash,
                    sync_status,
                ),
            )

    def enqueue_category_job(
        self,
        *,
        event: CategoryEvent,
        content_hash: str,
        semantic_text: str,
        model_name: str,
        embedding_version: str,
        message: KafkaMessageContext,
    ) -> EmbeddingJob:
        with self._connection() as conn, conn.transaction():
            document_row = conn.execute(
                """
                INSERT INTO category_embedding_documents (
                    category_id,
                    slug,
                    name,
                    description,
                    is_active,
                    semantic_text,
                    content_hash,
                    sync_status,
                    last_error
                )
                VALUES (%s::uuid, %s, %s, %s, %s, %s, %s, 'pending', NULL)
                ON CONFLICT (category_id) DO UPDATE SET
                    slug = EXCLUDED.slug,
                    name = EXCLUDED.name,
                    description = EXCLUDED.description,
                    is_active = EXCLUDED.is_active,
                    semantic_text = EXCLUDED.semantic_text,
                    content_hash = EXCLUDED.content_hash,
                    sync_status = 'pending',
                    last_error = NULL
                RETURNING id
                """,
                (
                    event.category_id,
                    event.slug,
                    event.name,
                    event.description,
                    event.is_active,
                    semantic_text,
                    content_hash,
                ),
            ).fetchone()
            document_id = int(document_row["id"])
            row = conn.execute(
                """
                INSERT INTO embedding_jobs (
                    target_type,
                    target_id,
                    job_type,
                    source_topic,
                    source_partition,
                    source_offset,
                    source_key,
                    content_hash,
                    model_name,
                    embedding_version,
                    payload,
                    status
                )
                VALUES (
                    'category',
                    %s,
                    'embed_category',
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    'pending'
                )
                ON CONFLICT (target_type, target_id, job_type, content_hash, model_name, embedding_version)
                DO UPDATE SET
                    source_topic = EXCLUDED.source_topic,
                    source_partition = EXCLUDED.source_partition,
                    source_offset = EXCLUDED.source_offset,
                    source_key = EXCLUDED.source_key,
                    payload = EXCLUDED.payload,
                    status = 'pending',
                    error_message = NULL,
                    scheduled_at = now(),
                    started_at = NULL,
                    finished_at = NULL
                RETURNING *
                """,
                (
                    document_id,
                    message.topic,
                    message.partition,
                    message.offset,
                    message.key,
                    content_hash,
                    model_name,
                    embedding_version,
                    Jsonb(event.raw_payload),
                ),
            ).fetchone()
            return EmbeddingJob.from_row(row)

    def replace_category_embedding(
        self,
        *,
        event: CategoryEvent,
        content_hash: str,
        semantic_text: str,
        embedding: list[float],
        model_name: str,
        embedding_version: str,
        output_dimensions: int,
        job_id: int,
    ) -> None:
        with self._connection() as conn, conn.transaction():
            document_row = conn.execute(
                """
                UPDATE category_embedding_documents
                SET slug = %s,
                    name = %s,
                    description = %s,
                    is_active = %s,
                    semantic_text = %s,
                    content_hash = %s
                WHERE category_id = %s::uuid
                RETURNING id
                """,
                (
                    event.slug,
                    event.name,
                    event.description,
                    event.is_active,
                    semantic_text,
                    content_hash,
                    event.category_id,
                ),
            ).fetchone()
            if document_row is None:
                raise RuntimeError(
                    f"Document for category {event.category_id} was not prepared before embedding"
                )
            document_id = int(document_row["id"])

            conn.execute(
                "DELETE FROM category_embeddings WHERE document_id = %s",
                (document_id,),
            )
            conn.execute(
                """
                INSERT INTO category_embeddings (
                    document_id,
                    category_id,
                    model_name,
                    embedding_version,
                    dimensions,
                    embedding
                )
                VALUES (%s, %s::uuid, %s, %s, %s, %s::vector)
                """,
                (
                    document_id,
                    event.category_id,
                    model_name,
                    embedding_version,
                    output_dimensions,
                    _to_pgvector_literal(embedding),
                ),
            )
            conn.execute(
                """
                UPDATE category_embedding_documents
                SET sync_status = 'ready',
                    last_error = NULL,
                    last_embedding_model = %s,
                    last_embedding_version = %s,
                    last_embedding_dimensions = %s,
                    last_synced_at = now()
                WHERE id = %s
                """,
                (
                    model_name,
                    embedding_version,
                    output_dimensions,
                    document_id,
                ),
            )
            conn.execute(
                """
                UPDATE embedding_jobs
                SET status = 'completed',
                    error_message = NULL,
                    finished_at = now()
                WHERE id = %s
                """,
                (job_id,),
            )

    def mark_category_job_failed(self, *, job_id: int, category_id: str, error_message: str) -> None:
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                UPDATE embedding_jobs
                SET status = 'failed',
                    error_message = %s,
                    finished_at = now()
                WHERE id = %s
                """,
                (error_message, job_id),
            )
            conn.execute(
                """
                UPDATE category_embedding_documents
                SET sync_status = 'failed',
                    last_error = %s
                WHERE category_id = %s::uuid
                """,
                (error_message, category_id),
            )

    def search_article_chunks(
        self,
        *,
        query_embedding: list[float],
        model_name: str,
        embedding_version: str,
        output_dimensions: int,
        limit: int,
    ) -> list[dict[str, object]]:
        vector_literal = _to_pgvector_literal(query_embedding)
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT
                    document.article_id,
                    document.title,
                    document.original_url,
                    chunk.chunk_index,
                    chunk.chunk_type,
                    LEFT(chunk.content, 280) AS chunk_preview,
                    1 - (embedding.embedding <=> %s::vector) AS score
                FROM article_chunk_embeddings AS embedding
                INNER JOIN article_embedding_chunks AS chunk
                    ON chunk.id = embedding.chunk_id
                INNER JOIN article_embedding_documents AS document
                    ON document.id = embedding.document_id
                WHERE document.sync_status = 'ready'
                    AND document.article_status = 'PUBLISHED'
                    AND embedding.model_name = %s
                    AND embedding.embedding_version = %s
                    AND embedding.dimensions = %s
                ORDER BY embedding.embedding <=> %s::vector
                LIMIT %s
                """,
                (
                    vector_literal,
                    model_name,
                    embedding_version,
                    output_dimensions,
                    vector_literal,
                    limit,
                ),
            ).fetchall()
        return [dict(row) for row in rows]


def _to_pgvector_literal(values: list[float]) -> str:
    if not values:
        raise ValueError("Embedding vector cannot be empty")
    return "[" + ",".join(format(float(value), ".12g") for value in values) + "]"
