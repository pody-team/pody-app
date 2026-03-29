# Embedding Service Maintenance Guide

## 1. Muc tieu cua tai lieu

Tai lieu nay giai thich chi tiet:

- `embedding-service` dang giai quyet bai toan gi
- Luong du lieu di qua service nhu the nao
- Cac bang du lieu duoc dung vao muc dich gi
- Cach cai dat, chay local, va kiem tra service
- Cach debug cac loi pho bien
- Nhung nguyen tac quan trong khi chinh sua de tranh lam vo luong embedding

Tai lieu nay duoc viet de dong nghiep co the:

- doc va hieu nhanh service ma khong can mo tung file code
- biet can sua o dau khi co loi
- biet cach mo rong them pipeline embedding trong tuong lai

## 2. Service nay dang lam gi

`embedding-service` hien tai chi xu ly `article embedding`.

Scope hien tai:

- Nhan CDC event cua bang `articles` tu Debezium qua Kafka
- Chuan hoa noi dung bai viet thanh document text
- Cat document thanh cac `chunk`
- Goi Gemini Embeddings de tao vector
- Luu ket qua vao database rieng dung `PostgreSQL + pgvector`
- Cho phep test semantic search thong qua API public cua service

Scope chua lam:

- Chua xu ly `category embedding`
- Chua xu ly `user embedding`
- Chua expose qua `api-gateway`
- Chua co batch re-index tool rieng

## 3. Tong quan kien truc

Luong tong the:

1. `article-service` ghi du lieu vao DB nguon `article-postgres`
2. Debezium theo doi bang `public.articles`
3. Debezium day event vao Kafka topic `article.embedding.requested`
4. `embedding-service` consume topic nay
5. Service parse event, quyet dinh co can embed hay khong
6. Neu can embed:
   - tao job
   - cat chunk
   - goi Gemini
   - luu vector vao `embedding-postgres`
7. Khi can test search, client goi API search cua `embedding-service`
8. Service embed cau query, query vector similarity tren `pgvector`, va tra ve ket qua

## 4. Cac thanh phan chinh trong code

### 4.1. Bootstrap va runtime

- `app/main.py`
  - Tao FastAPI app
  - Gan `runtime`, controller, view vao `app.state`
  - Dung `lifespan` de start/stop service

- `app/runtime.py`
  - Noi cac thanh phan voi nhau
  - Khoi tao DB pool, repository, provider, service, controller
  - Cho DB san sang
  - Probe Gemini provider truoc khi start consumer
  - Start Kafka consumer neu startup hop le

### 4.2. Config

- `app/config/settings.py`
  - Doc env var
  - Validate config
  - Khoa `EMBEDDING_OUTPUT_DIMENSIONS = 1536`
  - Tinh `chunking signature` tu config chunking

- `app/config/database.py`
  - Tao `psycopg_pool.ConnectionPool`

### 4.3. Controller

- `app/controller/article_event_controller.py`
  - Dieu phoi message Kafka vao service nghiep vu

- `app/controller/kafka_article_consumer_controller.py`
  - Tao topic neu chua ton tai
  - Chay Kafka consumer background
  - Commit, retry, backoff, cap nhat state health

- `app/controller/article_search_controller.py`
  - Dieu phoi search request vao service nghiep vu

- `app/controller/system_controller.py`
  - Tra ve thong tin overview va health

### 4.4. Service nghiep vu

- `app/service/article_embedding_service.py`
  - Parse event
  - Quy dinh bai nao duoc embed
  - Tinh hash noi dung
  - Kiem tra co can re-embed hay khong
  - Tao chunks
  - Goi Gemini provider
  - Luu ket qua qua repository

- `app/service/gemini_provider.py`
  - Quan ly nhieu API key
  - Probe provider luc startup
  - Goi `embed_content`
  - Rotate key khi gap quota/rate-limit
  - Backoff khi tat ca key deu bi `429 RESOURCE_EXHAUSTED`

### 4.5. Model va repository

- `app/model/request`
  - Parse Kafka payload va search payload

- `app/model/response`
  - Shape response cho health, overview, search

