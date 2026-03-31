# Pody Notification Service

Initial notification service focused on delivery concerns for internal system emails, with Kafka-driven delivery, retry/DLQ, processed-event tracking, and email delivery logs.

## Endpoints

- `GET /healthz`
- `GET /api/v1/public/notifications/healthz`
- `GET /api/v1/public/notifications/openapi.yaml`
- `GET /api/v1/public/notifications/docs`
- `GET /api/v1/notifications`
- `GET /api/v1/notifications/unread-count`
- `PATCH /api/v1/notifications/{id}/read`
- `PATCH /api/v1/notifications/read-all`
- `GET /api/v1/notifications/settings`
- `PUT /api/v1/notifications/settings`
- `POST /internal/notifications/email/verification`
- `POST /internal/notifications/inbox`
- `POST /internal/notifications/dev/seed-inbox`

## Run locally

```bash
cd server/notification-service
cp .env.example .env
go run ./cmd/notification
```

## Send real emails

Set `EMAIL_SENDER_MODE=smtp` and provide working SMTP credentials.

Example for Gmail with an app password:

```bash
export EMAIL_SENDER_MODE=smtp
export EMAIL_FROM="your-address@gmail.com"
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USERNAME="your-address@gmail.com"
export SMTP_PASSWORD="your-app-password"
export SMTP_TLS_MODE="starttls"
```

Then restart the notification stack:

```bash
docker compose up -d --build notification-service api-gateway identity-service
```

## API Docs

- OpenAPI spec: `http://localhost:8080/api/v1/public/notifications/openapi.yaml`
- Swagger UI: `http://localhost:8080/api/v1/public/notifications/docs`

## Seed demo inbox

For local development, you can insert a few demo notifications for a user:

```bash
curl -X POST http://localhost:8087/internal/notifications/dev/seed-inbox \
  -H "Content-Type: application/json" \
  -H "X-Internal-Api-Key: $INTERNAL_API_KEY" \
  -d '{"user_id":"<identity-user-id>"}'
```

Then open the app and refresh the `Notifications` tab.

## Notes

- `INTERNAL_API_KEY` is required for internal callers like `identity-service`.
- `POST /internal/notifications/inbox` lets trusted internal services insert one app notification directly.
- Verification emails are primarily consumed from Kafka via `VERIFICATION_EVENTS_TOPIC`.
- Password reset emails are consumed from Kafka via `PASSWORD_RESET_EVENTS_TOPIC`.
- Failed deliveries are re-published to `VERIFICATION_RETRY_TOPIC` and poison/terminal failures go to `VERIFICATION_DLQ_TOPIC`.
- Password reset retries/DLQ use `PASSWORD_RESET_RETRY_TOPIC` and `PASSWORD_RESET_DLQ_TOPIC`.
- Local Docker uses a dedicated Postgres database for `notification-service`.
- With `EMAIL_SENDER_MODE=log`, outgoing verification and password reset links are written to service logs for local development.
- `SMTP_TLS_MODE` supports `starttls`, `tls`, and `none`.
