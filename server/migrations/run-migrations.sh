#!/bin/sh
set -eu

wait_for_db() {
  url="$1"
  name="$2"
  attempts="${3:-30}"
  connect_timeout="${PGCONNECT_TIMEOUT:-5}"
  i=1
  log_file="/tmp/$(echo "$name" | tr ' ' '_')-connect.log"

  until PGCONNECT_TIMEOUT="$connect_timeout" psql "$url" -v ON_ERROR_STOP=1 -c "select 1" >"$log_file" 2>&1; do
    if [ "$i" -ge "$attempts" ]; then
      echo "failed to connect to $name after $attempts attempts"
      cat "$log_file"
      return 1
    fi

    echo "waiting for $name ($i/$attempts)"
    i=$((i + 1))
    sleep 1
  done
}

apply_migration() {
  url="$1"
  file="$2"
  name="$3"

  echo "applying $name"
  psql "$url" -v ON_ERROR_STOP=1 -f "$file"
}

apply_demo_seed_if_enabled() {
  url="$1"
  file="$2"
  name="$3"

  if [ "${ENABLE_DEMO_SEED:-false}" = "true" ]; then
    apply_migration "$url" "$file" "$name"
  else
    echo "skipping $name (set ENABLE_DEMO_SEED=true to enable demo seed)"
  fi
}

: "${IDENTITY_DATABASE_URL:?IDENTITY_DATABASE_URL is required}"
: "${NOTIFICATION_DATABASE_URL:?NOTIFICATION_DATABASE_URL is required}"
: "${CONTENT_DATABASE_URL:?CONTENT_DATABASE_URL is required}"
: "${AI_DATABASE_URL:?AI_DATABASE_URL is required}"
: "${ARTICLE_DATABASE_URL:?ARTICLE_DATABASE_URL is required}"

wait_for_db "$IDENTITY_DATABASE_URL" "identity database"
wait_for_db "$NOTIFICATION_DATABASE_URL" "notification database"
wait_for_db "$CONTENT_DATABASE_URL" "content database"
wait_for_db "$AI_DATABASE_URL" "ai database"
wait_for_db "$ARTICLE_DATABASE_URL" "article database"

apply_migration "$IDENTITY_DATABASE_URL" /migrations/identity_service.sql "identity service schema"
apply_migration "$IDENTITY_DATABASE_URL" /migrations/identity_service_email_verification.sql "identity email verification migration"
apply_migration "$IDENTITY_DATABASE_URL" /migrations/identity_service_eventing.sql "identity eventing migration"
apply_migration "$IDENTITY_DATABASE_URL" /migrations/identity_service_password_reset.sql "identity password reset migration"
apply_migration "$NOTIFICATION_DATABASE_URL" /migrations/notification_service.sql "notification service schema"
apply_migration "$CONTENT_DATABASE_URL" /migrations/content_service.sql "content service schema"
apply_demo_seed_if_enabled "$CONTENT_DATABASE_URL" /migrations/content_service_demo_seed.sql "content service demo seed"
apply_migration "$AI_DATABASE_URL" /migrations/ai_service.sql "ai service schema"
apply_migration "$ARTICLE_DATABASE_URL" /migrations/article_service.sql "article service schema"
apply_demo_seed_if_enabled "$ARTICLE_DATABASE_URL" /migrations/article_service_demo_seed.sql "article service demo seed"
