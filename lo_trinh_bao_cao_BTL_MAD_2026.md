# Lộ Trình Làm Báo Cáo BTL MAD 2026 - Pody

Tài liệu này dùng để chia quá trình viết báo cáo BTL MAD thành các phase rõ ràng, bám theo yêu cầu trong file `docs/yeu cau BTL_MAD 2026.docx` và cấu trúc hệ thống Pody hiện tại.

Mục tiêu báo cáo: 25-30 trang bản cứng, trình bày rõ ràng, có đầy đủ thông tin nhóm, mô tả ứng dụng, phân tích yêu cầu, thiết kế tổng quan/chi tiết, kết quả triển khai, kết quả thử nghiệm, hạn chế, định hướng và tài liệu tham khảo.

## Tổng Quan Phân Chia Phase

| Phase | Nội dung chính | Mức độ | Đầu ra cần có |
| --- | --- | --- | --- |
| Phase 1 | Phần chung: mở đầu, lý do chọn đề tài, concept, yêu cầu, công nghệ | Nhóm | Khung báo cáo, mô tả đề tài, bảng công nghệ, phân công |
| Phase 2 | Phân tích thiết kế tổng quan: kiến trúc, use case tổng quan, ER tổng quan, triển khai | Nhóm | Sơ đồ kiến trúc, use case tổng quan, ER tổng quan, deployment overview |
| Phase 3 | Phần riêng từng cá nhân theo cụm service | Cá nhân | Use case chi tiết, class/sequence/ER riêng, giao diện, kết quả |
| Phase 4 | Kết quả tổng hợp, thử nghiệm, kết luận, hạn chế, định hướng | Nhóm + cá nhân | Bảng kết quả, minh chứng demo, kết luận, tài liệu tham khảo |
| Phase 5 | Rà soát hình thức và đóng gói bản cứng | Nhóm | File báo cáo hoàn chỉnh, mục lục, danh mục hình/bảng, format |

## Phase 1 - Phần Chung, Mô Tả Và Đặc Tả Đề Tài

### Mục tiêu

Tạo nền tảng chung cho báo cáo: người đọc phải hiểu Pody là ứng dụng gì, vì sao nhóm chọn đề tài, ứng dụng giải quyết vấn đề nào, phạm vi thực hiện đến đâu và mỗi thành viên đóng góp phần nào.

### Các mục cần viết

1. Trang bìa
   - Tên trường, học phần, giảng viên hướng dẫn.
   - Tên ứng dụng: Pody.
   - Thông tin Nhóm QLĐT và Nhóm BTL.
   - Danh sách thành viên: họ tên đầy đủ, MSSV.
   - Thành viên thực hiện báo cáo nếu báo cáo theo cá nhân.

2. Trang thành viên và đóng góp
   - Lập bảng gồm: STT, họ tên, MSSV, vai trò, service/phạm vi phụ trách, công việc cụ thể, tỷ lệ đóng góp.
   - Phân chia đề xuất:
     - Thành viên 1: AI tạo podcast - `ai-service`, `content-service`.
     - Thành viên 2: Báo và podcast báo - `article_service`, `embedding_service`.
     - Thành viên 3: Hạ tầng và xác thực - `api-gateway`, `identity-service`.
     - Thành viên 4: Thông báo - `notification-service`.

3. Giới thiệu ứng dụng
   - Pody là ứng dụng nghe podcast và tạo nội dung podcast có hỗ trợ AI.
   - Người dùng có thể đăng ký/đăng nhập, đọc/tìm bài báo, nghe podcast, lưu tập yêu thích, theo dõi thông báo.
   - Creator có thể dùng AI để tạo kế hoạch sản xuất show, tạo episode và lưu nội dung vào hệ thống.
   - Hệ thống được xây theo kiến trúc microservices, có Flutter app, API Gateway và các backend service độc lập.

