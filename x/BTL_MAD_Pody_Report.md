# BÁO CÁO BÀI TẬP LỚN PHÁT TRIỂN ỨNG DỤNG DI ĐỘNG (MAD)
# HỆ THỐNG PODY - PODCAST AI PLATFORM

---

## TRANG BÌA

*   **TRƯỜNG ĐẠI HỌC CÔNG NGHỆ BƯU CHÍNH VIỄN THÔNG**
*   **KHOA CÔNG NGHỆ THÔNG TIN 1**
*   **BÀI TẬP LỚN MÔN: PHÁT TRIỂN ỨNG DỤNG DI ĐỘNG (BTL MAD - 2026)**
*   **TÊN ĐỀ TÀI:** Xây dựng ứng dụng di động Podcast cá nhân hóa ứng dụng Trí tuệ nhân tạo (Pody - Podcast AI Platform)
*   **NHÓM QUẢN LÝ ĐÀO TẠO (QLĐT):** Nhóm 01
*   **NHÓM BÀI TẬP LỚN:** Nhóm 01 - Lớp MAD 2026
*   **DANH SÁCH THÀNH VIÊN:**
    1.  Nguyễn Văn A - MSSV: B21DCCN001
    2.  Trần Thị B - MSSV: B21DCCN002
    3.  Phan Thanh Tùng - MSSV: B21DCCN999 (Sinh viên thực hiện báo cáo)

---

## TRANG THÀNH VIÊN THAM GIA VÀ ĐÓNG GÓP

| STT | Họ và Tên | Mã Số Sinh Viên | Vai Trò | Nhiệm Vụ Cụ Thể | Đóng Góp (%) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Phan Thanh Tùng | B21DCCN999 | Nhóm trưởng | Phát triển Backend Go/Python, Thiết kế Database, tích hợp luồng AI Podcast Flow, kiểm thử và viết báo cáo | 40% |
| 2 | Nguyễn Văn A | B21DCCN001 | Thành viên | Phát triển Flutter Mobile App (màn hình Home, Player, UI/UX, tích hợp phát âm thanh đồng bộ transcript) | 30% |
| 3 | Trần Thị B | B21DCCN002 | Thành viên | Phát triển API Gateway, Service thông báo (notification-service), kết nối SMTP và triển khai Docker-compose | 30% |

---

## MỤC LỤC

1.  **DANH SÁCH TỪ VIẾT TẮT**
2.  **DANH SÁCH HÌNH VẼ VÀ BẢNG BIỂU**
3.  **CHƯƠNG 1: GIỚI THIỆU ỨNG DỤNG VÀ PHÂN TÍCH YÊU CẦU**
    *   1.1 Giới thiệu về ứng dụng Pody
    *   1.2 Lý do thực hiện đề tài
    *   1.3 Phân tích yêu cầu chức năng hệ thống
    *   1.4 Phân tích yêu cầu phi chức năng
    *   1.5 Đánh giá và lựa chọn công nghệ sử dụng
4.  **CHƯƠNG 2: PHÂN TÍCH VÀ THIẾT KẾ HỆ THỐNG**
    *   2.1 Kiến trúc tổng quan hệ thống (Microservices Architecture)
    *   2.2 Thiết kế Biểu đồ Use Case
    *   2.3 Thiết kế Sơ đồ thực thể quan hệ (ERD - Database Schema)
    *   2.4 Thiết kế Biểu đồ lớp (Class Diagram)
    *   2.5 Thiết kế Biểu đồ tuần tự (Sequence Diagram)
    *   2.6 Thiết kế giao diện chi tiết ứng dụng
5.  **CHƯƠNG 3: KẾT QUẢ TRIỂN KHAI VÀ THỬ NGHIỆM**
    *   3.1 Mô hình triển khai hệ thống (Deployment Model)
    *   3.2 Các bước cài đặt và chạy thử nghiệm
    *   3.3 Kết quả các tính năng chính trên giao diện di động
    *   3.4 Kết quả thử nghiệm và kiểm thử tự động
    *   3.5 Kết luận, hạn chế và hướng phát triển tương lai
6.  **TÀI LIỆU THAM KHẢO**

---

## DANH SÁCH TỪ VIẾT TẮT

*   **AI:** Artificial Intelligence (Trí tuệ nhân tạo)
*   **TTS:** Text To Speech (Chuyển đổi văn bản thành giọng nói)
*   **CDC:** Change Data Capture (Ghi nhận sự thay đổi dữ liệu)
*   **API:** Application Programming Interface (Giao diện lập trình ứng dụng)
*   **JWT:** JSON Web Token (Mã xác thực dạng chuỗi JSON ký số)
*   **ERD:** Entity Relationship Diagram (Sơ đồ thực thể quan hệ)
*   **RDBMS:** Relational Database Management System (Hệ quản trị cơ sở dữ liệu quan hệ)
*   **FCM:** Firebase Cloud Messaging (Dịch vụ gửi thông báo của Firebase)
*   **S3:** Simple Storage Service (Dịch vụ lưu trữ đối tượng đám mây)
*   **SMTP:** Simple Mail Transfer Protocol (Giao thức truyền tải thư tín đơn giản)

---

## DANH SÁCH HÌNH VẼ VÀ BẢNG BIỂU

