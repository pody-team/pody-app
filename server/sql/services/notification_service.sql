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

CREATE TABLE IF NOT EXISTS user_notification_settings (
  user_id uuid PRIMARY KEY,
  push_enabled boolean NOT NULL DEFAULT true,
  email_enabled boolean NOT NULL DEFAULT true,
  new_episode_enabled boolean NOT NULL DEFAULT true,
  comment_enabled boolean NOT NULL DEFAULT true,
  follow_enabled boolean NOT NULL DEFAULT true,
  marketing_enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  actor_user_id uuid,
  type varchar(50) NOT NULL,
  target_type varchar(50),
  target_id uuid,
  title varchar(200) NOT NULL,
  body text NOT NULL,
  preview text,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamptz,
  actor_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  target_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS delivery_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid REFERENCES notifications(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  channel varchar(20) NOT NULL,
  device_token_hash text,
  provider varchar(40),
  delivery_status varchar(20) NOT NULL,
  provider_message_id text,
  error_message text,
  delivered_at timestamptz,
  opened_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_code varchar(80) NOT NULL,
  channel varchar(20) NOT NULL,
  title_template text NOT NULL,
  body_template text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ux_templates_code_channel UNIQUE (template_code, channel)
);

CREATE TABLE IF NOT EXISTS outbox_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type varchar(80) NOT NULL,
  aggregate_id uuid NOT NULL,
  event_type varchar(120) NOT NULL,
  payload_version integer NOT NULL DEFAULT 1,
  payload jsonb NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  last_error text,
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

CREATE INDEX IF NOT EXISTS ix_notifications_user_read_created
  ON notifications (user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_notifications_user_created
  ON notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_delivery_logs_notification_created
  ON delivery_logs (notification_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_delivery_logs_user_created
  ON delivery_logs (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_delivery_logs_status_created
  ON delivery_logs (delivery_status, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_outbox_events_status_available
  ON outbox_events (status, available_at);

CREATE INDEX IF NOT EXISTS ix_inbox_processed_events_processed_at
  ON inbox_processed_events (processed_at);

DROP TRIGGER IF EXISTS trg_user_notification_settings_set_updated_at ON user_notification_settings;
CREATE TRIGGER trg_user_notification_settings_set_updated_at
BEFORE UPDATE ON user_notification_settings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_templates_set_updated_at ON templates;
CREATE TRIGGER trg_templates_set_updated_at
BEFORE UPDATE ON templates
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
