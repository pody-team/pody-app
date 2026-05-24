#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use open qw(:std :encoding(UTF-8));

my $source = "BTL_MAD_Phase1.tex";
open my $fh, "<:encoding(UTF-8)", $source or die "Cannot read $source: $!";
my @lines = <$fh>;
close $fh;

sub slice_lines {
  my ($start, $end) = @_;
  return join("", @lines[($start - 1)..($end - 1)]);
}

my $common = slice_lines(1, 1110);

my @team = (
  {
    name => "Lại Xuân Hiếu",
    mssv => "B22DCCN309",
    work => "AI tạo podcast -- \\texttt{ai-service}, \\texttt{content-service}. Phụ trách luồng creator tạo podcast/show bằng AI, quản lý voice profiles, chat-create, production plan, job tạo show/episode, home feed, bookmark.",
  },
  {
    name => "Vũ Đức Thành",
    mssv => "B22DCCN801",
    work => "Báo và podcast báo -- \\texttt{article\\_service}, \\texttt{embedding\\_service}. Phụ trách crawl bài báo, category, tương tác bài viết, tạo podcast từ nhóm bài báo, embedding/search semantic, gán category ngữ nghĩa.",
  },
  {
    name => "Nguyễn Việt Huy",
    mssv => "B22DCCN393",
    work => "Hạ tầng và xác thực -- \\texttt{api-gateway}, \\texttt{identity-service}. Phụ trách cửa vào hệ thống, routing, JWT auth, đăng ký/đăng nhập, xác minh email, password reset, outbox event.",
  },
  {
    name => "Lê Minh Ngọc",
    mssv => "B22DCCN586",
    work => "Thông báo -- \\texttt{notification-service}. Phụ trách notification inbox, unread count, settings, email hệ thống, consume Kafka event, retry/DLQ, delivery logs.",
  },
);

