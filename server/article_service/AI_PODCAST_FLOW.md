# AI Podcast Flow Trong `article_service`

Tài liệu này giải thích chi tiết luồng `ai_podcast` trong `server/article_service` để bạn có thể:

- hiểu feature này dùng để làm gì
- biết request đi vào từ đâu
- biết job được xử lý như thế nào ở background
- map từng bước với code thật
- nhận ra các lưu ý và edge case quan trọng khi đọc code

## 1. Feature này dùng để làm gì?

`ai_podcast` là một feature cho phép user chọn một nhóm bài báo, sau đó hệ thống:

1. tạo một `job`
2. gom nội dung các bài báo đã chọn
3. tìm thêm context bên ngoài bằng search
4. tổng hợp ý chính
5. viết kịch bản podcast
6. validate kịch bản
7. gọi TTS để tạo audio
8. upload file audio + transcript lên MinIO
9. trả lại metadata để app có thể hiển thị và phát podcast

Điểm quan trọng: API không generate podcast ngay trong request/response. API chỉ tạo job và trả về trạng thái ban đầu là `queued`. Việc generate thực sự được xử lý bởi worker nền trong `AIPodcastRuntime`.

## 2. Entry point nằm ở đâu?

Luồng bắt đầu từ router:

- `server/article_service/ai_podcast/router.py`

Các endpoint chính:

- `POST /api/v1/article/podcast-jobs`: tạo job mới
- `GET /api/v1/article/podcast-jobs`: lấy danh sách job của user hiện tại
- `GET /api/v1/article/podcast-jobs/{job_id}`: lấy chi tiết một job

Router được mount vào API chung ở:

- `server/article_service/api.py`

Runtime background được khởi động khi app start ở:

- `server/article_service/main.py`

Trong `main.py`, ở startup event, app gọi:

- `initialize_ai_podcast_runtime()`

Hàm này sẽ start runtime, ensure bảng tồn tại, ensure bucket MinIO, và tạo worker loop nền.

## 3. Request tạo podcast đi như thế nào?

### 3.1 Request schema

Schema request ở:

- `server/article_service/ai_podcast/schemas.py`

`ArticlePodcastCreateRequest` nhận các field:

- `article_ids`: danh sách bài báo user chọn
- `voice`: tên voice cho TTS
- `target_minutes`: thời lượng mong muốn
- `language_code`: ngôn ngữ, mặc định là `vi`

### 3.2 Router -> Service

Ở `router.py`, endpoint `create_article_podcast_job()`:

1. lấy `auth_user`
2. resolve ra `user_id`
3. gọi `service.create_job(owner_user_id=user_id, request=request)`

### 3.3 Service -> Repository

Ở `server/article_service/ai_podcast/service.py`, `AIPodcastService.create_job()` chỉ làm 2 việc chính:

1. gọi repository để tạo job
2. chuyển một số lỗi domain thành HTTP error

Các lỗi quan trọng:

- `MissingSelectedArticlesError` -> `404`
- `NoRecommendedArticlesError` -> `400`

### 3.4 Repository tạo job như thế nào?

Code ở:

- `server/article_service/ai_podcast/repository.py`

`AIPodcastRepository.create_job()` xử lý theo 2 nhánh:

#### Nhánh A: user có truyền `article_ids`

1. chuẩn hóa list article id bằng `_normalize_article_ids()`
2. loại trùng
3. giữ tối đa 20 bài
4. load article từ DB
5. nếu thiếu bài nào thì raise `MissingSelectedArticlesError`

#### Nhánh B: user không truyền `article_ids`

Hệ thống tự load tối đa 20 bài recommended bằng `ArticleQueryRepository.list_articles_with_extra(...)`.

Nếu không có bài recommended nào, repository raise `NoRecommendedArticlesError`.

### 3.5 Dữ liệu được lưu lúc tạo job

Repository tạo:

- 1 record trong bảng `article_podcast_jobs`
- N record trong bảng `article_podcast_job_articles`

Các snapshot được lưu ngay lúc tạo job:

- `title_snapshot`
- `summary_snapshot`
- `sort_order`

