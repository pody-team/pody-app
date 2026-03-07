# Thiết Kế Cơ Sở Dữ Liệu Pody

Dựa trên việc phân tích các màn hình chức năng của ứng dụng (Home, Player, News, Create, Library, Detail, Comments, v.v.), dưới đây là thiết kế Cơ sở dữ liệu (Database Schema) toàn diện cho hệ thống Pody. CSDL được thiết kế theo hướng quan hệ (RDBMS) như PostgreSQL.

## 1. Sơ Đồ Thực Thể Kết Hợp (ERD)

```mermaid
erDiagram
    USERS {
        uuid id PK
        string username "Tên hiển thị"
        string email "Email đăng nhập"
        string avatar_url "Link ảnh đại diện"
        string bio "Mô tả ngắn"
        datetime created_at
        datetime updated_at
    }

    PODCASTS {
        uuid id PK
        uuid owner_id FK "Người tạo/Author"
        string content_type "Loại: 'podcast' hoặc 'storytelling'"
        string title "Tên Kênh/Tuyển tập truyện"
        text description "Mô tả kênh/truyện"
        string cover_image_url "Ảnh bìa"
        int total_listens "Tổng số lượt nghe"
        datetime created_at
    }

    EPISODES {
        uuid id PK
        uuid podcast_id FK "Thuộc kênh nào"
        string title "Tên tập"
        text description "Tóm tắt / Nội dung"
        string audio_url "Link file âm thanh"
        string cover_image_url "Ảnh bìa của tập"
        int duration_seconds "Thời lượng (giây)"
        int listen_count "Số lượt nghe tập"
        int like_count "Số lượt thả tim"
        int comment_count "Số lượt bình luận"
        datetime published_at "Ngày xuất bản"
    }

    CATEGORIES {
        int id PK
        string name "Tên danh mục (Tech, Society...)"
        string icon_name
    }

    PODCAST_CATEGORIES {
        uuid podcast_id FK
        int category_id FK
    }

    COMMENTS {
        uuid id PK
        uuid user_id FK "Người bình luận"
        uuid episode_id FK "Tập được bình luận"
        text content "Nội dung chat/bình luận"
        int audio_timestamp "Thời điểm timestamp (nếu có)"
        datetime created_at
    }

    LIKES {
        uuid user_id FK
        uuid episode_id FK
        datetime created_at
    }

    BOOKMARKS {
        uuid user_id FK
        uuid episode_id FK
        datetime created_at
    }

    PLAYLISTS {
        uuid id PK
        uuid user_id FK "Chủ sở hữu"
        string name "Tên Playlist"
        string description
        boolean is_public "Công khai hay riêng tư"
        datetime created_at
    }

    PLAYLIST_ITEMS {
        uuid playlist_id FK
        uuid episode_id FK
        int position "Vị trí trong playlist"
        datetime added_at
    }

    NEWS_ARTICLES {
        uuid id PK
        string title "Tiêu đề bài báo/News"
        string publisher "Nguồn cập nhật"
        string source_url "Link gốc"
        string cover_image_url
        text content_text "Nội dung text thô"
        datetime published_at
    }

    PRODUCTION_PLANS {
        uuid id PK
        uuid user_id FK "Người yêu cầu tạo AI"
        uuid source_article_id FK "ID Bài báo tạo ra tập này (Nullable)"
        string title "Tên dự kiến"
        string host_voice_id "Giọng đọc AI đã chọn"
        string status "Trạng thái (Pending, Generating, Done)"
        string generated_audio_url "Kết quả trả về"
        datetime created_at
    }

    NOTIFICATIONS {
        uuid id PK
        uuid user_id FK "Người nhận"
        string type "Loại (Like, Comment, AI_Done...)"
        string title 
        text message
        boolean is_read "Trạng thái đọc"
        datetime created_at
    }

    %% Relationships
    USERS ||--o{ PODCASTS : "creates/owns channel"
    USERS ||--o{ COMMENTS : "writes"
    USERS ||--o{ LIKES : "gives"
    USERS ||--o{ BOOKMARKS : "saves"
    USERS ||--o{ PLAYLISTS : "creates"
    USERS ||--o{ PRODUCTION_PLANS : "initiates AI task"
    USERS ||--o{ NOTIFICATIONS : "receives"

    CATEGORIES ||--o{ PODCAST_CATEGORIES : "has"
    PODCASTS ||--o{ PODCAST_CATEGORIES : "belongs to"
    
    PODCASTS ||--o{ EPISODES : "contains"
    
    EPISODES ||--o{ COMMENTS : "receives"
    EPISODES ||--o{ LIKES : "receives"
    EPISODES ||--o{ BOOKMARKS : "is saved into library"
    EPISODES ||--o{ PLAYLIST_ITEMS : "included in"
    
    PLAYLISTS ||--o{ PLAYLIST_ITEMS : "contains"
    
    NEWS_ARTICLES ||--o{ PRODUCTION_PLANS : "acts as source for"
    PRODUCTION_PLANS ||--o| EPISODES : "generates final"
```

