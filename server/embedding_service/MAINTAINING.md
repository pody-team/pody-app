# Embedding Service Maintenance Guide

## 1. Muc tieu cua tai lieu

Tai lieu nay mo ta dung flow hien tai cua `embedding-service` sau khi da them:

- category bootstrap tu `article_service`
- semantic mapping `article -> categories`
- outbox + Kafka publisher de dong bo ket qua semantic category nguoc ve `article_service`

Tai lieu duoc viet de maintainer co the:

- hieu service dang lam gi ma khong can lan tung file
- biet du lieu nam o bang nao
- biet luc nao service goi Gemini, luc nao skip
- biet cach debug khi article khong duoc gan category
- biet chinh sua o dau khi can mo rong sau nay

## 2. Service nay dang lam gi

`embedding-service` hien tai co 5 nhiem vu chinh:

1. Consume CDC event cua bang `articles` tu Kafka topic `article.embedding.requested`
2. Embed article thanh chunk embeddings + document embedding
3. Bootstrap category vectors tu taxonomy trong `article_service`
4. Tinh top semantic categories cho moi article
5. Publish ket qua semantic mapping ve `article_service` qua topic `article.category.matches.generated`

Scope hien tai:

- co `article embedding`
- co `category embedding bootstrap`
- co `article -> category semantic mapping`
- co `outbox publisher` de sync ket qua sang `article_service`
- co `semantic search` de test retrieval

Scope chua lam:

- chua co `user embedding`
- chua expose qua `api-gateway`
- chua co batch re-index CLI rieng

## 3. Tong quan kien truc

Luong tong the hien tai:

1. `article-db-init` seed taxonomy `categories` trong `article_service`
2. `embedding-service` startup, doc category tu article DB
3. Neu category nao chua co vector hoac vector da stale, service se embed category do va luu vao embedding DB
4. Debezium theo doi bang `public.articles`
5. Debezium day event vao Kafka topic `article.embedding.requested`
6. `embedding-service` consume event article
7. Service parse event, quyet dinh co can embed hay khong
8. Neu can embed:
   - tao / cap nhat article document
   - tao job
   - cat chunk
   - goi Gemini
   - luu chunk vectors
   - luu document vector
   - refresh internal `article_category_matches`
   - ghi `outbox_events`
9. Publisher nen consume `outbox_events` va day event sang topic `article.category.matches.generated`
10. `article_service` consume event nay va luu semantic rows vao bang `category_articles`

Can nhin dung vai tro cua tung service:

- `article_service`
  - so huu taxonomy `categories`
  - so huu projection online `category_articles`
- `embedding-service`
  - so huu read-model vector
  - so huu semantic scoring noi bo
  - publish semantic category result ve `article_service`

`embedding-service` KHONG la source of truth cho category. No chi la noi tinh toan semantic.

## 4. Cac thanh phan chinh trong code

### 4.1. Bootstrap va runtime

- `app/main.py`
  - tao FastAPI app
  - gan runtime vao `app.state`

- `app/runtime.py`
  - khoi tao DB pool cho embedding DB
  - khoi tao DB pool rieng de doc taxonomy category tu article DB
  - khoi tao provider, repository, services, controllers
  - probe Gemini provider luc startup
  - bootstrap category vectors
  - start Kafka article consumer
  - start outbox publisher cho category sync event

### 4.2. Config

- `app/config/settings.py`
  - doc env var
  - validate config
  - khoa `EMBEDDING_OUTPUT_DIMENSIONS = 1536`
  - doc config cho:
    - article Kafka topic
    - category sync Kafka topic
    - category bootstrap source DB
    - outbox poll interval / batch size
    - article-category mapping threshold

### 4.3. Controller

- `app/controller/article_event_controller.py`
  - dieu phoi message article tu Kafka vao service nghiep vu

- `app/controller/kafka_article_consumer_controller.py`
  - tao topic article neu chua ton tai
  - chay Kafka consumer background
  - commit, retry, backoff, cap nhat health state

- `app/controller/kafka_article_category_sync_publisher.py`
  - tao topic `article.category.matches.generated` neu chua ton tai
  - poll `outbox_events`
  - publish tung event sang Kafka
  - mark `published` hoac `failed`
  - retry voi `available_at`