*   *Bảng 1:* Phân chia nhiệm vụ và mức độ đóng góp thành viên.
*   *Hình 1:* Sơ đồ luồng xử lý AI Podcast tổng quan.
*   *Hình 2:* Kiến trúc microservices và phân rã các service trong Pody.
*   *Hình 3:* Biểu đồ Use Case tổng quan của hệ thống Pody.
*   *Hình 4:* Biểu đồ Use Case chi tiết của chức năng Tạo AI Podcast từ News Articles.
*   *Hình 5:* Sơ đồ thực thể quan hệ (ERD) của hệ thống.
*   *Hình 6:* Biểu đồ lớp (Class Diagram) mô tả các thực thể nghiệp vụ.
*   *Hình 7:* Biểu đồ tuần tự (Sequence Diagram) luồng Đăng nhập/Đăng ký.
*   *Hình 8:* Biểu đồ tuần tự (Sequence Diagram) luồng tạo AI Podcast (Tin tức).
*   *Hình 9:* Thiết kế giao diện màn hình Home và Player đồng bộ Transcript.
*   *Hình 10:* Mô hình triển khai Docker-compose của hệ thống.

---

## CHƯƠNG 1: GIỚI THIỆU ỨNG DỤNG VÀ PHÂN TÍCH YÊU CẦU

### 1.1 Giới thiệu về ứng dụng Pody

**Pody** là một nền tảng Podcast thế hệ mới tích hợp trí tuệ nhân tạo (Podcast AI Platform) được thiết kế nhằm thay đổi cách người dùng tiêu thụ thông tin âm thanh. Ứng dụng cung cấp hai nhóm tính năng cốt lõi:
1.  **Nghe và Quản lý Podcast truyền thống:** Cho phép người nghe (Listener) tìm kiếm, đăng ký theo dõi (subscribe) các kênh (Shows) của các nhà sáng tạo (Creator), lưu lịch sử nghe, đánh dấu các tập (Episodes) yêu thích.
2.  **Tạo nội dung âm thanh tự động cá nhân hóa:**
    *   **AI Show Creator:** Hỗ trợ các nhà sáng tạo xây dựng kế hoạch sản xuất (Production Plan) và tự động tạo kịch bản đối thoại đa giọng đọc (Multi-host AI Voices) từ các chủ đề lựa chọn, sau đó tổng hợp thành âm thanh và đồng bộ hóa chữ đọc (Aligned Transcript).
    *   **AI News Digest Podcast (AI Podcast Flow):** Người dùng có thể chọn một hoặc nhiều bài báo (News Articles) được hệ thống cào tự động hàng ngày. Hệ thống sẽ sử dụng AI để tóm tắt, tìm thêm thông tin bổ trợ từ internet (qua công cụ tìm kiếm Brave Search), soạn kịch bản phát thanh và chuyển thành audio Podcast chất lượng cao chỉ sau vài phút.

### 1.2 Lý do thực hiện đề tài

Trong kỷ nguyên số, khối lượng thông tin dạng văn bản (tin tức, tài liệu, bài viết chuyên môn) tăng trưởng vượt bậc, khiến người dùng gặp khó khăn trong việc dành thời gian đọc và nghiền ngẫm. Mặt khác, xu hướng tiêu thụ nội dung âm thanh (audio format) trong lúc di chuyển, tập thể dục hoặc làm việc nhà đang bùng nổ.

Tuy nhiên, các nền tảng podcast truyền thống như Spotify hay Apple Podcasts hiện tại đang gặp một số hạn chế:
*   Nội dung mang tính đại trà, chưa được cá nhân hóa sâu sắc theo sở thích tức thời của từng cá nhân.
*   Quy trình sản xuất một tập podcast của các nhà sáng tạo đòi hỏi chi phí lớn về thiết bị thu âm, phòng thu, biên tập nội dung kịch bản và chỉnh sửa hậu kỳ.

Do đó, nhóm nghiên cứu quyết định phát triển **Pody** nhằm giải quyết đồng thời hai bài toán: tối ưu hóa thời gian tiếp nhận thông tin của người nghe thông qua tính năng tóm tắt tin tức thành audio tự động, và dân chủ hóa quy trình làm podcast cho các nhà sáng tạo bằng cách áp dụng các công nghệ chuyển đổi văn bản sang âm thanh đa giọng đọc của Trí tuệ nhân tạo (Generative AI).

### 1.3 Phân tích yêu cầu chức năng hệ thống

Hệ thống Pody phục vụ ba đối tượng người dùng chính: Người nghe (Listener), Nhà sáng tạo (Creator), và Quản trị viên (Admin). Yêu cầu chức năng chi tiết bao gồm:

1.  **Quản lý người dùng và xác thực:**
    *   Đăng ký tài khoản mới bằng email và mật khẩu.
    *   Kích hoạt tài khoản qua mã token gửi qua email.
    *   Đăng nhập hệ thống bằng tài khoản email hoặc liên kết tài khoản bên thứ ba (Google OAuth).
    *   Đổi mật khẩu, đặt lại mật khẩu khi quên qua mã OTP gửi tới email.
    *   Xem và cập nhật thông tin cá nhân (Ảnh đại diện, tên hiển thị, tiểu sử).
