BEGIN;

INSERT INTO categories (id, slug, name, applies_to, sort_order, is_active)
VALUES
  ('51000000-0000-0000-0000-000000000001', 'cong-nghe', 'Cong nghe', 'show', 10, true),
  ('51000000-0000-0000-0000-000000000002', 'dieu-tra', 'Dieu tra', 'show', 20, true),
  ('51000000-0000-0000-0000-000000000003', 'cham-soc-ban-than', 'Cham soc ban than', 'show', 30, true),
  ('51000000-0000-0000-0000-000000000004', 'giai-thich-de-hieu', 'Giai thich de hieu', 'show', 40, true),
  ('51000000-0000-0000-0000-000000000005', 'chuyen-ke', 'Chuyen ke', 'show', 50, true),
  ('51000000-0000-0000-0000-000000000006', 'ngu-ngon', 'Ngu ngon', 'show', 60, true)
ON CONFLICT (id) DO UPDATE
SET
  slug = EXCLUDED.slug,
  name = EXCLUDED.name,
  applies_to = EXCLUDED.applies_to,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;

INSERT INTO tags (id, slug, name)
VALUES
  ('61000000-0000-0000-0000-000000000001', 'ai', 'AI'),
  ('61000000-0000-0000-0000-000000000002', 'tech', 'Tech'),
  ('61000000-0000-0000-0000-000000000003', 'weekly', 'Weekly'),
  ('61000000-0000-0000-0000-000000000004', 'crime', 'Crime'),
  ('61000000-0000-0000-0000-000000000005', 'case-files', 'Case Files'),
  ('61000000-0000-0000-0000-000000000006', 'night-listening', 'Night Listening'),
  ('61000000-0000-0000-0000-000000000007', 'night', 'Night'),
  ('61000000-0000-0000-0000-000000000008', 'reflection', 'Reflection'),
  ('61000000-0000-0000-0000-000000000009', 'architecture', 'Architecture'),
  ('61000000-0000-0000-0000-000000000010', 'mobile', 'Mobile'),
  ('61000000-0000-0000-0000-000000000011', 'mvvm', 'MVVM'),
  ('61000000-0000-0000-0000-000000000012', 'mvp', 'MVP'),
  ('61000000-0000-0000-0000-000000000013', 'product', 'Product'),
  ('61000000-0000-0000-0000-000000000014', 'true-crime', 'True Crime'),
  ('61000000-0000-0000-0000-000000000015', 'dna', 'DNA'),
  ('61000000-0000-0000-0000-000000000016', 'investigation', 'Investigation'),
  ('61000000-0000-0000-0000-000000000017', 'timeline', 'Timeline')
ON CONFLICT (id) DO UPDATE
SET
  slug = EXCLUDED.slug,
  name = EXCLUDED.name;

INSERT INTO shows (
  id,
  owner_user_id,
  owner_display_name_snapshot,
  owner_avatar_url_snapshot,
  title,
  slug,
  description,
  content_type,
  language_code,
  cover_image_url,
  publish_status,
  visibility,
  monetization_type,
  credit_cost,
  subscriber_count,
  episode_count,
  total_listen_count,
  published_at
)
VALUES
  (
    '11000000-0000-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111',
    'Pody Studio',
    'https://picsum.photos/seed/pody-owner/200/200',
    'Future Minds',
    'future-minds',
    'Show cong nghe do AI host Nova dan dat, bien nhung chu de ky thuat thanh cuoc tro chuyen de theo doi va de nho.',
    'podcast',
    'vi',
    'https://picsum.photos/seed/future-minds-cover/800/800',
    'published',
    'public',
    'free',
    0,
    12500,
    3,
    1200000,
    '2026-03-14T08:00:00Z'
  ),
  (
    '11000000-0000-0000-0000-000000000002',
    '11111111-1111-1111-1111-111111111111',
    'Pody Studio',
    'https://picsum.photos/seed/pody-owner/200/200',
    'True Crime Daily',
    'true-crime-daily',
    'Nhung ho so hinh su duoc ke lai theo nhip dieu tra cham, ro va co khong khi, do AI host Minh Tra dan dat.',
    'storytelling',
    'vi',
    'https://picsum.photos/seed/true-crime-daily/800/800',
    'published',
    'public',
    'free',
    0,
    8200,
    2,
    860000,
    '2026-03-13T08:00:00Z'
  ),
  (
    '11000000-0000-0000-0000-000000000003',
    '11111111-1111-1111-1111-111111111111',
    'Pody Studio',
    'https://picsum.photos/seed/pody-owner/200/200',
    'Midnight Reset',
    'midnight-reset',
    'Mot show chua co tap nao nhung da san sang voi AI host Lumi, danh cho cac episode tam su va reset cuoi ngay.',
    'storytelling',
    'vi',
    'https://picsum.photos/seed/midnight-reset/800/800',
    'published',
    'public',
    'free',
    0,
    5600,
    0,
    42000,
    '2026-03-15T08:00:00Z'
  )
