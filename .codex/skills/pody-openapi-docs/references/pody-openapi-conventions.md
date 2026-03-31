# Pody OpenAPI Conventions

## File Map

### Go services

- `server/<service>/internal/httpserver/server.go`: source of truth for routes
- `server/<service>/internal/httpserver/docs.go`: embedded YAML + Swagger UI handler
- `server/<service>/internal/httpserver/docs/openapi.yaml`: static spec
- `server/<service>/internal/httpserver/server_test.go`: service doc endpoint tests
- `server/<service>/README.md`: endpoint list and API docs URLs

### AI service

- `server/ai-service/app/main.py`: routes, public docs endpoints, OpenAPI normalization
- `server/ai-service/app/models.py`: response models that shape the spec
- `server/ai-service/tests/test_api.py`: docs and schema tests
- `server/ai-service/README.md`: endpoint list and API docs URLs

### Gateway

- `server/api-gateway/internal/config/config.go`: public and protected route prefixes
- `server/api-gateway/internal/config/config_test.go`: route config coverage
- `server/api-gateway/internal/httpserver/server.go`: `/docs` landing page
- `server/api-gateway/internal/httpserver/server_test.go`: public docs links and bypass checks
- `server/api-gateway/README.md`: gateway example doc URLs

## Current Conventions

- Keep public docs URLs under `/api/v1/public/<service>/openapi.yaml` and `/api/v1/public/<service>/docs`.
- Keep all published specs on OpenAPI `3.0.3`.
- For Go services, serve `application/yaml` from the embedded spec handler.
- For `ai-service`, generate YAML from FastAPI, normalize nullable fields for OpenAPI `3.0.3`, and remove paths that should not be advertised through the gateway.
- Put `servers: [{ url: http://localhost:8080 }]` in published specs so the contract matches gateway usage.

## Auth Modeling

- `identity-service`: use `bearerAuth` for protected endpoints.
- `content-service`: use header auth via `X-Auth-User-ID`; document optional `X-Auth-Email` and `X-Auth-Name` only where used.
- `notification-service`: use header auth via `X-Auth-User-ID` for inbox/settings endpoints and `X-Internal-Api-Key` for internal endpoints.
- `ai-service`: use header auth via `X-Auth-User-ID`; optional `X-Auth-Email` and `X-Auth-Name` appear in the generated schema because the handler reads them.

## Common Mismatches To Catch

- Routes exist in `server.go` or `main.py` but not in the spec.
- README endpoint lists omit routes or list gateway helper routes that are not part of the service.
- Swagger UI and `openapi.yaml` routes exist in code but are absent from the spec.
- Gateway `/docs` page links only some services.
- Public specs expose paths that only work on the service directly, not through `:8080`.

## Verification Commands

### Static docs

```bash
ruby -e 'require "yaml"; YAML.load_file("server/content-service/internal/httpserver/docs/openapi.yaml")'
```

Replace the path for the service you edited.

### Go services

```bash
go test ./...
```

Run from the service directory, and from `server/api-gateway` when gateway docs changed.

### AI service

```bash
PYTHONPATH=/Users/promex04/Documents/Pody/Pody/server/ai-service /tmp/pody-ai-docs-venv/bin/pytest server/ai-service/tests -q
```

### Docker verification

```bash
docker compose up --build -d identity-service notification-service content-service ai-service api-gateway
curl http://localhost:8080/docs
curl http://localhost:8080/api/v1/public/identity/openapi.yaml
curl http://localhost:8080/api/v1/public/content/openapi.yaml
curl http://localhost:8080/api/v1/public/notifications/openapi.yaml
curl http://localhost:8080/api/v1/public/ai/openapi.yaml
```