4. Lý do chọn đề tài
   - Nhu cầu nghe podcast và tiêu thụ nội dung ngắn/dạng âm thanh ngày càng tăng.
   - Tin tức và nội dung dài cần được tóm tắt, chuyển đổi thành dạng dễ nghe.
   - AI có thể hỗ trợ lập kế hoạch, tạo kịch bản, tạo transcript/audio, giúp rút ngắn thời gian sản xuất podcast.
   - Đề tài phù hợp để áp dụng mobile app, backend microservices, AI, tìm kiếm semantic, event-driven và notification.

5. Concept thực hiện ứng dụng
   - "Đọc nhanh, nghe sau, tạo podcast bằng AI".
   - Hệ thống gồm 2 luồng chính:
     - Luồng listener: khám phá nội dung, đọc báo, nghe podcast, lưu bookmark, nhận thông báo.
     - Luồng creator: chat với AI, tạo production plan, tạo show/episode, quản lý nội dung.

6. Phân tích yêu cầu ứng dụng
   - Yêu cầu chức năng:
     - Đăng ký, đăng nhập, xác minh email, quên mật khẩu, Google sign-in.
     - Xem danh sách show, chi tiết show, danh sách episode, chi tiết episode.
     - Đọc bài báo, lọc/tìm kiếm bài báo, tương tác reaction/comment/metric đọc bài.
     - Tạo podcast từ nhóm bài báo bằng job nền.
     - Tạo show podcast bằng AI.
     - Nhận thông báo trong app và email hệ thống.
   - Yêu cầu phi chức năng:
     - Tách service để dễ bảo trì và mở rộng.
     - API có Gateway điều phối và kiểm tra JWT.
     - Dữ liệu mỗi service có database riêng, không phụ thuộc foreign key chéo service.
     - Có health check, OpenAPI docs, test và Docker Compose để demo.

7. Phân tích và lựa chọn công nghệ
   - Mobile: Flutter.
   - API Gateway và một số service: Go, `chi`, reverse proxy, JWT middleware.
   - AI/Article/Embedding: Python, FastAPI, SQLAlchemy.
   - Database: PostgreSQL, pgvector cho embedding.
   - Cache/storage/message:
     - Redis cho cache/phụ trợ.
     - Kafka cho event-driven.
     - Debezium cho CDC từ article sang embedding.
     - MinIO/Google Cloud Storage cho media object.
   - AI provider: Gemini/Google GenAI, TTS, embedding model.
   - Triển khai local: Docker Compose.

### Đầu ra của Phase 1

- Khung chương 1 hoàn chỉnh.
- Bảng phân công thành viên.
- Bảng yêu cầu chức năng/phi chức năng.
- Bảng công nghệ và lý do lựa chọn.

## Phase 2 - Phân Tích Thiết Kế Tổng Quan Cấp Nhóm

### Mục tiêu

Mô tả toàn cảnh hệ thống Pody trước khi đi vào phần riêng từng cá nhân. Phase này cần có hình vẽ tổng quan, use case tổng quan và mô hình triển khai.

### 2.1 Kiến trúc tổng quan hệ thống

Cần vẽ sơ đồ gồm các khối:

- Client:
  - Flutter app.
- API Gateway:
  - Route `/api/v1/public/*` cho endpoint public.
  - Route `/api/v1/*` cho endpoint cần auth.
  - JWT auth middleware, CORS, logging, request ID, route discovery, docs.
- Backend services:
  - `identity-service`: xác thực, user profile, token, email verification, password reset.
  - `content-service`: show, episode, home feed, bookmark, creator shows.
  - `ai-service`: AI chat-create, production plan, create show, episode plan, TTS/transcript job.
  - `article_service`: crawl/đọc bài báo, category, reaction, comment, metric, article podcast jobs.
  - `embedding_service`: tạo embedding bài báo/category, search semantic, gán category ngữ nghĩa.
  - `notification-service`: notification inbox, unread count, settings, email verification/password reset, retry/DLQ.
- Infrastructure:
  - PostgreSQL riêng theo service.
  - pgvector cho embedding.
  - Kafka và Debezium cho event.
  - Redis, MinIO, Kafka UI.

Gợi ý đặt tên hình: "Hình 2.1. Kiến trúc tổng quan hệ thống Pody".