- `app/controller/article_search_controller.py`
  - dieu phoi search request vao service nghiep vu

- `app/controller/system_controller.py`
  - tra ve overview va health

### 4.4. Service nghiep vu

- `app/service/article_embedding_service.py`
  - parse article event
  - quyet dinh bai nao duoc embed
  - tinh `content_hash`
  - kiem tra co can re-embed hay khong
  - goi chunking
  - goi Gemini cho article
  - tinh document embedding tu chunk embeddings
  - ghi DB va enqueue outbox event

- `app/service/category_embedding_service.py`
  - dong bo category tu taxonomy source
  - chi embed category nao thieu / stale
  - skip category da current
  - neu category vectors thay doi thi refresh lai article-category matches
  - enqueue sync event cho cac article `ready + published`

- `app/service/gemini_provider.py`
  - quan ly nhieu API key
  - probe provider luc startup
  - rotate key khi gap quota / rate-limit
  - backoff khi tat ca key deu bi `429`

### 4.5. Model va repository

- `app/model/request`
  - parse Kafka payload va search payload

- `app/model/entity`
  - dataclass dai dien cho row DB, gom ca:
    - article embedding document
    - article category match
    - outbox event
    - category catalog item

- `app/model/repository/category_catalog_repository.py`
  - doc category taxonomy tu article DB

- `app/model/repository/embedding_repository.py`
  - persistence logic cho toan bo embedding DB
  - upsert article metadata
  - replace article chunks / vectors
  - replace category vectors
  - refresh `article_category_matches`
  - quan ly `embedding_jobs`
  - quan ly `outbox_events`
  - query semantic search

### 4.6. Utility

- `app/util/chunking.py`
  - cat title, summary, body thanh chunk

- `app/util/hashing.py`
  - tinh SHA-256 cho noi dung text

- `app/util/vector_math.py`
  - build document embedding dai dien cho article tu chunk embeddings

- `app/util/article_category_sync_event.py`
  - build payload `article.category.matches.generated.v1`

## 5. Cau truc thu muc