Việc snapshot này giúp khi xem job detail vẫn biết user đã chọn bài gì tại thời điểm tạo job, ngay cả khi article gốc thay đổi sau đó.

## 4. Các bảng dữ liệu của feature này

Models nằm ở:

- `server/article_service/ai_podcast/models.py`

### 4.1 `article_podcast_jobs`

Bảng job chính, lưu:

- `id`
- `owner_user_id`
- `status`
- `voice`
- `target_minutes`
- `language_code`
- `error_message`
- `created_at`, `updated_at`
- `started_at`, `finished_at`

### 4.2 `article_podcast_job_articles`

Bảng mapping giữa job và article được chọn, lưu:

- `job_id`
- `article_id`
- `sort_order`
- `title_snapshot`
- `summary_snapshot`

### 4.3 `article_podcast_drafts`

Lưu kết quả text pipeline:

- `podcast_title`
- `podcast_description`
- `research_summary`
- `outline_json`
- `script_text`
- `source_pack_json`
- `related_sources_json`
- `validation_report_json`

### 4.4 `article_podcast_assets`

Lưu output media:

- `audio_url`
- `storage_key`
- `mime_type`
- `duration_seconds`
- `transcript_url`
- `transcript_storage_key`
- `metadata_json`

## 5. Worker nền chạy như thế nào?

Code nằm trong:

- `server/article_service/ai_podcast/service.py`

Class quan trọng là `AIPodcastRuntime`.

### 5.1 Runtime được khởi tạo với những gì?

Trong `AIPodcastRuntime.__init__()` runtime tạo sẵn:

- `text_provider`
- `tts_provider`
- `search_tool`
- `storage`

Tất cả đều dựa trên config trong:

- `server/article_service/ai_podcast/config.py`

### 5.2 Khi start runtime

`start()` sẽ:

1. `ensure_tables()`
2. `storage.ensure_bucket()`
3. tạo `asyncio` worker task chạy `_worker_loop()`

Lưu ý: bảng của feature này không thấy được tạo bằng SQL migration riêng trong `server/sql`; thay vào đó runtime tự `create(..., checkfirst=True)` khi app startup.

### 5.3 Worker loop làm gì?

`_worker_loop()` chạy lặp:

1. mở DB session mới
2. gọi `repository.claim_next_job_id()`
3. nếu chưa có job phù hợp thì sleep theo `worker_poll_interval_seconds`
4. nếu có job thì gọi `_process_job(...)`

`claim_next_job_id()` hiện pick job theo `created_at asc()` và chấp nhận cả các trạng thái:

- `queued`
- `researching`
- `drafting`
- `validating`
- `synthesizing`
- `uploading`

Điều này cho thấy worker được thiết kế hơi theo hướng “resume job chưa hoàn tất”, không chỉ riêng `queued`.

## 6. Luồng xử lý thật của một job

Đây là phần quan trọng nhất. Tất cả nằm trong:

- `server/article_service/ai_podcast/service.py`
- method: `AIPodcastRuntime._process_job(...)`

Luồng thực tế:

### Bước 1: Load processing bundle

Runtime gọi:

- `repository.get_processing_bundle(job_id=job_id)`

Bundle trả về gồm:

- `job`
- `selected_articles`

Mỗi article trong `selected_articles` có:

- `article_id`
- `title`
- `summary`
- `content`
- `original_url`
- `published_at`

Nguồn dữ liệu này lấy từ bảng `articles` thật, không phải chỉ từ snapshot.

### Bước 2: Chuyển trạng thái sang `researching`

Runtime gọi:

- `repository.update_job_status(status="researching")`

Khi status lần đầu vào `researching`, repository set luôn `started_at`.

### Bước 3: Build research pack

Code ở:

- `server/article_service/ai_podcast/pipeline/research.py`

`build_research_pack(...)` làm các việc sau:

1. rút ra `topic_hint` từ title/summary của 1-2 bài đầu tiên
2. cắt ngắn query nếu quá dài
3. gọi search tool với query dạng:
   `boi canh moi nhat va xu huong lien quan den {topic_hint}`
4. gom kết quả search external
5. tạo `ResearchPack`

`ResearchPack` gồm:

- `primary_sources`: các bài báo được chọn
- `external_context_sources`: nguồn ngoài từ search
- `research_summary`: mô tả ngắn về bộ dữ liệu research

Nếu Brave Search không cấu hình hoặc call lỗi:

- hệ thống không fail ngay
- chỉ log warning
- external sources sẽ rỗng
- research summary sẽ ghi chú rằng external research unavailable

Nói cách khác, search ngoài là phần bổ sung context, không phải hard dependency bắt buộc để pipeline chạy tiếp.

### Bước 4: Chuyển trạng thái sang `drafting`

Runtime gọi:

- `repository.update_job_status(status="drafting")`

### Bước 5: Synthesis

Code ở:

- `server/article_service/ai_podcast/pipeline/synthesis.py`

Hàm `build_synthesis(...)` chỉ gọi:

- `text_provider.synthesize(...)`

Input là `research_pack.model_dump(...)`.

Output là `SynthesisDraft`, gồm:

- `topic`
- `key_insights`
- `overlap_points`
- `external_context`
- `research_summary`

Ý nghĩa của bước này:

- chưa viết thành script hoàn chỉnh
- mới tổng hợp “đọc hiểu” từ source để chuẩn bị cho bước script writing

### Bước 6: Script writing

Code ở:

- `server/article_service/ai_podcast/pipeline/script_writer.py`

`build_script(...)` gọi:

- `text_provider.write_script(...)`

Input gồm:

- `research_pack`
- `synthesis`
- `target_minutes`
- `language_code`

Output là `ScriptDraft`, gồm:

- `podcast_title`
- `podcast_description`
- `outline`
- `script_text`

### Bước 7: Chuyển trạng thái sang `validating`

Runtime gọi:

- `repository.update_job_status(status="validating")`

### Bước 8: Validate script

Code ở:

- `server/article_service/ai_podcast/pipeline/validator.py`

`validate_script(...)` check:

- title có rỗng không
- script có rỗng không
- outline có rỗng không

Ngoài ra còn tính:

- `word_count`
- `estimated_duration_seconds`

Và sinh warning nếu:

- script có vẻ ngắn hơn target
- script có vẻ lặp lại bất thường

Nếu validation không hợp lệ (`valid == False`) thì runtime raise exception và job chuyển sang `failed`.

### Bước 9: Lưu draft xuống DB

Nếu validation pass, runtime gọi:

- `repository.save_draft(...)`

Đây là lúc toàn bộ output text pipeline được persist:

- title
- description
- research summary
- outline
- script text
- source pack
- external related sources
- validation report

Điểm hay ở đây là bạn có thể debug lại khá tốt chỉ bằng DB vì gần như toàn bộ text artifact đã được lưu.

### Bước 10: Chuyển trạng thái sang `synthesizing`

Runtime gọi:

- `repository.update_job_status(status="synthesizing")`

### Bước 11: Tạo audio bằng TTS

Code ở:

- `server/article_service/ai_podcast/pipeline/audio_worker.py`
- `server/article_service/ai_podcast/providers/tts_generation.py`

`synthesize_audio(...)` chỉ bọc một call đến:

- `tts_provider.synthesize(script_text=..., voice=..., language_code=...)`

Output là `AudioArtifact` gồm:

- `audio_bytes`
- `duration_seconds`
- `transcript_json`
- `mime_type`

### Bước 12: Chuyển trạng thái sang `uploading`

Runtime gọi:

- `repository.update_job_status(status="uploading")`

### Bước 13: Upload lên MinIO

Code ở:

- `server/article_service/ai_podcast/storage/minio_store.py`

Object key được build theo format:

- `{owner_user_id}/{job_id}/{slugify(podcast_title)}/podcast.wav`
- `{owner_user_id}/{job_id}/{slugify(podcast_title)}/transcript.json`

Sau khi upload xong, runtime gọi:

- `repository.save_asset(...)`

để lưu:

- `audio_url`
- `storage_key`
- `mime_type`
- `duration_seconds`
- `transcript_url`
- `transcript_storage_key`
- metadata như `voice` và `bucket`

### Bước 14: Hoàn tất

Runtime gọi:

- `repository.update_job_status(status="completed")`

