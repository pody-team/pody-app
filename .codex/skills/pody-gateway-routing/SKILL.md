---
name: pody-gateway-routing
description: Maintain gateway routing conventions in the Pody repo. Use when exposing a service through the API gateway, adding public or protected prefixes, wiring docs routes, preserving auth bypass for public paths, updating route metadata, or verifying proxy behavior and gateway tests.
---

# Pody Gateway Routing

Keep gateway config, auth behavior, docs links, and proxy targets aligned when a service is added or changed.

## Workflow

1. Decide whether the route is public or protected.
   Public service prefixes belong under `/api/v1/public/<service>`.
   Protected service prefixes belong under `/api/v1/<service>`.

2. Add or update the route in gateway config.
   Edit `server/api-gateway/internal/config/config.go`.
   Keep the route name predictable, usually `<service>-public` for public traffic and `<service>` for protected traffic.
   Keep `EnvKey`, `DefaultURL`, and `UpstreamPath` aligned with the upstream service.

3. Preserve gateway auth behavior.
   Public routes bypass JWT because the gateway mounts them in the public group.
   Protected routes run through `withJWTAuth`, and the middleware forwards auth claims as `X-Auth-*` headers.
   Do not add a route under the public prefix if the downstream handler should require user auth.

4. Keep docs discoverable.
   If a service publishes docs, add it to the gateway `/docs` landing page and make sure the public prefix exposes both `/docs` and `/openapi.yaml`.

5. Verify the proxy path really matches the upstream route.
   The prefix mounted in the gateway and the upstream path in config should preserve the same service path layout.

## Checklists

### Config Changes

- Add both public and protected entries when the service needs both.
- Use the correct service URL env var.
- Keep default localhost ports aligned with the service README and Docker setup.
- Update config tests when new routes are added.

### Auth And Proxy Behavior

- Public routes should bypass JWT.
- Protected routes should return `401` without a bearer token.
- Protected requests should forward auth claims as `X-Auth-*` headers.
- Keep reverse proxy path joining behavior stable.

### Docs Surface

- Update `/docs` landing page when a service publishes Swagger or OpenAPI.
- Keep gateway README examples in sync with new public docs URLs.

## Repo Notes

Read [references/pody-gateway-routing-reference.md](references/pody-gateway-routing-reference.md) for the exact file map, naming patterns, auth flow, and verification commands.
