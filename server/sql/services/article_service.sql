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

COMMIT;
