---
name: pody-http-api-conventions
description: Standardize HTTP API design in the Pody repo. Use when adding or refactoring service routes, request and response payloads, auth headers, status codes, public versus protected paths, health endpoints, or README and OpenAPI descriptions that must match runtime behavior.
---

# Pody HTTP API Conventions

Keep route shape, auth behavior, response format, and docs aligned across Pody services.

## Workflow

1. Start from live handlers, not from docs.
   Read the router and handler request structs or models first. Treat `server.go` or `app/main.py` as the source of truth.

2. Preserve the public versus protected split.
   Public routes live under `/api/v1/public/<service>`.
   Protected routes live under `/api/v1/<service>`.
   Keep `/healthz` on the service itself, and expose `/api/v1/public/<service>/healthz` when the service is gateway-facing.

3. Match auth to runtime, not preference.
   Protected gateway routes receive JWT auth at the gateway, then downstream services read propagated headers such as `X-Auth-User-ID`.
   `identity-service` protected endpoints are documented as bearer-token endpoints because clients call them through the gateway with `Authorization: Bearer <jwt>`.
   Only document optional propagated headers like `X-Auth-Email` or `X-Auth-Name` when handlers actually read them.

4. Keep payloads and status codes predictable.
   Success responses should match existing service style: plain JSON objects, usually wrapping resources like `{"show": ...}` or lists like `{"notifications": [...]}`.
   Errors should stay simple and consistent with runtime output, typically `{"error": "<message>"}`.
   Reuse established status patterns: `200` for reads and updates, `201` for create, `202` for queued or async work, `204` for no-body success, `400` for bad input, `401` for missing auth, `404` for missing resource, `502` for upstream dependency failures, `500` for server errors.

5. Finish with a consistency pass.
   If routes or payloads changed, update the OpenAPI spec, service README, and tests in the same pass.

## Checklists

### Route Design

- Keep service-specific prefixes stable: `/api/v1/public/<service>` and `/api/v1/<service>`.
- Prefer resource-oriented paths and preserve existing nouns already in the repo.
- Do not invent a new auth mechanism if the gateway already propagates identity headers.

### Payloads And Auth

- Check request structs or Pydantic models before documenting JSON fields.
- Keep response envelopes aligned with the handler implementation.
- Return `401` when `X-Auth-User-ID` or bearer auth is required and missing.
- Use `X-Internal-Api-Key` only for internal routes that already rely on it.

### Cross-File Sync

- Update README endpoint lists when routes change.
- Update OpenAPI when the contract changes.
- Add or adjust tests that prove public access, protected access, and core response shape.

## Repo Notes

Read [references/pody-http-api-reference.md](references/pody-http-api-reference.md) for the current route map, auth propagation rules, status code patterns, and common drift to catch.