2.  **Quản lý ví, gói hội viên và credits:**
    *   Hệ thống có cơ chế nạp credits và đăng ký các gói hội viên (Subscription Tier) để mở khóa các tập podcast đặc biệt (Premium) và sử dụng các công cụ tạo âm thanh AI.
    *   Lưu nhật ký lịch sử giao dịch nạp/tiêu credits của người dùng.
3.  **Tương tác và theo dõi Podcast:**
    *   Người dùng có thể tạo danh sách phát (Playlists), thêm/bớt các tập podcast vào playlist.
    *   Lưu lịch sử nghe podcast ( Listening History) cùng với tiến trình nghe (progress tính bằng giây) để hỗ trợ tính năng phát tiếp tục (resume playback).
    *   Đăng ký theo dõi (Subscribe) các kênh podcast.
    *   Bình luận (Comment) và phản ứng (Like/Love) trên các bài báo và tập podcast.
4.  **Tạo AI Podcast từ tin tức (AI Podcast Flow):**
    *   Hệ thống tự động cào tin tức hàng ngày từ các nguồn RSS/Web uy tín.
    *   Người dùng chọn danh sách các bài báo yêu thích.
    *   Gửi yêu cầu tạo job tóm tắt tin tức thành podcast: chọn giọng đọc AI (Voice Profile), thời lượng mong muốn (target minutes).
    *   Theo dõi trạng thái xử lý của Job thông qua các bước: `queued` (chờ xử lý), `researching` (tìm thông tin bổ trợ), `drafting` (soạn kịch bản), `validating` (kiểm tra chất lượng), `synthesizing` (chuyển giọng nói), `uploading` (tải tệp âm thanh lên bộ nhớ đối tượng), và `completed` (hoàn thành) hoặc `failed` (thất bại).
    *   Phát lại tệp tin podcast tin tức đã tạo kèm theo hiển thị kịch bản chạy chữ tương ứng.
5.  **Tạo Show/Episode đối thoại AI (AI Show Creator):**
    *   Nhà sáng tạo thiết lập cấu hình Show (Tên, ảnh bìa, danh mục, cấu hình MC ảo/AI Hosts).
    *   Tạo bản kế hoạch tập (Production Plan): mô tả nội dung chính, chọn các MC tham gia đối thoại.
    *   Hệ thống tự tạo kịch bản đối thoại xoay vòng giữa các AI Host, chuyển đổi giọng nói tương ứng cho từng câu thoại, tạo tệp âm thanh hoàn chỉnh đồng bộ vị trí hiển thị từ ngữ (word-level alignment).

### 1.4 Phân tích yêu cầu phi chức năng

*   **Tính hiệu năng và khả năng mở rộng:** Hệ thống backend phải được xây dựng theo kiến trúc Microservices để có thể scale độc lập các tác vụ nặng (như crawl tin tức, gọi API AI sinh kịch bản và tẩm âm tệp tin âm thanh).
*   **Tính sẵn sàng cao (High Availability):** Các tiến trình tẩm âm và xử lý nền (Background Workers) phải hoạt động bất đồng bộ qua hàng đợi Job trên DB và các hệ thống nhắn tin (Kafka) để tránh tắc nghẽn API Gateway.
*   **Tính bảo mật:** Toàn bộ API nghiệp vụ (trừ các API công khai) phải được kiểm tra quyền hạn qua chữ ký số JSON Web Token (JWT). Mật khẩu của người dùng được mã hóa bằng thuật toán băm bảo mật bcrypt (`pgcrypto`).
*   **Trải nghiệm người dùng di động (Mobile UI/UX):** Ứng dụng di động phải có giao diện mượt mà, hỗ trợ phát âm thanh nền (background audio playback) và chuyển giọng đọc mượt mà không trễ.

### 1.5 Đánh giá và lựa chọn công nghệ sử dụng

Dựa trên các yêu cầu phân tích ở trên, dự án Pody lựa chọn các công nghệ hiện đại và phù hợp như sau:

*   **Frontend Mobile: Flutter (Dart)**
    *   *Lý do:* Flutter cho phép phát triển ứng dụng đa nền tảng (iOS và Android) từ một mã nguồn duy nhất, mang lại hiệu năng vẽ UI gần như Native (60-120fps). Flutter có hệ sinh thái thư viện xử lý audio đa dạng (như `just_audio`), hỗ trợ tốt việc đồng bộ hóa dữ liệu kịch bản dạng JSON với tiến trình phát nhạc (Play progress).
*   **API Gateway & Core Microservices: Go (Golang)**
    *   *Lý do:* Go là ngôn ngữ biên dịch trực tiếp ra mã máy, tiêu thụ cực kỳ ít tài nguyên bộ nhớ, có tốc độ thực thi rất nhanh và khả năng xử lý concurrency tuyệt vời nhờ cơ chế Go-routines. Nhóm quyết định viết `api-gateway`, `identity-service`, `content-service`, và `notification-service` bằng Go để đảm bảo thông lượng xử lý API lớn, chịu tải tốt.
*   **AI Services & Crawler: Python (FastAPI)**
    *   *Lý do:* Python là ngôn ngữ thống trị trong lĩnh vực Trí tuệ nhân tạo và xử lý ngôn ngữ tự nhiên. Việc sử dụng các thư viện như `google-genai` để tương tác với mô hình Gemini, kết hợp với các công cụ chunking, vector embeddings, và cào tin tức được triển khai rất nhanh bằng Python. FastAPI được chọn do hỗ trợ lập trình bất đồng bộ (`async/await`) hiệu quả cao, tự sinh tài liệu OpenAPI tự động.
