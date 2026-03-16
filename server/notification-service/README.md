# Pody Notification Service

Initial notification service focused on delivery concerns for internal system emails, with Kafka-driven delivery, retry/DLQ, and processed-event tracking.

## Endpoints

- `GET /healthz`
- `POST /internal/notifications/email/verification`

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

## Notes

- `INTERNAL_API_KEY` is required for internal callers like `identity-service`.
- Verification emails are primarily consumed from Kafka via `VERIFICATION_EVENTS_TOPIC`.
- Failed deliveries are re-published to `VERIFICATION_RETRY_TOPIC` and poison/terminal failures go to `VERIFICATION_DLQ_TOPIC`.
- Local Docker uses a dedicated Postgres database for `notification-service`.
- With `EMAIL_SENDER_MODE=log`, outgoing verification links are written to service logs for local development.
- `SMTP_TLS_MODE` supports `starttls`, `tls`, and `none`.