```text
server/embedding_service/
|-- app/
|   |-- api/
|   |-- config/
|   |-- controller/
|   |-- model/
|   |   |-- entity/
|   |   |-- repository/
|   |   |-- request/
|   |   `-- response/
|   |-- service/
|   |-- util/
|   |-- view/
|   |-- main.py
|   `-- runtime.py
|-- tests/
|-- Dockerfile
|-- README.md
`-- MAINTAINING.md
```

## 6. Cac bang trong database embedding

Schema nam o:

- `server/sql/services/embedding_service.sql`

Embedding DB la read-model rieng. Day KHONG phai DB nghiep vu goc.

### 6.1. `article_embedding_documents`

Ban ghi tong quat cho moi article duoc service quan ly.

Muc dich:

- map `article_id` sang embedding DB
- luu metadata article can cho search / debug
- luu `content_hash`
- luu `last_chunking_signature`
- luu `sync_status`

Nen hieu bang nay nhu "ho so embedding" cua article.

### 6.2. `article_embedding_chunks`

Luu text chunk da cat ra tu article.

Muc dich:

- luu `chunk_index`
- phan loai `title`, `summary`, `body`
- luu `content` goc cua chunk
- luu `content_hash`

### 6.3. `article_chunk_embeddings`

Luu vector tung chunk.

Muc dich:

- moi chunk co mot vector
- trace theo `model_name`, `embedding_version`, `dimensions`
- phuc vu semantic search theo passage

### 6.4. `article_document_embeddings`

Luu vector dai dien cho toan bo article.

Muc dich:

- dung cho semantic mapping `article -> category`
- tranh phai so sanh category voi tung chunk rieng le
- phuc vu ranking top category cua article

Vector nay duoc build tu chunk embeddings, khong goi them mot request Gemini rieng chi de lay document vector.

### 6.5. `category_embedding_documents`

Ban ghi tong quat cho moi category trong taxonomy.

Muc dich:

- map `category_id`, `slug`, `name`, `description`
- luu `semantic_text = name + description`
- luu `content_hash`
- luu `sync_status`
- luu metadata model/version/dimensions cuoi cung

### 6.6. `category_embeddings`

Luu vector cua category.

Muc dich:

- category vector phai nam cung embedding space voi article vector
- phuc vu semantic mapping `article -> categories`

### 6.7. `article_category_matches`

Bang read-model noi bo cua `embedding-service`.

Muc dich:

- luu top semantic category cho moi article
- luu `score`
- luu `rank`
- luu `model_name`, `embedding_version`

Quan trong:

- bang nay chi phuc vu tinh toan va debug trong `embedding-service`
- request path online KHONG nen phu thuoc truc tiep vao bang nay
- ket qua online cuoi cung se duoc sync ve `article_service.category_articles`

### 6.8. `embedding_jobs`

Bang theo doi cong viec embed.

Muc dich:

- luu job type
- luu source topic/partition/offset
- luu content hash, model, version
- luu status `pending/processing/completed/failed`
- luu so lan retry
- luu thong diep loi

### 6.9. `outbox_events`

Bang outbox de publish semantic category sync event.

Muc dich:

- de `embedding-service` publish event theo kieu transactional outbox
- dam bao event chi duoc tao sau khi article embedding + article_category_matches da duoc ghi thanh cong
- cho phep retry publisher neu Kafka tam thoi loi

`aggregate_id` la `TEXT` de luu `article_id` an toan.

Trang thai:

- `pending`
- `published`
- `failed`

## 7. Luong khoi dong service

Khi container `embedding-service` bat dau:

1. FastAPI app duoc tao trong `app/main.py`
2. `EmbeddingRuntime` duoc khoi tao
3. Service doi embedding DB san sang
4. Service kiem tra co Gemini API key hay khong
5. Service probe Gemini provider
6. Neu category bootstrap bat:
   - doi article source DB san sang
   - doc category taxonomy
   - embed category nao thieu / stale
   - refresh article-category matches neu category vectors co thay doi
7. Start publisher cho topic `article.category.matches.generated`
8. Start consumer cho topic `article.embedding.requested`

Y nghia:

- startup se fail som neu DB / provider / category source DB co van de
- category vectors duoc "lam day" ngay khi service len, khong can API them category

## 8. Luong category bootstrap

### 8.1. Category den tu dau

Category khong di qua Kafka.

Nguon category la taxonomy trong `article_service`, duoc doc truc tiep tu article DB.

### 8.2. Logic bootstrap

Voi moi category:

1. Build `semantic_text = name + description`
2. Tinh `content_hash`
3. Tim document hien co trong embedding DB
4. Neu category inactive:
   - sync metadata
   - khong goi Gemini
   - co the trigger refresh match neu active state thay doi
5. Neu vector hien tai van con hop le:
   - chi sync metadata
   - skip embed
6. Neu category chua co vector hoac vector stale:
   - goi Gemini
   - luu `category_embedding_documents`
   - luu `category_embeddings`

### 8.3. Khi nao category vector duoc coi la current

Category vector duoc coi la reusable khi dong thoi dung:

- `content_hash` khong doi
- `is_active = true`
- `sync_status = ready`
- `last_embedding_model` khong doi
- `last_embedding_version` khong doi
- `last_embedding_dimensions` khong doi

### 8.4. Khi category thay doi thi dieu gi xay ra

Neu bootstrap lam thay doi category vectors:

1. refresh lai `article_category_matches` cho tat ca article `ready + published`
2. enqueue sync event cho tung article do

Neu bootstrap khong thay doi gi:

- khong refresh match
- khong tao backfill event

## 9. Luong ingest article embedding

### 9.1. Event den tu dau

Nguon event:

- Debezium theo doi `public.articles`
- event duoc route sang topic `article.embedding.requested`

### 9.2. Consumer xu ly ra sao

Khi nhan duoc Kafka message:

1. Parse payload thanh `ArticleEvent`
2. Gop `title + summary + content` thanh `document_text`
3. Tinh `content_hash`
4. Tinh `chunking_signature`
5. Tim document hien co

### 9.3. Rule nghiep vu quan trong

#### Rule 1: chi embed article `PUBLISHED`

Neu `status` khong phai `PUBLISHED`:

- chi sync metadata hoac mark `skipped`
- khong goi Gemini
- xoa internal `article_category_matches`
- enqueue sync event voi `matches = []`

Y nghia:

- `article_service` se xoa semantic rows cu neu article khong con public

#### Rule 2: skip neu embedding hien tai van current

Service skip re-embed khi dung tat ca dieu kien:

- `content_hash` khong doi
- `sync_status = ready`
- `last_embedding_model` khong doi
- `last_embedding_version` khong doi
- `last_embedding_dimensions` khong doi
- `last_chunking_signature` khong doi

Neu skip:

- service chi sync metadata
- khong goi Gemini lai
- khong tao chunk/vector moi

#### Rule 3: metadata-only update khong can re-embed

Vi du:

- doi `author`
- doi `thumbnail_url`
- doi `published_at`

ma text chinh khong doi thi:

- chi sync metadata
- khong re-embed

### 9.4. Neu can embed

Neu khong skip:

1. upsert document
2. tao job trong `embedding_jobs`
3. mark job `processing`
4. dung `build_article_chunks()`
5. goi Gemini cho tung chunk
6. validate dimensions = `1536`
7. tinh `article_document_embedding`
8. replace chunk rows va chunk vectors
9. replace document embedding
10. refresh `article_category_matches`
11. enqueue outbox event `article.category.matches.generated.v1`
12. mark job `completed`

Mot diem quan trong:

- refresh match va enqueue outbox event duoc thuc hien trong cung transaction voi viec ghi article embedding
- nhu vay se tranh publish event khi DB chua ghi xong

### 9.5. Neu co loi

#### Parse loi vinh vien

Vi du payload sai schema:

- consumer commit offset
- log loi
- tang `failed_articles`

#### Loi transient

Vi du:

- DB tam thoi loi
- Kafka tam thoi loi
- Gemini loi mang

thi:

- consumer `seek` lai offset cu
- khong commit
- message se duoc xu ly lai

#### Loi quota Gemini

Neu tat ca key deu bi `429`:

- provider nem `EmbeddingRateLimitError`
- consumer giu nguyen offset
- doi theo `EMBEDDING_GEMINI_QUOTA_RETRY_DELAY_SECONDS`
- thu lai sau

## 10. Luong semantic mapping article -> category

Sau khi article co document embedding, repository se so sanh:

- `article_document_embeddings.embedding`
voi
- `category_embeddings.embedding`

Service luu:

- top `N` category theo `ARTICLE_CATEGORY_MATCH_MAX_MATCHES`
- chi giu category co `score >= ARTICLE_CATEGORY_MATCH_MIN_SCORE`

Ket qua duoc luu vao `article_category_matches`.

Mong dinh hien tai:

- `max_matches = 3`
- `min_score = 0.2`

## 11. Luong publish semantic category ve article_service

### 11.1. Topic va event

Kafka topic:

- `article.category.matches.generated`

Event type:

- `article.category.matches.generated.v1`

### 11.2. Payload

Payload hien tai co dang:

```json
{
  "event_id": "uuid",
  "idempotency_key": "article-category-sync:{article_id}:{content_hash}:{model_name}:{embedding_version}",
  "event_type": "article.category.matches.generated.v1",
  "occurred_at": "ISO-8601",
  "source_service": "embedding-service",
  "article_id": 123,
  "article_status": "PUBLISHED",
  "content_hash": "sha256",
  "model_name": "gemini-embedding-001",
  "embedding_version": "v1",
  "matches": [
    {
      "category_id": "uuid",
      "rank": 1,
      "score": 0.82,
      "is_primary": true
    }
  ]
}
```

`matches` duoc phep rong. Day la signal de `article_service` xoa semantic rows hien co cua article do.

### 11.3. Outbox va publisher

Publisher doc `outbox_events` theo batch:

- chi doc row `pending` hoac `failed` da den `available_at`
- publish thanh cong thi mark `published`
- publish fail thi mark `failed` va tinh `available_at` moi

Retry schedule hien tai:

- attempt 1 -> 1s
- attempt 2 -> 2s
- attempt 3 -> 4s
- attempt 4 -> 8s
- attempt 5 -> 16s
- attempt 6 tro len -> 32s

### 11.4. Tranh lap event

`idempotency_key` duoc build theo:

- `article_id`
- `content_hash`
- `model_name`
- `embedding_version`

Y nghia:

- cung mot noi dung article va cung mot config embedding thi event sync co semantic meaning giong nhau
- consumer ben `article_service` phai dedupe theo `event_id`

## 12. Luong search

API:

- `POST /api/v1/public/embedding/articles/search`

Body:

```json
{
  "query": "tin tuc cong nghe AI",
  "limit": 5
}
```

Luong xu ly:

1. service nhan query text
2. embed query voi `task_type = RETRIEVAL_QUERY`
3. query `pgvector` tren `article_chunk_embeddings`
4. join nguoc ve document + chunk
5. tra ve top match

Search hien tai van:

- query theo chunk
- khong query theo `article_document_embeddings`
- khong dung `article_category_matches` cho search API

## 13. API hien co

### `GET /`

Tra ve overview co ban cua service:

- ten service
- topic article
- consumer group
- embedding model
- so API key dang config
- category bootstrap bat hay khong

### `GET /healthz`

Health noi bo.

### `GET /api/v1/public/embedding/healthz`

Health public de test nhanh.

### `POST /api/v1/public/embedding/articles/search`

Semantic search de test retrieval.

## 14. Y nghia cua health

Service duoc coi la `ok` khi:

- embedding DB san sang
- Gemini provider probe da pass
- category bootstrap da xong
- article Kafka topic san sang
- article consumer dang connect
- category sync topic san sang
- outbox publisher dang connect

Health hien tai con track them:

- `ready_category_embeddings`
- `processed_articles`
- `skipped_articles`
- `failed_articles`
- `processed_categories`
- `skipped_categories`
- `failed_categories`
- `last_error`

## 15. Cau hinh env quan trong

### 15.1. Database

```env
EMBEDDING_DATABASE_URL=postgresql://postgres:postgres@embedding-postgres:5432/pody_embedding
EMBEDDING_DATABASE_URL_LOCAL=postgresql://postgres:postgres@localhost:5434/pody_embedding