Nếu có exception ở bất kỳ bước nào trong `_process_job()`:

- job chuyển sang `failed`
- `error_message` được lưu
- `finished_at` được set

## 7. Provider hoạt động như thế nào?

## 7.1 Text provider

Code ở:

- `server/article_service/ai_podcast/providers/text_generation.py`

Có 2 chế độ chính:

- `GoogleGenAITextGenerationProvider`
- `StubTextGenerationProvider`

`build_text_generation_provider(settings)` chọn provider theo config.

### Google provider

Nếu `use_google_provider == True`:

- gọi `google.genai`
- prompt dùng template ở `ai_podcast/prompts/templates.py`
- bước synthesis dùng `RESEARCH_SUMMARY_PROMPT`
- bước script writing dùng `SCRIPT_WRITER_PROMPT`

Response text được parse JSON bằng `_parse_json_response(...)`.

Nếu parse lỗi:

- fallback sang output của stub provider

### Stub provider

Nếu không có Google provider, hệ thống vẫn chạy được bằng stub:

- synthesize: tạo summary giả lập từ titles
- write_script: tạo một script deterministic dựa trên topic, số lượng bài, key insights

Điều này rất hữu ích cho local dev và test, vì pipeline vẫn chạy end-to-end mà không cần AI thật.

## 7.2 TTS provider

Code ở:

- `server/article_service/ai_podcast/providers/tts_generation.py`

Cũng có 2 mode:

- `GoogleGenAITTSGenerationProvider`
- `StubTTSGenerationProvider`

### Google TTS

Nếu Google client khả dụng:

- gửi prompt `TTS_STYLE_PROMPT + script_text`
- yêu cầu response modality là `AUDIO`
- build speech config từ `voice` và `language_code`

Audio raw PCM sẽ được convert sang WAV bằng `_pcm16_to_wav(...)`.

### Stub TTS

Nếu không có Google TTS:

- tạo một WAV giả bằng dữ liệu im lặng
- duration được estimate từ word count
- transcript hiện là JSON rỗng `{"segments":[]}`

Tức là local/test mode vẫn có `audio_url` thật sau khi upload, nhưng nội dung audio chỉ là file WAV giả lập.

## 8. Search ngoài hoạt động như thế nào?

Code ở:

- `server/article_service/ai_podcast/pipeline/research.py`

Search tool có 2 loại:

- `BraveSearchTool`
- `DisabledSearchTool`

`build_search_tool(...)` sẽ:

- nếu có `BRAVE_SEARCH_API_KEY` -> dùng Brave Search thật
- nếu không có -> dùng disabled tool trả về results rỗng

Vì vậy pipeline không phụ thuộc cứng vào Brave Search.

## 9. MinIO storage hoạt động như thế nào?

Code ở:

- `server/article_service/ai_podcast/storage/minio_store.py`

Store chỉ `enabled` khi đủ các điều kiện:

- import được thư viện `minio`
- có endpoint
- có access key
- có secret key
- có public base URL

Nếu thiếu cấu hình MinIO:

- `ensure_bucket()` sẽ bỏ qua
- nhưng đến bước `upload_audio()` thì runtime sẽ fail với lỗi:
  `article podcast minio storage is not configured`

Nghĩa là pipeline vẫn đi qua research, drafting, validating, synthesize, nhưng sẽ fail ở bước upload nếu storage chưa sẵn sàng.

## 10. Client app dùng API này như thế nào?

Phía Flutter gọi API ở:

- `flutter-app/lib/data/article_service.dart`

Các hàm tương ứng:

- `createPodcastJob(...)`
- `fetchPodcastJobs()`
- `fetchPodcastJobDetail(jobId)`

Flow phía app là:

1. tạo job
2. poll hoặc mở màn hình chi tiết job
3. đọc status
4. khi `completed` thì dùng `audio_url` để phát lại

## 11. Trạng thái job và ý nghĩa

Các status xuất hiện trong code:

- `queued`: vừa tạo xong, chờ worker xử lý
- `researching`: đang gom source + context ngoài
- `drafting`: đang tổng hợp và viết script
- `validating`: đang check draft
- `synthesizing`: đang tạo audio
- `uploading`: đang upload audio/transcript
- `completed`: hoàn tất
- `failed`: lỗi ở một bước nào đó