my %members = (
  1 => {
    file => "BTL_MAD_TV1_AI_Content.tex",
    label => "Lại Xuân Hiếu -- AI tạo podcast",
    performer => "Lại Xuân Hiếu",
    mssv => "B22DCCN309",
    range => [1111, 1241],
    scope => "AI + Content",
    diagrams => "Component, ER, sequence tạo show, sequence nghe episode",
    summary => "Chat-create, production plan, generation job, show/episode, player/transcript, bookmark.",
    result => "Chat-create, production plan, job tạo show, ghi show/episode sang Content DB, home feed, show detail, episode detail, player transcript và bookmark.",
    evidence => "API AI/Content, AI DB, Content DB, màn hình create, My Shows, show detail và player.",
    tests => [
      ["AI", "Tạo production plan", "Trả plan hợp lệ với title, hosts và episode drafts.", "Plan được lưu trong AI DB khi provider sẵn sàng.", "Pass"],
      ["AI", "Tạo show từ production plan", "Tạo generation job và ghi show/episode sang Content DB.", "Job chạy nền, kết quả hiển thị ở My Shows/Home.", "Pass"],
      ["Content", "Xem home feed", "Trả danh sách show/episode published.", "Trả dữ liệu seed show và episode.", "Pass"],
      ["Content", "Xem episode detail", "Trả audio URL, transcript/assets nếu có.", "App mở player và thông tin episode.", "Pass"],
      ["Content", "Bookmark episode", "Lưu/bỏ lưu episode theo user.", "Bookmark được ghi nhận qua Content Service.", "Pass"],
    ],
    metrics => [
      ["Content categories", "6", "Seed trong \\texttt{content\\_service\\_demo\\_seed.sql}."],
      ["Content tags", "17", "Seed trong \\texttt{content\\_service\\_demo\\_seed.sql}."],
      ["Shows", "3", "Seed: Future Minds, True Crime Daily, Midnight Reset."],
      ["Episodes", "5", "Seed episode published cho Future Minds và True Crime Daily."],
      ["Show hosts", "3", "Seed AI host: Nova, Minh Tra, Lumi."],
      ["Voice profiles", "Chốt khi demo", "Schema đã có; số lượng phụ thuộc seed/runtime của AI flow."],
      ["Production plans/jobs", "Chốt khi demo", "Phát sinh khi creator chat và tạo show bằng AI."],
    ],
    limits => [
      "Luồng AI phụ thuộc API key, quota, latency và chất lượng phản hồi của provider.",
      "TTS, transcript alignment và upload audio cần chạy bất đồng bộ nên cần cơ chế theo dõi job chi tiết hơn.",
      "Cần bổ sung prompt versioning, evaluation và cache kết quả nếu triển khai production.",
    ],
  },
  2 => {
    file => "BTL_MAD_TV2_Article_Embedding.tex",
    label => "Vũ Đức Thành -- Báo và podcast báo",
    performer => "Vũ Đức Thành",
    mssv => "B22DCCN801",
    range => [1243, 1356],
    scope => "Article + Embedding",
    diagrams => "Component, ER, sequence article detail, sequence article podcast",
    summary => "Crawl/read article, reaction/comment/metric, article podcast job, CDC embedding, semantic search.",
    result => "Crawl/seed article, list/detail article, category, reaction/comment/metric, article podcast job, CDC embedding, category matching và semantic search.",
    evidence => "API Article/Embedding, Debezium/Kafka flow, Article DB, Embedding DB, màn hình news list/article detail.",
    tests => [
      ["Article", "Xem danh sách bài báo", "Trả list có category/stats.", "API trả article seed/crawl.", "Pass"],
      ["Article", "Xem chi tiết bài báo", "Tăng view count và trả detail.", "Article detail hiển thị nội dung và metadata.", "Pass"],
      ["Article", "Reaction/comment bài báo", "Ghi interaction/comment theo user.", "Dữ liệu được lưu qua Article Service.", "Pass"],
      ["Article Podcast", "Tạo podcast job", "Job queued/processing/completed và có asset khi xử lý xong.", "Job được tạo; audio phụ thuộc provider/key.", "Pass có điều kiện"],
      ["Embedding", "Search semantic", "Trả article liên quan theo vector similarity.", "Hoạt động khi embedding DB đã có vector.", "Pass có điều kiện"],
    ],
    metrics => [
      ["News sources", "3", "Seed: VnExpress, Thanh Nien, Tech Crunch."],
      ["Articles", "1+", "Seed một bài smoke test; crawler có thể bổ sung thêm khi chạy thật."],
      ["Article stats", "1+", "Seed view count cho article đầu tiên."],
      ["Article categories", "Theo taxonomy", "Seed trong schema Article Service."],
      ["Article podcast jobs", "Chốt khi demo", "Phát sinh khi user chọn bài và tạo job podcast."],
      ["Embedding documents/chunks", "Chốt khi demo", "Phát sinh sau CDC/embedding job cho article."],
    ],
    limits => [
      "Chất lượng search phụ thuộc chất lượng nội dung crawl, chunking và embedding model.",
      "Article podcast cần xử lý nền vì research, script, TTS và upload audio có độ trễ cao.",
      "CDC/category sync cần theo dõi idempotency và retry khi Kafka hoặc provider lỗi.",
    ],
  },
  3 => {
    file => "BTL_MAD_TV3_Gateway_Identity.tex",
    label => "Nguyễn Việt Huy -- Hạ tầng và xác thực",
    performer => "Nguyễn Việt Huy",
    mssv => "B22DCCN393",
    range => [1358, 1470],
    scope => "Gateway + Identity",
    diagrams => "Component, ER, sequence sign-up/verify, sequence protected route",
    summary => "Routing public/protected, JWT, sign-up/sign-in, Google sign-in, refresh, reset password, outbox event.",
    result => "API Gateway routing, public/protected route, JWT auth, sign-up/sign-in, Google sign-in, refresh token, forgot/reset password, profile và outbox event.",
    evidence => "Route metadata, Identity DB, outbox event, auth API, màn hình sign-up/sign-in/profile.",
    tests => [
      ["Auth", "Đăng ký tài khoản mới", "Tạo user, verification token và publish email event.", "Tạo user và ghi outbox event trong Identity DB.", "Pass"],
      ["Auth", "Đăng nhập user hợp lệ", "Trả access token và refresh token.", "API trả token, Gateway dùng token cho route protected.", "Pass"],
      ["Auth", "Refresh token", "Trả access token mới nếu refresh token hợp lệ.", "Token flow hoạt động qua public identity route.", "Pass"],
      ["Auth", "Forgot/reset password", "Tạo reset token và gửi email event.", "Outbox event được tạo để Notification Service xử lý.", "Pass"],
      ["Gateway", "Gọi API protected không token", "Gateway chặn request.", "Trả \\texttt{401 Unauthorized}.", "Pass"],
    ],
    metrics => [
      ["Identity users", "Chốt khi demo", "Phát sinh khi đăng ký/sign-in Google."],
      ["Auth sessions", "Chốt khi demo", "Phát sinh khi đăng nhập/refresh token."],
      ["Verification tokens", "Chốt khi demo", "Phát sinh khi đăng ký tài khoản mới."],
      ["Password reset tokens", "Chốt khi demo", "Phát sinh khi forgot password."],
      ["Outbox events", "Chốt khi demo", "Email verification/reset event chờ publish sang Kafka."],
      ["Gateway routes", "Nhiều nhóm route", "Route metadata tổng hợp public/protected routes qua \\texttt{/api/v1/\\_meta/routes}."],
    ],
    limits => [
      "Gateway mới tập trung vào routing/auth cơ bản cho demo, chưa có rate limiting nâng cao.",
      "Refresh token rotation, audit log và quản lý phiên có thể cần siết chặt hơn cho production.",
      "OAuth provider hiện mới ưu tiên Google; có thể mở rộng Apple/Facebook tùy yêu cầu.",
    ],
  },
  4 => {
    file => "BTL_MAD_TV4_Notification.tex",
    label => "Lê Minh Ngọc -- Thông báo",
    performer => "Lê Minh Ngọc",
    mssv => "B22DCCN586",
    range => [1472, 1582],
    scope => "Notification",
    diagrams => "Component, ER, sequence email event, sequence inbox/read",
    summary => "Inbox, unread count, settings, internal notification, email delivery, idempotency, retry/DLQ.",
    result => "Notification inbox, unread count, mark read/read all, settings, email verification/reset, internal notification, processed-event tracking và retry/DLQ contract.",
    evidence => "Notification DB, delivery log, Kafka consumer, internal notification API, màn hình notifications/settings.",
    tests => [
      ["Notification", "Xem danh sách thông báo", "Trả notification inbox theo user.", "API trả danh sách có phân trang.", "Pass"],
      ["Notification", "Xem unread count", "Trả số notification chưa đọc.", "API trả count theo user.", "Pass"],
      ["Notification", "Mark read", "Cập nhật trạng thái đã đọc.", "\\texttt{read\\_at}/is\\_read được cập nhật.", "Pass"],
      ["Notification", "Cập nhật settings", "Lưu cấu hình email/push/category notification.", "Settings được đọc/ghi qua Notification Service.", "Pass"],
      ["Email event", "Gửi email verification/reset", "Consume Kafka event, kiểm tra idempotency và ghi delivery log.", "Hoạt động khi Kafka/email sender sẵn sàng.", "Pass có điều kiện"],
    ],
    metrics => [
      ["Notifications", "Chốt khi demo", "Phát sinh từ seed inbox hoặc internal notification API."],
      ["Unread/read notifications", "Chốt khi demo", "Đếm theo trạng thái read/unread của user."],
      ["Notification settings", "Chốt khi demo", "Một bản settings theo user khi người dùng cập nhật."],
      ["Delivery logs", "Chốt khi demo", "Phát sinh khi gửi email verification/reset."],
      ["Processed events", "Chốt khi demo", "Theo dõi event đã xử lý để chống trùng."],
      ["Retry/DLQ records", "Chốt khi demo", "Phát sinh khi giả lập lỗi gửi email hoặc lỗi xử lý event."],
    ],
    limits => [
      "Email sender local/log chưa phản ánh đầy đủ deliverability thực tế.",
      "Push notification mobile, template management nâng cao và dashboard DLQ chưa hoàn thiện.",
      "Cần bổ sung quan sát delivery, retry và alerting nếu triển khai production.",
    ],
  },
);

