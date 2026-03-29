# Embedding Service

`embedding_service` is now an embedding pipeline for the local Pody stack.

Detailed maintainer guide:

- See [MAINTAINING.md](./MAINTAINING.md)

## Current scope

- Consumes article CDC events from Kafka topic `article.embedding.requested`
- Consumes category events from Kafka topic `category.embedding.requested`
- Ensures both Kafka topics exist on startup
- Stores article and category embeddings in a dedicated PostgreSQL database with `pgvector`
- Splits article text into chunks
- Reuses the same Gemini embedding provider for article and category documents
- Persists documents, chunks, embeddings, and processing jobs
- Exposes `GET /healthz`
- Exposes `GET /api/v1/public/embedding/healthz`
- Exposes `POST /api/v1/public/embedding/articles/search`

## Local infrastructure

- Article DB: `article-postgres` on port `5433`
- Embedding DB: `embedding-postgres` on port `5434`
- Kafka Connect / Debezium: `http://localhost:8083`
- Kafka UI: `http://localhost:8090`
- Embedding service: `http://localhost:8088`

## Gemini configuration

You can configure one or many Gemini API keys:

```env
EMBEDDING_GEMINI_API_KEYS=key_one,key_two,key_three
```

Fallback env vars also work:

```env
GOOGLE_API_KEY=...
GEMINI_API_KEY=...
```

Important runtime env vars:

```env
EMBEDDING_DATABASE_URL=postgresql://postgres:postgres@embedding-postgres:5432/pody_embedding
EMBEDDING_DATABASE_URL_LOCAL=postgresql://postgres:postgres@localhost:5434/pody_embedding
EMBEDDING_GOOGLE_GENAI_BASE_URL=
GEMINI_EMBEDDING_MODEL=gemini-embedding-001
EMBEDDING_VERSION=v1
EMBEDDING_OUTPUT_DIMENSIONS=1536
EMBEDDING_BATCH_SIZE=16
EMBEDDING_GEMINI_QUOTA_RETRY_DELAY_SECONDS=60
ARTICLE_CHUNK_TARGET_CHARS=1400
ARTICLE_CHUNK_OVERLAP_CHARS=180
ARTICLE_CHUNK_MIN_CHARS=250
KAFKA_CATEGORY_TOPIC=category.embedding.requested
```

## Run with Docker Compose

```bash
docker compose up --build kafka article-postgres article-db-init article-service embedding-postgres embedding-db-init debezium-connect debezium-register embedding-service kafka-ui
```

## Useful checks

```bash
curl http://localhost:8083/connectors
curl http://localhost:8088/healthz
curl http://localhost:8088/api/v1/public/embedding/healthz
curl -X POST http://localhost:8088/api/v1/public/embedding/articles/search \
  -H "Content-Type: application/json" \
  -d '{"query":"tin tuc cong nghe", "limit": 5}'
docker logs -f pody-embedding-service
```

## What gets stored

- `article_embedding_documents`
- `article_embedding_chunks`
- `article_chunk_embeddings`
- `category_embedding_documents`
- `category_embeddings`
- `embedding_jobs`
