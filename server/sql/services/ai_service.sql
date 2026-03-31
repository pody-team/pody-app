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

CREATE TABLE IF NOT EXISTS voice_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(120) NOT NULL,
  provider text NOT NULL CHECK (provider IN ('google', 'openai', 'elevenlabs', 'azure', 'other')),
  provider_voice_id text NOT NULL,
  language_code varchar(16) NOT NULL,
  gender text NOT NULL CHECK (gender IN ('male', 'female', 'neutral', 'unknown')),
  sample_audio_url text,
  cost_credits_per_minute integer NOT NULL DEFAULT 0 CHECK (cost_credits_per_minute >= 0),
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_voice_profiles_provider UNIQUE (provider, provider_voice_id)
);

CREATE TABLE IF NOT EXISTS chat_threads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL,
  title varchar(160) NOT NULL DEFAULT 'New Podcast',
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS production_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid NOT NULL,
  thread_id uuid REFERENCES chat_threads(id) ON DELETE SET NULL,
  target_show_id uuid,
  series_title varchar(200) NOT NULL,
  series_description text NOT NULL DEFAULT '',
  tone_style text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'reviewing', 'producing', 'completed', 'failed')),
  auto_generate_images boolean NOT NULL DEFAULT false,
  auto_generate_intro_music boolean NOT NULL DEFAULT false,
  target_language_code varchar(10) NOT NULL DEFAULT 'vi',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  text_content text NOT NULL DEFAULT '',
  plan_id uuid REFERENCES production_plans(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  attachment_type text NOT NULL CHECK (attachment_type IN ('image', 'document', 'audio')),
  file_name varchar(255) NOT NULL,
  url text,
  storage_key text,
  mime_type varchar(120),
  size_bytes bigint CHECK (size_bytes >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS production_plan_tags (
  plan_id uuid NOT NULL REFERENCES production_plans(id) ON DELETE CASCADE,
  tag_name varchar(80) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (plan_id, tag_name)
);

CREATE TABLE IF NOT EXISTS production_plan_hosts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES production_plans(id) ON DELETE CASCADE,
  voice_profile_id uuid REFERENCES voice_profiles(id) ON DELETE SET NULL,
  display_name varchar(120) NOT NULL,
  avatar_url text,
  role text NOT NULL DEFAULT 'host'
    CHECK (role IN ('host', 'co_host', 'guest', 'narrator')),
  persona_type text NOT NULL DEFAULT 'ai'
    CHECK (persona_type IN ('human', 'ai')),
  sort_order smallint NOT NULL CHECK (sort_order >= 0),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_plan_hosts_order UNIQUE (plan_id, sort_order)
);

CREATE TABLE IF NOT EXISTS production_plan_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES production_plans(id) ON DELETE CASCADE,
  source_article_id uuid NOT NULL,
  source_title varchar(300) NOT NULL,
  source_publisher varchar(160),
  source_url text,
  source_summary text NOT NULL DEFAULT '',
  sort_order integer NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_plan_sources_order UNIQUE (plan_id, sort_order)
);

CREATE TABLE IF NOT EXISTS production_plan_episode_drafts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES production_plans(id) ON DELETE CASCADE,
  generated_episode_id uuid,
  episode_number integer NOT NULL CHECK (episode_number >= 1),
  title varchar(240) NOT NULL,
  description text NOT NULL DEFAULT '',
  estimated_duration_seconds integer NOT NULL DEFAULT 900 CHECK (estimated_duration_seconds >= 0),
  notes text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'approved', 'generated', 'failed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_plan_episode_drafts_number UNIQUE (plan_id, episode_number)
);

CREATE TABLE IF NOT EXISTS generation_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES production_plans(id) ON DELETE CASCADE,
  episode_draft_id uuid REFERENCES production_plan_episode_drafts(id) ON DELETE SET NULL,
  job_type text NOT NULL
    CHECK (job_type IN ('plan_generation', 'script_generation', 'audio_generation', 'image_generation', 'publish_episode', 'show_creation', 'transcript_generation')),
  status text NOT NULL DEFAULT 'queued'
    CHECK (status IN ('queued', 'running', 'completed', 'failed', 'cancelled')),
  provider varchar(80),
  input_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  output_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  error_message text,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE generation_jobs
  DROP CONSTRAINT IF EXISTS generation_jobs_job_type_check;

ALTER TABLE generation_jobs
  ADD CONSTRAINT generation_jobs_job_type_check
  CHECK (job_type IN ('plan_generation', 'script_generation', 'audio_generation', 'image_generation', 'publish_episode', 'show_creation', 'transcript_generation'));

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

CREATE INDEX IF NOT EXISTS ix_chat_threads_owner_updated
  ON chat_threads (owner_user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS ix_production_plans_owner_updated
  ON production_plans (owner_user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS ix_generation_jobs_status_created
  ON generation_jobs (status, created_at);

CREATE INDEX IF NOT EXISTS ix_outbox_events_status_available
  ON outbox_events (status, available_at);

DROP TRIGGER IF EXISTS trg_voice_profiles_set_updated_at ON voice_profiles;
CREATE TRIGGER trg_voice_profiles_set_updated_at
BEFORE UPDATE ON voice_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_chat_threads_set_updated_at ON chat_threads;
CREATE TRIGGER trg_chat_threads_set_updated_at
BEFORE UPDATE ON chat_threads
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_production_plans_set_updated_at ON production_plans;
CREATE TRIGGER trg_production_plans_set_updated_at
BEFORE UPDATE ON production_plans
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_plan_hosts_set_updated_at ON production_plan_hosts;
CREATE TRIGGER trg_plan_hosts_set_updated_at
BEFORE UPDATE ON production_plan_hosts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_plan_episode_drafts_set_updated_at ON production_plan_episode_drafts;
CREATE TRIGGER trg_plan_episode_drafts_set_updated_at
BEFORE UPDATE ON production_plan_episode_drafts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