sub apply_common_info {
  my ($tex, $m) = @_;

  $tex =~ s/\\textbf\{\\large TRƯỜNG ĐẠI HỌC CÔNG NGHỆ THÔNG TIN\}\\\\\[2pt\]\n\s*\\textbf\{\\large ĐẠI HỌC QUỐC GIA THÀNH PHỐ HỒ CHÍ MINH\}\\\\\[2pt\]\n\s*\\textbf\{\\large KHOA CÔNG NGHỆ PHẦN MỀM\}/\\textbf{\\large HỌC VIỆN CÔNG NGHỆ BƯU CHÍNH VIỄN THÔNG}\\\\[2pt]\n    \\textbf{\\large KHOA CÔNG NGHỆ THÔNG TIN}/;
  $tex =~ s/\n\s*\\textbf\{\\large POSTS AND TELECOMMUNICATIONS INSTITUTE OF TECHNOLOGY\}\\\\\[2pt\]//g;
  $tex =~ s/% Logo trường \(uncomment và thay đường dẫn nếu có\)\n\s*% \\includegraphics\[width=3cm\]\{logo_uit\.png\}/\\includegraphics[width=3.2cm]{assets\/logo_ptit.png}/;
  $tex =~ s/TP\. Hồ Chí Minh, 2026/Hà Nội, 2026/g;

  $tex =~ s/\\textbf\{Giảng viên hướng dẫn:\}\s*&\s*\\textit\{\(Điền tên GV hướng dẫn\)\}/\\textbf{Giảng viên hướng dẫn:} \& \\textit{ThS. Nguyễn Hoàng Anh}/;
  $tex =~ s/\\textbf\{Nhóm QLĐT:\}\s*&\s*\\textit\{\(Điền nhóm QLĐT\)\}/\\textbf{Nhóm QLĐT:}           \& \\textit{CNPM05}/;
  $tex =~ s/\\textbf\{Nhóm BTL:\}\s*&\s*\\textit\{\(Điền nhóm BTL\)\}/\\textbf{Nhóm BTL:}             \& \\textit{01}/;

  my $member_line = "\\textbf{Thành viên thực hiện:} & \\textit{$m->{performer} -- $m->{mssv}} \\\\[6pt]\n";
  $tex =~ s/      \\textbf\{Thành viên thực hiện:\} & \\textit\{[^}]+\} \\\\\[6pt\]\n/      $member_line/;
  $tex =~ s/(\\textbf\{Nhóm BTL:\}\s*&\s*\\textit\{01\}\s*\\\\\n)(?!\s*\\textbf\{Thành viên thực hiện:\})/$1      $member_line/;

  $tex =~ s/1 & \(Điền họ tên thành viên 1\) & \(MSSV\) \\\\/1 & $team[0]->{name} & $team[0]->{mssv} \\\\/;
  $tex =~ s/2 & \(Điền họ tên thành viên 2\) & \(MSSV\) \\\\/2 & $team[1]->{name} & $team[1]->{mssv} \\\\/;
  $tex =~ s/3 & \(Điền họ tên thành viên 3\) & \(MSSV\) \\\\/3 & $team[2]->{name} & $team[2]->{mssv} \\\\/;
  $tex =~ s/4 & \(Điền họ tên thành viên 4\) & \(MSSV\) \\\\/4 & $team[3]->{name} & $team[3]->{mssv} \\\\/;

  for my $i (0..3) {
    my $n = $i + 1;
    my $name = $team[$i]->{name};
    my $mssv = $team[$i]->{mssv};
    my $work = $team[$i]->{work};
    $tex =~ s/\\textit\{\(Thành viên $n\)\}\s*&\n\s*\\textit\{\(MSSV\)\}\s*&\n\s*Thành viên\s*&\n\s*.*?\s*&\n\s*25\\% \\\\/\\textit{$name} \&\n  \\textit{$mssv} \&\n  Thành viên \&\n  $work \&\n  25\\% \\\\/s;
  }

  $tex =~ s/Thành viên 1 -- AI tạo podcast/Lại Xuân Hiếu -- AI tạo podcast/g;
  $tex =~ s/Thành viên 2 -- Báo và podcast báo/Vũ Đức Thành -- Báo và podcast báo/g;
  $tex =~ s/Thành viên 3 -- Hạ tầng và xác thực/Nguyễn Việt Huy -- Hạ tầng và xác thực/g;
  $tex =~ s/Thành viên 4 -- Thông báo/Lê Minh Ngọc -- Thông báo/g;
  $tex =~ s/Thành viên 1 phụ trách/Lại Xuân Hiếu phụ trách/g;
  $tex =~ s/Thành viên 2 phụ trách/Vũ Đức Thành phụ trách/g;
  $tex =~ s/Thành viên 3 phụ trách/Nguyễn Việt Huy phụ trách/g;
  $tex =~ s/Thành viên 4 phụ trách/Lê Minh Ngọc phụ trách/g;
  $tex =~ s/^% ---- 3\.\d Thành viên \d ----\n//gm;

  return $tex;
}

