# Pody Database Schema
_Dự án Pody App (Podcast AI Platform)_

## 1. Mảng Người Khách Hàng (Users Collection)
_Dành cho cả Listener và Creator_

**Collection Name:** `users`
**Document ID:** `user_id` (Tự gen hoặc trùng `uid` của Firebase Auth)

* **`user_id`** (String): ID của người dùng.
* **`email`** (String): Địa chỉ email.
* **`display_name`** (String): Tên hiển thị.
* **`handle`** (String, Unique): Username (ví dụ: @tino_phan).
* **`avatar_url`** (String): Link ảnh đại diện.
* **`bio`** (String): Giới thiệu ngắn.
* **`account_type`** (Enum/String): `listener` hoặc `creator`.
* **`auth_provider`** (Array of Strings): Các phương thức đăng nhập đã liên kết (ví dụ: `[google.com, apple.com, password]`). **-> Support Google Auth**
* **`google_id`** (String): ID định danh của Google Auth.
* **`fcm_tokens`** (Array of Strings): Tokens để gửi push notification.
* **`created_at`** (Timestamp): Thời gian tạo tài khoản.
* **`updated_at`** (Timestamp): Thời gian cập nhật gần nhất.

### 1.1 Subscription & Credits (Sub-collection)
_Theo dõi gói trả phí và số lượng Credit của người dùng_
**Collection Name:** `users/{user_id}/wallet_subscriptions`
**Document ID:** `wallet_id` (1 user có 1 document duy nhất hoặc list các bản ghi mua bán lịch sử)

* **`current_tier`** (Enum/String): Tên gói hiện tại (ví dụ: `free`, `pro_monthly`, `creator_annual`).
* **`subscription_status`** (Enum/String): `active`, `canceled`, `past_due`, `unpaid`.
* **`stripe_customer_id`** / **`revenuecat_id`** (String): ID quản lý thanh toán.
* **`subscription_end_date`** (Timestamp): Ngày hết hạn gói.
* **`total_credits`** (Integer): Số credit hiện có (Dùng để generate AI giọng nói, nghe premium podcast...). **-> Support Subscription Credit**
* **`last_credit_recharge`** (Timestamp): Lần nạp/tặng credit gần nhất.
* **`free_credits_used_this_month`** (Integer): Số credit miễn phí đã dùng tháng này.

---

## 2. Thể Loại (Categories/Tags Collection)

**Collection Name:** `categories`
**Document ID:** `category_id`

* **`category_id`** (String)
* **`name`** (String): Tên hiển thị (ví dụ: Technology, Comedy).
* **`slug`** (String): Dành cho URL/Share (ví dụ: technology).
* **`icon_url`** (String): Link ảnh/icon thu nhỏ.
* **`color_code`** (String): Mã màu dạng Hex (ví dụ: `#FF5733`).

---

## 3. Nội Dung Podcasts (Podcasts Collection)
_Một Podcast sẽ chứa nhiều Tập (Episodes)_

**Collection Name:** `podcasts`
**Document ID:** `podcast_id`

* **`podcast_id`** (String)
* **`creator_id`** (String): Tham chiếu `users.user_id`.
* **`title`** (String): Tên chương trình.
* **`description`** (String): Mô tả.
* **`cover_image_url`** (String): Ảnh bìa.
* **`categories`** (Array of Strings): Danh sách `category_id`.
* **`tags`** (Array of Strings): Các từ khóa tìm kiếm.
* **`language`** (String): Ngôn ngữ (ví dụ: `vi`, `en`).
* **`is_premium`** (Boolean): True nếu podcast này chỉ dành cho tài khoản có Subscription/Trả credit.
* **`credit_cost`** (Integer): Số credit cần trả để unlock (nếu `is_premium` = true).
* **`total_episodes`** (Integer): Số tập hiện có (để đếm).
* **`total_listens`** (Integer): Lượt nghe cộng dồn.
* **`status`** (Enum/String): `draft`, `published`, `archived`.
* **`created_at`** (Timestamp)