- `app/model/entity`
  - Dataclass dai dien cho row DB

- `app/model/repository/embedding_repository.py`
  - Toan bo persistence logic
  - Upsert metadata
  - Tao job
  - Replace chunks + embeddings
  - Query semantic search

### 4.6. Utility

- `app/util/chunking.py`
  - Cat title, summary, body thanh cac chunk

- `app/util/hashing.py`
  - Tinh SHA-256 cho noi dung text

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
|   |   |-- response/
|   |   `-- value_object/
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

Database nay la read-model rieng cho embedding, khong phai DB nghiep vu goc.

### 6.1. `article_embedding_documents`

Day la ban ghi tong quat cho moi bai viet duoc service quan ly.

Muc dich:

- map `article_id` tu source DB sang embedding DB
- luu metadata can dung cho search/debug
- luu `content_hash` de quyet dinh co can re-embed hay khong
- luu `last_chunking_signature` de biet config chunking co doi khong
- luu tinh trang dong bo: `pending`, `processing`, `ready`, `failed`, `skipped`

Nen hieu bang nay nhu "ho so embedding" cua moi article.

### 6.2. `article_embedding_chunks`

Day la cac doan van ban da duoc cat tu article.

Muc dich:

- luu `chunk_index`
- phan loai chunk: `title`, `summary`, `body`
- luu `content` goc cua tung chunk
- luu `content_hash` cua chunk

Bang nay giup:

- semantic search theo tung doan
- RAG/passage retrieval trong tuong lai
- re-embed chinh xac hon neu chunking thay doi

### 6.3. `article_chunk_embeddings`

Day la noi luu vector thuc te.

Muc dich:

- moi chunk co mot vector embedding
- luu thong tin trace:
  - `model_name`
  - `embedding_version`
  - `dimensions`
- cho phep query similarity bang `pgvector`

Cot `embedding` dang dung:

- `VECTOR(1536)`

Index hien tai:

- `hnsw` voi `vector_cosine_ops`

### 6.4. `embedding_jobs`

Day la bang theo doi cong viec embed.

Muc dich:

- luu job type
- luu source topic/partition/offset
- luu content hash, model, version
- luu status `pending/processing/completed/failed`
- luu so lan retry
- luu thong diep loi

Bang nay rat huu ich khi debug pipeline va audit.

## 7. Luong khoi dong service

Khi container `embedding-service` bat dau:

1. FastAPI app duoc tao trong `app/main.py`
2. `EmbeddingRuntime` duoc khoi tao
3. Service doi DB embedding san sang
4. Service kiem tra co API key hay khong
5. Service probe Gemini provider voi model da config
6. Neu probe fail:
   - service khong start Kafka consumer
   - `healthz` se bao `degraded`
7. Neu probe ok:
   - service dam bao topic Kafka ton tai
   - service start consumer thread

Y nghia:

- Service khong con cho den luc an message dau tien moi phat hien key sai/model sai/network sai
- Loi provider duoc phat hien som ngay luc startup

## 8. Luong ingest article embedding

### 8.1. Event den tu dau

Nguon event:

- Debezium theo doi `public.articles`
- Connector route event sang topic `article.embedding.requested`

### 8.2. Consumer xu ly ra sao

Khi Kafka consumer nhan duoc message:

1. Parse payload JSON thanh `ArticleEvent`
2. Gop `title + summary + content` thanh `document_text`
3. Tinh `content_hash`
4. Tinh `chunking_signature` tu config chunking
5. Tim document hien co trong DB embedding

### 8.3. Rule nghiep vu quan trong

#### Rule 1: chi embed bai `PUBLISHED`

Neu `status` khong phai `PUBLISHED`:

- service chi upsert metadata
- danh dau `sync_status = skipped`
- khong goi Gemini
- khong tao embeddings moi

Ly do:

- tranh ton quota cho bai chua public
- tranh dua du lieu khong hop le vao he thong retrieval

#### Rule 2: skip neu embedding hien tai van con hop le

Service se skip re-embed khi dong thoi dung ca 6 dieu kien:

- `content_hash` khong doi
- `sync_status = ready`
- `last_embedding_model` khong doi
- `last_embedding_version` khong doi
- `last_embedding_dimensions` khong doi
- `last_chunking_signature` khong doi

Neu skip:

- service van dong bo metadata moi nhat xuong `article_embedding_documents`
- nhung khong goi Gemini lai

#### Rule 3: metadata-only update khong can re-embed

Vi du:

- doi `author`
- doi `thumbnail_url`
- doi `published_at`

ma noi dung text khong doi thi:

- service chi sync metadata
- khong tao chunk/vector moi

### 8.4. Neu can embed

Neu khong skip:

1. Tao hoac cap nhat document
2. Tao job trong `embedding_jobs`
3. Danh dau job `processing`
4. Dung `build_article_chunks()` de cat text
5. Goi Gemini embedding cho tung chunk
6. Validate dimensions phai dung `1536`
7. Xoa chunk/vector cu cua document do
8. Chen chunk moi
9. Chen vector moi vao `article_chunk_embeddings`
10. Cap nhat document sang `ready`
11. Danh dau job `completed`

### 8.5. Neu co loi

#### Parse loi vinh vien

Vi du payload sai schema:

- consumer commit offset
- log loi
- tang `failed_articles`

Ly do:

- tranh bi ket vinh vien o mot message sai contract

#### Loi transient

Vi du:

- DB tam thoi loi
- Gemini loi mang
- provider chua san sang

thi:

- consumer `seek` lai dung offset cu
- khong commit
- message se duoc xu ly lai

#### Loi quota Gemini

Neu tat ca key deu bi `429 RESOURCE_EXHAUSTED`:

- provider nem `EmbeddingRateLimitError`
- consumer giu nguyen offset
- doi theo `EMBEDDING_GEMINI_QUOTA_RETRY_DELAY_SECONDS`
- khong reconnect Kafka lien tuc moi 2 giay nua

Dieu nay quan trong cho free tier vi no giup tranh dot quota them.

## 9. Luong search

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

1. Service nhan query text
2. Goi Gemini de embed query voi `task_type = RETRIEVAL_QUERY`
3. Query `pgvector` tren `article_chunk_embeddings`
4. Dung cosine similarity
5. Join nguoc ve `article_embedding_documents` va `article_embedding_chunks`
6. Tra ve top match

Khi search:

- chi lay document co `sync_status = ready`
- chi lay article co `article_status = PUBLISHED`
- chi lay embeddings dung model/version/dimensions hien tai

## 10. API hien co

### `GET /`

Tra ve overview co ban cua service:

- ten service
- topic
- consumer group
- model embedding
- so key dang config

### `GET /healthz`

Health noi bo.

### `GET /api/v1/public/embedding/healthz`

Health public de test nhanh.

### `POST /api/v1/public/embedding/articles/search`

Semantic search de test retrieval thuc te.

## 11. Y nghia cua health

Service duoc coi la `ok` khi:

- DB embedding san sang
- Gemini provider probe da pass
- topic Kafka san sang
- consumer dang connect

Luu y:

- `last_error` van duoc tra ve de debug
- nhung service khong con bi coi la `degraded` chi vi message gan nhat loi

Y nghia nay hop ly hon cho monitoring:

- readiness = ha tang va runtime song
- error detail = du lieu van hanh

## 12. Cau hinh env quan trong

### 12.1. Database

```env
EMBEDDING_DATABASE_URL=postgresql://postgres:postgres@embedding-postgres:5432/pody_embedding
EMBEDDING_DATABASE_URL_LOCAL=postgresql://postgres:postgres@localhost:5434/pody_embedding
```

`EMBEDDING_DATABASE_URL`:

- dung ben trong Docker network

`EMBEDDING_DATABASE_URL_LOCAL`:

- dung tu may host qua DBeaver, pgAdmin, psql

### 12.2. Gemini

```env
EMBEDDING_GEMINI_API_KEYS=key_one,key_two,key_three
GEMINI_EMBEDDING_MODEL=gemini-embedding-001
EMBEDDING_VERSION=v1
EMBEDDING_OUTPUT_DIMENSIONS=1536
EMBEDDING_BATCH_SIZE=16
EMBEDDING_GEMINI_QUOTA_RETRY_DELAY_SECONDS=60
EMBEDDING_GOOGLE_GENAI_BASE_URL=
```

Ghi chu:

- `EMBEDDING_OUTPUT_DIMENSIONS` hien tai bat buoc phai la `1536`
- `EMBEDDING_GOOGLE_GENAI_BASE_URL` de trong neu goi thang Gemini bang API key
- Chi set `EMBEDDING_GOOGLE_GENAI_BASE_URL` khi embedding-service can di qua proxy rieng

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

### 12.3. Kafka

```env
KAFKA_BROKERS=kafka:9092
KAFKA_TOPIC=article.embedding.requested
KAFKA_CONSUMER_GROUP=embedding-service
KAFKA_AUTO_OFFSET_RESET=earliest
KAFKA_REQUEST_TIMEOUT_MS=30000
KAFKA_SESSION_TIMEOUT_MS=10000
```

### 12.4. Chunking

```env
ARTICLE_CHUNK_TARGET_CHARS=1400
ARTICLE_CHUNK_OVERLAP_CHARS=180
ARTICLE_CHUNK_MIN_CHARS=250
ARTICLE_DEFAULT_LANGUAGE_CODE=vi
```

Moi khi doi cac gia tri nay:

- `chunking_signature` se doi
- service se buoc re-embed cac article khi event moi di qua

## 13. Cac service local lien quan

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
- `kafka-ui`

## 14. Cach chay local

### 14.1. Dieu kien can

- Docker Desktop hoac Docker Engine dang chay
- Docker Compose hoat dong
- Co Gemini API key hop le trong `.env`

### 14.2. Chay stack

```bash
docker compose up --build kafka article-postgres article-db-init article-service embedding-postgres embedding-db-init debezium-connect debezium-register embedding-service kafka-ui
```

### 14.3. Cac dia chi can biet

- Kafka UI: `http://localhost:8090`
- Debezium Connect: `http://localhost:8083`
- Embedding service: `http://localhost:8088`
- Embedding DB tu host: `localhost:5434`

