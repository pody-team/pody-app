BEGIN;

-- Seeding popular news sources in Vietnam
INSERT INTO news_sources (name, domain, rss_url, reliability_score, status) VALUES
('VnExpress', 'vnexpress.net', 'https://vnexpress.net/rss', 9.5, 'ACTIVE'),
('Thanh Nien', 'thanhnien.vn', 'https://thanhnien.vn/rss', 9.0, 'ACTIVE'),
('Tech Crunch', 'techcrunch.com', 'https://techcrunch.com/feed', 8.7, 'ACTIVE')
ON CONFLICT (domain) DO NOTHING;

-- Seeding demo categories and stats for existing articles
-- (Assuming some articles already exist from crawling)

INSERT INTO article_categories (article_id, category_name)
SELECT id, 'Tech' FROM articles LIMIT 1
ON CONFLICT DO NOTHING;

INSERT INTO article_stats (article_id, view_count)
SELECT id, 100 FROM articles LIMIT 1
ON CONFLICT (article_id) DO NOTHING;

COMMIT;