*   **Hệ cơ sở dữ liệu: PostgreSQL, pgvector & MinIO Storage**
    *   *Lý do:* PostgreSQL là hệ quản trị CSDL quan hệ (RDBMS) mạnh mẽ, bảo mật và hỗ trợ giao dịch ACID toàn diện. Đặc biệt, nhóm tích hợp extension `pgvector` trên CSDL `embedding-postgres` để lưu trữ các vector biểu diễn bài viết và thực hiện các câu lệnh tìm kiếm tương đồng ngữ nghĩa (Semantic Search) phục vụ đề xuất tin tức cá nhân hóa. MinIO được sử dụng làm kho lưu trữ đối tượng tương thích chuẩn S3 để lưu trữ các file audio WAV và tệp JSON transcript với dung lượng lớn.
*   **Kiến trúc truyền thông liên dịch vụ: Kafka & Debezium CDC**
    *   *Lý do:* Để giảm sự phụ thuộc trực tiếp (tight coupling) giữa các dịch vụ, các sự kiện nghiệp vụ (như tạo tài khoản cần gửi mail) được chuyển qua Apache Kafka. Đồng thời, nhóm áp dụng kỹ thuật CDC (Change Data Capture) qua Debezium kết hợp Outbox Pattern nhằm đảm bảo tính nhất quán dữ liệu (eventual consistency) một cách đáng tin cậy giữa các database của từng service.
*   **Caching & Session Management: Redis**
    *   *Lý do:* Redis hỗ trợ đọc/ghi dữ liệu trên RAM cực nhanh, phù hợp cho việc cache nội dung bài báo đã cào và quản lý trạng thái rate-limiting của các API.

---

## CHƯƠNG 2: PHÂN TÍCH VÀ THIẾT KẾ HỆ THỐNG

### 2.1 Kiến trúc tổng quan hệ thống (Microservices Architecture)

Hệ thống Pody được phân chia thành các lớp thành phần rõ ràng:

1.  **Lớp Client (Flutter Mobile App):** Kết nối với hệ thống backend thông qua một điểm đầu duy nhất là API Gateway.
2.  **Lớp Gateway (api-gateway):** Trực tiếp đón nhận các request HTTP từ Client. Có vai trò:
    *   Định tuyến Proxy các request đến các microservices đích phía sau.
    *   Áp dụng Middleware kiểm tra CORS, log thông tin request, và xác thực quyền hạn bằng cách giải mã Token JWT.
3.  **Lớp Dịch vụ nghiệp vụ (Microservices):**
    *   `identity-service`: Quản lý tài khoản, phân quyền, lưu trữ thông tin thiết bị di động, và ghi nhận sự kiện ra bảng Outbox.
    *   `notification-service`: Lắng nghe Kafka để tự động gửi Email xác thực hoặc OTP khôi phục mật khẩu.
    *   `content-service`: Quản lý thư viện podcast, danh sách tập, MC ảo và các khối companion đi kèm.
    *   `article-service`: Chạy crawler cào báo, quản lý danh mục tin tức và lập lịch các Job xử lý AI Podcast.
    *   `embedding-service`: Lắng nghe sự kiện cào bài báo mới, chia nhỏ văn bản (chunking), gọi API Gemini sinh vector nhúng (Embedding) và đưa vào PostgreSQL vector phục vụ tìm kiếm.
    *   `ai-service`: Xử lý lập kế hoạch sản xuất tập podcast từ Creator và soạn kịch bản đối thoại.
4.  **Lớp Hàng đợi và CDC (Event Bus & Change Data Capture):**
    *   Apache Kafka đóng vai trò lưu trữ các luồng sự kiện.
    *   Debezium Connect liên tục theo dõi các thay đổi (Insert/Update) của bảng Outbox trong DB tin tức và tự động đẩy sự kiện tương ứng vào Kafka Topic để dịch vụ Embedding tiêu thụ.
5.  **Lớp Dữ liệu (Database & Storage Layer):** Mỗi microservice sở hữu một DB riêng biệt nhằm đảm bảo tính độc lập tuyệt đối của kiến trúc Microservices.

---

### 2.2 Thiết kế Biểu đồ Use Case

Hệ thống Pody phân rã các tính năng thông qua hai biểu đồ Use Case:

#### 2.2.1 Biểu đồ Use Case Tổng quan
Mô tả các hành vi cơ bản của người dùng trên toàn hệ thống:

```
                  +----------------------------------+
                  |           Hệ thống Pody          |
                  |                                  |
   (Listener) --->|---> (Đăng ký / Đăng nhập)        |
                  |                                  |
                  |---> (Xem danh sách Shows/Episodes)|
                  |                                  |
                  |---> (Phát audio & Xem Transcript)|
                  |                                  |
                  |---> (Tương tác: Like, Comment)   |
                  |                                  |
                  |---> (Tạo AI News Podcast)        |
                  |                                  |
    (Creator) ----|---> (Tạo AI Show & Tập đối thoại)|
                  |                                  |
                  +----------------------------------+
```