## 15. Cach smoke test

### Cach 1: dung du lieu seed

Neu connector dang o `snapshot.mode=initial` va article demo da seed:

1. Start stack
2. Xem log:

```bash
docker logs -f pody-debezium-register
docker logs -f pody-embedding-service
```

3. Kiem tra health:

```bash
curl http://localhost:8088/healthz
```

4. Kiem tra DB embedding:

```bash
docker exec -it pody-embedding-postgres psql -U postgres -d pody_embedding -c "select article_id, chunk_count, sync_status from article_embedding_documents;"
docker exec -it pody-embedding-postgres psql -U postgres -d pody_embedding -c "select article_id, dimensions from article_chunk_embeddings limit 10;"
```

### Cach 2: update mot article de bat event moi

```bash
docker exec -it pody-article-postgres psql -U postgres -d pody_article -c "update articles set summary = summary || ' updated at ' || now()::text where original_url = 'https://pody.local/articles/debezium-smoke-test';"
```

Sau do xem:

```bash
docker logs -f pody-embedding-service
```

### Test search

```bash
curl -X POST http://localhost:8088/api/v1/public/embedding/articles/search ^
  -H "Content-Type: application/json" ^
  -d "{\"query\":\"debezium kafka article embedding\", \"limit\": 5}"
```