ON CONFLICT (id) DO UPDATE
SET
  owner_user_id = EXCLUDED.owner_user_id,
  owner_display_name_snapshot = EXCLUDED.owner_display_name_snapshot,
  owner_avatar_url_snapshot = EXCLUDED.owner_avatar_url_snapshot,
  title = EXCLUDED.title,
  slug = EXCLUDED.slug,
  description = EXCLUDED.description,
  content_type = EXCLUDED.content_type,
  language_code = EXCLUDED.language_code,
  cover_image_url = EXCLUDED.cover_image_url,
  publish_status = EXCLUDED.publish_status,
  visibility = EXCLUDED.visibility,
  monetization_type = EXCLUDED.monetization_type,
  credit_cost = EXCLUDED.credit_cost,
  subscriber_count = EXCLUDED.subscriber_count,
  episode_count = EXCLUDED.episode_count,
  total_listen_count = EXCLUDED.total_listen_count,
  published_at = EXCLUDED.published_at,
  updated_at = now();

INSERT INTO show_categories (show_id, category_id, is_primary)
VALUES
  ('11000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', true),
  ('11000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000004', false),
  ('11000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000002', true),
  ('11000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000005', false),
  ('11000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000003', true),
  ('11000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000006', false)
ON CONFLICT (show_id, category_id) DO UPDATE
SET is_primary = EXCLUDED.is_primary;

INSERT INTO show_tags (show_id, tag_id)
VALUES
  ('11000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001'),
  ('11000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000002'),
  ('11000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000003'),
  ('11000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000004'),
  ('11000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000005'),
  ('11000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000006'),
  ('11000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000007'),
  ('11000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000008')
ON CONFLICT (show_id, tag_id) DO NOTHING;

INSERT INTO show_hosts (
  id,
  show_id,
  linked_voice_profile_id,
  display_name,
  avatar_url,
  role,
  persona_type,
  sort_order,
  bio
)
VALUES
  (
    '21000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000001',
    '31000000-0000-0000-0000-000000000001',
    'Nova',
    'https://picsum.photos/seed/nova-host/200/200',
    'host',
    'ai',
    0,
    'AI host cua Future Minds, chuyen bien cac chu de cong nghe thanh nhung cuoc tro chuyen de nghe va de nho.'
  ),
  (
    '21000000-0000-0000-0000-000000000002',
    '11000000-0000-0000-0000-000000000002',
    '31000000-0000-0000-0000-000000000002',
    'Minh Tra',
    'https://picsum.photos/seed/minh-tra-host/200/200',
    'host',
    'ai',
    0,
    'AI narrator chuyen ke cac ho so dieu tra, tap trung vao nhip ke cham va tao khong khi.'
  ),
  (
    '21000000-0000-0000-0000-000000000003',
    '11000000-0000-0000-0000-000000000003',
    '31000000-0000-0000-0000-000000000003',
    'Lumi',
    'https://picsum.photos/seed/lumi-host/200/200',
    'host',
    'ai',
    0,
    'AI host cho nhung episode nhe nhang, cham va de nghe vao buoi toi.'
  )
ON CONFLICT (id) DO UPDATE
SET
  linked_voice_profile_id = EXCLUDED.linked_voice_profile_id,
  display_name = EXCLUDED.display_name,
  avatar_url = EXCLUDED.avatar_url,
  role = EXCLUDED.role,
  persona_type = EXCLUDED.persona_type,
  sort_order = EXCLUDED.sort_order,
  bio = EXCLUDED.bio,
  updated_at = now();

