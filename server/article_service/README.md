# Pody Article Service

`article_service` la microservice phu trach 2 nhom chuc nang chinh:

- Crawl bai bao tu RSS feed va luu vao PostgreSQL.
- Cung cap HTTP API de doc bai bao, react bai bao, comment bai bao, va ghi nhan metric doc bai.

Service nay da duoc tach lai theo huong de doc, de test, va de maintain hon:

- `api.py`: dinh nghia route
- `dependencies.py`: db session, auth context, service wiring
- `services/`: business logic
- `repositories/`: truy cap database
- `models/`: SQLAlchemy models
- `main.py`: app lifecycle + scheduler

## Muc Luc

- Kien truc tong quan
- Cac model dang dai dien cho gi
- Cac repository dang lam gi
- Luong hoat dong
- API hien co
- Thu muc chinh
- Cai dat va chay
- Test

## Kien Truc Tong Quan

Luot request HTTP di theo flow:

```text
Client
  -> API route
  -> Dependency
  -> Service
  -> Repository
  -> PostgreSQL
```

Y nghia tung lop:

- Route chi nhan request va tra response.
- Dependency lo khoi tao `db session`, auth user, va service.
- Service chua business logic.
- Repository chi tap trung doc/ghi database.
- Model dai dien cho bang trong database.

Crawler di theo flow rieng:

```text
Scheduler
  -> CrawlerService
  -> services/crawler/*
  -> StorageService
  -> ArticleRepository facade
  -> PostgreSQL + Redis
```

## Cac Model Dang Dai Dien Cho Gi

### [models/article.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/models/article.py)

Dai dien cho bang `articles`.

- Day la bang chinh cua bai bao.
- Moi row la 1 bai bao.
- Chua cac truong noi dung nhu `title`, `summary`, `content`, `author`, `original_url`, `thumbnail_url`, `published_at`, `source_id`, `status`.

### [models/category.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/models/category.py)

Dai dien cho bang `categories`.

- Day la bang category chuan cua `article_service`.
- Moi category co `id`, `slug`, `name`, `description`, `is_active`.
- Bang nay la source-of-truth cho category trong pham vi article/news.

### [models/category_article.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/models/category_article.py)

Dai dien cho bang `category_articles`.

- Day la bang trung gian giua `Article` va `Category`.
- Mot bai bao co the co nhieu category.
- Co them `is_primary` de xac dinh category chinh hien ra o list API.

### [models/article_category.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/models/article_category.py)

- File nay chi con la compatibility shim de code cu import `ArticleCategory` khong bi vo.
- Code moi nen dung `CategoryArticle`.

### [models/article_stat.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/models/article_stat.py)

Dai dien cho bang `article_stats`.

- Luu thong ke tong hop cua bai bao.
- Hien tai dang dung cho `view_count`.

### [models/article_interaction.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/models/article_interaction.py)

Dai dien cho bang `article_interactions`.

- Luu reaction cua user tren bai bao.
- Hien tai co `LIKE`, `LOVE`, `DISLIKE`.
- Moi user chi co 1 reaction tren 1 bai bao nhờ unique `(article_id, user_id)`.

### [models/article_metric.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/models/article_metric.py)

Dai dien cho bang `article_metrics`.

- Luu metric hanh vi doc bai.
- Hien tai la `reading_time_seconds`.
- Day la du lieu log, khong phai du lieu tong hop.

### [models/article_comment.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/models/article_comment.py)

Dai dien cho bang `article_comments`.

- Luu comment cua user tren bai bao.
- Moi row la 1 comment.
- Chua `user_id`, `user_name`, `content`, `created_at`, `updated_at`.

### [models/base.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/models/base.py)

- Chua `Base` dung chung cho toan bo SQLAlchemy model.

## Cac Repository Dang Lam Gi

### [repositories/article_write_repository.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/repositories/article_write_repository.py)

Phu trach ghi du lieu bai bao.

Chuc nang:

- `get_by_id`
- `exists_by_url`
- `insert_article`
- `add_category`

Repo nay duoc crawler va service layer dung de kiem tra bai bao co ton tai hay khong, va de insert bai moi.

### [repositories/article_query_repository.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/repositories/article_query_repository.py)

Phu trach doc du lieu bai bao.

Chuc nang:

- `list_articles_with_extra`
- `get_article_detail`

