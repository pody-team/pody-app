#!/bin/sh
set -eu

wait_for_db() {
  url="$1"
  name="$2"

  until psql "$url" -c "select 1" >/dev/null 2>&1; do
    echo "waiting for $name"
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

: "${IDENTITY_DATABASE_URL:?IDENTITY_DATABASE_URL is required}"
: "${NOTIFICATION_DATABASE_URL:?NOTIFICATION_DATABASE_URL is required}"
: "${CONTENT_DATABASE_URL:?CONTENT_DATABASE_URL is required}"

wait_for_db "$IDENTITY_DATABASE_URL" "identity database"
wait_for_db "$NOTIFICATION_DATABASE_URL" "notification database"
wait_for_db "$CONTENT_DATABASE_URL" "content database"

apply_migration "$IDENTITY_DATABASE_URL" /migrations/identity_service.sql "identity service schema"
apply_migration "$IDENTITY_DATABASE_URL" /migrations/identity_service_email_verification.sql "identity email verification migration"
apply_migration "$IDENTITY_DATABASE_URL" /migrations/identity_service_eventing.sql "identity eventing migration"
apply_migration "$IDENTITY_DATABASE_URL" /migrations/identity_service_password_reset.sql "identity password reset migration"
apply_migration "$NOTIFICATION_DATABASE_URL" /migrations/notification_service.sql "notification service schema"
apply_migration "$CONTENT_DATABASE_URL" /migrations/content_service.sql "content service schema"
apply_migration "$CONTENT_DATABASE_URL" /migrations/content_service_demo_seed.sql "content service demo seed"