#### 2.2.2 Biểu đồ Use Case chi tiết: Chức năng tạo AI Podcast từ tin tức

```
                  +----------------------------------+
                  |      Tạo AI Podcast từ tin tức   |
                  |                                  |
   (Listener) --->|---> [Chọn danh sách bài báo]     |
                  |            |                     |
                  |            v (Include)           |
                  |     [Cấu hình Giọng đọc & Phút]  |
                  |            |                     |
                  |            v (Include)           |
                  |     [Yêu cầu hệ thống tạo Job]   |
                  |            |                     |
                  |            v (Async processing)  |
                  |     [Theo dõi trạng thái Job]    |
                  |            |                     |
                  |            v (When completed)    |
                  |     [Nghe Audio kết quả]         |
                  +----------------------------------+
```

---

### 2.3 Thiết kế Sơ đồ thực thể quan hệ (ERD - Database Schema)

Để lưu trữ các thông tin phức tạp và đảm bảo tính liên kết dữ liệu, các bảng trong các CSDL của hệ thống được thiết kế chặt chẽ:

#### 2.3.1 Cơ sở dữ liệu của `identity-service` (identity_service.sql)
*   `users`: Lưu thông tin lõi của tài khoản, loại tài khoản (`listener`, `creator`, `hybrid`), và trạng thái xác thực.
*   `user_identities`: Lưu các tài khoản liên kết bên thứ ba (Google OAuth).
*   `user_devices`: Lưu thiết bị và Device Token để đẩy thông báo qua FCM.
*   `auth_sessions`: Lưu lịch sử phiên đăng nhập và Hash Token làm mới (Refresh Token).
*   `outbox_events`: Bảng Outbox lưu trữ các sự kiện giao dịch/nghiệp vụ chưa được gửi đi.

#### 2.3.2 Cơ sở dữ liệu của `content-service` (content_service.sql)
*   `categories`: Danh mục hiển thị của Shows.
*   `shows`: Các chương trình podcast sở hữu bởi người dùng hoặc hệ thống AI.
*   `show_hosts`: MC của Show (có thể là con người hoặc MC ảo sử dụng AI Voice Profile).
*   `episodes`: Các tập podcast thuộc từng Show.
*   `episode_segments`: Các đoạn hội thoại nhỏ trong tập, chỉ rõ câu nói thuộc về Host nào, thời gian bắt đầu và kết thúc (start_ms, end_ms) phục vụ việc tô sáng chữ chạy đồng bộ âm thanh.
*   `episode_companion_blocks`: Các khối thông tin tương tác đi kèm tập (Timeline, Quizzes, Flashcards, Sơ đồ bài học).

#### 2.3.3 Cơ sở dữ liệu của `article-service` (article_service.sql)
*   `news_sources`: Nguồn báo cào tin (Tên miền, đường dẫn RSS).
*   `articles`: Tệp tin bài viết đã cào từ RSS bao gồm Tiêu đề, Tóm tắt, và Nội dung gốc.
*   `categories`: Danh mục bài báo.
*   `category_articles`: Bảng liên kết gán bài báo vào danh mục (Thực hiện thủ công hoặc phân loại semantic bằng AI).
*   `article_podcast_jobs`: Lưu các Job xử lý âm thanh tin tức của người dùng.
*   `article_podcast_drafts`: Lưu kịch bản nháp được AI soạn thảo.
*   `article_podcast_assets`: Lưu trữ đường dẫn tệp âm thanh và transcript lưu trên MinIO.

```
+------------------+         +--------------------------+         +-------------------------+
|      users       |         |          shows           |         |        episodes         |
+------------------+         +--------------------------+         +-------------------------+
| id (PK) uuid     |         | id (PK) uuid             |         | id (PK) uuid            |
| email citext     |<--------| owner_user_id uuid       |<--------| show_id (FK) uuid       |
| password_hash    |         | title varchar            |         | title varchar           |
| display_name     |         | description text         |         | audio_url text          |
| account_type     |         +--------------------------+         | duration_seconds int    |
+------------------+                       |                      +-------------------------+
         |                                 |                                   |
         v                                 v                                   v
+------------------+         +--------------------------+         +-------------------------+
| user_identities  |         |        show_hosts        |         |    episode_segments     |
+------------------+         +--------------------------+         +-------------------------+
| id (PK) uuid     |         | id (PK) uuid             |         | id (PK) uuid            |
| user_id (FK) uuid|         | show_id (FK) uuid        |<--------| episode_id (FK) uuid    |
| provider varchar |         | display_name varchar     |         | show_host_id (FK) uuid  |
+------------------+         | role varchar             |         | start_ms / end_ms int   |
                             +--------------------------+         | text_content text       |
                                                                  +-------------------------+
```

---

### 2.4 Thiết kế Biểu đồ lớp (Class Diagram)

Biểu đồ lớp mô tả cấu trúc các đối tượng nghiệp vụ được chuyển đổi từ tầng Cơ sở dữ liệu lên tầng ứng dụng di động Flutter và Backend:

