# Pody Identity Service

Go service for user identity in Pody, with:

- email/password sign-up with email verification
- email/password sign-in after verification
- Google sign-in using Google ID token
- access token + refresh token issuance
- `GET /api/v1/identity/me`

## Endpoints

- `GET /healthz`
- `GET /api/v1/public/identity/healthz`
- `POST /api/v1/public/identity/sign-up`
- `POST /api/v1/public/identity/sign-in`
- `POST /api/v1/public/identity/google`
- `POST /api/v1/public/identity/refresh`
- `POST /api/v1/public/identity/sign-out`
- `GET /api/v1/public/identity/verify-email`
- `POST /api/v1/public/identity/resend-verification`
- `GET /api/v1/identity/me`

## Run locally

```bash
cd server/identity-service
cp .env.example .env
go run ./cmd/identity
```

## Run with Docker

```bash
docker compose up --build postgres kafka notification-service identity-service
```

## Notes

- Apply the schema in [identity_service.sql](/Users/promex04/Documents/Pody/Pody/server/sql/services/identity_service.sql) before running.
- `GOOGLE_CLIENT_IDS` accepts a comma-separated list.
- `JWT_SECRET` should match what your API Gateway uses to verify access tokens if you keep HMAC auth.
- Email verification events are written to an outbox table first, then published to Kafka and consumed by [notification-service](/Users/promex04/Documents/Pody/Pody/server/notification-service).
- Published outbox events are cleaned up in the background based on `OUTBOX_RETENTION`.

## Example sign-up request

```bash
curl -X POST http://localhost:8080/api/v1/public/identity/sign-up \
  -H "Content-Type: application/json" \
  -d '{
    "email": "hello@pody.vn",
    "password": "super-secret",
    "display_name": "Promex"
  }'
```

## Local verification flow

With `EMAIL_SENDER_MODE=log` in `notification-service`, the verification link is written to notification service logs:

```bash
docker logs pody-notification-service
```

Open the logged `verification_url`, then sign in normally.