### 2.2 Luồng xử lý tổng quan

Nên vẽ ít nhất 4 luồng:

1. Luồng xác thực
   - Flutter app -> API Gateway -> Identity Service -> PostgreSQL.
   - Identity Service ghi outbox event -> Kafka -> Notification Service gửi email.

2. Luồng nghe podcast/show
   - Flutter app -> API Gateway -> Content Service -> Content DB.
   - Lấy home feed, show detail, episode detail, bookmark.

3. Luồng tạo podcast bằng AI
   - Flutter app -> API Gateway -> AI Service.
   - AI Service tạo thread/production plan/job.
   - Job tạo show/episode và ghi vào Content DB.
   - Có thể gọi Notification Service khi job hoàn thành.

4. Luồng bài báo và podcast báo
   - Article Service crawl RSS -> Article DB.
   - Debezium/Kafka đẩy event -> Embedding Service -> Embedding DB.
   - User tạo article podcast job -> worker tổng hợp, tạo script/audio/transcript -> lưu asset.

### 2.3 Use case tổng quan cấp nhóm

Tác nhân chính:

- Khách chưa đăng nhập.
- Người dùng đã đăng nhập.
- Creator.
- Hệ thống AI.
- Hệ thống thông báo/email.

Use case tổng quan:

- Đăng ký tài khoản.
- Xác minh email.
- Đăng nhập/đăng xuất.
- Xem trang chủ nội dung.
- Xem show/episode.
- Lưu/bỏ lưu episode.
- Đọc bài báo.
- Tương tác với bài báo.
- Tạo podcast từ bài báo.
- Chat với AI để tạo kế hoạch podcast.
- Tạo show/episode từ production plan.
- Xem và đánh dấu thông báo.

Gợi ý đặt tên hình: "Hình 2.2. Use case tổng quan ứng dụng Pody".

### 2.4 ER tổng quan cấp nhóm

Vì mỗi service có database riêng, ER tổng quan nên vẽ theo cụm:

- Identity DB:
  - users, refresh_tokens, email_verification_tokens, password_reset_tokens, outbox_events.
- Content DB:
  - shows, episodes, hosts, show_hosts, episode_transcripts, bookmarks.
- AI DB:
  - chat_threads, chat_messages, production_plans, ai_jobs, voice_profiles.
- Article DB:
  - articles, categories, category_articles, article_stats, article_interactions, article_comments, article_metrics, article_podcast_jobs, article_podcast_assets.
- Embedding DB:
  - article_embedding_documents, article_embedding_chunks, article_chunk_embeddings, article_document_embeddings, category_embeddings, article_category_matches, embedding_jobs.
- Notification DB:
  - notifications, notification_settings, email_delivery_logs, inbox_processed_events.

Lưu ý khi viết: giữa các database không nên vẽ foreign key vật lý chéo service; chỉ ghi chú bằng external id như `user_id`, `show_id`, `article_id`.

### 2.5 Mô hình triển khai tổng quát

Cần mô tả Docker Compose:

- API Gateway port `8080`.
- Identity Service port `8081`.
- Content Service port `8082`.
- Article Service port `8084`.
- AI Service port `8085`.
- Notification Service port `8087`.
- Embedding Service port `8088`.
- Article Postgres port `5433`.
- Embedding Postgres port `5434`.
- Kafka port `9092`, Debezium Connect port `8083`, Kafka UI port `8090`.
- MinIO port `9000/9001`, Redis port `6379`.

### Đầu ra của Phase 2

- Sơ đồ kiến trúc tổng quan.
- Use case tổng quan.
- ER tổng quan theo cụm service.
- Mô hình triển khai Docker Compose.
- Bảng mapping service - chức năng - database - endpoint chính.

## Phase 3 - Phần Riêng Từng Cá Nhân Theo Service

Phase này là phần quan trọng nhất để đáp ứng yêu cầu "mức cá nhân" trong đề bài: use case chi tiết, class diagram, sequence diagram, ER riêng, giao diện đáp ứng chức năng và kết quả thực hiện.