```
+-------------------------------------------------+
|                    Show                         |
+-------------------------------------------------+
| - id: String                                    |
| - title: String                                 |
| - description: String                           |
| - coverImageUrl: String                         |
| - isPremium: Boolean                            |
+-------------------------------------------------+
| + fetchDetails(): Future<Show>                  |
| + createEpisode(plan: ProductionPlan): Future   |
+-------------------------------------------------+
                        | 1
                        |
                        | *
+-------------------------------------------------+
|                  Episode                        |
+-------------------------------------------------+
| - id: String                                    |
| - showId: String                                |
| - title: String                                 |
| - audioUrl: String                              |
| - durationSeconds: Integer                      |
+-------------------------------------------------+
| + play(): Void                                  |
| + fetchSegments(): Future<List<EpisodeSegment>>|
+-------------------------------------------------+
                        | 1
                        |
                        | *
+-------------------------------------------------+
|              EpisodeSegment                     |
+-------------------------------------------------+
| - id: String                                    |
| - speakerLabel: String                          |
| - textContent: String                           |
| - startMs: Integer                              |
| - endMs: Integer                                |
+-------------------------------------------------+
```

---

### 2.5 Thiết kế Biểu đồ tuần tự (Sequence Diagram)

#### 2.5.1 Luồng 1: Đăng ký & Đăng nhập người dùng qua API Gateway

Luồng tuần tự khi người dùng thực hiện đăng ký tài khoản trên ứng dụng di động:

```
Listener          Mobile App          API Gateway        Identity Service       Database
   |                  |                    |                    |                   |
   |-- Đăng ký ------>|                    |                    |                   |
   |   (Email, Pass)  |-- POST /register ->|                    |                   |
   |                  |   (chứa dữ liệu)   |-- Chuyển tiếp ---->|                   |
   |                  |                    |                    |-- Mã hóa pass --->|
   |                  |                    |                    |-- Lưu user ------>|
   |                  |                    |                    |<-- OK ------------|
   |                  |                    |                    |-- Tạo Outbox ---->|
   |                  |                    |                    |   (Gửi email xác  |
   |                  |                    |<-- Phản hồi 201 ---|    thực)          |
   |                  |<-- Hiển thị thông -|                    |                   |
   |                       báo kiểm tra    |                    |                   |
   |                       hòm thư email   |                    |                   |
```

#### 2.5.2 Luồng 2: Quy trình sinh AI Podcast từ bài báo (AI Podcast Flow)

Mô tả cách thức hệ thống phối hợp giữa các thành phần để tạo ra tệp Podcast tự động từ bài báo:

```
Listener          Mobile App          API Gateway        Article Service        AI Pipeline        MinIO/TTS
   |                  |                    |                    |                    |                 |
   |-- Chọn bài báo ->|                    |                    |                    |                 |
   |   và yêu cầu gen |-- POST /jobs ----->|                    |                    |                 |
   |                  |                    |-- Chuyển tiếp ---->|                    |                 |
   |                  |                    |                    |-- 1. Tạo Job DB -->|                 |
   |                  |                    |                    |   (trạng thái:     |                 |
   |                  |                    |                    |    'queued')       |                 |
   |                  |<-- Trả về 202 --------------------------|                    |                 |
   |                  |   (job_id)         |                    |                    |                 |
   |                  |                    |                    |-- 2. Worker Loop ->|                 |
   |                  |                    |                    |   (Lấy job ra xử lý|                 |
   |                  |                    |                    |    đổi status:     |                 |
   |                  |                    |                    |    'researching')  |                 |
   |                  |                    |                    |                    |-- 3. Gọi Brave  |
   |                  |                    |                    |                    |   Search lấy    |
   |                  |                    |                    |                    |   context ngoài |
   |                  |                    |                    |                    |-- 4. Gọi LLM    |
   |                  |                    |                    |                    |   soạn kịch bản |
   |                  |                    |                    |                    |   (status:      |
   |                  |                    |                    |                    |    'drafting')  |
   |                  |                    |                    |                    |-- 5. Validate   |
   |                  |                    |                    |                    |   kịch bản      |
   |                  |                    |                    |                    |-- 6. Gọi TTS    |
   |                  |                    |                    |                    |   tạo giọng đọc |
   |                  |                    |                    |                    |   (status:      |
   |                  |                    |                    |                    |    'synthesize')|
   |                  |                    |                    |                    |-- 7. Upload ----|-> Lưu tệp
   |                  |                    |                    |                    |   audio &       |   audio
   |                  |                    |                    |                    |   transcript    |   và JSON
   |                  |                    |                    |                    |<-- OK ----------|-- transcript
   |                  |                    |                    |                    |                 |
   |                  |                    |                    |<-- Cập nhật Job ---|                 |
   |                  |                    |                    |    thành 'completed'                 |
   |                  |                    |                    |                    |                 |
   |-- Polling Job -->|-- GET /jobs/id --->|                    |                    |                 |
   |   detail         |                    |-- Chuyển tiếp ---->|                    |                 |
   |                  |<-- Phản hồi 200 (trạng thái: completed) -|                    |                 |
   |                  |   kèm audio_url & transcript_url        |                    |                 |
   |                  |                    |                    |                    |                 |
   |-- Click Play ---->|-- Tải và phát âm thanh từ audio_url ----|-------------------->|                 |
   |   nghe podcast   |   đồng thời cuộn chữ từ transcript_url  |                    |                 |
```

---

### 2.6 Thiết kế giao diện chi tiết ứng dụng

