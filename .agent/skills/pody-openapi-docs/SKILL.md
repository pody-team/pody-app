---
name: pody-openapi-docs
description: Maintain OpenAPI and Swagger docs for the Pody microservices repo. Use when adding docs for a service, syncing specs with live routes, exposing public docs through the gateway, updating README endpoint lists, or auditing whether service docs are complete and consistent.
---

# Pody OpenAPI Docs

Keep service routes, OpenAPI specs, Swagger UI entry points, gateway docs, tests, and READMEs aligned.

## Workflow

1. Inspect the service routes before editing docs.
   Read the service router first, not the existing spec. Compare live handlers against the current OpenAPI file or generated schema.

2. Follow the service's doc pattern.
   For Go services such as `identity-service`, `content-service`, and `notification-service`, keep docs in `internal/httpserver/docs/openapi.yaml`, embed them from `internal/httpserver/docs.go`, and expose `/api/v1/public/<service>/openapi.yaml` plus `/api/v1/public/<service>/docs`.
   For `ai-service`, keep public docs in `app/main.py` and generate the YAML from FastAPI. Keep the public spec on OpenAPI `3.0.3` and filter out paths that are not gateway-routable.

3. Keep auth modeling consistent with runtime behavior.
   Use `bearerAuth` for protected identity endpoints.
   Use header-based API keys for gateway-propagated auth on services that read `X-Auth-User-ID`.
   Document optional propagated headers only when the handler actually reads them.

4. Update all affected surfaces together.
   If a service gains or changes docs routes, update the service spec, the service README, gateway landing page links, gateway route config if a new public prefix is needed, and tests on both the service and gateway side.

5. Verify completeness, not just syntax.
   Confirm every public or protected route that should be documented appears in the spec.
   Confirm docs endpoints themselves appear in the spec for services that publish static YAML.
   Confirm README endpoint lists match the service's real routes and do not mix in unrelated gateway helper routes.

## Checklists

### Add Or Update Service Docs

- Read the router file and enumerate actual endpoints.
- Compare that list against the current OpenAPI paths.
- Add missing schemas for envelopes, auth headers, path params, and error responses.
- Keep examples and response codes aligned with handler behavior.
- Add or update tests that assert the spec contains the expected paths.

### Expose Docs Through Gateway

- Add a public route in `server/api-gateway/internal/config/config.go` if the service needs `/api/v1/public/<service>`.
- Add the service card to `server/api-gateway/internal/httpserver/server.go` landing page when appropriate.
- Update `server/api-gateway/internal/httpserver/server_test.go` and `server/api-gateway/internal/config/config_test.go`.

### Final Verification

- Parse static YAML specs before finishing.
- Run targeted service tests.
- Run gateway tests if the public docs surface changed.
- Rebuild the relevant containers with Docker Compose and `curl` the docs URLs through `http://localhost:8080`.

## Repo Notes

Read [references/pody-openapi-conventions.md](references/pody-openapi-conventions.md) when you need the exact file map, command checklist, and current cross-service conventions.
