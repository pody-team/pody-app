from __future__ import annotations

from contextlib import contextmanager

from psycopg.types.json import Jsonb
from psycopg_pool import ConnectionPool

from app.model.entity import (
    ArticleCategoryMatch,
    ArticleEmbeddingDocument,
    CategoryCatalogItem,
    CategoryEmbeddingDocument,
    EmbeddingJob,
    OutboxEvent,
)
from app.model.request import ArticleEvent, KafkaMessageContext
from app.model.value_object import PreparedArticleChunk
from app.util.article_category_sync_event import (
    EVENT_TYPE as ARTICLE_CATEGORY_SYNC_EVENT_TYPE,
    build_article_category_sync_payload,
)


class EmbeddingRepository:
    """Repository lam viec voi DB embedding, pgvector, job va outbox."""

    def __init__(self, pool: ConnectionPool) -> None:
        self._pool = pool

    @contextmanager
    def _connection(self):
        """Lay connection tu pool va tu dong tra ve pool sau khi dung."""
        with self._pool.connection() as conn:
            yield conn

    def ping(self) -> bool:
        """Kiem tra nhanh database embedding co san sang khong."""
        try:
            with self._connection() as conn:
                conn.execute("SELECT 1").fetchone()
            return True
        except Exception:
            return False

    def get_document(self, *, article_id: int) -> ArticleEmbeddingDocument | None:
        """Lay document embedding metadata cua mot bai bao."""
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
        """Lay document embedding metadata cua mot category."""
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

    def count_ready_category_documents(self) -> int:
        """Dem category embedding dang ready va active."""
        with self._connection() as conn:
            row = conn.execute(
                """
                SELECT COUNT(*) AS ready_count
                FROM category_embedding_documents
                WHERE sync_status = 'ready'
                  AND is_active = TRUE
                """
            ).fetchone()
        return int(row["ready_count"] or 0)

    def list_publishable_outbox_events(self, *, limit: int) -> list[OutboxEvent]:
        """Lay cac outbox event san sang publish sang article_service."""
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT *
                FROM outbox_events
                WHERE status IN ('pending', 'failed')
                  AND available_at <= now()
                ORDER BY created_at ASC
                LIMIT %s
                """,
                (limit,),
            ).fetchall()
        return [OutboxEvent.from_row(row) for row in rows]

    def mark_outbox_event_published(self, *, event_id: str) -> None:
        """Danh dau outbox event da publish thanh cong."""
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                UPDATE outbox_events
                SET status = 'published',
                    last_error = NULL,
                    published_at = now()
                WHERE id = %s::uuid
                """,
                (event_id,),
            )

    def mark_outbox_event_failed(self, *, event_id: str, next_retry_at, error_message: str) -> None:
        """Danh dau outbox event publish loi va hen thoi diem retry."""
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                UPDATE outbox_events
                SET status = 'failed',
                    attempts = attempts + 1,
                    last_error = %s,
                    available_at = %s
                WHERE id = %s::uuid
                """,
                (error_message, next_retry_at, event_id),
            )

    def list_ready_public_article_ids(self) -> list[int]:
        """Lay id cac bai da embed san sang va dang PUBLISHED."""
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT article_id
                FROM article_embedding_documents
                WHERE sync_status = 'ready'
                  AND article_status = 'PUBLISHED'
                ORDER BY article_id ASC
                """
            ).fetchall()
        return [int(row["article_id"]) for row in rows]

    def sync_article_metadata(
        self,
        *,
        event: ArticleEvent,
        content_hash: str,
        chunking_signature: str,
        default_language_code: str,
    ) -> None:
        """Cap nhat metadata bai bao khi embedding hien co van tai su dung duoc."""
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
        """Upsert document metadata cho bai bao khong can/khong duoc tao embedding."""
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
        """Tao hoac reset job embedding cho mot event bai bao."""
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
        """Danh dau job va document bai bao dang duoc xu ly."""
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

    def replace_article_embedding(
        self,
        *,
        event: ArticleEvent,
        content_hash: str,
        chunking_signature: str,
        chunks: list[PreparedArticleChunk],
        embeddings: list[list[float]],
        document_embedding: list[float],
        model_name: str,
        embedding_version: str,
        output_dimensions: int,
        max_matches: int,
        min_score: float,
        default_language_code: str,
        job_id: int,
    ) -> None:
        """Thay the toan bo chunk/vector cua bai bao trong mot transaction."""
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

            # Xoa vector cu truoc khi chen lai de document luon phan anh embedding moi nhat.
            conn.execute(
                "DELETE FROM article_chunk_embeddings WHERE document_id = %s",
                (document_id,),
            )
            conn.execute(
                "DELETE FROM article_document_embeddings WHERE document_id = %s",
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
                INSERT INTO article_document_embeddings (
                    document_id,
                    article_id,
                    model_name,
                    embedding_version,
                    dimensions,
                    embedding
                )
                VALUES (%s, %s, %s, %s, %s, %s::vector)
                """,
                (
                    document_id,
                    event.article_id,
                    model_name,
                    embedding_version,
                    output_dimensions,
                    _to_pgvector_literal(document_embedding),
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
            self._refresh_article_category_matches_for_article(
                conn=conn,
                article_id=event.article_id,
                model_name=model_name,
                embedding_version=embedding_version,
                output_dimensions=output_dimensions,
                max_matches=max_matches,
                min_score=min_score,
            )
            self._enqueue_article_category_sync_event(
                conn=conn,
                article_id=event.article_id,
                model_name=model_name,
                embedding_version=embedding_version,
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

    def delete_article_category_matches(self, *, article_id: int) -> None:
        """Xoa cac match category semantic cua mot bai bao."""
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                DELETE FROM article_category_matches
                WHERE article_id = %s
                """,
                (article_id,),
            )

    def delete_article_category_matches_and_enqueue_sync_event(
        self,
        *,
        article_id: int,
        model_name: str,
        embedding_version: str,
    ) -> None:
        """Xoa match category va enqueue event sync de article_service cap nhat projection."""
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                DELETE FROM article_category_matches
                WHERE article_id = %s
                """,
                (article_id,),
            )
            self._enqueue_article_category_sync_event(
                conn=conn,
                article_id=article_id,
                model_name=model_name,
                embedding_version=embedding_version,
            )

    def sync_category_metadata(
        self,
        *,
        category: CategoryCatalogItem,
        content_hash: str,
        semantic_text: str,
    ) -> None:
        """Cap nhat metadata category khi embedding category hien co van dung duoc."""
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
                    category.slug,
                    category.name,
                    category.description,
                    category.is_active,
                    semantic_text,
                    content_hash,
                    category.category_id,
                ),
            )

    def upsert_category_document_without_embedding(
        self,
        *,
        category: CategoryCatalogItem,
        content_hash: str,
        semantic_text: str,
        sync_status: str,
    ) -> None:
        """Upsert category document khi category khong can/khong duoc tao embedding."""
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
                    category.category_id,
                    category.slug,
                    category.name,
                    category.description,
                    category.is_active,
                    semantic_text,
                    content_hash,
                    sync_status,
                ),
            )

    def replace_category_embedding(
        self,
        *,
        category: CategoryCatalogItem,
        content_hash: str,
        semantic_text: str,
        embedding: list[float],
        model_name: str,
        embedding_version: str,
        output_dimensions: int,
    ) -> None:
        """Thay the embedding vector cua mot category."""
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
                VALUES (%s::uuid, %s, %s, %s, %s, %s, %s, 'processing', NULL)
                ON CONFLICT (category_id) DO UPDATE SET
                    slug = EXCLUDED.slug,
                    name = EXCLUDED.name,
                    description = EXCLUDED.description,
                    is_active = EXCLUDED.is_active,
                    semantic_text = EXCLUDED.semantic_text,
                    content_hash = EXCLUDED.content_hash,
                    sync_status = 'processing',
                    last_error = NULL
                RETURNING id
                """,
                (
                    category.category_id,
                    category.slug,
                    category.name,
                    category.description,
                    category.is_active,
                    semantic_text,
                    content_hash,
                ),
            ).fetchone()
            if document_row is None:
                raise RuntimeError(
                    f"Document for category {category.category_id} was not prepared before embedding"
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
                    category.category_id,
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
    def refresh_article_category_matches_for_article(
        self,
        *,
        article_id: int,
        model_name: str,
        embedding_version: str,
        output_dimensions: int,
        max_matches: int,
        min_score: float,
    ) -> None:
        """Tinh lai category semantic cho mot bai bao va enqueue event sync."""
        with self._connection() as conn, conn.transaction():
            self._refresh_article_category_matches_for_article(
                conn=conn,
                article_id=article_id,
                model_name=model_name,
                embedding_version=embedding_version,
                output_dimensions=output_dimensions,
                max_matches=max_matches,
                min_score=min_score,
            )
            self._enqueue_article_category_sync_event(
                conn=conn,
                article_id=article_id,
                model_name=model_name,
                embedding_version=embedding_version,
            )

    def refresh_article_category_matches_for_all_articles(
        self,
        *,
        model_name: str,
        embedding_version: str,
        output_dimensions: int,
        max_matches: int,
        min_score: float,
    ) -> None:
        """Tinh lai category semantic cho tat ca bai da co document embedding."""
        with self._connection() as conn, conn.transaction():
            conn.execute(
                """
                DELETE FROM article_category_matches
                WHERE model_name = %s
                  AND embedding_version = %s
                """,
                (model_name, embedding_version),
            )
            conn.execute(
                """
                INSERT INTO article_category_matches (
                    article_id,
                    category_id,
                    score,
                    rank,
                    source,
                    model_name,
                    embedding_version
                )
                WITH ranked_matches AS (
                    SELECT
                        article_embedding.article_id,
                        category_embedding.category_id,
                        1 - (article_embedding.embedding <=> category_embedding.embedding) AS score,
                        row_number() OVER (
                            PARTITION BY article_embedding.article_id
                            ORDER BY article_embedding.embedding <=> category_embedding.embedding ASC,
                                     category_embedding.category_id ASC
                        ) AS rank
                    FROM article_document_embeddings AS article_embedding
                    INNER JOIN article_embedding_documents AS article_document
                        ON article_document.id = article_embedding.document_id
                    INNER JOIN category_embeddings AS category_embedding
                        ON category_embedding.model_name = article_embedding.model_name
                       AND category_embedding.embedding_version = article_embedding.embedding_version
                       AND category_embedding.dimensions = article_embedding.dimensions
                    INNER JOIN category_embedding_documents AS category_document
                        ON category_document.id = category_embedding.document_id
                    WHERE article_document.sync_status = 'ready'
                      AND article_document.article_status = 'PUBLISHED'
                      AND article_embedding.model_name = %s
                      AND article_embedding.embedding_version = %s
                      AND article_embedding.dimensions = %s
                      AND category_document.sync_status = 'ready'
                      AND category_document.is_active = TRUE
                )
                SELECT
                    article_id,
                    category_id,
                    score,
                    rank,
                    'semantic',
                    %s,
                    %s
                FROM ranked_matches
                WHERE rank <= %s
                  AND score >= %s
                """,
                (
                    model_name,
                    embedding_version,
                    output_dimensions,
                    model_name,
                    embedding_version,
                    max_matches,
                    min_score,
                ),
            )

    def enqueue_article_category_sync_event(
        self,
        *,
        article_id: int,
        model_name: str,
        embedding_version: str,
    ) -> None:
        """Tao outbox event sync category cho mot bai bao."""
        with self._connection() as conn, conn.transaction():
            self._enqueue_article_category_sync_event(
                conn=conn,
                article_id=article_id,
                model_name=model_name,
                embedding_version=embedding_version,
            )

    def list_article_category_matches(
        self,
        *,
        article_id: int,
        model_name: str,
        embedding_version: str,
    ) -> list[ArticleCategoryMatch]:
        """Lay danh sach category match cua mot bai bao theo model/version."""
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT *
                FROM article_category_matches
                WHERE article_id = %s
                  AND model_name = %s
                  AND embedding_version = %s
                ORDER BY rank ASC, category_id ASC
                """,
                (article_id, model_name, embedding_version),
            ).fetchall()
        return [ArticleCategoryMatch.from_row(row) for row in rows]

    def search_article_chunks(
        self,
        *,
        query_embedding: list[float],
        model_name: str,
        embedding_version: str,
        output_dimensions: int,
        limit: int,
    ) -> list[dict[str, object]]:
        """Tim cac chunk bai bao gan vector query nhat bang pgvector."""
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

    def _enqueue_article_category_sync_event(
        self,
        *,
        conn,
        article_id: int,
        model_name: str,
        embedding_version: str,
    ) -> None:
        """Tao payload event va ghi vao outbox trong transaction hien tai."""
        document_row = conn.execute(
            """
            SELECT article_status, content_hash
            FROM article_embedding_documents
            WHERE article_id = %s
            """,
            (article_id,),
        ).fetchone()
        if document_row is None:
            return

        match_rows = conn.execute(
            """
            SELECT *
            FROM article_category_matches
            WHERE article_id = %s
              AND model_name = %s
              AND embedding_version = %s
            ORDER BY rank ASC, category_id ASC
            """,
            (article_id, model_name, embedding_version),
        ).fetchall()
        matches = [ArticleCategoryMatch.from_row(row) for row in match_rows]
        payload = build_article_category_sync_payload(
            article_id=article_id,
            article_status=str(document_row["article_status"] or "PUBLISHED"),
            content_hash=str(document_row["content_hash"] or ""),
            model_name=model_name,
            embedding_version=embedding_version,
            matches=matches,
        )
        conn.execute(
            """
            INSERT INTO outbox_events (
                aggregate_type,
                aggregate_id,
                event_type,
                payload_version,
                payload,
                status
            )
            VALUES (%s, %s, %s, 1, %s, 'pending')
            """,
            (
                "article",
                str(article_id),
                ARTICLE_CATEGORY_SYNC_EVENT_TYPE,
                Jsonb(payload),
            ),
        )

    def _refresh_article_category_matches_for_article(
        self,
        *,
        conn,
        article_id: int,
        model_name: str,
        embedding_version: str,
        output_dimensions: int,
        max_matches: int,
        min_score: float,
    ) -> None:
        """Tinh category match cho mot bai bao bang cosine distance cua pgvector."""
        conn.execute(
            """
            DELETE FROM article_category_matches
            WHERE article_id = %s
              AND model_name = %s
              AND embedding_version = %s
            """,
            (article_id, model_name, embedding_version),
        )
        conn.execute(
            """
            INSERT INTO article_category_matches (
                article_id,
                category_id,
                score,
                rank,
                source,
                model_name,
                embedding_version
            )
            WITH ranked_matches AS (
                SELECT
                    article_embedding.article_id,
                    category_embedding.category_id,
                    1 - (article_embedding.embedding <=> category_embedding.embedding) AS score,
                    row_number() OVER (
                        PARTITION BY article_embedding.article_id
                        ORDER BY article_embedding.embedding <=> category_embedding.embedding ASC,
                                 category_embedding.category_id ASC
                    ) AS rank
                FROM article_document_embeddings AS article_embedding
                INNER JOIN article_embedding_documents AS article_document
                    ON article_document.id = article_embedding.document_id
                INNER JOIN category_embeddings AS category_embedding
                    ON category_embedding.model_name = article_embedding.model_name
                   AND category_embedding.embedding_version = article_embedding.embedding_version
                   AND category_embedding.dimensions = article_embedding.dimensions
                INNER JOIN category_embedding_documents AS category_document
                    ON category_document.id = category_embedding.document_id
                WHERE article_embedding.article_id = %s
                  AND article_document.sync_status = 'ready'
                  AND article_document.article_status = 'PUBLISHED'
                  AND article_embedding.model_name = %s
                  AND article_embedding.embedding_version = %s
                  AND article_embedding.dimensions = %s
                  AND category_document.sync_status = 'ready'
                  AND category_document.is_active = TRUE
            )
            SELECT
                article_id,
                category_id,
                score,
                rank,
                'semantic',
                %s,
                %s
            FROM ranked_matches
            WHERE rank <= %s
              AND score >= %s
            """,
            (
                article_id,
                model_name,
                embedding_version,
                output_dimensions,
                model_name,
                embedding_version,
                max_matches,
                min_score,
            ),
        )


def _to_pgvector_literal(values: list[float]) -> str:
    """Chuyen list float thanh literal '[...]' de bind vao cot pgvector."""
    if not values:
        raise ValueError("Embedding vector cannot be empty")
    return "[" + ",".join(format(float(value), ".12g") for value in values) + "]"