## 2. Giải Text & Mô Hình Hóa Bảng

Dưới đây là mô tả chi tiết cho từng luồng dữ liệu chính của Pody:

### A. Quản lý Nội Dung (Core)
- **`USERS`:** Bảng quy tụ mọi tài khoản tham gia (nghe, tác giả podcast/truyện). 
- **`PODCASTS` (Shows/Series):** Đại diện cho một Kênh Podcast hoặc một Tuyển tập truyện kể (Audiobook/Storytelling). Biến `content_type` giúp phân dải UI thành 2 luồng: Podcast thời sự/chia sẻ và Kể chuyện/Audiobook.
- **`EPISODES`:** Từng phần riêng lẻ/từng tập được phát hành của kênh (hoặc từng chương truyện). Ghi nhận thời lượng, link file MP3, các chỉ số đếm ngược tương tác.

### B. Tương Tác Của Người Dùng (Social Metrics)
- **`LIKES` & `BOOKMARKS`:** Quản lý hành động Thả tim (nằm trong Player) và Lưu tập (Đưa vào Thư viện) của user. Bookmark list sẽ trích xuất ra mục "Saved" ở Library Screen.
- **`COMMENTS`:** Lưu trữ bình luận từ `comments_overlay.dart`. Điểm đặc sắc là có trường `audio_timestamp`, hỗ trợ tính năng comment đính kèm theo mốc thời gian của Podcast (SoundCloud style).
- **`PLAYLISTS` & `PLAYLIST_ITEMS`:** Hỗ trợ tính năng thiết lập thêm danh sách phát cá nhân hóa của user.

### C. Tính Năng AI Podcast (Đặc trưng Pody) 
Đây là điểm khác biệt của Pody - tính năng hô biến "News" thành "Podcast":
- **`NEWS_ARTICLES`:** Cào (Scrape) hoặc fetch qua API các bài báo thời sự mỗi ngày để show lên màn hình `news_screen.dart`.
- **`PRODUCTION_PLANS`:** Khi user bấm "Thêm vào playlist tạo AI", hệ thống sinh ra một Plan. Bảng lưu trữ tùy chỉnh (giọng đọc, chủ đề) và bắt đầu track tiến trình tạo AI (Status: Pending, Generating, Finished). Lịch sử của nó hiển thị ở tính năng Create / Edit Plan.
- Khi Plan hoàn tất, hệ thống có thể fill data để tạo bản ghi tự động sang bảng **`EPISODES`** đi kèm cờ nhận diện (is_ai_generated).

### D. Thông Báo
- **`NOTIFICATIONS`:** Hệ thống đẩy cho user qua app khi AI vừa sinh xong kịch bản/âm thanh, khi có ai đó Reply bình luận, hoặc channel theo dõi có tập mới.
