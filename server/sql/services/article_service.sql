BEGIN;

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

-- 1. Article Categories (M-1 or M-M)
CREATE TABLE IF NOT EXISTS article_categories (
    id BIGSERIAL PRIMARY KEY,
    article_id BIGINT NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_article_categories_article_id ON article_categories (article_id);
CREATE INDEX IF NOT EXISTS ix_article_categories_name ON article_categories (category_name);

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
