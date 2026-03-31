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

INSERT INTO categories (id, slug, name, description, is_active)
VALUES
    ('0c4e34fd-8b70-4e5b-90c0-42b35e9cb2d1', 'thoi-su', 'Thoi su', 'Tin tuc cap nhat ve chinh tri, xa hoi va cac van de thoi su trong ngay.', TRUE),
    ('0c8ec260-3917-4871-baa7-dcb6957d8447', 'quoc-te', 'Quoc te', 'Tin tuc quoc te, dia chinh tri, kinh te va cac su kien noi bat tren the gioi.', TRUE),
    ('1463d0e3-5dc9-4ea6-a08b-d1916c76bfdf', 'kinh-doanh', 'Kinh doanh', 'Tin tuc doanh nghiep, thi truong, thuong mai va chien luoc kinh doanh.', TRUE),
    ('1c20459d-ec50-4217-8e8c-b2b962cf664f', 'tai-chinh', 'Tai chinh', 'Tin tuc tai chinh, dau tu, ngan hang, chung khoan va quan ly tai san.', TRUE),
    ('205f73c5-8394-48e1-a0c9-bdbfa8245041', 'cong-nghe', 'Cong nghe', 'Tin tuc cong nghe, AI, phan mem, thiet bi so va san pham moi.', TRUE),
    ('2b5b8a43-1e71-48df-9050-7c4f4f8944dd', 'khoa-hoc', 'Khoa hoc', 'Tin tuc nghien cuu, phat hien khoa hoc, doi moi va ung dung khoa hoc.', TRUE),
    ('364a4276-bcbc-4a53-972d-1d99226f07cb', 'giao-duc', 'Giao duc', 'Tin tuc giao duc, hoc tap, truong hoc, ky thi va xu huong dao tao.', TRUE),
    ('3f580fd8-6c52-406f-a82c-a4a4ad8eb49d', 'suc-khoe', 'Suc khoe', 'Tin tuc suc khoe, y te, dinh duong, phong benh va cham soc co the.', TRUE),
    ('46a6073f-0e74-47b3-b5ec-3f8a2dfadc2a', 'the-thao', 'The thao', 'Tin tuc bong da, the thao thanh tich cao, giai dau va van dong vien.', TRUE),
    ('58d6b7e5-f66e-43f5-9f75-e4b5a4504cae', 'giai-tri', 'Giai tri', 'Tin tuc phim anh, am nhac, nguoi noi tieng va xu huong giai tri.', TRUE),
    ('66553f6b-174c-46a5-9a5d-c89907a53f1b', 'van-hoa', 'Van hoa', 'Tin tuc van hoa, sach, nghe thuat, le hoi va doi song tinh than.', TRUE),
    ('771225a1-a3d7-45cd-af1c-a6cc02e5808c', 'phap-luat', 'Phap luat', 'Tin tuc phap luat, an ninh, chinh sach, vu an va quy dinh moi.', TRUE),
    ('84a8dc74-e420-4201-b032-b05e13b64344', 'du-lich', 'Du lich', 'Tin tuc du lich, diem den, kinh nghiem di chuyen va xu huong nghi duong.', TRUE),
    ('9ab92a57-c2e6-4db9-a512-7d4db09e5e0d', 'bat-dong-san', 'Bat dong san', 'Tin tuc thi truong nha dat, quy hoach, du an va dau tu bat dong san.', TRUE),
    ('a4d7c6bf-f1c1-4d10-9e42-0104d9f1f0f8', 'xe', 'Xe', 'Tin tuc oto, xe may, giao thong, cong nghe xe va danh gia phuong tien.', TRUE),
    ('b5bdb13e-9e2d-46ce-9dd0-d0f6fb757ced', 'doi-song', 'Doi song', 'Tin tuc doi song, gia dinh, tieu dung, xu huong song va cau chuyen xa hoi.', TRUE)
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

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
    assignment_source VARCHAR(20) NOT NULL DEFAULT 'manual',
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    match_rank INTEGER,
    score DOUBLE PRECISION,
    model_name VARCHAR(120),
    embedding_version VARCHAR(40),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE category_articles
    ADD COLUMN IF NOT EXISTS assignment_source VARCHAR(20) NOT NULL DEFAULT 'manual';
ALTER TABLE category_articles
    ADD COLUMN IF NOT EXISTS match_rank INTEGER;
ALTER TABLE category_articles
    ADD COLUMN IF NOT EXISTS score DOUBLE PRECISION;
ALTER TABLE category_articles
    ADD COLUMN IF NOT EXISTS model_name VARCHAR(120);
ALTER TABLE category_articles
    ADD COLUMN IF NOT EXISTS embedding_version VARCHAR(40);
ALTER TABLE category_articles
    ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE category_articles
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
UPDATE category_articles
SET assignment_source = COALESCE(NULLIF(assignment_source, ''), 'manual'),
    assigned_at = COALESCE(assigned_at, created_at),
    updated_at = COALESCE(updated_at, created_at);
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_category_articles_assignment_source'
    ) THEN
        ALTER TABLE category_articles
            ADD CONSTRAINT ck_category_articles_assignment_source
            CHECK (assignment_source IN ('manual', 'semantic'));
    END IF;
END $$;
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_category_articles_article_category'
    ) THEN
        ALTER TABLE category_articles
            DROP CONSTRAINT uq_category_articles_article_category;
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS ix_category_articles_article_id ON category_articles (article_id);
CREATE INDEX IF NOT EXISTS ix_category_articles_category_id ON category_articles (category_id);
CREATE INDEX IF NOT EXISTS ix_category_articles_article_source
    ON category_articles (article_id, assignment_source, match_rank);
CREATE INDEX IF NOT EXISTS ix_category_articles_article_primary
    ON category_articles (article_id, assignment_source, is_primary);
CREATE UNIQUE INDEX IF NOT EXISTS uq_category_articles_article_category_source
    ON category_articles (article_id, category_id, assignment_source);
DROP INDEX IF EXISTS uq_category_articles_primary;
CREATE UNIQUE INDEX IF NOT EXISTS uq_category_articles_primary_source
    ON category_articles (article_id, assignment_source)
    WHERE is_primary;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_category_articles_set_updated_at') THEN
        CREATE TRIGGER trg_category_articles_set_updated_at
        BEFORE UPDATE ON category_articles
        FOR EACH ROW
        EXECUTE FUNCTION set_updated_at();
    END IF;
END $$;

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

        INSERT INTO category_articles (article_id, category_id, assignment_source, is_primary, assigned_at, updated_at)
        SELECT
            migrated.article_id,
            categories.id,
            'manual',
            migrated.category_rank = 1,
            NOW(),
            NOW()
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
        ON CONFLICT (article_id, category_id, assignment_source) DO NOTHING;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS category_users (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS ix_category_users_user_id ON category_users (user_id);
CREATE INDEX IF NOT EXISTS ix_category_users_category_id ON category_users (category_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_category_users_user_category
    ON category_users (user_id, category_id);

CREATE TABLE IF NOT EXISTS inbox_processed_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL UNIQUE,
    source_service VARCHAR(80) NOT NULL,
    event_type VARCHAR(120) NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_inbox_processed_events_processed_at
    ON inbox_processed_events (processed_at);

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