Neu thanh cong:

- response co `matches`
- co `article_id`, `title`, `chunk_preview`, `score`

## 16. Luu y quan trong khi dung free tier Gemini

Free tier thuong bi gioi han:

- requests per minute
- tokens per minute
- requests per day

Can luu y:

- Nhieu API key cung mot project co the van chia se chung quota
- Debezium `snapshot.mode=initial` co the lam service an rat nhieu article ngay luc boot
- `article-service` neu crawl san co the tao them event moi

Khuyen nghi khi test:

- Tat initial crawl cua article-service neu khong can
- Giu it du lieu nguon
- Update 1 bai smoke-test thay vi de ca backlog chay
- Tang `EMBEDDING_GEMINI_QUOTA_RETRY_DELAY_SECONDS` neu can

## 17. Cac loi pho bien va cach debug

### 17.1. `No Gemini API key configured`

Nguyen nhan:

- Chua set `EMBEDDING_GEMINI_API_KEYS`
- Hoac fallback key rong

Huong xu ly:

- Kiem tra `.env`
- Rebuild `embedding-service`

### 17.2. Provider probe fail luc startup

Bieu hien:

- consumer khong start
- `/healthz` bao `provider_ready=false`

Nguyen nhan:

- key sai
- model sai
- network loi
- proxy sai base URL

