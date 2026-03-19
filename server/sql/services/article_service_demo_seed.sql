BEGIN;

-- Seeding popular news sources in Vietnam
INSERT INTO news_sources (name, domain, rss_url, reliability_score, status) VALUES
('VnExpress', 'vnexpress.net', 'https://vnexpress.net/rss', 9.5, 'ACTIVE'),
('Thanh Nien', 'thanhnien.vn', 'https://thanhnien.vn/rss', 9.0, 'ACTIVE'),
('Tech Crunch', 'techcrunch.com', 'https://techcrunch.com/feed', 8.7, 'ACTIVE')
ON CONFLICT (domain) DO NOTHING;

COMMIT;
