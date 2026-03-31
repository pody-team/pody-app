BEGIN;

-- Seeding popular news sources in Vietnam
INSERT INTO news_sources (name, domain, rss_url, reliability_score, status) VALUES
('VnExpress', 'vnexpress.net', 'https://vnexpress.net/rss', 9.5, 'ACTIVE'),
('Thanh Nien', 'thanhnien.vn', 'https://thanhnien.vn/rss', 9.0, 'ACTIVE'),
('Tech Crunch', 'techcrunch.com', 'https://techcrunch.com/feed', 8.7, 'ACTIVE')
ON CONFLICT (domain) DO NOTHING;

INSERT INTO articles (
    source_id,
    title,
    author,
    summary,
    content,
    original_url,
    thumbnail_url,
    published_at,
    status
)
SELECT
    id,
    'Debezium smoke test article',
    'Pody Dev',
    'Article mẫu để kiểm tra luồng CDC sang Kafka.',
    'Nếu connector hoạt động, embedding-service sẽ log ra bản ghi này từ Kafka.',
    'https://pody.local/articles/debezium-smoke-test',
    'https://pody.local/assets/debezium-smoke-test.jpg',
    now(),
    'PUBLISHED'
FROM news_sources
WHERE domain = 'vnexpress.net'
ON CONFLICT (original_url) DO NOTHING;

-- Link the smoke-test article to the seeded technology taxonomy.
INSERT INTO category_articles (article_id, category_id, assignment_source, is_primary)
SELECT
    articles.id,
    categories.id,
    'manual',
    TRUE
FROM articles
JOIN categories
    ON categories.slug = 'cong-nghe'
WHERE articles.original_url = 'https://pody.local/articles/debezium-smoke-test'
ON CONFLICT (article_id, category_id, assignment_source) DO UPDATE SET
    is_primary = EXCLUDED.is_primary;

INSERT INTO article_stats (article_id, view_count)
SELECT id, 100 FROM articles LIMIT 1
ON CONFLICT (article_id) DO NOTHING;

COMMIT;
