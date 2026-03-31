BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug citext NOT NULL UNIQUE,
  name varchar(120) NOT NULL,
  icon_name varchar(80),
  color_hex varchar(7),
  applies_to text NOT NULL DEFAULT 'show'
    CHECK (applies_to IN ('show', 'news', 'mixed')),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug citext NOT NULL UNIQUE,
  name varchar(80) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS shows (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL,
  owner_display_name_snapshot varchar(120),
  owner_avatar_url_snapshot text,
  title varchar(200) NOT NULL,
  slug citext NOT NULL UNIQUE,
  description text NOT NULL DEFAULT '',
  content_type text NOT NULL DEFAULT 'podcast'
    CHECK (content_type IN ('podcast', 'storytelling', 'news_digest')),
  language_code varchar(10) NOT NULL DEFAULT 'vi',
  cover_image_url text,
  publish_status text NOT NULL DEFAULT 'draft'
    CHECK (publish_status IN ('draft', 'published', 'archived')),
  visibility text NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public', 'unlisted', 'followers_only')),
  monetization_type text NOT NULL DEFAULT 'free'
    CHECK (monetization_type IN ('free', 'subscription', 'credit_unlock')),
  credit_cost integer NOT NULL DEFAULT 0 CHECK (credit_cost >= 0),
  subscriber_count bigint NOT NULL DEFAULT 0 CHECK (subscriber_count >= 0),
  episode_count integer NOT NULL DEFAULT 0 CHECK (episode_count >= 0),
  total_listen_count bigint NOT NULL DEFAULT 0 CHECK (total_listen_count >= 0),
  published_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS show_categories (
  show_id uuid NOT NULL REFERENCES shows(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (show_id, category_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_show_categories_primary
  ON show_categories (show_id)
  WHERE is_primary;

CREATE TABLE IF NOT EXISTS show_tags (
  show_id uuid NOT NULL REFERENCES shows(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES tags(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (show_id, tag_id)
);

CREATE TABLE IF NOT EXISTS show_hosts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  show_id uuid NOT NULL REFERENCES shows(id) ON DELETE CASCADE,
  linked_user_id uuid,
  linked_voice_profile_id uuid,
  display_name varchar(120) NOT NULL,
  avatar_url text,
  role text NOT NULL DEFAULT 'host'
    CHECK (role IN ('host', 'co_host', 'guest', 'narrator')),
  persona_type text NOT NULL DEFAULT 'human'
    CHECK (persona_type IN ('human', 'ai')),
  sort_order smallint NOT NULL CHECK (sort_order >= 0),
  bio text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_show_hosts_order UNIQUE (show_id, sort_order)
);

CREATE TABLE IF NOT EXISTS episodes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  show_id uuid NOT NULL REFERENCES shows(id) ON DELETE CASCADE,
  source_plan_id uuid,
  title varchar(240) NOT NULL,
  slug citext NOT NULL,
  description text NOT NULL DEFAULT '',
  season_number integer NOT NULL DEFAULT 1 CHECK (season_number >= 1),
  episode_number integer CHECK (episode_number >= 1),
  audio_url text,
  audio_storage_key text,
  cover_image_url text,
  duration_seconds integer NOT NULL DEFAULT 0 CHECK (duration_seconds >= 0),
  publish_status text NOT NULL DEFAULT 'draft'
    CHECK (publish_status IN ('draft', 'scheduled', 'published', 'archived', 'failed')),
  visibility text NOT NULL DEFAULT 'public'
    CHECK (visibility IN ('public', 'followers_only', 'premium')),
  credit_cost integer NOT NULL DEFAULT 0 CHECK (credit_cost >= 0),
  is_ai_generated boolean NOT NULL DEFAULT false,
  listen_count bigint NOT NULL DEFAULT 0 CHECK (listen_count >= 0),
  like_count bigint NOT NULL DEFAULT 0 CHECK (like_count >= 0),
  comment_count bigint NOT NULL DEFAULT 0 CHECK (comment_count >= 0),
  published_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_episodes_show_slug UNIQUE (show_id, slug),
  CONSTRAINT ux_episodes_show_number UNIQUE (show_id, season_number, episode_number)
);

CREATE TABLE IF NOT EXISTS episode_tags (
  episode_id uuid NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES tags(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (episode_id, tag_id)
);

CREATE TABLE IF NOT EXISTS episode_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  episode_id uuid NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  asset_type text NOT NULL
    CHECK (asset_type IN ('image', 'transcript', 'waveform', 'subtitle', 'cover', 'attachment')),
  url text,
  storage_key text,
  mime_type varchar(120),
  size_bytes bigint CHECK (size_bytes >= 0),
  sort_order smallint NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_episode_assets_order UNIQUE (episode_id, asset_type, sort_order)
);

CREATE TABLE IF NOT EXISTS episode_segments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  episode_id uuid NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  show_host_id uuid REFERENCES show_hosts(id) ON DELETE SET NULL,
  segment_index integer NOT NULL CHECK (segment_index >= 0),
  speaker_label varchar(120),
  start_ms integer NOT NULL CHECK (start_ms >= 0),
  end_ms integer NOT NULL CHECK (end_ms >= start_ms),
  text_content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_episode_segments_order UNIQUE (episode_id, segment_index)
);

CREATE TABLE IF NOT EXISTS episode_bookmarks (
  user_id uuid NOT NULL,
  episode_id uuid NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, episode_id)
);

CREATE TABLE IF NOT EXISTS episode_companion_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  episode_id uuid NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
  block_type text NOT NULL
    CHECK (block_type IN ('timeline', 'diagram_image', 'takeaway', 'quiz', 'story_cast', 'quote', 'chapter_list', 'flashcards')),
  title varchar(160) NOT NULL DEFAULT '',
  sort_order integer NOT NULL CHECK (sort_order >= 0),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_preview_enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_episode_companion_blocks_order UNIQUE (episode_id, sort_order)
);

CREATE TABLE IF NOT EXISTS outbox_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type varchar(80) NOT NULL,
  aggregate_id uuid NOT NULL,
  event_type varchar(120) NOT NULL,
  payload_version integer NOT NULL DEFAULT 1,
  payload jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'published', 'failed')),
  available_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS inbox_processed_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL UNIQUE,
  source_service varchar(80) NOT NULL,
  event_type varchar(120) NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_shows_owner_created
  ON shows (owner_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_shows_status_published
  ON shows (publish_status, published_at DESC);

CREATE INDEX IF NOT EXISTS ix_episodes_show_published
  ON episodes (show_id, published_at DESC);

CREATE INDEX IF NOT EXISTS ix_episodes_status_published
  ON episodes (publish_status, published_at DESC);

CREATE INDEX IF NOT EXISTS ix_episode_segments_episode_order
  ON episode_segments (episode_id, segment_index);

CREATE INDEX IF NOT EXISTS ix_episode_bookmarks_user_created
  ON episode_bookmarks (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_outbox_events_status_available
  ON outbox_events (status, available_at);

DROP TRIGGER IF EXISTS trg_shows_set_updated_at ON shows;
CREATE TRIGGER trg_shows_set_updated_at
BEFORE UPDATE ON shows
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_show_hosts_set_updated_at ON show_hosts;
CREATE TRIGGER trg_show_hosts_set_updated_at
BEFORE UPDATE ON show_hosts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_episodes_set_updated_at ON episodes;
CREATE TRIGGER trg_episodes_set_updated_at
BEFORE UPDATE ON episodes
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_episode_companion_blocks_set_updated_at ON episode_companion_blocks;
CREATE TRIGGER trg_episode_companion_blocks_set_updated_at
BEFORE UPDATE ON episode_companion_blocks
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