Mỗi cá nhân nên viết theo một format thống nhất:

1. Giới thiệu phạm vi phụ trách.
2. Chức năng chính.
3. Use case chi tiết.
4. Thiết kế database/ER riêng.
5. Class/component diagram.
6. Sequence diagram cho 1-2 luồng tiêu biểu.
7. API/service contract.
8. Giao diện liên quan.
9. Kết quả đạt được và test minh chứng.
10. Hạn chế riêng của phần đó.

### Thành Viên 1 - AI Tạo Podcast: `ai-service` và `content-service`

#### Phạm vi

Phụ trách luồng creator tạo podcast/show bằng AI và lưu thành nội dung nghe được trong Content Service.

#### Nội dung cần viết

- Mô tả `ai-service`:
  - FastAPI + Google GenAI.
  - Quản lý voice profiles.
  - Chat-create threads.
  - Production plans.
  - Episode plan generation.
  - Job tạo show từ production plan.
  - TTS, transcript alignment, upload audio.
- Mô tả `content-service`:
  - Quản lý show, episode, host.
  - Home feed, show detail, episode detail.
  - Creator my shows.
  - Bookmark episode.

#### Use case chi tiết để vẽ

- Creator tạo thread chat với AI.
- Creator gửi message để refine ý tưởng podcast.
- Creator xem production plan.
- Creator tạo show từ production plan.
- Người dùng xem show detail/episode detail.
- Người dùng bookmark episode.

#### Sequence diagram gợi ý

1. Tạo show bằng AI:
   - Creator -> Flutter app -> API Gateway -> AI Service.
   - AI Service tạo production plan/job.
   - Worker trong AI Service ghi show/episode vào Content DB.
   - AI Service gọi Notification Service khi hoàn thành.

2. Nghe episode:
   - User -> Flutter app -> API Gateway -> Content Service.
   - Content Service đọc episode/transcript/audio URL từ Content DB.
   - Flutter app hiện player và transcript.

#### ER riêng

- AI DB:
  - voice_profiles.
  - chat_threads.
  - chat_messages.
  - production_plans.
  - ai_jobs.
- Content DB:
  - shows.
  - episodes.
  - hosts.
  - show_hosts.
  - episode_transcripts.
  - episode_bookmarks.

#### Giao diện cần chụp

- Màn hình tạo podcast/AI setup.
- Màn hình chat/tạo plan nếu có.
- Màn hình library/my shows.
- Màn hình show detail.
- Màn hình player/transcript.

#### Kết quả cần thống kê

- Số voice profiles seed.
- Số show/episode demo.
- Ví dụ 1 production plan tạo thành show.
- Endpoint chính:
  - `POST /api/v1/ai/chat-create/threads`
  - `POST /api/v1/ai/chat-create/threads/{thread_id}/messages`
  - `GET /api/v1/ai/production-plans/{plan_id}`
  - `POST /api/v1/ai/production-plans/{plan_id}/create-show`
  - `GET /api/v1/public/content/home`
  - `GET /api/v1/public/content/shows/{showID}`
  - `GET /api/v1/public/content/episodes/{episodeID}`
  - `POST /api/v1/content/shows`

### Thành Viên 2 - Báo Và Podcast Báo: `article_service` và `embedding_service`

#### Phạm vi

Phụ trách luồng đọc báo, crawl bài báo, category, tương tác bài viết, tìm kiếm/phân loại semantic và tạo podcast từ nhóm bài báo.

#### Nội dung cần viết

- Mô tả `article_service`:
  - Crawl bài báo từ RSS.
  - Lưu article, category, stats, reaction, comment, metric.
  - API đọc danh sách/detail bài báo.
  - Feature article podcast job: user chọn bài báo, tạo job nền, tổng hợp nội dung, tạo script/audio/transcript.
- Mô tả `embedding_service`:
  - Consume CDC article event từ Kafka.
  - Chunk nội dung bài báo.
  - Gọi Gemini embedding.
  - Lưu vector vào PostgreSQL + pgvector.
  - Search semantic và gán category ngữ nghĩa.