---

## 4. Tập (Episodes Collection)
_Chi tiết nội dung của từng tập_

**Collection Name:** `episodes`
**Document ID:** `episode_id`

* **`episode_id`** (String)
* **`podcast_id`** (String): Tham chiếu `podcasts.podcast_id`.
* **`creator_id`** (String)
* **`title`** (String)
* **`description`** (String)
* **`audio_url`** (String): Link file MP3/M4A.
* **`duration_seconds`** (Integer): Độ dài âm thanh.
* **`size_bytes`** (Integer): Dung lượng file.
* **`cover_image_url`** (String): Ảnh bìa riêng (nếu có, không thì lấy của podcast cha).
* **`episode_number`** (Integer): Tập mấy.
* **`season_number`** (Integer): Mùa mấy.
* **`is_premium`** (Boolean): True nếu chỉ tập này tính phí.
* **`credit_cost`** (Integer): Số credit cần trả.
* **`transcript_url`** (String): File JSON hoặc VTT (Dành cho AI đọc và highlight chữ).
* **`ai_hosts`** (Array of Strings): ID của các AI Voices đã dùng trong tập này (Nếu là AI gen).
* **`listens_count`** (Integer): Số người nghe.
* **`likes_count`** (Integer): Số likes.
* **`published_at`** (Timestamp)

---

## 5. Danh Sách Nghe (Playlists Collection)
_Tạo bởi người dùng_

**Collection Name:** `playlists`
**Document ID:** `playlist_id`

* **`playlist_id`** (String)
* **`user_id`** (String)
* **`name`** (String)
* **`description`** (String)
* **`cover_image_url`** (String)
* **`is_public`** (Boolean)
* **`episodes`** (Array of Maps): 
  * `episode_id` (String)
  * `added_at` (Timestamp)
* **`created_at`** (Timestamp)

---

## 6. Lịch Sử / Tương Tác Của Người Dùng (Interactions)

### 6.1 Lịch sử nghe (Listening History)
**Collection Name:** `users/{user_id}/listening_history`
**Document ID:** `history_id`

* **`episode_id`** (String)
* **`podcast_id`** (String)
* **`progress_seconds`** (Integer): Thời gian đang nghe dở.
* **`is_completed`** (Boolean): `true` nếu đã nghe hết.
* **`listened_at`** (Timestamp): Lần nghe cuối.

### 6.2 Lịch sử giao dịch Credit (Credit Logs)
**Collection Name:** `users/{user_id}/credit_transactions`
**Document ID:** `transaction_id`

* **`amount`** (Integer): Số dương (nạp/tặng), Câm (tiêu xài).
* **`transaction_type`** (Enum/String): `purchase`, `subscription_reward`, `unlock_premium`, `ai_generation`.
* **`description`** (String): Diễn giải (ví dụ: "Unlock Episode Tội Phạm Băng Cốc").
* **`reference_id`** (String): ID hệ thống ngoài (ví dụ Stripe transaction ID hoặc Episode ID).
* **`created_at`** (Timestamp)

---

## 7. AI Resources (Giọng đọc AI)
_Danh sách các giọng đọc AI được hỗ trợ_

**Collection Name:** `ai_voices`
**Document ID:** `voice_id`

* **`voice_id`** (String)
* **`name`** (String)
* **`gender`** (String): `male`, `female`, `neutral`.
* **`language`** (String): `vi-VN`, `en-US`.
* **`provider`** (String): `google`, `elevenlabs`, `openai`.
* **`provider_voice_id`** (String): Mã ID bên cung cấp thứ 3.
* **`sample_audio_url`** (String): Link audio nghe thử.
* **`credit_cost_per_minute`** (Integer): Số credit trừ đi trên mỗi phút audio gen ra bằng giọng này.
* **`is_active`** (Boolean)
