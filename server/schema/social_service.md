# Social Service Database Design

## Storage

- Primary store: **MongoDB**
- Hot cache / ephemeral counters: **Redis**

## Nguyên Tắc

- Không join sang Identity hoặc Content DB.
- Lưu `user_id`, `show_id`, `episode_id` như external id.
- Những field cần render nhanh nên lưu snapshot cục bộ.

## Collections

### `user_follows`

```json
{
  "_id": "uuid",
  "follower_user_id": "uuid",
  "followed_user_id": "uuid",
  "follower_snapshot": {
    "display_name": "Promex",
    "avatar_url": "..."
  },
  "followed_snapshot": {
    "display_name": "Anh Ba",
    "avatar_url": "..."
  },
  "created_at": "date"
}
```

Indexes:

- unique `(follower_user_id, followed_user_id)`
- `(followed_user_id, created_at desc)`

### `show_follows`

```json
{
  "_id": "uuid",
  "user_id": "uuid",
  "show_id": "uuid",
  "notifications_enabled": true,
  "show_snapshot": {
    "title": "Future Minds",
    "cover_image_url": "..."
  },
  "created_at": "date"
}
```

Indexes:

- unique `(user_id, show_id)`
- `(show_id, created_at desc)`

### `saved_episodes`

```json
{
  "_id": "uuid",
  "user_id": "uuid",
  "episode_id": "uuid",
  "show_id": "uuid",
  "episode_snapshot": {
    "title": "MVC thời hiện đại",
    "cover_image_url": "...",
    "duration_seconds": 1920
  },
  "saved_at": "date"
}
```

Indexes:

- unique `(user_id, episode_id)`
- `(user_id, saved_at desc)`

### `playlists`

```json
{
  "_id": "uuid",
  "owner_user_id": "uuid",
  "name": "Morning Tech",
  "description": "",
  "cover_image_url": "...",
  "is_public": false,
  "item_count": 12,
  "created_at": "date",
  "updated_at": "date"
}
```

Indexes:

- `(owner_user_id, updated_at desc)`

### `playlist_items`

```json
{
  "_id": "uuid",
  "playlist_id": "uuid",
  "episode_id": "uuid",
  "show_id": "uuid",
  "sort_order": 0,
  "episode_snapshot": {
    "title": "Episode title",
    "show_title": "Show title",
    "cover_image_url": "..."
  },
  "added_at": "date"
}
```

Indexes:

- unique `(playlist_id, episode_id)`
- unique `(playlist_id, sort_order)`

### `listening_progress`

```json
{
  "_id": "uuid",
  "user_id": "uuid",
  "episode_id": "uuid",
  "show_id": "uuid",
  "position_seconds": 340,
  "progress_ratio": 0.42,
  "total_duration_seconds": 810,
  "is_completed": false,
  "last_played_at": "date",
  "completed_at": null
}
```

Indexes:

- unique `(user_id, episode_id)`
- `(user_id, last_played_at desc)`

### `episode_reactions`

```json
{
  "_id": "uuid",
  "episode_id": "uuid",
  "user_id": "uuid",
  "reaction_type": "like",
  "user_snapshot": {
    "display_name": "Promex",
    "avatar_url": "..."
  },
  "created_at": "date"
}
```

Indexes:

- unique `(episode_id, user_id, reaction_type)`
- `(episode_id, created_at desc)`

### `comments`

```json
{
  "_id": "uuid",
  "episode_id": "uuid",
  "show_id": "uuid",
  "user_id": "uuid",
  "parent_comment_id": null,
  "root_comment_id": "uuid",
  "body": "Hay quá",
  "audio_timestamp_ms": 93200,
  "status": "visible",
  "like_count": 12,
  "reply_count": 3,
  "user_snapshot": {
    "display_name": "Promex",
    "avatar_url": "..."
  },
  "episode_snapshot": {
    "title": "Episode title"
  },
  "created_at": "date",
  "updated_at": "date"
}
```

Indexes:

- `(episode_id, created_at desc)`
- `(episode_id, audio_timestamp_ms)`
- `(root_comment_id, created_at)`
- `(user_id, created_at desc)`

### `episode_engagement_counters`

```json
{
  "_id": "episode_id",
  "episode_id": "uuid",
  "like_count": 842,
  "comment_count": 120,
  "save_count": 55,
  "updated_at": "date"
}
```

Redis giữ:

- counter nóng theo episode;
- top comments ngắn hạn;
- recently played cache.

### `outbox_events`

Document dùng để phát event:

```json
{
  "_id": "uuid",
  "aggregate_type": "comment",
  "aggregate_id": "uuid",
  "event_type": "CommentCreated",
  "payload_version": 1,
  "payload": {},
  "status": "pending",
  "available_at": "date",
  "published_at": null,
  "created_at": "date"
}
```

### `inbox_processed_events`

```json
{
  "_id": "uuid",
  "event_id": "uuid",
  "source_service": "content",
  "event_type": "EpisodePublished",
  "processed_at": "date"
}
```
