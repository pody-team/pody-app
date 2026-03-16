# Pody API Gateway

Initial Go API Gateway / BFF scaffold for the Pody microservice architecture.

## What is included

- HTTP server using `chi` plus the Go standard library reverse proxy
- Reverse proxy routing for:
  - `/api/v1/public/identity`
  - `/api/v1/identity`
  - `/api/v1/content`
  - `/api/v1/social`
  - `/api/v1/news`
  - `/api/v1/ai`
  - `/api/v1/billing`
  - `/api/v1/notifications`
- Request ID, panic recovery, request logging, and CORS middleware
- JWT auth middleware for `/api/v1/*`
- `GET /healthz`
- `GET /readyz`
- `GET /` and `GET /api/v1/_meta/routes` for route discovery

## Run locally

```bash
cd server/api-gateway
cp .env.example .env
go run ./cmd/gateway
```

The gateway listens on `http://localhost:8080` by default.

## Run with Docker

```bash
docker compose up --build api-gateway
```

## Environment variables

```bash
PORT=8080
ALLOWED_ORIGINS=*
READ_TIMEOUT=5s
WRITE_TIMEOUT=10s
IDLE_TIMEOUT=30s
SHUTDOWN_TIMEOUT=10s
JWT_SECRET=change-me
AUTH_EXCLUDED_PATHS=

IDENTITY_SERVICE_URL=http://localhost:8081
CONTENT_SERVICE_URL=http://localhost:8082
SOCIAL_SERVICE_URL=http://localhost:8083
NEWS_SERVICE_URL=http://localhost:8084
AI_SERVICE_URL=http://localhost:8085
BILLING_SERVICE_URL=http://localhost:8086
NOTIFICATION_SERVICE_URL=http://localhost:8087
```

## Example requests

```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/api/v1/_meta/routes
curl http://localhost:8080/api/v1/public/identity/healthz
curl -X POST http://localhost:8080/api/v1/public/identity/sign-in
curl -H "Authorization: Bearer <jwt>" http://localhost:8080/api/v1/social/comments
```

## Suggested next steps

1. Add per-service rate limiting and circuit breaking.
2. Add BFF endpoints that aggregate data across Content, Social, Billing, and Identity.
3. Add service health fan-out for stronger readiness checks.