CATEGORY_SOURCE_DATABASE_URL=postgresql://postgres:postgres@article-postgres:5432/pody_article
```

`CATEGORY_SOURCE_DATABASE_URL` la DB nguon de doc taxonomy category.

### 15.2. Gemini

```env
EMBEDDING_GEMINI_API_KEYS=key_one,key_two
GEMINI_EMBEDDING_MODEL=gemini-embedding-001
EMBEDDING_VERSION=v1
EMBEDDING_OUTPUT_DIMENSIONS=1536
EMBEDDING_BATCH_SIZE=16
EMBEDDING_GEMINI_QUOTA_RETRY_DELAY_SECONDS=60
EMBEDDING_GOOGLE_GENAI_BASE_URL=
```

Fallback key:

```env
GOOGLE_API_KEY=...
GEMINI_API_KEY=...
```

Service se collect key theo thu tu:

1. `EMBEDDING_GEMINI_API_KEYS`
2. `GOOGLE_API_KEY`
3. `GEMINI_API_KEY`

Va se loai bo key trung lap.

### 15.3. Kafka

```env
KAFKA_BROKERS=kafka:9092
KAFKA_TOPIC=article.embedding.requested
ARTICLE_CATEGORY_SYNC_TOPIC=article.category.matches.generated
KAFKA_CONSUMER_GROUP=embedding-service
KAFKA_AUTO_OFFSET_RESET=earliest
KAFKA_REQUEST_TIMEOUT_MS=30000
KAFKA_SESSION_TIMEOUT_MS=10000
OUTBOX_POLL_INTERVAL_SECONDS=1
OUTBOX_BATCH_SIZE=20
```

### 15.4. Category bootstrap

```env
CATEGORY_BOOTSTRAP_ENABLED=true
CATEGORY_SOURCE_DATABASE_POOL_MIN_SIZE=1
CATEGORY_SOURCE_DATABASE_POOL_MAX_SIZE=3
```

### 15.5. Chunking

```env
ARTICLE_CHUNK_TARGET_CHARS=1400
ARTICLE_CHUNK_OVERLAP_CHARS=180
ARTICLE_CHUNK_MIN_CHARS=250
ARTICLE_DEFAULT_LANGUAGE_CODE=vi
```

### 15.6. Article-category mapping

```env
ARTICLE_CATEGORY_MATCH_MAX_MATCHES=3
ARTICLE_CATEGORY_MATCH_MIN_SCORE=0.2
```

Moi khi doi:

- model
- version
- dimensions
- chunking config
- category semantic text

thi co the phat sinh re-embed / re-match / re-sync event.

## 16. Cac service local lien quan

De local stack hoat dong, cac container lien quan la:

- `kafka`
- `debezium-connect`
- `debezium-register`
- `article-postgres`
- `article-db-init`
- `article-service`
- `embedding-postgres`
- `embedding-db-init`
- `embedding-service`

Luu y:

- `article-db-init`, `embedding-db-init`, `debezium-register` la job mot lan
- neu chung `Exited (0)` thi do la binh thuong

## 17. Cach chay local

### 17.1. Dieu kien can

- Docker Desktop hoac Docker Engine dang chay
- Docker Compose hoat dong
- co Gemini API key hop le trong `.env`

### 17.2. Chay stack toi thieu cho flow nay

```bash
docker compose up --build kafka redis article-postgres article-db-init article-service embedding-postgres embedding-db-init debezium-connect debezium-register embedding-service
```

Neu muon tranh backlog qua lon khi test:

```bash
ARTICLE_ENABLE_INITIAL_CRAWL=false docker compose up --build kafka redis article-postgres article-db-init article-service embedding-postgres embedding-db-init debezium-connect debezium-register embedding-service
```

### 17.3. Cac dia chi can biet

- Article service: `http://localhost:8084`
- Embedding service: `http://localhost:8088`
- Article DB tu host: `localhost:5433`
- Embedding DB tu host: `localhost:5434`
- Debezium Connect: `http://localhost:8083`

