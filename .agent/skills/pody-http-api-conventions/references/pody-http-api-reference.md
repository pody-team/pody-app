# Pody HTTP API Reference

## Source Files To Read First

- `server/<service>/internal/httpserver/server.go` for Go services
- `server/ai-service/app/main.py` for AI service
- `server/<service>/README.md` for the user-facing endpoint list
- `server/<service>/internal/httpserver/docs/openapi.yaml` when the service has static OpenAPI
- `server/ai-service/app/models.py` for AI response schema details

## Route Split Conventions

- Public gateway-facing routes live under `/api/v1/public/<service>`.
- Protected routes live under `/api/v1/<service>`.
- Services also keep a direct `/healthz` route for local health checks.
- Public docs and health should be reachable through the gateway prefix when the service is user-facing.

Current examples:

- `identity-service`
  - Public: `/api/v1/public/identity/...`
  - Protected: `/api/v1/identity/...`
- `content-service`
  - Public reads and docs: `/api/v1/public/content/...`
  - Protected creator actions: `/api/v1/content/...`
- `notification-service`
  - Public docs and health: `/api/v1/public/notifications/...`
  - Protected inbox/settings: `/api/v1/notifications/...`
  - Internal only: `/internal/...`
- `ai-service`
  - Public docs and health: `/api/v1/public/ai/...`
  - Protected creator endpoints: `/api/v1/ai/...`

## Auth Conventions

Gateway behavior:

- Gateway protected routes require `Authorization: Bearer <jwt>`.
- Gateway middleware injects claims into downstream headers:
  - `X-Auth-User-ID`
  - `X-Auth-Role`
  - `X-Auth-Email`
  - `X-Auth-Name`

Downstream service expectations:

- `identity-service`
  - Public auth flows are unauthenticated.
  - Protected `/api/v1/identity/...` endpoints are bearer-token endpoints from the client perspective.
- `content-service`
  - Protected handlers require `X-Auth-User-ID`.
  - `X-Auth-Email` and `X-Auth-Name` are optional and only matter where handlers read them.
- `notification-service`
  - Protected inbox/settings handlers require `X-Auth-User-ID`.
  - Internal routes require `X-Internal-Api-Key`.
- `ai-service`
  - Protected handlers require `X-Auth-User-ID`.
  - `X-Auth-Email` and `X-Auth-Name` appear only because handlers read them.

## Response Patterns

Go services commonly use:

- `writeJSON(w, status, map[string]any{...})`
- `writeError(w, status, err)` producing `{"error": "..."}`

Common response shapes already in the repo:

- Single resource: `{"show": {...}}`, `{"thread": {...}}`, `{"draft": {...}}`
- List response: `{"shows": [...]}`, `{"notifications": [...]}`, `{"voice_profiles": [...]}`
- Counters or status: `{"unread_count": 3}`, `{"status": "queued"}`

Avoid introducing new envelope styles unless the service already uses them.

## Status Code Patterns In Current Repo

- `200 OK`
  - reads
  - updates that return JSON
  - verification success payloads
- `201 Created`
  - create operations like content show creation or AI thread creation
- `202 Accepted`
  - queued email or background-style work
- `204 No Content`
  - identity sign-out
- `400 Bad Request`
  - invalid JSON
  - missing required path or body field
  - validation failures
- `401 Unauthorized`
  - missing bearer token at gateway
  - missing `X-Auth-User-ID` in downstream protected handlers
- `404 Not Found`
  - missing resource
- `502 Bad Gateway`
  - planner or provider failure in AI
  - upstream email/provider failures
- `500 Internal Server Error`
  - unexpected store or server errors

## Naming Guidance

- Reuse existing service nouns instead of inventing synonyms.
- Prefer plural collection paths for list resources and singular path params for one resource.
- Keep path params explicit, for example `{showID}`, `{episodeID}`, `{notificationID}`.
- When Chi uses `r.Get("/")` inside a route group, document the canonical path without relying on a trailing slash distinction.

## Common Drift To Catch

- README lists endpoints that the router does not expose.
- Handlers require auth headers that the spec or README does not mention.
- Public docs paths exist in code but not in the service spec.
- Status codes in docs do not match the actual handler behavior.
- AI-generated schema exposes internal-only paths that should not be public through the gateway.

## Useful Checks

```bash
rg -n 'router\\.Route|r\\.(Get|Post|Put|Patch|Delete)|@app\\.(get|post|put|patch|delete)' server
rg -n 'X-Auth-|X-Internal-Api-Key|Authorization' server
```
