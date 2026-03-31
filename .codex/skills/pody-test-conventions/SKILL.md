---
name: pody-test-conventions
description: Apply consistent test coverage in the Pody repo. Use when adding or refactoring service endpoints, gateway routes, OpenAPI docs, auth behavior, config loading, or AI service APIs so each change ships with the right targeted Go or pytest coverage.
---

# Pody Test Conventions

Add the smallest set of tests that proves the change works and that the contract did not drift.

## Workflow

1. Test the changed contract, not just internals.
   Start from the route, config surface, or user-visible behavior that changed.

2. Match the repo's existing test style.
   Go services use focused `httptest`-based tests in `internal/httpserver/server_test.go`.
   Gateway uses config tests plus request-level proxy and auth tests.
   `ai-service` uses `pytest` with `TestClient` and fake service implementations.

3. Cover both happy path and guardrails.
   For endpoint work, add at least one success test and one failure or auth test.
   For docs work, assert the docs endpoint returns content and that the spec includes the critical path entries.

4. Run targeted suites before finishing.
   Run the changed service tests, then gateway tests if any public surface or routing changed.

## Checklists

### Go HTTP Services

- Public route works without auth when expected.
- Protected route fails with `401` when auth is missing.
- Success response contains the key JSON fields the contract depends on.
- Docs endpoints return `200` and the expected content type or marker text.
- OpenAPI spec tests assert critical paths or tags, not just `openapi: 3.0.3`.

### Gateway

- Public route bypasses auth.
- Protected route requires auth.
- Docs landing page contains links for all documented services touched by the change.
- Config tests cover new route names and target URLs.

### AI Service

- `TestClient` covers public docs and protected API behavior.
- Generated OpenAPI assertions check for normalized `3.0.3` output and absence of internal-only paths.
- Fake service responses should be stable and include the fields needed by the response models.

## Repo Notes

Read [references/pody-test-reference.md](references/pody-test-reference.md) for file locations, command matrix, and the minimum test set by change type.