Repo nay join `articles`, `category_articles`, `categories`, `article_stats` de tra ve du lieu cho list/detail.

Contract hien tai:

- `GET /api/v1/article` tra ve `category` la primary category.
- `GET /api/v1/article/{id}` tra ve `categories` la day du danh sach category active cua bai bao.

### [repositories/article_stats_repository.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/repositories/article_stats_repository.py)

Phu trach thong ke.

Chuc nang:

- `increment_view_count`

### [repositories/article_reaction_repository.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/repositories/article_reaction_repository.py)

Phu trach reaction.

Chuc nang:

- `add_interaction`
- `get_reaction_summary`

Logic hien tai:

- Neu user bam lai dung reaction cu thi reaction se bi bo.
- Neu user bam reaction khac thi reaction cu se bi thay the.

### [repositories/article_metric_repository.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/repositories/article_metric_repository.py)

Phu trach metric doc bai.

Chuc nang:

- `track_metric`

### [repositories/article_comment_repository.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/repositories/article_comment_repository.py)

Phu trach comment.

Chuc nang:

- `add_comment`
- `list_comments`
- `count_comments`

### [repositories/article_repository.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/repositories/article_repository.py)

Day la facade de giu compatibility cho code cu.

- No delegate sang cac repo nho hon.
- Crawler hien tai dang dung facade nay.
- Code moi nen uu tien dung repo chuyen biet hoac service layer.

## Cac Service Dang Lam Gi

### [services/article_query_service.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/services/article_query_service.py)

Chua business logic cho luong doc.

Chuc nang:

- `list_articles`
- `get_article_detail`
- `get_reactions`
- `list_comments`
- `ensure_article_exists`

Service nay goi nhieu repo cung luc de ghep du lieu thanh response day du.

Vi du `get_article_detail`:

1. Lay bai bao.
2. Tang `view_count`.
3. Lay reaction summary.
4. Dem tong comment.
5. Tra response cho client.

### [services/article_engagement_service.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/services/article_engagement_service.py)

Chua business logic cho hanh vi nguoi dung.

Chuc nang:

- `add_reaction`
- `track_metric`
- `create_comment`
- `ensure_article_exists`
- `normalize_reaction_type`

Vi du `add_reaction`:

1. Kiem tra bai bao ton tai.
2. Validate reaction type.
3. Luu reaction hoac toggle reaction.
4. Lay summary moi.
5. Tra ket qua cho client.

## Dependency Va API

### [dependencies.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/dependencies.py)

File nay co 3 vai tro chinh:

- Cap `db session`.
- Khoi tao `ArticleQueryService` va `ArticleEngagementService`.
- Doc auth context tu header `X-Auth-User-ID`.

`resolve_user_id` dang hoat dong theo thu tu:

1. Uu tien `X-Auth-User-ID`.
2. Neu khong co thi fallback sang `user_id` trong body de tuong thich voi client cu.

### [api.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/api.py)

File nay chi dinh nghia endpoint va goi service.

Nhung endpoint hien co:

- `GET /healthz`
- `GET /api/v1/article`
- `GET /api/v1/article/categories`
- `GET /api/v1/article/{article_id}`
- `GET /api/v1/article/{article_id}/reactions`
- `POST /api/v1/article/{article_id}/reactions`
- `POST /api/v1/article/{article_id}/interaction`
- `POST /api/v1/article/{article_id}/metric`
- `GET /api/v1/article/{article_id}/comments`
- `POST /api/v1/article/{article_id}/comments`

## Luong Hoat Dong

### 1. Xem danh sach bai bao

```text
GET /api/v1/article
  -> api.py
  -> ArticleQueryService.list_articles()
  -> ArticleQueryRepository.list_articles_with_extra()
  -> PostgreSQL
```

`GET /api/v1/article` ho tro:

- `category`: loc theo ten hoac slug the loai.
- `q`: tim kiem trong `title` va `summary`.

### 1.1 Xem danh sach the loai

```text
GET /api/v1/article/categories
  -> api.py
  -> ArticleQueryService.list_categories()
  -> ArticleQueryRepository.list_categories_with_counts()
  -> PostgreSQL
```

### 2. Xem chi tiet bai bao

