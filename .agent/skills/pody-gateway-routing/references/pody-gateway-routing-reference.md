# Pody Gateway Routing Reference

## Files To Touch

- `server/api-gateway/internal/config/config.go`
- `server/api-gateway/internal/config/config_test.go`
- `server/api-gateway/internal/httpserver/server.go`
- `server/api-gateway/internal/httpserver/server_test.go`
- `server/api-gateway/internal/httpserver/middleware.go`
- `server/api-gateway/internal/httpserver/proxy.go`
- `server/api-gateway/README.md`

## Current Route Naming Pattern

Public routes:

- `identity-public`
- `notifications-public`
- `content-public`
- `ai-public`

Protected routes:

- `identity`
- `content`
- `social`
- `news`
- `ai`
- `billing`
- `notifications`

Prefer this naming scheme for future services.

## Prefix And Upstream Rules

- Gateway route prefix is what clients call.
- `UpstreamPath` should match the path already exposed by the upstream service.
- For services that already mount `/api/v1/public/<service>` or `/api/v1/<service>`, keep the same upstream path.
- When the route prefix already includes the full service path, the proxy trims the prefix and appends the remaining suffix to `TargetURL`.

Examples from current config:

- Prefix: `/api/v1/public/content`
  - UpstreamPath: `/api/v1/public/content`
- Prefix: `/api/v1/identity`
  - UpstreamPath: `/api/v1/identity`

## Auth Flow

Gateway groups:

- Public group mounts routes whose prefix starts with `/api/v1/public/`
- Protected group mounts all other `/api/v1/...` service routes and runs `withJWTAuth`

JWT middleware behavior:

- Rejects missing bearer token with `401`
- Parses JWT claims and injects:
  - `X-Auth-User-ID`
  - `X-Auth-Role`
  - `X-Auth-Email`
  - `X-Auth-Name`

Implication:

- Downstream services should not parse JWT themselves for normal protected traffic.
- Public docs and public health endpoints should be routed under `/api/v1/public/...` so they bypass gateway JWT enforcement.

## Docs Landing Page Conventions

Gateway `/docs` currently links:

- Identity Service
- AI Service
- Content Service
- Notification Service

Each card should expose:

- Swagger UI link
- OpenAPI YAML link

If a new service gains docs, add it here in the same style.

## Tests To Update

- `config_test.go`
  - default route count and specific route target coverage
- `server_test.go`
  - public route bypasses auth
  - protected route requires auth
  - docs landing page contains the expected links
- `auth_test.go`
  - only when auth skip behavior changes
- `proxy_test.go`
  - only when proxy path joining behavior changes

## Common Mistakes

- Adding a service route in config but forgetting `/docs` landing page.
- Using a public prefix for a protected handler.
- Forgetting to set `UpstreamPath`, so the proxy strips or duplicates the service prefix incorrectly.
- Updating service docs routes without updating gateway README examples.
- Assuming public paths are skipped by config alone; in this repo they bypass JWT because they are mounted in the public group.

## Verification Commands

```bash
go test ./...
```

Run from:

- `server/api-gateway`

And for runtime checks:

```bash
docker compose up --build -d api-gateway identity-service content-service notification-service ai-service
curl http://localhost:8080/docs
curl http://localhost:8080/api/v1/_meta/routes
```