Kiem tra:

- `GEMINI_EMBEDDING_MODEL`
- `EMBEDDING_GOOGLE_GENAI_BASE_URL`
- Internet/proxy

### 17.3. `429 RESOURCE_EXHAUSTED`

Nguyen nhan:

- Het quota free tier

Hanh vi hien tai:

- offset khong bi commit
- service doi theo `EMBEDDING_GEMINI_QUOTA_RETRY_DELAY_SECONDS`
- sau do thu lai

Huong xu ly:

- Giam backlog
- Doi den het cua so quota
- Dung key/project co quota lon hon

### 17.4. `Network is unreachable`

Nguyen nhan:

- service dang tro sai `EMBEDDING_GOOGLE_GENAI_BASE_URL`
- hoac proxy khong reachable

Neu ban muon goi thang Gemini:

- de trong `EMBEDDING_GOOGLE_GENAI_BASE_URL`

### 17.5. Search khong ra ket qua

Kiem tra theo thu tu:

1. `article_embedding_documents` co row chua
2. `article_chunk_embeddings` co row chua
3. `sync_status` co phai `ready` khong
4. `article_status` co phai `PUBLISHED` khong
5. `dimensions/model/version` co dung voi cau hinh hien tai khong

## 18. Cach thay doi model hoac dimensions

Hien tai schema dang khoa:

- `VECTOR(1536)`

Nen neu ban muon doi sang dimensions khac:

1. Tao migration moi
2. Doi schema `VECTOR(...)`
3. Doi validation trong `settings.py`
4. Rebuild va re-embed du lieu

Khong nen chi doi `.env` ma khong doi schema.

## 19. Cach thay doi chunking

Neu doi:

- `ARTICLE_CHUNK_TARGET_CHARS`
- `ARTICLE_CHUNK_OVERLAP_CHARS`
- `ARTICLE_CHUNK_MIN_CHARS`

thi `chunking_signature` se doi.

Y nghia:

- Bai nao nhan event moi se duoc re-embed
- Du lieu cu trong DB van ton tai cho den khi event moi di qua

Neu can re-embed hang loat:

- phai tao lai event hoac co batch job rieng

## 20. Cach mo rong service trong tuong lai

Khi them `category embedding` hoac `user embedding`, nen giu nguyen nguyen tac:

1. Moi domain co request parser rieng
2. Moi domain co service nghiep vu rieng
3. Repository van la noi duy nhat giao tiep DB
4. Provider van la abstraction chung cho embedding model
5. Khong goi provider truc tiep tu controller

Huong mo rong hop ly:

- `CategoryEmbeddingService`
- `UserEmbeddingService`
- topic rieng hoac event contract rieng
- schema rieng cho tung loai embedding

## 21. Lenh huu ich cho maintainers

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

## 22. Tom tat nguyen tac quan trong nhat

Neu chi can nho 8 dieu, hay nho:

1. Service nay hien chi embed `article`
2. Chi bai `PUBLISHED` moi duoc embed
3. DB embedding la DB rieng, khong phai DB nghiep vu goc
4. Vector dang dung `pgvector` voi `VECTOR(1536)`
5. Skip/re-embed dua tren `content_hash + model + version + dimensions + chunking_signature`
6. Provider duoc probe luc startup truoc khi consumer chay
7. Khi het quota Gemini, service backoff thay vi reconnect lien tuc
8. Search hien dang query theo chunk, khong phai theo 1 vector/article

