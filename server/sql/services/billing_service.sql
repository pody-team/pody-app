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

CREATE TABLE IF NOT EXISTS subscription_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code citext NOT NULL UNIQUE,
  name varchar(120) NOT NULL,
  billing_period text NOT NULL
    CHECK (billing_period IN ('monthly', 'yearly', 'lifetime')),
  price_amount numeric(12,2) NOT NULL CHECK (price_amount >= 0),
  currency char(3) NOT NULL DEFAULT 'USD',
  monthly_credit_grant integer NOT NULL DEFAULT 0 CHECK (monthly_credit_grant >= 0),
  max_private_shows integer CHECK (max_private_shows IS NULL OR max_private_shows >= 0),
  is_active boolean NOT NULL DEFAULT true,
  features jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  plan_id uuid NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,
  provider text NOT NULL CHECK (provider IN ('stripe', 'apple', 'google', 'manual')),
  provider_customer_id text,
  provider_subscription_id text,
  status text NOT NULL
    CHECK (status IN ('trialing', 'active', 'past_due', 'cancelled', 'expired')),
  started_at timestamptz NOT NULL,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean NOT NULL DEFAULT false,
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_user_subscriptions_provider_ref
  ON user_subscriptions (provider, provider_subscription_id)
  WHERE provider_subscription_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS payment_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  subscription_id uuid REFERENCES user_subscriptions(id) ON DELETE SET NULL,
  provider text NOT NULL CHECK (provider IN ('stripe', 'apple', 'google', 'manual')),
  provider_transaction_id text,
  transaction_type text NOT NULL
    CHECK (transaction_type IN ('subscription_charge', 'top_up', 'refund', 'adjustment')),
  status text NOT NULL
    CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
  amount numeric(12,2) NOT NULL CHECK (amount >= 0),
  currency char(3) NOT NULL DEFAULT 'USD',
  raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS credit_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  delta_credits integer NOT NULL,
  balance_after integer NOT NULL CHECK (balance_after >= 0),
  entry_type text NOT NULL
    CHECK (entry_type IN ('subscription_grant', 'top_up', 'unlock_episode', 'ai_generation', 'refund', 'admin_adjustment', 'reservation_release')),
  reference_type text NOT NULL DEFAULT 'manual'
    CHECK (reference_type IN ('subscription', 'payment', 'episode', 'show', 'plan', 'job', 'manual', 'reservation')),
  reference_id uuid,
  description text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS credit_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  purpose text NOT NULL
    CHECK (purpose IN ('ai_generation', 'episode_unlock', 'show_unlock')),
  reference_type text NOT NULL
    CHECK (reference_type IN ('plan', 'job', 'episode', 'show')),
  reference_id uuid NOT NULL,
  reserved_credits integer NOT NULL CHECK (reserved_credits > 0),
  status text NOT NULL DEFAULT 'held'
    CHECK (status IN ('held', 'captured', 'released', 'expired')),
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS content_entitlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  show_id uuid,
  episode_id uuid,
  access_type text NOT NULL
    CHECK (access_type IN ('subscription', 'credit_unlock', 'purchase', 'gift')),
  granted_by_ledger_id uuid REFERENCES credit_ledger(id) ON DELETE SET NULL,
  granted_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  CONSTRAINT chk_content_entitlements_target CHECK (num_nonnulls(show_id, episode_id) = 1)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_content_entitlements_episode
  ON content_entitlements (user_id, episode_id)
  WHERE episode_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_content_entitlements_show
  ON content_entitlements (user_id, show_id)
  WHERE show_id IS NOT NULL;

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

CREATE INDEX IF NOT EXISTS ix_user_subscriptions_user_status
  ON user_subscriptions (user_id, status, current_period_end DESC);

CREATE INDEX IF NOT EXISTS ix_payment_transactions_user_created
  ON payment_transactions (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_credit_ledger_user_created
  ON credit_ledger (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_credit_reservations_user_status
  ON credit_reservations (user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_outbox_events_status_available
  ON outbox_events (status, available_at);

DROP TRIGGER IF EXISTS trg_subscription_plans_set_updated_at ON subscription_plans;
CREATE TRIGGER trg_subscription_plans_set_updated_at
BEFORE UPDATE ON subscription_plans
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_user_subscriptions_set_updated_at ON user_subscriptions;
CREATE TRIGGER trg_user_subscriptions_set_updated_at
BEFORE UPDATE ON user_subscriptions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_payment_transactions_set_updated_at ON payment_transactions;
CREATE TRIGGER trg_payment_transactions_set_updated_at
BEFORE UPDATE ON payment_transactions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_credit_reservations_set_updated_at ON credit_reservations;
CREATE TRIGGER trg_credit_reservations_set_updated_at
BEFORE UPDATE ON credit_reservations
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

COMMIT;
