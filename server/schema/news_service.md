# News Service Database Design

## Storage

- Primary store: **MongoDB**
- Search index: **OpenSearch**

## Collections

### `sources`

```json
{
  "_id": "uuid",
  "name": "VNExpress",
  "slug": "vnexpress",
  "base_url": "https://vnexpress.net",
  "rss_url": "https://vnexpress.net/rss",
  "language_code": "vi",
  "is_active": true,
  "created_at": "date"
}
```

Indexes:

- unique `slug`

### `crawl_jobs`

```json
{
  "_id": "uuid",
  "source_id": "uuid",
  "job_type": "rss_fetch",
  "status": "running",
  "started_at": "date",
  "finished_at": null,
  "stats": {
    "fetched": 40,
    "inserted": 12,
    "updated": 3
  },
  "error_message": null
}
```

Indexes:

- `(source_id, started_at desc)`
- `(status, started_at desc)`

### `articles`

```json
{
  "_id": "uuid",
  "source_id": "uuid",
  "external_id": "source-native-id",
  "title": "Apple công bố ...",
  "summary": "Tóm tắt ngắn",
  "body_text": "Nội dung đầy đủ",
  "canonical_url": "https://...",
  "image_url": "https://...",
  "author_name": "Author",
  "language_code": "vi",
  "categories": ["tech", "ai"],
  "published_at": "date",
  "ingested_at": "date",
  "status": "published",
  "raw_payload": {}
}
```

Indexes:

- unique `(source_id, external_id)` nếu `external_id` có
- unique `canonical_url`
- `(published_at desc)`
- `(status, published_at desc)`
- text search / OpenSearch sync key

### `article_chunks`

Nếu cần semantic search hoặc prompt grounding:

```json
{
  "_id": "uuid",
  "article_id": "uuid",
  "chunk_index": 0,
  "content": "Đoạn văn bản",
  "embedding_id": "optional",
  "created_at": "date"
}
```

Indexes:

- `(article_id, chunk_index)`

### `outbox_events`

Dùng để phát `NewsArticlePublished`, `NewsArticleArchived`.

### `inbox_processed_events`

Dùng để tiêu thụ event idempotent từ service khác nếu có.

## OpenSearch Index

Tên đề xuất: `news_articles_search`

Field chính:

- `article_id`
- `title`
- `summary`
- `body_text`
- `publisher`
- `published_at`
- `categories`
- `language_code`

Sorting chính:

- `published_at desc`
- `relevance score`
