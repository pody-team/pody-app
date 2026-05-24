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
- `POST /api/v1/ai/production-plans/{plan_id}/create-show`
- `POST /api/v1/ai/episode-plans/generate`
- `GET /api/v1/ai/jobs/{job_id}`

## API Docs

- OpenAPI spec via gateway: `http://localhost:8080/api/v1/public/ai/openapi.yaml`
- Swagger UI via gateway: `http://localhost:8080/api/v1/public/ai/docs`
- Direct FastAPI docs on the service: `http://localhost:8085/docs`

## Notes

- The service persists chat threads, production plans, and jobs in the database configured by `DATABASE_URL`.
- The relational schema lives in [ai_service.sql](/Users/promex04/Documents/Pody/Pody/server/sql/services/ai_service.sql).
- Voice profiles are managed in the AI database and are no longer populated by demo seed migrations.
- Creator chat, planning, dialogue generation, and TTS all call Vertex AI directly through `google-genai`.
- The current default text model is `gemini-3.5-flash`. On Vertex AI this model is served on the `global` endpoint, so set `GOOGLE_CLOUD_LOCATION=global` unless you intentionally move to a different model.
- Configure `GOOGLE_CLOUD_PROJECT`, and optionally `GOOGLE_CLOUD_LOCATION` / `GOOGLE_TTS_MODEL`, to enable live AI flows.
- If `GOOGLE_CLOUD_PROJECT` is not configured, the service falls back to a deterministic local planner so the stack still runs in dev.
- `POST /api/v1/ai/production-plans/{plan_id}/create-show` returns `202 Accepted` and queues a background `show_creation` job.
- The show creation worker needs `CONTENT_DATABASE_URL` so it can write shows and episodes into the content database.
- Episode audio is uploaded to Google Cloud Storage; configure `GOOGLE_CLOUD_STORAGE_BUCKET` and optionally `GOOGLE_CLOUD_STORAGE_PUBLIC_BASE_URL`.
- Transcript alignment uses Meta MMS forced alignment via `torchaudio.pipelines.MMS_FA`; the Docker image installs CPU-only `torch` + `torchaudio`.
- Set `TRANSCRIPT_ALIGNMENT_MODE=mms` to require MMS alignment, or `auto` only if you explicitly want proportional fallback in dev.
- For local Docker, mount an ADC file and set `GOOGLE_APPLICATION_CREDENTIALS` so the container can reuse your host `gcloud auth application-default login` credentials.
- When a queued show finishes, `ai-service` can call `notification-service` via `NOTIFICATION_SERVICE_URL` + `NOTIFICATION_INTERNAL_API_KEY` to insert an in-app notification for the creator.
