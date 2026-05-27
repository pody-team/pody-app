# Pody

Pody is a mobile-first podcast and news platform built with Flutter and a microservice backend. The system combines content browsing, article ingestion, semantic search, notifications, authentication, and AI-assisted podcast creation.

## Main components

- `flutter-app/` — Flutter mobile application.
- `server/api-gateway/` — API gateway for routing and authentication context propagation.
- `server/identity-service/` — authentication, user profile, JWT/session management.
- `server/content-service/` — podcast/show/episode content APIs.
- `server/article_service/` — article crawling, article feed, comments, reactions, and article podcast jobs.
- `server/embedding_service/` — article embedding pipeline, semantic search, and category matching.
- `server/ai-service/` — AI creator workflows, production plans, show creation, TTS, and transcripts.
- `server/notification-service/` — in-app/email notification workflows.
- `server/sql/` — database schemas and migrations used by local services.

## Local development

The project is designed to run locally with Docker Compose.

```bash
docker compose up --build
```

Common service ports:

- API Gateway: `8080`
- Identity Service: `8081`
- Content Service: `8082`
- Article Service: `8084`
- AI Service: `8085`
- Notification Service: `8087`
- Embedding Service: `8088`

## Notes

- Do not commit local secrets, API keys, generated reports, LaTeX build outputs, or report image assets.
- Configure required environment variables before running services that depend on Google GenAI, Google Cloud Storage, Kafka, or external APIs.
- Service-specific setup details are documented in each service directory where applicable.