#### Use case chi tiết để vẽ

- User xem danh sách bài báo.
- User lọc/tìm kiếm bài báo theo category/query.
- User xem chi tiết bài báo.
- User reaction/comment bài báo.
- User chọn nhiều bài báo để tạo podcast.
- Hệ thống tạo embedding khi có bài báo mới.
- User tìm kiếm semantic bài báo.

#### Sequence diagram gợi ý

1. Đọc chi tiết bài báo:
   - User -> Flutter app -> API Gateway -> Article Service.
   - Article Service tăng view count, lấy reaction summary, count comments, trả detail.

2. Tạo podcast từ bài báo:
   - User -> Flutter app -> Article Service tạo `article_podcast_job`.
   - Worker lấy article snapshots.
   - Worker research/tóm tắt/viết script/TTS.
   - Worker upload audio/transcript và cập nhật job.

3. Embedding từ article event:
   - Article DB thay đổi.
   - Debezium -> Kafka topic.
   - Embedding Service consume event.
   - Chunk text -> embedding provider -> Embedding DB.

#### ER riêng

- Article DB:
  - articles.
  - categories.
  - category_articles.
  - article_stats.
  - article_interactions.
  - article_comments.
  - article_metrics.
  - article_podcast_jobs.
  - article_podcast_job_articles.
  - article_podcast_drafts.
  - article_podcast_assets.
- Embedding DB:
  - article_embedding_documents.
  - article_embedding_chunks.
  - article_chunk_embeddings.
  - article_document_embeddings.
  - category_embedding_documents.
  - category_embeddings.
  - article_category_matches.
  - embedding_jobs.

#### Giao diện cần chụp

- Màn hình news list.
- Màn hình article detail.
- Màn hình chọn bài tạo podcast.
- Màn hình article podcast job/library/playback.
- Màn hình kết quả search nếu có.

#### Kết quả cần thống kê

- Số bài báo trong CSDL demo.
- Số category.
- Số comment/reaction/metric mẫu.
- Số embedding document/chunk/job.
- Ví dụ 1 job podcast từ bài báo với status/audio URL/transcript URL.
- Endpoint chính:
  - `GET /api/v1/article`
  - `GET /api/v1/article/categories`
  - `GET /api/v1/article/{article_id}`
  - `POST /api/v1/article/{article_id}/reactions`
  - `GET /api/v1/article/{article_id}/comments`
  - `POST /api/v1/article/podcast-jobs`
  - `GET /api/v1/article/podcast-jobs/{job_id}`
  - `POST /api/v1/public/embedding/articles/search`

### Thành Viên 3 - Hạ Tầng Và Xác Thực: `api-gateway` và `identity-service`

#### Phạm vi

Phụ trách cửa vào hệ thống, routing, public/protected API, JWT authentication, user identity, email verification, password reset và tích hợp event với notification.

#### Nội dung cần viết

- Mô tả `api-gateway`:
  - Reverse proxy cho các service.
  - Public routes và protected routes.
  - JWT auth middleware.
  - Request ID, logging, recovery, CORS.
  - Route metadata và docs.
- Mô tả `identity-service`:
  - Sign-up/sign-in.
  - Email verification.
  - Google sign-in.
  - Refresh token/sign-out.
  - Forgot/reset password.
  - User profile `me`.
  - Outbox events sang Kafka cho email verification/password reset.

#### Use case chi tiết để vẽ

- Người dùng đăng ký tài khoản.
- Người dùng xác minh email.
- Người dùng đăng nhập bằng email/password.
- Người dùng đăng nhập bằng Google.
- Người dùng refresh token.
- Người dùng quên mật khẩu và reset password.
- Gateway kiểm tra JWT trước khi proxy request protected.

#### Sequence diagram gợi ý

1. Đăng ký và xác minh email:
   - User -> Flutter app -> API Gateway -> Identity Service.
   - Identity Service tạo user + verification token + outbox event.
   - Outbox publisher -> Kafka.
   - Notification Service gửi email.
   - User bấm link verify -> Identity Service cập nhật verified.