sub latex_rows {
  my ($rows) = @_;
  my $out = "";
  for my $row (@$rows) {
    $out .= join(" & ", @$row) . " \\\\\n\\hline\n";
  }
  return $out;
}

sub phase3_summary {
  my ($m) = @_;
  return <<"TEX";

\\section{Tổng hợp đầu ra Phase 3}
\\label{sec:phase3-summary}

Bảng~\\ref{tab:phase3-output} tổng hợp đầu ra của phần cá nhân trong Chương 3.

\\begin{table}[H]
\\centering
\\caption{Tổng hợp đầu ra Phase 3 -- $m->{scope}}
\\label{tab:phase3-output}
\\renewcommand{\\arraystretch}{1.3}
\\scriptsize
\\begin{tabularx}{\\textwidth}{|l|X|X|}
\\hline
\\textbf{Cụm phụ trách} & \\textbf{Sơ đồ đã bổ sung} & \\textbf{Nội dung chính} \\\\
\\hline
$m->{scope} & $m->{diagrams} & $m->{summary} \\\\
\\hline
\\end{tabularx}
\\end{table}

\\vspace{1cm}
\\noindent\\rule{\\textwidth}{0.4pt}

\\noindent
\\textit{Kết thúc Phase 3 -- Thiết kế chi tiết cá nhân.}

TEX
}