## 18. Cach smoke test

### 18.1. Kiem tra category da duoc bootstrap

```bash
docker exec pody-embedding-postgres psql -U postgres -d pody_embedding -c "select count(*) from category_embedding_documents;"
docker exec pody-embedding-postgres psql -U postgres -d pody_embedding -c "select count(*) from category_embeddings;"
```

Ky vong:

- co row trong `category_embedding_documents`
- co row trong `category_embeddings`

### 18.2. Kiem tra article da duoc embed

```bash
docker exec pody-embedding-postgres psql -U postgres -d pody_embedding -c "select article_id, chunk_count, sync_status from article_embedding_documents order by article_id;"
docker exec pody-embedding-postgres psql -U postgres -d pody_embedding -c "select article_id, model_name, embedding_version from article_document_embeddings order by article_id;"
```

### 18.3. Kiem tra internal semantic matches

```bash
docker exec pody-embedding-postgres psql -U postgres -d pody_embedding -c "select article_id, category_id, rank, score from article_category_matches order by article_id, rank;"
```

### 18.4. Kiem tra outbox event da duoc tao

```bash
docker exec pody-embedding-postgres psql -U postgres -d pody_embedding -c "select event_type, status, aggregate_id, created_at from outbox_events order by created_at desc limit 20;"
```