## 12. Những điểm dễ nhầm hoặc đáng chú ý khi đọc code

### 12.1 `target_minutes` từ request hiện không thực sự được dùng

Trong `ArticlePodcastCreateRequest` có field `target_minutes`, và Flutter cũng gửi field này lên.

Nhưng trong `AIPodcastRepository.create_job()`:

- `target_minutes` của job được set bằng `_derive_target_minutes(len(articles))`
- không dùng giá trị `request.target_minutes`

Tức là thời lượng hiện tại phụ thuộc vào số article thực tế sau khi normalize, không phụ thuộc vào lựa chọn của client.

Ví dụ:

- 20 bài -> khoảng 12 phút
- 15 bài -> khoảng 9 phút
- ít bài -> tối thiểu 2 phút

### 12.2 Tạo job không commit ngay trong repository

Repository gọi `session.add(...)` và `flush()`, không tự commit. Commit phụ thuộc vòng đời session của request. Đây là pattern bình thường nếu app đang quản lý transaction ở layer cao hơn, nhưng khi debug cần nhớ điều này.

### 12.3 Worker có thể pick cả job đang dở dang

`claim_next_job_id()` không chỉ lấy `queued` mà còn lấy luôn các status đang xử lý dở. Điều này có thể hữu ích để resume, nhưng cũng là điểm cần để ý nếu sau này muốn chống reprocessing hoặc scale nhiều worker.

### 12.4 Search ngoài là optional

Thiếu Brave Search không làm job fail. Hệ thống vẫn chạy tiếp với `external_context_sources = []`.

### 12.5 AI thật cũng là optional

Thiếu Google GenAI hoặc package client:

- text generation fallback sang stub
- TTS fallback sang WAV giả lập

Nên local environment vẫn chạy được end-to-end.

### 12.6 MinIO là điểm fail cứng ở cuối pipeline

Nếu storage không cấu hình đầy đủ, job sẽ fail ở bước upload. Đây là dependency bắt buộc để ra kết quả usable.

### 12.7 Job detail trộn dữ liệu snapshot và artifact đã generate

Khi gọi `GET /podcast-jobs/{job_id}`, response trả ra:

- selected article snapshots
- research summary
- title/description
- outline
- script text
- audio url
- duration
- error

Điều này khiến endpoint detail gần như là “full debug view” của pipeline.

## 13. Map nhanh từ flow sang file code

Nếu muốn đọc code theo đúng luồng, nên mở theo thứ tự này:

1. `server/article_service/ai_podcast/router.py`
2. `server/article_service/ai_podcast/service.py`
3. `server/article_service/ai_podcast/repository.py`
4. `server/article_service/ai_podcast/models.py`
5. `server/article_service/ai_podcast/pipeline/research.py`
6. `server/article_service/ai_podcast/pipeline/synthesis.py`
7. `server/article_service/ai_podcast/pipeline/script_writer.py`
8. `server/article_service/ai_podcast/pipeline/validator.py`
9. `server/article_service/ai_podcast/pipeline/audio_worker.py`
10. `server/article_service/ai_podcast/providers/text_generation.py`
11. `server/article_service/ai_podcast/providers/tts_generation.py`
12. `server/article_service/ai_podcast/storage/minio_store.py`
13. `server/article_service/ai_podcast/config.py`
14. `server/article_service/main.py`

## 14. Tóm tắt 1 câu dễ nhớ

`ai_podcast` trong `article_service` là một pipeline background kiểu job-based: API tạo job, worker nền lấy job ra, tổng hợp bài báo + context ngoài, viết script, validate, TTS, upload asset, rồi trả kết quả qua các endpoint list/detail.

## 15. Nếu bạn muốn đọc sâu hơn nữa

Có 3 hướng đọc tiếp rất đáng giá:

- đọc `server/article_service/tests/test_ai_podcast_routes.py` để thấy behavior mong muốn
- đọc `flutter-app/lib/data/article_service.dart` để hiểu app gọi API nào
- chạy thật một job rồi inspect 4 bảng `article_podcast_*` để thấy artifact được lưu ra sao