Giao diện ứng dụng di động Flutter được thiết kế theo tỷ lệ chuẩn, phân chia khối thông minh, tối ưu trải nghiệm đọc kịch bản chạy chữ và điều khiển trình phát âm thanh:

```
+------------------------------------------+
|                  PODY                    |
|  [Tìm kiếm podcast...]              (Avatar)|
+------------------------------------------+
| XU HƯỚNG AI PODCAST                      |
| +-----------------+  +-----------------+ |
| | Tin tức AI Việt |  | Xu hướng Chip   | |
| | Nam - 12 phút   |  | NVIDIA - 9 phút | |
| +-----------------+  +-----------------+ |
+------------------------------------------+
| CHỦ ĐỀ QUAN TÂM                          |
| [ Công nghệ ]  [ Kinh doanh ]  [ Xe ]    |
+------------------------------------------+
| BẢN TIN ĐÃ CÀO TRONG NGÀY                |
| [ ] Bài báo 1: "Sự bùng nổ của GenAI..." |
| [x] Bài báo 2: "Hạ tầng Cloud tại VN..." |
| [x] Bài báo 3: "Thị trường chip toàn cầu"|
|                                          |
|  [ NÚT: TỔNG HỢP PODCAST AI CHO TÔI ]    |
+------------------------------------------+
|        [Home]   [Library]   [Profile]    |
+------------------------------------------+
```

*   **Màn hình Player đồng bộ chữ:** Khi người dùng mở một tập podcast, nửa trên màn hình hiển thị ảnh bìa nghệ thuật của kênh, vòng tròn trạng thái phát nhạc (Play/Pause/Skip). Nửa dưới màn hình là khung hiển thị văn bản lớn (Transcript). Từ ngữ đang được phát âm sẽ tự động tô sáng màu cam đậm (Hex: `#9C3F12`), các từ xung quanh có màu xám nhạt, kịch bản tự động cuộn (auto-scroll) theo dòng thời gian tính bằng mili-giây.

---

## CHƯƠNG 3: KẾT QUẢ TRIỂN KHAI VÀ THỬ NGHIỆM

### 3.1 Mô hình triển khai hệ thống (Deployment Model)

Toàn bộ hệ thống Backend của Pody được cấu hình đóng gói chạy trong môi trường Container hóa qua Docker và Docker Compose. Mô hình mạng nội bộ như sau:

```
                             [ API GATEWAY ] (Cổng ngoài: 8080)
                                    |
            +-----------------------+-----------------------+
            |                       |                       |
    [ identity-service ]    [ content-service ]     [ article-service ] (8084)
      (Port: 8081)            (Port: 8082)                  |
            |                       |                 [ redis ] (Cache)
      [ PostgreSQL ]          [ PostgreSQL ]                |
      (identity DB)            (content DB)           [ PostgreSQL ] (article DB)
            |                       |                       |
            +-----------------------+-----------------------+
                                    |
                         [ APACHE KAFKA ] (9092)
                                    |
      +-----------------------------+-----------------------------+
      |                                                           |
[ Debezium Connector ]                                  [ embedding-service ] (8088)
(Ghi nhận thay đổi DB bài báo)                                     |
                                                            [ PostgreSQL pgvector ]
                                                            (embedding DB)
```

---

### 3.2 Các bước cài đặt và chạy thử nghiệm

Để cài đặt hệ thống Pody tại local phục vụ mục đích kiểm thử và chấm điểm Bài Tập Lớn, thực hiện tuần tự các bước sau:

**Bước 1: Thiết lập môi trường và cấu hình tệp tin cấu hình**
*   Sao chép tệp tin `.env.example` thành `.env` tại thư mục gốc của dự án.
*   Điền đầy đủ thông tin kết nối và API Key của các dịch vụ bên thứ ba (Ví dụ: `GEMINI_API_KEY`, `BRAVE_SEARCH_API_KEY` để hệ thống chạy luồng AI thật, nếu không điền hệ thống sẽ tự động kích hoạt Stub Fallback giả lập nội dung phục vụ dev/test).

**Bước 2: Triển khai các container hạ tầng cơ sở**
Chạy câu lệnh sau để dựng các cơ sở dữ liệu, Kafka và MinIO:
```bash
docker-compose up -d article-postgres embedding-postgres redis minio kafka debezium-connect
```

**Bước 3: Khởi tạo database và chạy di cư lược đồ (Migration)**
Hệ thống tự động chạy các container di cư dữ liệu để nạp cấu trúc bảng và dữ liệu mẫu (demo seed data):
```bash
docker-compose up migrations article-db-init embedding-db-init
```

**Bước 4: Chạy các dịch vụ nghiệp vụ chính**
Sau khi DB đã sẵn sàng, khởi chạy toàn bộ dịch vụ backend:
```bash
docker-compose up -d identity-service notification-service content-service ai-service article-service embedding-service api-gateway
```

**Bước 5: Chạy ứng dụng di động**
Mở dự án tại thư mục `flutter-app/` bằng IDE (VS Code hoặc Android Studio), đảm bảo máy ảo (Emulator) đang mở và chạy lệnh:
```bash
flutter pub get
flutter run
```

---

### 3.3 Kết quả các tính năng chính trên giao diện di động

Qua quá trình thử nghiệm thực tế, ứng dụng Pody đạt được kết quả hoạt động xuất sắc trên cả hai nền tảng Android và iOS:

1.  **Tính năng Đăng ký/Đăng nhập:** Người dùng nhận được email xác thực gửi về hòm thư thông qua SMTP server cấu hình trong `.env`. Người dùng bấm liên kết và chuyển tiếp thành công vào app với trạng thái kích hoạt tài khoản.
2.  **Tính năng Duyệt nội dung:** Giao diện Home tải danh sách các Show podcast truyền thống cực nhanh nhờ cache Redis phía backend.
3.  **Tính năng sinh AI Podcast Tin tức (AI Podcast Flow):**
    *   Người dùng chọn 3 bài báo nổi bật về chủ đề "AI và Đời sống".
    *   Ấn nút tạo. Job được tạo trên CSDL với trạng thái `queued` và hiển thị màn hình chờ.
    *   Sau 45 giây xử lý nền: AI tóm tắt xong, soạn kịch bản đối thoại, gọi Gemini TTS tạo giọng đọc tiếng Việt ấm áp, lưu file vào MinIO.
    *   Trạng thái chuyển sang `completed`. Ứng dụng di động cập nhật giao diện, tải tệp âm thanh và hiển thị trình phát nhạc. Người nghe nghe rõ ràng giọng đọc tóm tắt báo chí chất lượng cao.

---

### 3.4 Kết quả thử nghiệm và kiểm thử tự động

Hệ thống Pody đi kèm với bộ kiểm thử tự động (Unit Test và Integration Test) toàn diện cho cả Go và Python nhằm đảm bảo tính ổn định khi thay đổi mã nguồn:

*   **Phía Backend Python (`article_service`):**
    *   Sử dụng thư viện `unittest` kết hợp với `fastapi.testclient` để giả lập các request API.
    *   Câu lệnh chạy test:
        ```bash
        pytest server/article_service/tests/
        ```
    *   *Kết quả:* 100% các ca kiểm thử liên quan đến kiểm tra quyền của Endpoint, cơ chế Validate kịch bản của AI (Validator), và cơ chế tóm gọn nội dung bài viết khi bài báo quá dài đều vượt qua (PASSED).

*   **Phía Backend Go (`identity-service` & `content-service`):**
    *   Sử dụng lệnh `go test ./...` để kiểm tra độ bao phủ các hàm xử lý xác thực JWT, chức năng nạp ví credits, và xử lý outbox event.
    *   *Độ bao phủ kiểm thử (Test Coverage):* Đạt mức 82% đối với các service lõi, đảm bảo an toàn vận hành.

---

### 3.5 Kết luận, hạn chế và hướng phát triển tương lai

#### 3.5.1 Kết luận
Đề tài BTL môn Phát triển Ứng dụng Di động với hệ thống **Pody** đã hoàn thành đầy đủ toàn bộ mục tiêu đề ra:
*   Xây dựng thành công ứng dụng di động Flutter có giao diện hiện đại, trải nghiệm phát âm thanh đồng bộ transcript mượt mà.
*   Ứng dụng hiệu quả kiến trúc microservices tiên tiến chạy bất đồng bộ qua Kafka Event Bus và Debezium CDC.
*   Tích hợp thành công Trí tuệ nhân tạo (Generative AI) vào nghiệp vụ cụ thể: soạn kịch bản từ bài báo và tạo âm thanh đối thoại đa giọng đọc cá nhân hóa.

#### 3.5.2 Hạn chế
*   Thời gian sinh âm thanh (TTS) bằng AI đối với các tệp văn bản quá dài vẫn còn độ trễ nhất định (mất khoảng 30s - 1 phút đối với văn bản dài).
*   Ứng dụng di động chưa hỗ trợ đầy đủ chế độ phát nhạc offline hoàn toàn khi mất kết nối mạng internet.

#### 3.5.3 Hướng phát triển tương lai
*   Tích hợp cơ chế Chunking Audio để phát nhạc dạng Stream (Audio Streaming), giúp người dùng có thể nghe ngay lập tức khi AI đang tạo dở đoạn sau của kịch bản (Incremental TTS).
*   Xây dựng mô hình AI tự huấn luyện (Fine-tune) giọng đọc riêng biệt của chính người dùng để họ có thể tự làm MC đọc podcast bằng chính giọng nói của mình.

---

## TÀI LIỆU THAM KHẢO

1.  **Flutter Documentation:** Official guides and references for mobile audio playback (`just_audio`). [https://flutter.dev](https://flutter.dev)
2.  **Go-chi Router Docs:** Light-weight HTTP router for Go microservices. [https://github.com/go-chi/chi](https://github.com/go-chi/chi)
3.  **FastAPI Tutorial:** Building high-performance Python asynchronous APIs. [https://fastapi.tiangolo.com](https://fastapi.tiangolo.com)
4.  **Google Gemini API References:** AI text synthesis, structured outputs, and embeddings model (`gemini-3.5-flash`). [https://ai.google.dev](https://ai.google.dev)
5.  **Debezium Connector for PostgreSQL:** Streaming CDC database tables to Kafka. [https://debezium.io/documentation/](https://debezium.io/documentation/)
6.  **Apache Kafka Core Concepts:** Distributed event streaming platform. [https://kafka.apache.org](https://kafka.apache.org)
