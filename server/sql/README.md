# SQL Schemas Theo Microservice

Thư mục này chỉ chứa schema cho các service dùng PostgreSQL.

## Danh sách

- `services/identity_service.sql`
- `services/content_service.sql`
- `services/ai_service.sql`
- `services/billing_service.sql`

## Quy ước

1. Mỗi file tương ứng một database riêng.
2. Không có foreign key tới database của service khác.
3. Mọi tham chiếu sang service khác chỉ là external id.
4. Mỗi service có `outbox_events` và `inbox_processed_events` để hỗ trợ event-driven integration.
