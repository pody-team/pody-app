# Notification Service Database Design

## Storage

- Primary store: **MongoDB**

## Collections

### `user_notification_settings`

```json
{
  "_id": "uuid",
  "user_id": "uuid",
  "push_enabled": true,
  "email_enabled": false,
  "new_episode_enabled": true,
  "comment_enabled": true,
  "follow_enabled": true,
  "marketing_enabled": false,
  "updated_at": "date"
}
```

Indexes:

- unique `user_id`

### `notifications`

```json
{
  "_id": "uuid",
  "user_id": "uuid",
  "actor_user_id": "uuid",
  "type": "comment",
  "target_type": "episode",
  "target_id": "uuid",
  "title": "Linh commented on your episode",
  "body": "Cách giải thích khúc MVVM rất dễ hiểu.",
  "preview": "Cách giải thích khúc MVVM rất dễ hiểu.",
  "is_read": false,
  "read_at": null,
  "actor_snapshot": {
    "display_name": "Linh",
    "avatar_url": "..."
  },
  "target_snapshot": {
    "title": "MVC thời hiện đại"
  },
  "created_at": "date"
}
```

Indexes:

- `(user_id, is_read, created_at desc)`
- `(user_id, created_at desc)`

### `delivery_logs`

```json
{
  "_id": "uuid",
  "notification_id": "uuid",
  "user_id": "uuid",
  "channel": "push",
  "device_token_hash": "hashed",
  "provider": "fcm",
  "delivery_status": "sent",
  "provider_message_id": "provider-id",
  "error_message": null,
  "delivered_at": "date",
  "opened_at": null,
  "created_at": "date"
}
```

Indexes:

- `(notification_id, created_at desc)`
- `(user_id, created_at desc)`
- `(delivery_status, created_at desc)`

### `templates`

```json
{
  "_id": "uuid",
  "template_code": "episode_published",
  "channel": "push",
  "title_template": "{{show_title}} has a new episode",
  "body_template": "{{episode_title}} is now available",
  "is_active": true,
  "updated_at": "date"
}
```

Indexes:

- unique `(template_code, channel)`

### `outbox_events`

Dùng khi Notification muốn phát event như `NotificationDelivered`.

### `inbox_processed_events`

Lưu `event_id` đã xử lý để tránh gửi notification trùng khi consumer retry.
