# Content Service

`content-service` currently provides read-only APIs for the listener app and creator library screens.

## Endpoints

- `GET /healthz`
- `GET /api/v1/public/content/healthz`
- `GET /api/v1/public/content/home`
- `GET /api/v1/public/content/shows/{showID}`
- `GET /api/v1/public/content/shows/{showID}/episodes`
- `GET /api/v1/public/content/episodes/{episodeID}`
- `POST /api/v1/content/shows`
- `GET /api/v1/content/me/shows`

## Notes

- The service now reads from the managed Postgres database configured via `DATABASE_URL`.
- Demo content is seeded through the migrations container from [content_service_demo_seed.sql](/Users/promex04/Documents/Pody/Pody/server/sql/services/content_service_demo_seed.sql).
- The relational schema lives in [content_service.sql](/Users/promex04/Documents/Pody/Pody/server/sql/services/content_service.sql).
- `POST /api/v1/content/shows` currently creates a show with a single AI host at show level and defaults the show to `published/public` so the existing listener + creator screens can open it immediately. Draft/publish workflow can be split out in the next step.