2. Gọi API protected:
   - Flutter app gửi Authorization Bearer token.
   - API Gateway verify JWT.
   - Gateway bổ sung auth context header.
   - Gateway proxy tới service đích.

#### ER riêng

- Identity DB:
  - users.
  - refresh_tokens.
  - email_verification_tokens.
  - password_reset_tokens.
  - outbox_events.
  - inbox_processed_events nếu có.

#### Giao diện cần chụp

- Sign up.
- Verify email.
- Sign in.
- Forgot password/reset password.
- Profile/settings.

#### Kết quả cần thống kê

- Số user demo.
- Ví dụ access token/refresh token flow.
- Số event verification/password reset đã publish.
- Endpoint chính:
  - `POST /api/v1/public/identity/sign-up`
  - `POST /api/v1/public/identity/sign-in`
  - `POST /api/v1/public/identity/google`
  - `POST /api/v1/public/identity/refresh`
  - `POST /api/v1/public/identity/forgot-password`
  - `POST /api/v1/public/identity/reset-password`
  - `GET /api/v1/identity/me`
  - `PATCH /api/v1/identity/me`
  - `GET /api/v1/_meta/routes`

### Thành Viên 4 - Thông Báo: `notification-service`

#### Phạm vi

Phụ trách thông báo trong app, đếm unread, cài đặt thông báo, email hệ thống, consume Kafka event, retry và DLQ.

#### Nội dung cần viết

- Mô tả `notification-service`:
  - Notification inbox.
  - Unread count.
  - Mark read/read all.
  - Notification settings.
  - Internal API tạo notification.
  - Consume email verification event và password reset event.
  - Email sender log/smtp.
  - Retry topic, DLQ topic, processed-event tracking, email delivery logs.

#### Use case chi tiết để vẽ

- User xem danh sách thông báo.
- User đánh dấu 1 thông báo đã đọc.
- User đánh dấu tất cả thông báo đã đọc.
- User cập nhật cài đặt thông báo.
- Hệ thống gửi email verification.
- Hệ thống gửi email reset password.
- Internal service tạo in-app notification khi AI job hoàn thành.

#### Sequence diagram gợi ý

1. Gửi email verification:
   - Identity Service publish event.
   - Kafka topic `identity.email.verification.requested`.
   - Notification Service consume.
   - Kiểm tra idempotency/processed event.
   - Gửi email qua log/smtp.
   - Ghi delivery log, retry nếu lỗi.

2. Xem và đánh dấu thông báo:
   - Flutter app -> API Gateway -> Notification Service.
   - Notification Service đọc notifications/settings từ Notification DB.
   - User mark read -> cập nhật `read_at`.

#### ER riêng

- Notification DB:
  - notifications.
  - notification_settings.
  - email_delivery_logs.
  - inbox_processed_events.
  - processed event/delivery retry tables nếu schema có.

#### Giao diện cần chụp

- Notifications tab/list.
- Badge/unread count nếu có.
- Notification settings.
- Log email verification/reset password trong local.

#### Kết quả cần thống kê

- Số notification demo.
- Số unread/read.
- Ví dụ 1 email verification delivery log.
- Ví dụ retry/DLQ nếu có test.
- Endpoint chính:
  - `GET /api/v1/notifications`
  - `GET /api/v1/notifications/unread-count`
  - `PATCH /api/v1/notifications/{id}/read`
  - `PATCH /api/v1/notifications/read-all`
  - `GET /api/v1/notifications/settings`
  - `PUT /api/v1/notifications/settings`
  - `POST /internal/notifications/email/verification`
  - `POST /internal/notifications/inbox`

### Đầu ra của Phase 3

- Mỗi thành viên có 1 tiểu mục riêng trong chương Phân tích thiết kế chi tiết.
- Mỗi thành viên có ít nhất:
  - 1 use case chi tiết.
  - 1 class/component diagram.
  - 1 sequence diagram.
  - 1 ER/service data diagram.
  - 2-4 ảnh giao diện/kết quả.
  - Bảng endpoint/chức năng phụ trách.