### 18.5. Kiem tra semantic rows da duoc sync ve article_service

```bash
docker exec pody-article-postgres psql -U postgres -d pody_article -c "select article_id, category_id, assignment_source, match_rank, score from category_articles where assignment_source = 'semantic' order by article_id, match_rank;"
```

### 18.6. Test search

```bash
curl -X POST http://localhost:8088/api/v1/public/embedding/articles/search \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"tin tuc cong nghe AI\", \"limit\": 5}"
```

## 19. Cac loi pho bien va cach debug

### 19.1. `No Gemini API key configured`

Nguyen nhan:

- chua set `EMBEDDING_GEMINI_API_KEYS`
- hoac fallback key rong

Huong xu ly:

- kiem tra `.env`
- rebuild `embedding-service`

### 19.2. Provider probe fail luc startup

Bieu hien:

- article consumer khong start
- category bootstrap khong chay
- `/healthz` bao `provider_ready=false`

Nguyen nhan:

- key sai
- model sai
- network loi
- proxy sai base URL

### 19.3. Category bootstrap khong tao vector

Kiem tra theo thu tu:

1. `CATEGORY_BOOTSTRAP_ENABLED=true`
2. `CATEGORY_SOURCE_DATABASE_URL` dung DB article
3. bang `categories` trong article DB co du lieu
4. category co `name` / `description` hop le
5. provider da san sang

