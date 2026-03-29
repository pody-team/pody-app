BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS news_sources (
    id BIGSERIAL PRIMARY KEY,
    domain VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    rss_url TEXT NOT NULL,
    reliability_score FLOAT DEFAULT 0.5,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Keep the oldest row per domain so unique indexes can be added safely
-- on databases where the demo seed has already run multiple times.
DELETE FROM news_sources a
USING news_sources b
WHERE a.id > b.id
  AND a.domain = b.domain;

CREATE TABLE IF NOT EXISTS articles (
    id BIGSERIAL PRIMARY KEY,
    source_id BIGINT NOT NULL,
    title TEXT NOT NULL,
    author VARCHAR(255),
    summary TEXT,
    content TEXT,
    original_url TEXT NOT NULL UNIQUE,
    thumbnail_url VARCHAR(1000),
    published_at TIMESTAMPTZ,
    status VARCHAR(50) NOT NULL DEFAULT 'PUBLISHED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_articles_original_url ON articles (original_url);
CREATE INDEX IF NOT EXISTS ix_articles_source_id ON articles (source_id);
CREATE INDEX IF NOT EXISTS ix_articles_published_at ON articles (published_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_news_sources_domain ON news_sources (domain);
CREATE UNIQUE INDEX IF NOT EXISTS uq_news_sources_rss_url ON news_sources (rss_url);

-- Trigger for updated_at if it's used in this project
-- (Other services seem to have a set_updated_at function)

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_news_sources_set_updated_at') THEN
        CREATE TRIGGER trg_news_sources_set_updated_at
        BEFORE UPDATE ON news_sources
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_articles_set_updated_at') THEN
        CREATE TRIGGER trg_articles_set_updated_at
        BEFORE UPDATE ON articles
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;
END $$;

-- --- NEW TABLES FOR EXTENDED FEATURES ---

-- 1. Canonical categories for the article domain.
-- CategoryUser belongs in identity-service later, so article-service only owns
-- Category and the CategoryArticle join table.
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(120) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_categories_name ON categories (name);
CREATE INDEX IF NOT EXISTS ix_categories_active ON categories (is_active);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_categories_set_updated_at') THEN
        CREATE TRIGGER trg_categories_set_updated_at
        BEFORE UPDATE ON categories
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS category_articles (
    id BIGSERIAL PRIMARY KEY,
    article_id BIGINT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_category_articles_article_category UNIQUE (article_id, category_id)
);
CREATE INDEX IF NOT EXISTS ix_category_articles_article_id ON category_articles (article_id);
CREATE INDEX IF NOT EXISTS ix_category_articles_category_id ON category_articles (category_id);
CREATE INDEX IF NOT EXISTS ix_category_articles_article_primary ON category_articles (article_id, is_primary);
CREATE UNIQUE INDEX IF NOT EXISTS uq_category_articles_primary
    ON category_articles (article_id)
    WHERE is_primary;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = 'article_categories'
    ) THEN
        INSERT INTO categories (slug, name, description, is_active)
        SELECT DISTINCT
            COALESCE(
                NULLIF(
                    trim(BOTH '-' FROM regexp_replace(lower(trim(category_name)), '[^a-z0-9]+', '-', 'g')),
                    ''
                ),
                'category-' || substr(md5(lower(trim(category_name))), 1, 12)
            ) AS slug,
            trim(category_name) AS name,
            NULL AS description,
            TRUE AS is_active
        FROM article_categories
        WHERE trim(category_name) <> ''
        ON CONFLICT (slug) DO NOTHING;

        INSERT INTO category_articles (article_id, category_id, is_primary)
        SELECT
            migrated.article_id,
            categories.id,
            migrated.category_rank = 1
        FROM (
            SELECT
                article_categories.id,
                article_categories.article_id,
                trim(article_categories.category_name) AS category_name,
                row_number() OVER (
                    PARTITION BY article_categories.article_id
                    ORDER BY article_categories.created_at ASC, article_categories.id ASC
                ) AS category_rank
            FROM article_categories
            WHERE trim(article_categories.category_name) <> ''
        ) AS migrated
        JOIN categories
            ON categories.slug = COALESCE(
                NULLIF(
                    trim(BOTH '-' FROM regexp_replace(lower(migrated.category_name), '[^a-z0-9]+', '-', 'g')),
                    ''
                ),
                'category-' || substr(md5(lower(migrated.category_name)), 1, 12)
            )
        ON CONFLICT (article_id, category_id) DO NOTHING;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS outbox_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type VARCHAR(80) NOT NULL,
    aggregate_id UUID NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    payload_version INTEGER NOT NULL DEFAULT 1,
    payload JSONB NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    available_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_outbox_events_status_available
    ON outbox_events (status, available_at);
CREATE INDEX IF NOT EXISTS ix_outbox_events_aggregate
    ON outbox_events (aggregate_type, aggregate_id, created_at DESC);

-- 2. Article Stats (View counts)
CREATE TABLE IF NOT EXISTS article_stats (
    article_id BIGINT PRIMARY KEY,
    view_count BIGINT DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Interaction table (LIKE, DISLIKE, LOVE)
CREATE TABLE IF NOT EXISTS article_interactions (
    id BIGSERIAL PRIMARY KEY,
    article_id BIGINT NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    interaction_type VARCHAR(50) NOT NULL, -- LIKE, LOVE, etc.
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_article_interactions_article_id ON article_interactions (article_id);
CREATE INDEX IF NOT EXISTS ix_article_interactions_user_id ON article_interactions (user_id);
DELETE FROM article_interactions a
USING article_interactions b
WHERE a.id < b.id
  AND a.article_id = b.article_id
  AND a.user_id = b.user_id;
CREATE UNIQUE INDEX IF NOT EXISTS uq_article_interactions_article_user
    ON article_interactions (article_id, user_id);

-- Backfill updated_at for older environments.
ALTER TABLE article_interactions
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE article_interactions
    ALTER COLUMN user_id TYPE VARCHAR(255) USING user_id::text;

-- 4. Metrics table (Reading metrics)
CREATE TABLE IF NOT EXISTS article_metrics (
    id BIGSERIAL PRIMARY KEY,
    article_id BIGINT NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    reading_time_seconds INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_article_metrics_article_id ON article_metrics (article_id);
ALTER TABLE article_metrics
    ALTER COLUMN user_id TYPE VARCHAR(255) USING user_id::text;

-- 5. Article comments
CREATE TABLE IF NOT EXISTS article_comments (
    id BIGSERIAL PRIMARY KEY,
    article_id BIGINT NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    user_name VARCHAR(255),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_article_comments_article_id ON article_comments (article_id);
CREATE INDEX IF NOT EXISTS ix_article_comments_user_id ON article_comments (user_id);
CREATE INDEX IF NOT EXISTS ix_article_comments_article_created_at
    ON article_comments (article_id, created_at DESC);
ALTER TABLE article_comments
    ALTER COLUMN user_id TYPE VARCHAR(255) USING user_id::text;

COMMIT;