sub chapter4 {
  my ($m) = @_;
  my $test_rows = latex_rows($m->{tests});
  my $metric_rows = latex_rows($m->{metrics});
  my $limit_items = join("", map { "  \\item $_\n" } @{$m->{limits}});
  return <<"TEX";
\\clearpage

% ============================================================
% CHƯƠNG 4 - KẾT QUẢ, THỬ NGHIỆM VÀ ĐÁNH GIÁ
% ============================================================
\\chapter{KẾT QUẢ, THỬ NGHIỆM VÀ ĐÁNH GIÁ}
\\label{chap:ket-qua}

Chương này tách rõ kết quả chung của nhóm và kết quả riêng của phần cá nhân: $m->{label}. Phần triển khai local được giữ ở mức tổng quát, còn bảng kết quả, kiểm thử và số liệu minh chứng tập trung vào cụm $m->{scope}.

\\section{Kết quả ứng dụng}
\\label{sec:ket-qua-ung-dung}

\\subsection{Kết quả tổng quát cấp nhóm}

Hệ thống đã được tổ chức theo kiến trúc microservices với Flutter App, API Gateway và các backend service độc lập. Các service chính có health check, tài liệu OpenAPI/Swagger, database riêng và có thể chạy local thông qua Docker Compose.

\\begin{table}[H]
\\centering
\\caption{Kết quả tổng quát cấp nhóm}
\\label{tab:ket-qua-tong-quat}
\\renewcommand{\\arraystretch}{1.3}
\\small
\\begin{tabularx}{\\textwidth}{|l|X|c|}
\\hline
\\textbf{Hạng mục} & \\textbf{Kết quả đạt được} & \\textbf{Trạng thái} \\\\
\\hline
Mobile app & Flutter App có các màn hình auth, home/show/episode, news/article, create AI, profile và notifications. & Đạt \\\\
\\hline
API Gateway & Điều phối request, tách route public/protected, kiểm tra JWT và proxy đến service đích. & Đạt \\\\
\\hline
Backend services & Identity, Content, AI, Article, Embedding và Notification được tách theo nghiệp vụ. & Đạt \\\\
\\hline
Database-per-service & Mỗi service có schema/database riêng, tham chiếu chéo qua external ID thay vì foreign key vật lý. & Đạt \\\\
\\hline
Event-driven & Kafka/Debezium hỗ trợ outbox email, CDC bài báo, category sync và xử lý bất đồng bộ. & Đạt \\\\
\\hline
Local deployment & Docker Compose khởi động infrastructure, database init, services, gateway, Kafka UI, Redis và MinIO. & Đạt \\\\
\\hline
\\end{tabularx}
\\end{table}

\\subsection{Kết quả theo phạm vi cá nhân}

\\begin{table}[H]
\\centering
\\caption{Kết quả cá nhân -- $m->{scope}}
\\label{tab:ket-qua-ca-nhan}
\\renewcommand{\\arraystretch}{1.3}
\\small
\\begin{tabularx}{\\textwidth}{|l|X|}
\\hline
\\textbf{Nội dung} & \\textbf{Kết quả} \\\\
\\hline
Cụm phụ trách & $m->{scope} \\\\
\\hline
Chức năng đã hoàn thành & $m->{result} \\\\
\\hline
Minh chứng chính & $m->{evidence} \\\\
\\hline
\\end{tabularx}
\\end{table}

\\section{Cài đặt và triển khai ứng dụng}
\\label{sec:cai-dat-trien-khai}

\\subsection{Yêu cầu môi trường}

\\begin{itemize}[leftmargin=2cm]
  \\item Docker và Docker Compose.
  \\item Flutter SDK để chạy mobile app.
  \\item File cấu hình môi trường cho các API key nếu chạy đầy đủ luồng AI/TTS/embedding.
  \\item Port local chưa bị chiếm: 8080, 8081, 8082, 8083, 8084, 8085, 8087, 8088, 5433, 5434, 6379, 8090, 9000 và 9001.
\\end{itemize}

\\subsection{Các bước triển khai local}

\\begin{enumerate}[leftmargin=2cm]
  \\item Kiểm tra Docker Desktop đã chạy.
  \\item Cấu hình biến môi trường cần thiết cho Gemini/GenAI, MinIO/GCS hoặc SMTP nếu muốn chạy đầy đủ tính năng bên thứ ba.
  \\item Khởi động toàn bộ hệ thống backend bằng Docker Compose.
  \\item Chờ các database init/migration hoàn tất và các service chuyển sang trạng thái healthy.
  \\item Đăng ký Debezium connector nếu connector chưa được đăng ký tự động.
  \\item Chạy Flutter App và trỏ base URL về API Gateway \\texttt{http://localhost:8080}.
  \\item Kiểm tra health check, docs và các luồng demo chính.
\\end{enumerate}

\\begin{lstlisting}[language=bash,caption={Lệnh chạy hệ thống local},label={lst:docker-compose-up}]
docker compose up --build
\\end{lstlisting}

\\subsection{URL kiểm tra nhanh}

\\begin{table}[H]
\\centering
\\caption{URL kiểm tra hệ thống sau khi khởi động}
\\label{tab:url-kiem-tra}
\\renewcommand{\\arraystretch}{1.3}
\\small
\\begin{tabularx}{\\textwidth}{|l|X|}
\\hline
\\textbf{Mục đích} & \\textbf{URL} \\\\
\\hline
Health check Gateway & \\texttt{http://localhost:8080/healthz} \\\\
\\hline
Tổng hợp docs & \\texttt{http://localhost:8080/docs} \\\\
\\hline
Route metadata & \\texttt{http://localhost:8080/api/v1/\\_meta/routes} \\\\
\\hline
Kafka UI & \\texttt{http://localhost:8090} \\\\
\\hline
MinIO Console & \\texttt{http://localhost:9001} \\\\
\\hline
\\end{tabularx}
\\end{table}

\\section{Kết quả thử nghiệm cá nhân}
\\label{sec:ket-qua-thu-nghiem}

\\begin{longtable}{|p{2.8cm}|p{4.0cm}|p{4.3cm}|p{3.0cm}|p{1.6cm}|}
\\caption{Bảng test case cá nhân -- $m->{scope}}
\\label{tab:test-case}\\\\
\\hline
\\textbf{Nhóm chức năng} & \\textbf{Test case} & \\textbf{Kết quả mong đợi} & \\textbf{Kết quả thực tế} & \\textbf{TT} \\\\
\\hline
\\endfirsthead
\\hline
\\textbf{Nhóm chức năng} & \\textbf{Test case} & \\textbf{Kết quả mong đợi} & \\textbf{Kết quả thực tế} & \\textbf{TT} \\\\
\\hline
\\endhead
$test_rows\\end{longtable}

\\section{Số liệu minh chứng trong CSDL}
\\label{sec:so-lieu-minh-chung}

\\begin{table}[H]
\\centering
\\caption{Số liệu demo cá nhân -- $m->{scope}}
\\label{tab:so-lieu-demo}
\\renewcommand{\\arraystretch}{1.3}
\\small
\\begin{tabularx}{\\textwidth}{|l|c|X|}
\\hline
\\textbf{Hạng mục} & \\textbf{Số lượng demo} & \\textbf{Nguồn/ghi chú} \\\\
\\hline
$metric_rows\\end{tabularx}
\\end{table}

\\section{Đánh giá hạn chế}
\\label{sec:han-che}

\\subsection{Hạn chế chung}

\\begin{itemize}[leftmargin=2cm]
  \\item Hệ thống hiện tối ưu cho demo/local, chưa hoàn thiện toàn bộ tiêu chuẩn production như autoscaling, backup, monitoring và alerting.
  \\item Database-per-service giúp tách service rõ ràng nhưng đòi hỏi quản lý consistency bằng event, idempotency và retry/DLQ cẩn thận.
\\end{itemize}

\\subsection{Hạn chế riêng của phần cá nhân}

\\begin{itemize}[leftmargin=2cm]
$limit_items\\end{itemize}

\\section{Định hướng phát triển}
\\label{sec:dinh-huong}

\\begin{enumerate}[leftmargin=2cm]
  \\item Hoàn thiện recommendation cá nhân hóa dựa trên lịch sử nghe/đọc, favorite categories và embedding similarity.
  \\item Bổ sung dashboard quản trị nội dung, nguồn tin, moderation comment và theo dõi chất lượng podcast tạo bằng AI.
  \\item Cải thiện AI pipeline với prompt versioning, evaluation, cache kết quả, multi-voice dialogue và kiểm duyệt nội dung tự động.
  \\item Triển khai production trên cloud với CI/CD, observability, log aggregation, backup database và secrets management.
  \\item Mở rộng notification sang push notification thực tế trên iOS/Android và template management cho nhiều loại email/in-app message.
\\end{enumerate}

\\section{Tài liệu tham khảo}
\\label{sec:tai-lieu-tham-khao}

\\begin{enumerate}[leftmargin=2cm]
  \\item Flutter documentation: \\texttt{https://docs.flutter.dev}
  \\item Go documentation: \\texttt{https://go.dev/doc}
  \\item FastAPI documentation: \\texttt{https://fastapi.tiangolo.com}
  \\item PostgreSQL documentation: \\texttt{https://www.postgresql.org/docs}
  \\item pgvector documentation: \\texttt{https://github.com/pgvector/pgvector}
  \\item Apache Kafka documentation: \\texttt{https://kafka.apache.org/documentation}
  \\item Debezium documentation: \\texttt{https://debezium.io/documentation}
  \\item Docker Compose documentation: \\texttt{https://docs.docker.com/compose}
  \\item Google GenAI/Gemini documentation.
  \\item Tài liệu nội bộ repository: README của từng service trong hệ thống Pody.
\\end{enumerate}

\\vspace{1cm}
\\noindent\\rule{\\textwidth}{0.4pt}

\\noindent
\\textit{Kết thúc bản báo cáo cá nhân -- $m->{label}.}

\\end{document}
TEX
}

for my $id (1, 2, 3, 4) {
  my $m = $members{$id};
  my ($start, $end) = @{$m->{range}};
  my $tex = $common . slice_lines($start, $end) . phase3_summary($m) . chapter4($m);
  $tex = apply_common_info($tex, $m);
  open my $out, ">:encoding(UTF-8)", $m->{file} or die "Cannot write $m->{file}: $!";
  print {$out} $tex;
  close $out;
  print "Wrote $m->{file}\n";
}
