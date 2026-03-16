BEGIN;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS email_verified_at timestamptz;

CREATE TABLE IF NOT EXISTS email_verification_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_email_verification_tokens_user_created
  ON email_verification_tokens (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_email_verification_tokens_expires
  ON email_verification_tokens (expires_at);

COMMIT;
