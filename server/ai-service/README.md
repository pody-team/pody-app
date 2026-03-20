# AI Service

`ai-service` now runs on `FastAPI + google-genai` and powers creator-side AI workflows.

## Endpoints

- `GET /healthz`
- `GET /api/v1/public/ai/healthz`
- `GET /api/v1/public/ai/openapi.yaml`
- `GET /api/v1/public/ai/docs`
- `GET /api/v1/ai/voice-profiles`
- `POST /api/v1/ai/chat-create/threads`
- `GET /api/v1/ai/chat-create/threads`
- `GET /api/v1/ai/chat-create/threads/{thread_id}`
- `POST /api/v1/ai/chat-create/threads/stream`
- `POST /api/v1/ai/chat-create/threads/{thread_id}/messages`
- `POST /api/v1/ai/chat-create/threads/{thread_id}/messages/stream`
- `GET /api/v1/ai/production-plans`
- `GET /api/v1/ai/production-plans/{plan_id}`
- `POST /api/v1/ai/episode-plans/generate`
- `GET /api/v1/ai/jobs/{job_id}`

## API Docs

- OpenAPI spec via gateway: `http://localhost:8080/api/v1/public/ai/openapi.yaml`
- Swagger UI via gateway: `http://localhost:8080/api/v1/public/ai/docs`
- Direct FastAPI docs on the service: `http://localhost:8085/docs`

## Notes

- The service persists chat threads, production plans, and jobs in the database configured by `DATABASE_URL`.
- The relational schema lives in [ai_service.sql](/Users/promex04/Documents/Pody/Pody/server/sql/services/ai_service.sql).
- Voice profiles are seeded through [ai_service_demo_seed.sql](/Users/promex04/Documents/Pody/Pody/server/sql/services/ai_service_demo_seed.sql).
- Set `GOOGLE_API_KEY` or `GEMINI_API_KEY` to use Google GenAI live.
- If you are routing through a local Gemini proxy, set `GOOGLE_GENAI_BASE_URL` such as `http://host.docker.internal:3030`. In that mode the service will still use the Google SDK, but send traffic to your proxy instead of Google directly.
- If neither a Google key nor a proxy base URL is configured, the service falls back to a deterministic local planner so the stack still runs in dev.