## Phase 4 - Kết Quả, Thử Nghiệm, Kết Luận Và Định Hướng

### 4.1 Kết quả ứng dụng

Cần viết theo 2 mức:

1. Kết quả tổng quát cấp nhóm
   - Hệ thống chạy được qua Docker Compose.
   - API Gateway điều phối các service.
   - Flutter app tích hợp các màn hình chính.
   - Các service có health check và OpenAPI docs.
   - Dữ liệu demo có thể khởi tạo qua SQL seed/migration.

2. Kết quả theo cá nhân
   - Mỗi thành viên viết phần mình phụ trách:
     - Chức năng đã hoàn thành.
     - API đã có.
     - Bảng dữ liệu liên quan.
     - Ảnh giao diện minh chứng.
     - Test/kiểm thử đã thực hiện.

### 4.2 Các bước cài đặt và triển khai ứng dụng

Nên viết theo thứ tự:

1. Cài đặt Docker/Docker Compose.
2. Tạo file `.env` từ biến môi trường mẫu nếu cần.
3. Chạy database, Kafka, Redis, MinIO.
4. Chạy migration/db-init.
5. Chạy các service backend.
6. Chạy API Gateway.
7. Chạy Flutter app.
8. Kiểm tra health endpoint và docs.

Lệnh minh họa có thể đưa vào báo cáo:

```bash
docker compose up --build
```

Và các URL kiểm tra:

- `http://localhost:8080/healthz`
- `http://localhost:8080/docs`
- `http://localhost:8080/api/v1/_meta/routes`
- `http://localhost:8080/api/v1/public/identity/docs`
- `http://localhost:8080/api/v1/public/ai/docs`
- `http://localhost:8080/api/v1/public/content/docs`
- `http://localhost:8080/api/v1/public/notifications/docs`

### 4.3 Kết quả thử nghiệm

Cần có bảng test case tóm tắt:

| Nhóm chức năng | Test case | Kết quả mong đợi | Kết quả thực tế | Trạng thái |
| --- | --- | --- | --- | --- |
| Auth | Đăng ký tài khoản mới | Tạo user và gửi verification email | Điền sau khi test | Pass/Fail |
| Auth | Đăng nhập user đã verify | Trả access/refresh token | Điền sau khi test | Pass/Fail |
| Content | Xem home feed | Trả danh sách show/episode | Điền sau khi test | Pass/Fail |
| AI | Tạo production plan | Trả plan/job hợp lệ | Điền sau khi test | Pass/Fail |
| Article | Xem danh sách bài báo | Trả list có category/stats | Điền sau khi test | Pass/Fail |
| Article Podcast | Tạo podcast job | Job queued/processing/completed | Điền sau khi test | Pass/Fail |
| Embedding | Search semantic | Trả article liên quan | Điền sau khi test | Pass/Fail |
| Notification | Xem unread count | Trả số thông báo chưa đọc | Điền sau khi test | Pass/Fail |

### 4.4 Số liệu minh chứng trong CSDL

Mỗi thành viên cần lấy số liệu thực tế sau khi seed/demo:

- Số user.
- Số show.
- Số episode.
- Số article.
- Số category.
- Số article podcast job.
- Số embedding document/chunk.
- Số notification.
- Số delivery log.

Nếu không lấy được số liệu thực tế, ghi rõ là "dữ liệu demo" và chụp minh chứng từ app/API.

### 4.5 Hạn chế

Gợi ý viết:

- Hệ thống mới ở mức demo/local, chưa tối ưu cho production.
- Một số luồng AI phụ thuộc API key, quota và dịch vụ bên thứ ba.
- TTS/transcript/embedding có thể tốn thời gian xử lý nên cần job nền.
- Chưa có đầy đủ monitoring, alerting, rate limiting nâng cao.
- Các service tách database nên cần quản lý consistency bằng event/idempotency.
- Một số tính năng xa hơn như billing, social nâng cao, recommendation nâng cao chưa nằm trong phạm vi BTL.

### 4.6 Định hướng phát triển

Gợi ý viết:

- Hoàn thiện recommendation cá nhân hóa bằng embedding và lịch sử nghe/đọc.
- Thêm dashboard quản trị nội dung, nguồn tin, moderation.
- Hoàn thiện billing/subscription nếu cần thương mại hóa.
- Triển khai production trên cloud với observability, CI/CD, backup.
- Cải thiện chất lượng AI pipeline: prompt versioning, evaluation, cache kết quả, multi-voice podcast.
- Mở rộng notification sang push notification/mobile notification.

### 4.7 Tài liệu tham khảo

Cần gồm:

- Tài liệu Flutter.
- Tài liệu Go, FastAPI.
- PostgreSQL, pgvector.
- Kafka, Debezium.
- Docker Compose.
- Google GenAI/Gemini/TTS/Embedding.
- Các tài liệu nội bộ trong repo: README của từng service, OpenAPI docs.

### Đầu ra của Phase 4

- Chương Kết quả hoàn chỉnh.
- Bảng test case.
- Bảng số liệu CSDL/demo.
- Kết luận, hạn chế, định hướng.
- Danh sách tài liệu tham khảo.

## Phase 5 - Rà Soát Hình Thức Và Đóng Gói Báo Cáo

### Checklist hình thức bắt buộc

- Báo cáo 25-30 trang.
- Font Times New Roman, cỡ 14.
- Căn lề 2 bên.
- In 1 mặt.
- Có trang bìa đầy đủ thông tin Nhóm QLĐT và Nhóm BTL.
- Có trang thành viên tham gia và đóng góp.
- Có mục lục.
- Có danh sách từ viết tắt.
- Có danh sách hình vẽ.
- Có danh sách bảng biểu.
- Hình ảnh và bảng biểu đánh số theo chương.
- Ảnh giao diện vừa phải, không để 1 ảnh chiếm cả trang nếu không cần thiết.
- Chương mục rõ ràng, không bị lệch format.

### Checklist nội dung trước khi nộp

- Chứa mở đầu:
  - Giới thiệu ứng dụng.
  - Lý do chọn đề tài.
  - Concept.
  - Phân tích yêu cầu.
  - Lựa chọn công nghệ.
- Chứa phân tích thiết kế:
  - Kiến trúc tổng quan mức nhóm.
  - Use case tổng quan.
  - Use case chi tiết mức cá nhân.
  - Class/component diagram mức cá nhân.
  - Sequence diagram mức cá nhân.
  - ER mức nhóm/cá nhân.
  - Giao diện đáp ứng chức năng mức cá nhân.
- Chứa kết quả:
  - Mô hình triển khai.
  - Bước cài đặt/triển khai.
  - Kết quả chức năng qua giao diện.
  - Kết quả thử nghiệm/triển khai.
  - Số liệu CSDL/demo.
  - Kết luận, hạn chế.
  - Tài liệu tham khảo.

## Đề Xuất Cấu Trúc Báo Cáo 25-30 Trang

| Phần | Số trang gợi ý |
| --- | --- |
| Bìa, đóng góp, mục lục, danh mục | 3-4 |
| Chương 1: Mở đầu và yêu cầu | 4-5 |
| Chương 2: Phân tích thiết kế tổng quan | 5-6 |
| Chương 3: Thiết kế chi tiết cá nhân | 10-12 |
| Chương 4: Kết quả và thử nghiệm | 4-5 |
| Chương 5: Kết luận, hạn chế, định hướng, tài liệu tham khảo | 2-3 |

## Thứ Tự Làm Việc Để Không Bị Rối

1. Cả nhóm chốt phạm vi và phân công.
2. Viết Phase 1 trước để thống nhất câu chuyện chung.
3. Vẽ 3 hình tổng quan: kiến trúc, use case tổng quan, ER tổng quan.
4. Mỗi thành viên viết phần riêng theo service mình phụ trách.
5. Chụp giao diện và lấy số liệu demo/API.
6. Tổng hợp kết quả, test case, hạn chế, định hướng.
7. Rà soát format, danh mục hình/bảng, trang bìa và tỷ lệ trang.
