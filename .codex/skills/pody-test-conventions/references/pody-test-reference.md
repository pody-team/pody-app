# Pody Test Reference

## Main Test Locations

Go:

- `server/content-service/internal/httpserver/server_test.go`
- `server/identity-service/internal/httpserver/server_test.go`
- `server/notification-service/internal/httpserver/server_test.go`
- `server/api-gateway/internal/config/config_test.go`
- `server/api-gateway/internal/httpserver/server_test.go`
- `server/api-gateway/internal/httpserver/auth_test.go`
- `server/api-gateway/internal/httpserver/proxy_test.go`

Python:

- `server/ai-service/tests/test_api.py`
- `server/ai-service/tests/test_service.py`
- `server/ai-service/tests/test_planner.py`

## Minimum Test Set By Change Type

### Service route added or changed

- One success-path request test
- One auth or validation failure test
- One docs or spec assertion if the public contract changed

### OpenAPI or Swagger surface changed

- Endpoint test for `/api/v1/public/<service>/openapi.yaml`
- Endpoint test for `/api/v1/public/<service>/docs`
- Assertion that the spec includes at least one newly relevant path

### Gateway route added or changed

- Config test proving the route target is correct
- Gateway server test proving:
  - public route bypasses auth, or
  - protected route requires auth
- Docs landing page test when a docs card or public docs URL changed

### AI schema or docs changed

- `pytest` assertion on generated YAML body
- If auth behavior changed, one protected endpoint test without headers
- If response models changed, one success response assertion on the new shape

## Existing Patterns Worth Reusing

Go services:

- Build server with fake or demo dependencies
- Use `httptest.NewRequest` and `httptest.NewRecorder`
- Assert status code first
- Assert a few critical body substrings instead of snapshotting huge payloads

Gateway:

- Use `httptest.NewServer` as an upstream stub
- Assert the upstream path received by the proxy
- Keep auth tests focused on one route at a time

AI service:

- Build `TestClient(create_app(service=FakeAIService()))`
- Keep the fake service deterministic enough for response assertions
- Assert on YAML substrings for OpenAPI instead of full snapshots

## Command Matrix

Go service:

```bash
go test ./...
```

Run from the changed service directory.

Gateway:

```bash
go test ./...
```

Run from `server/api-gateway`.

AI service:

```bash
PYTHONPATH=/Users/promex04/Documents/Pody/Pody/server/ai-service /tmp/pody-ai-docs-venv/bin/pytest server/ai-service/tests -q
```

## Review Heuristics

- Prefer targeted assertions over giant response snapshots.
- When docs drift is the risk, assert on path presence, version, or auth header names.
- When proxy behavior changes, assert on the upstream path instead of only the final status code.
- When auth behavior changes, include at least one missing-auth test.
