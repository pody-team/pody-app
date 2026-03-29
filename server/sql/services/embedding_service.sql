BEGIN;

CREATE EXTENSION IF NOT EXISTS vector;

CREATE OR REPLACE FUNCTION set_embedding_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS article_embedding_documents (
    id BIGSERIAL PRIMARY KEY,
    article_id BIGINT NOT NULL UNIQUE,
    source_id BIGINT NOT NULL,
    article_status VARCHAR(50) NOT NULL DEFAULT 'PUBLISHED',
    title TEXT NOT NULL,
    author VARCHAR(255),
    summary TEXT,
    content TEXT NOT NULL DEFAULT '',
    original_url TEXT NOT NULL,
    thumbnail_url TEXT,
    language_code VARCHAR(16) NOT NULL DEFAULT 'vi',
    published_at TIMESTAMPTZ,
    content_hash CHAR(64) NOT NULL,
    chunk_count INTEGER NOT NULL DEFAULT 0,
    sync_status VARCHAR(32) NOT NULL DEFAULT 'pending',
    last_error TEXT,
    last_embedding_model VARCHAR(120),
    last_embedding_version VARCHAR(40),
    last_embedding_dimensions INTEGER,
    last_chunking_signature CHAR(64) NOT NULL,
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_article_embedding_documents_source_id
    ON article_embedding_documents (source_id);
CREATE INDEX IF NOT EXISTS ix_article_embedding_documents_sync_status
    ON article_embedding_documents (sync_status, last_synced_at DESC);
CREATE INDEX IF NOT EXISTS ix_article_embedding_documents_content_hash
    ON article_embedding_documents (content_hash);

CREATE TABLE IF NOT EXISTS article_embedding_chunks (
    id BIGSERIAL PRIMARY KEY,
    document_id BIGINT NOT NULL REFERENCES article_embedding_documents(id) ON DELETE CASCADE,
    article_id BIGINT NOT NULL,
    chunk_index INTEGER NOT NULL,
    chunk_type VARCHAR(32) NOT NULL,
    content TEXT NOT NULL,
    token_count_estimate INTEGER NOT NULL DEFAULT 0,
    char_count INTEGER NOT NULL DEFAULT 0,
    content_hash CHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (document_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS ix_article_embedding_chunks_article_id
    ON article_embedding_chunks (article_id);
CREATE INDEX IF NOT EXISTS ix_article_embedding_chunks_document_id
    ON article_embedding_chunks (document_id);

CREATE TABLE IF NOT EXISTS article_chunk_embeddings (
    id BIGSERIAL PRIMARY KEY,
    chunk_id BIGINT NOT NULL REFERENCES article_embedding_chunks(id) ON DELETE CASCADE,
    document_id BIGINT NOT NULL REFERENCES article_embedding_documents(id) ON DELETE CASCADE,
    article_id BIGINT NOT NULL,
    model_name VARCHAR(120) NOT NULL,
    embedding_version VARCHAR(40) NOT NULL,
    dimensions INTEGER NOT NULL,
    embedding VECTOR(1536) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (chunk_id, model_name, embedding_version)
);

CREATE INDEX IF NOT EXISTS ix_article_chunk_embeddings_article_id
    ON article_chunk_embeddings (article_id);
CREATE INDEX IF NOT EXISTS ix_article_chunk_embeddings_document_id
    ON article_chunk_embeddings (document_id);
CREATE INDEX IF NOT EXISTS ix_article_chunk_embeddings_model
    ON article_chunk_embeddings (model_name, embedding_version);
CREATE INDEX IF NOT EXISTS ix_article_chunk_embeddings_embedding_cosine_hnsw
    ON article_chunk_embeddings USING hnsw (embedding vector_cosine_ops);

CREATE TABLE IF NOT EXISTS category_embedding_documents (
    id BIGSERIAL PRIMARY KEY,
    category_id UUID NOT NULL UNIQUE,
    slug VARCHAR(120) NOT NULL,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    semantic_text TEXT NOT NULL DEFAULT '',
    content_hash CHAR(64) NOT NULL,
    sync_status VARCHAR(32) NOT NULL DEFAULT 'pending',
    last_error TEXT,
    last_embedding_model VARCHAR(120),
    last_embedding_version VARCHAR(40),
    last_embedding_dimensions INTEGER,
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_category_embedding_documents_slug
    ON category_embedding_documents (slug);
CREATE INDEX IF NOT EXISTS ix_category_embedding_documents_sync_status
    ON category_embedding_documents (sync_status, last_synced_at DESC);
CREATE INDEX IF NOT EXISTS ix_category_embedding_documents_content_hash
    ON category_embedding_documents (content_hash);

CREATE TABLE IF NOT EXISTS category_embeddings (
    id BIGSERIAL PRIMARY KEY,
    document_id BIGINT NOT NULL REFERENCES category_embedding_documents(id) ON DELETE CASCADE,
    category_id UUID NOT NULL,
    model_name VARCHAR(120) NOT NULL,
    embedding_version VARCHAR(40) NOT NULL,
    dimensions INTEGER NOT NULL,
    embedding VECTOR(1536) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (document_id, model_name, embedding_version)
);

CREATE INDEX IF NOT EXISTS ix_category_embeddings_category_id
    ON category_embeddings (category_id);
CREATE INDEX IF NOT EXISTS ix_category_embeddings_document_id
    ON category_embeddings (document_id);
CREATE INDEX IF NOT EXISTS ix_category_embeddings_model
    ON category_embeddings (model_name, embedding_version);
CREATE INDEX IF NOT EXISTS ix_category_embeddings_embedding_cosine_hnsw
    ON category_embeddings USING hnsw (embedding vector_cosine_ops);

CREATE TABLE IF NOT EXISTS embedding_jobs (
    id BIGSERIAL PRIMARY KEY,
    target_type VARCHAR(40) NOT NULL,
    target_id BIGINT NOT NULL,
    job_type VARCHAR(40) NOT NULL,
    source_topic VARCHAR(255),
    source_partition INTEGER,
    source_offset BIGINT,
    source_key TEXT,
    content_hash CHAR(64) NOT NULL,
    model_name VARCHAR(120) NOT NULL,
    embedding_version VARCHAR(40) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    attempts INTEGER NOT NULL DEFAULT 0,
    error_message TEXT,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (target_type, target_id, job_type, content_hash, model_name, embedding_version)
);

CREATE INDEX IF NOT EXISTS ix_embedding_jobs_status
    ON embedding_jobs (status, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS ix_embedding_jobs_target
    ON embedding_jobs (target_type, target_id);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_article_embedding_documents_set_updated_at') THEN
        CREATE TRIGGER trg_article_embedding_documents_set_updated_at
        BEFORE UPDATE ON article_embedding_documents
        FOR EACH ROW
        EXECUTE FUNCTION set_embedding_updated_at();
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_category_embedding_documents_set_updated_at') THEN
        CREATE TRIGGER trg_category_embedding_documents_set_updated_at
        BEFORE UPDATE ON category_embedding_documents
        FOR EACH ROW
        EXECUTE FUNCTION set_embedding_updated_at();
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_embedding_jobs_set_updated_at') THEN
        CREATE TRIGGER trg_embedding_jobs_set_updated_at
        BEFORE UPDATE ON embedding_jobs
        FOR EACH ROW
        EXECUTE FUNCTION set_embedding_updated_at();
    END IF;
END $$;

COMMIT;