INSERT INTO episodes (
  id,
  show_id,
  title,
  slug,
  description,
  season_number,
  episode_number,
  audio_url,
  cover_image_url,
  duration_seconds,
  publish_status,
  visibility,
  credit_cost,
  is_ai_generated,
  listen_count,
  like_count,
  comment_count,
  published_at
)
VALUES
  (
    '41000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000001',
    'MVC thoi hien dai: cu nhung khong ky',
    'mvc-thoi-hien-dai-cu-nhung-khong-ky',
    'Nova di tu nhung nguyen ly can ban cua MVC, tai sao kieu tach Model View Controller van hop ly, va luc nao can mot tang ViewModel thuc su.',
    1,
    1,
    'https://example.com/audio/future-minds-001.mp3',
    'https://picsum.photos/seed/future-minds-cover/800/800',
    1920,
    'published',
    'public',
    0,
    true,
    180000,
    12500,
    842,
    '2026-03-15T08:00:00Z'
  ),
  (
    '41000000-0000-0000-0000-000000000002',
    '11000000-0000-0000-0000-000000000001',
    'Nhin nhanh ve MVVM va MVP',
    'nhin-nhanh-ve-mvvm-va-mvp',
    'Mot tap de nghe nhanh nhung du cu the de phan biet MVVM, MVP va khi nao team nen chon moi huong.',
    1,
    2,
    'https://example.com/audio/future-minds-002.mp3',
    'https://picsum.photos/seed/future-minds-cover/800/800',
    1680,
    'published',
    'public',
    0,
    true,
    130000,
    8300,
    421,
    '2026-03-14T08:00:00Z'
  ),
  (
    '41000000-0000-0000-0000-000000000003',
    '11000000-0000-0000-0000-000000000001',
    'Clean Architecture thuc chien',
    'clean-architecture-thuc-chien',
    'Tap nay tong hop ba sai lam pho bien nhat khi dua clean architecture vao san pham dang ship.',
    1,
    3,
    'https://example.com/audio/future-minds-003.mp3',
    'https://picsum.photos/seed/future-minds-cover/800/800',
    2100,
    'published',
    'public',
    0,
    true,
    97000,
    6100,
    310,
    '2026-03-13T08:00:00Z'
  ),
  (
    '41000000-0000-0000-0000-000000000004',
    '11000000-0000-0000-0000-000000000002',
    'Ho so 1995 va vet ADN bi bo sot',
    'ho-so-1995-va-vet-adn-bi-bo-sot',
    'Minh Tra ke lai qua trinh mo lai mot ho so lanh khi mot mau ADN cu bat ngo khop voi du lieu moi.',
    1,
    1,
    'https://example.com/audio/true-crime-001.mp3',
    'https://picsum.photos/seed/true-crime-daily/800/800',
    2700,
    'published',
    'public',
    0,
    true,
    250000,
    84200,
    5200,
    '2026-03-16T08:00:00Z'
  ),
  (
    '41000000-0000-0000-0000-000000000005',
    '11000000-0000-0000-0000-000000000002',
    'Camera an ninh da noi gi trong 17 giay cuoi',
    'camera-an-ninh-da-noi-gi-trong-17-giay-cuoi',
    'Mot timeline duoc lap lai tu nhung khung hinh rat mo, va vi sao 17 giay co the thay doi toan bo ket luan.',
    1,
    2,
    'https://example.com/audio/true-crime-002.mp3',
    'https://picsum.photos/seed/true-crime-daily/800/800',
    2340,
    'published',
    'public',
    0,
    true,
    190000,
    43100,
    2100,
    '2026-03-14T20:00:00Z'
  )
ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  slug = EXCLUDED.slug,
  description = EXCLUDED.description,
  season_number = EXCLUDED.season_number,
  episode_number = EXCLUDED.episode_number,
  audio_url = EXCLUDED.audio_url,
  cover_image_url = EXCLUDED.cover_image_url,
  duration_seconds = EXCLUDED.duration_seconds,
  publish_status = EXCLUDED.publish_status,
  visibility = EXCLUDED.visibility,
  credit_cost = EXCLUDED.credit_cost,
  is_ai_generated = EXCLUDED.is_ai_generated,
  listen_count = EXCLUDED.listen_count,
  like_count = EXCLUDED.like_count,
  comment_count = EXCLUDED.comment_count,
  published_at = EXCLUDED.published_at,
  updated_at = now();

INSERT INTO episode_tags (episode_id, tag_id)
VALUES
  ('41000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000001'),
  ('41000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000009'),
  ('41000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000010'),
  ('41000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000009'),
  ('41000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000011'),
  ('41000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000012'),
  ('41000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000009'),
  ('41000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000013'),
  ('41000000-0000-0000-0000-000000000004', '61000000-0000-0000-0000-000000000014'),
  ('41000000-0000-0000-0000-000000000004', '61000000-0000-0000-0000-000000000015'),
  ('41000000-0000-0000-0000-000000000004', '61000000-0000-0000-0000-000000000016'),
  ('41000000-0000-0000-0000-000000000005', '61000000-0000-0000-0000-000000000016'),
  ('41000000-0000-0000-0000-000000000005', '61000000-0000-0000-0000-000000000017')
ON CONFLICT (episode_id, tag_id) DO NOTHING;

COMMIT;