Neu category vector da current thi service se skip va KHONG goi Gemini lai.

### 19.4. `429 RESOURCE_EXHAUSTED`

Nguyen nhan:

- het quota free tier

Hanh vi hien tai:

- article consumer giu nguyen offset
- service doi theo `EMBEDDING_GEMINI_QUOTA_RETRY_DELAY_SECONDS`
- sau do thu lai

Huong xu ly:

- giam backlog
- tat initial crawl khi test
- doi het cua so quota
- dung them API key / project co quota lon hon

### 19.5. Outbox event co ma article_service khong nhan duoc

Kiem tra theo thu tu:

1. `outbox_events.status` trong embedding DB
2. log `embedding-service` publisher
3. topic `article.category.matches.generated` da ton tai chua
4. article-service consumer dang chay khong
5. article-service co gap loi khi ghi `category_articles` khong

### 19.6. pgAdmin khong thay bang embedding

Thuong la do dang nhin nham DB hoac nham port.

Dung:

- host: `localhost`
- port: `5434`
- database: `pody_embedding`

Khong phai:

- `5433`
- `pody_article`

### 19.7. `embedding-db-init` tu tat

Day la binh thuong neu exit code = `0`.

Do la init job, khong phai DB chay lau dai.

Container DB that su can phai la:

- `pody-embedding-postgres`

## 20. Cach thay doi model hoac dimensions

Schema hien tai khoa:

- `VECTOR(1536)`

Neu muon doi dimensions:

1. tao migration moi
2. doi schema `VECTOR(...)`
3. doi validation trong `settings.py`
4. re-embed du lieu

Khong nen chi doi `.env` ma khong doi schema.

## 21. Cach thay doi chunking

Neu doi:

- `ARTICLE_CHUNK_TARGET_CHARS`
- `ARTICLE_CHUNK_OVERLAP_CHARS`
- `ARTICLE_CHUNK_MIN_CHARS`

thi `chunking_signature` se doi.

Y nghia:

- article nhan event moi se duoc re-embed
- internal match va sync event cung duoc tao lai

## 22. Cach mo rong service trong tuong lai

Neu sau nay them `user embedding`, nen giu nguyen nguyen tac:

1. moi domain co request parser rieng
2. moi domain co service nghiep vu rieng
3. repository van la noi duy nhat giao tiep DB
4. provider van la abstraction chung cho embedding model
5. publisher / consumer event nen tach thanh component rieng

Huong mo rong hop ly:

- `UserEmbeddingService`
- schema rieng cho user vectors
- event contract rieng cho onboarding / user interests

## 23. Lenh huu ich cho maintainers

### Chay test

```bash
$env:PYTHONPATH='server/embedding_service'; py -3 -m unittest discover server/embedding_service/tests
```

### Compile nhanh

```bash
py -3 -m compileall server/embedding_service/app server/embedding_service/tests
```

### Xem compose config

```bash
docker compose config
```

### Xem log

```bash
docker logs -f pody-embedding-service
docker logs -f pody-debezium-register
```

## 24. Tom tat nhung dieu can nho nhat

Neu chi can nho 10 dieu, hay nho:

1. `embedding-service` embed article va bootstrap category vectors
2. Category duoc doc truc tiep tu article DB, khong di qua Kafka
3. Chi article `PUBLISHED` moi duoc embed
4. Category chi duoc embed khi thieu vector hoac vector stale
5. Service luu document vector cho article de map category
6. `article_category_matches` la bang noi bo, khong phai projection online cuoi cung
7. Ket qua semantic category duoc publish qua `outbox_events` + Kafka
8. `article_service` moi la noi luu online `category_articles`
9. Search API hien query theo chunk, khong phai theo category match
10. Khi het quota Gemini, service backoff va retry thay vi reconnect lien tuc