```text
GET /api/v1/article/{id}
  -> api.py
  -> ArticleQueryService.get_article_detail()
  -> ArticleQueryRepository.get_article_detail()
  -> ArticleStatsRepository.increment_view_count()
  -> ArticleReactionRepository.get_reaction_summary()
  -> ArticleCommentRepository.count_comments()
  -> response
```

Response detail hien co them:

- `reactions`
- `comments_count`
- `is_liked`
- `is_loved`
- `is_disliked`

### 3. React bai bao

```text
POST /api/v1/article/{id}/reactions
  -> api.py
  -> resolve_user_id()
  -> ArticleEngagementService.add_reaction()
  -> ArticleReactionRepository.add_interaction()
  -> ArticleReactionRepository.get_reaction_summary()
  -> response
```

### 4. Comment bai bao

```text
POST /api/v1/article/{id}/comments
  -> api.py
  -> resolve_user_id()
  -> ArticleEngagementService.create_comment()
  -> ArticleCommentRepository.add_comment()
  -> ArticleCommentRepository.count_comments()
  -> response
```

### 5. Gui metric doc bai

```text
POST /api/v1/article/{id}/metric
  -> api.py
  -> resolve_user_id()
  -> ArticleEngagementService.track_metric()
  -> ArticleMetricRepository.track_metric()
  -> PostgreSQL
```

### 6. Crawl bai bao moi

```text
Scheduler
  -> CrawlerService
  -> services/crawler/engine.py
  -> services/crawler/storage.py
  -> ArticleRepository facade
  -> PostgreSQL + Redis
```

## Thu Muc Chinh

- [main.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/main.py): lifecycle app, health startup, scheduler, uvicorn.
- [api.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/api.py): HTTP route definitions.
- [dependencies.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/dependencies.py): dependency injection cho db/auth/service.
- [schemas.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/schemas.py): request/response schema va utility nho.
- [models/](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/models): SQLAlchemy models.
- [repositories/](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/repositories): data access layer.
- [services/](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/services): business logic layer.
- [services/crawler/](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/services/crawler): crawler pipeline.
- [tests/test_api_routes.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/tests/test_api_routes.py): route-level tests cho feature moi.
- [setup_test.py](/D:/MyWorkSpace/pody/pody2/pody-app/server/article_service/setup_test.py): kiem tra environment + table setup.

## Database

Schema SQL nam tai:

- [article_service.sql](/D:/MyWorkSpace/pody/pody2/pody-app/server/sql/services/article_service.sql)

Bang lien quan den feature moi:

- `categories`
- `category_articles`
- `article_interactions`
- `article_comments`
- `article_metrics`
- `article_stats`

Huong mo rong tiep theo:

- Bang trung gian giua `Category` va `User` se la `CategoryUser`.
- Bang do khong nam trong `article_service`; no nen thuoc `identity-service` de tranh conflict domain.
- `categories` duoc seed san nhu mot taxonomy co dinh cho local flow, nen khong can route hay Kafka rieng de tao category.

## Cai Dat Va Chay

### 1. Cai dependency

```bash
pip install -r requirements.txt
```

### 2. Cau hinh moi truong

Tao `.env` va cau hinh toi thieu:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=tahanews
DB_USER=postgres
DB_PASSWORD=your_password

REDIS_HOST=localhost
REDIS_PORT=6379

CRAWLER_INTERVAL_MINUTES=30
MAX_CONCURRENT_REQUESTS=10
```

Hoac dung `ARTICLE_DATABASE_URL`.

### 3. Chay migration

Dam bao da apply:

- [article_service.sql](/D:/MyWorkSpace/pody/pody2/pody-app/server/sql/services/article_service.sql)

### 4. Run service

```bash
python main.py
```

## Test

Route-level test:

```bash
python -m unittest tests/test_api_routes.py
```

Compile nhanh de bat loi import/syntax:

```bash
python -m compileall .
```

Setup check:

```bash
python setup_test.py
```

## Ghi Chu Maintainability

Neu ban muon them feature moi, uu tien theo thu tu nay:

1. Them hoac sua model neu can thay doi schema.
2. Them repository chuyen biet neu co truy van moi.
3. Them service method cho business logic.
4. Noi route trong `api.py`.
5. Them test route-level.

Khong nen dua business logic vao:

- `api.py`
- repository facade
- `main.py`

Dieu do giu code de doc va de test hon ve sau.
