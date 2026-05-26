package httpserver

import (
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/promex04/pody/server/api-gateway/internal/config"
)

// metaResponse đại diện cho định dạng dữ liệu trả về thông tin metadata của Gateway.
type metaResponse struct {
	Name   string                `json:"name"`
	Status string                `json:"status"`
	Routes []config.ServiceRoute `json:"routes"`
}

// resetPasswordBridgeTemplate là giao diện web trung gian hướng dẫn người dùng quay lại ứng dụng di động Pody để đặt lại mật khẩu.
// Sử dụng Deep Link (pody://reset-password) để mở ứng dụng di động.
var resetPasswordBridgeTemplate = template.Must(template.New("reset-password-bridge").Parse(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Open Pody</title>
    <style>
      body { font-family: Georgia, serif; margin: 0; background: #f7f3eb; color: #1f1b16; }
      .wrap { max-width: 720px; margin: 0 auto; padding: 32px 20px 48px; }
      .card { background: #fffdf8; border: 1px solid #d8cab7; border-radius: 20px; padding: 24px; box-shadow: 0 16px 40px rgba(31, 27, 22, 0.08); }
      .eyebrow { color: #9c3f12; font-size: 13px; text-transform: uppercase; letter-spacing: 0.08em; font-weight: 700; }
      .button { display: inline-block; background: #9c3f12; color: #fffdf8; padding: 14px 20px; border-radius: 12px; text-decoration: none; font-weight: 700; }
      .button:hover { opacity: 0.92; }
      code { background: #f2e7d5; padding: 2px 6px; border-radius: 6px; word-break: break-all; }
      .copy { margin-top: 16px; background: #f2e7d5; border: none; padding: 10px 14px; border-radius: 10px; cursor: pointer; }
      .steps { margin: 20px 0 0; padding: 0 0 0 20px; color: #4f463d; }
      .steps li { margin-bottom: 8px; line-height: 1.5; }
      p { line-height: 1.6; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="card">
        <p class="eyebrow">Password reset</p>
        <h1>Quay lại Pody để đặt mật khẩu mới</h1>
        <p>Chạm vào nút bên dưới để mở lại ứng dụng và hoàn tất việc đổi mật khẩu. Nếu ứng dụng chưa mở, bạn vẫn có thể sao chép token và dán thủ công.</p>
        <p><a class="button" href="{{.AppURL}}">Mở Pody</a></p>
        <ul class="steps">
          <li>Ứng dụng sẽ mở thẳng vào màn đặt lại mật khẩu.</li>
          <li>Nếu chưa mở được app, hãy sao chép token bên dưới.</li>
          <li>Dán token vào màn reset password trong Pody và nhập mật khẩu mới.</li>
        </ul>
        <p>Nếu ứng dụng không mở tự động, bạn có thể sao chép token này:</p>
        <p><code id="reset-token">{{.Token}}</code></p>
        <button class="copy" type="button" onclick="copyToken()">Sao chép token</button>
      </div>
    </div>
    <script>
      const appUrl = "{{.AppURLString}}";
      setTimeout(() => { window.location.href = appUrl; }, 250);
      async function copyToken() {
        const token = document.getElementById('reset-token').textContent;
        if (navigator.clipboard && token) {
          await navigator.clipboard.writeText(token);
          alert('Đã sao chép token.');
        }
      }
    </script>
  </body>
</html>`))

// verifyEmailBridgeTemplate là giao diện web trung gian gọi API của Identity Service từ trình duyệt để xác thực email,
// sau đó cung cấp nút để mở ứng dụng di động đăng nhập.
var verifyEmailBridgeTemplate = template.Must(template.New("verify-email-bridge").Parse(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Verify Your Email</title>
    <style>
      body { font-family: Georgia, serif; margin: 0; background: #f7f3eb; color: #1f1b16; }
      .wrap { max-width: 720px; margin: 0 auto; padding: 32px 20px 48px; }
      .card { background: #fffdf8; border: 1px solid #d8cab7; border-radius: 20px; padding: 24px; box-shadow: 0 16px 40px rgba(31, 27, 22, 0.08); }
      .eyebrow { color: #9c3f12; font-size: 13px; text-transform: uppercase; letter-spacing: 0.08em; font-weight: 700; }
      .button { display: inline-block; background: #9c3f12; color: #fffdf8; padding: 14px 20px; border-radius: 12px; text-decoration: none; font-weight: 700; }
      .button.secondary { background: #f2e7d5; color: #1f1b16; }
      .actions a { margin-right: 12px; margin-bottom: 12px; }
      .status { display: inline-flex; align-items: center; gap: 8px; border-radius: 999px; padding: 8px 12px; font-size: 13px; font-weight: 700; background: #f2e7d5; color: #5a4731; }
      .status.success { background: #dff6ea; color: #16663b; }
      .status.error { background: #fde6de; color: #8d2f12; }
      p { line-height: 1.6; }
      .hint { color: #5b5348; }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="card">
        <p class="eyebrow">Email verification</p>
        <div id="status" class="status">Đang xác thực email của bạn...</div>
        <h1 id="title">Đợi một chút nhé</h1>
        <p id="message">Pody đang kiểm tra liên kết xác thực này để kích hoạt tài khoản của bạn.</p>
        <div class="actions">
          <a class="button" href="{{.AppURL}}">Mở Pody để đăng nhập</a>
          <a class="button secondary" href="{{.VerifyURL}}">Thử xác thực trực tiếp</a>
        </div>
        <p class="hint">Nếu bạn đã xác thực thành công rồi, chỉ cần quay lại ứng dụng và đăng nhập bằng email vừa tạo.</p>
      </div>
    </div>
    <script>
      const verifyUrl = "{{.VerifyURL}}";
      const status = document.getElementById('status');
      const title = document.getElementById('title');
      const message = document.getElementById('message');

      fetch(verifyUrl, { headers: { Accept: 'application/json' } })
        .then(async (response) => {
          const data = await response.json().catch(() => ({}));
          if (!response.ok) {
            throw new Error(data.error || data.message || 'Không thể xác thực email với liên kết này.');
          }

          status.className = 'status success';
          status.textContent = 'Đã xác thực xong';
          title.textContent = 'Email của bạn đã được xác thực';
          message.textContent = data.message || 'Bạn có thể quay lại Pody và đăng nhập ngay bây giờ.';
        })
        .catch((error) => {
          status.className = 'status error';
          status.textContent = 'Xác thực chưa thành công';
          title.textContent = 'Liên kết này chưa dùng được';
          message.textContent = error.message || 'Liên kết xác thực có thể đã hết hạn hoặc đã được sử dụng.';
        });
    </script>
  </body>
</html>`))

// New khởi dựng router Chi, đăng ký middlewares, định nghĩa các endpoint của Gateway,
// và cấu hình các reverse proxy tương ứng để phân phối tải đến từng microservice.
func New(cfg config.Config, logger *slog.Logger) *http.Server {
	router := chi.NewRouter()

	// Đăng ký các Middleware toàn cục cho Gateway
	router.Use(withCORS(cfg.AllowedOrigins))   // Xử lý CORS
	router.Use(withRequestID)                  // Đính kèm Request ID cho trace log
	router.Use(withRecover(logger))            // Phục hồi panic tránh crash server
	router.Use(withAccessLog(logger))          // Ghi nhận nhật ký truy cập

	// Endpoint kiểm tra nhanh thông tin tổng quan của Gateway
	router.Get("/", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, metaResponse{
			Name:   "pody-api-gateway",
			Status: "ok",
			Routes: cfg.Routes,
		})
	})

	// Giao diện web tổng hợp tài liệu API Docs của tất cả các microservices
	router.Get("/docs", func(w http.ResponseWriter, r *http.Request) {
		html := `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Pody API Docs</title>
    <style>
      body { font-family: Georgia, serif; margin: 40px; background: #f7f3eb; color: #1f1b16; }
      .card { background: #fffdf8; border: 1px solid #d8cab7; border-radius: 16px; padding: 20px; margin-bottom: 16px; max-width: 760px; }
      a { color: #9c3f12; text-decoration: none; }
      a:hover { text-decoration: underline; }
      h1, h2 { margin-top: 0; }
      code { background: #f2e7d5; padding: 2px 6px; border-radius: 6px; }
    </style>
  </head>
  <body>
    <h1>Pody API Docs</h1>
    <div class="card">
      <h2>Identity Service</h2>
      <p><a href="/api/v1/public/identity/docs">Swagger UI</a></p>
      <p><a href="/api/v1/public/identity/openapi.yaml">OpenAPI YAML</a></p>
    </div>
    <div class="card">
      <h2>AI Service</h2>
      <p><a href="/api/v1/public/ai/docs">Swagger UI</a></p>
      <p><a href="/api/v1/public/ai/openapi.yaml">OpenAPI YAML</a></p>
    </div>
    <div class="card">
      <h2>Content Service</h2>
      <p><a href="/api/v1/public/content/docs">Swagger UI</a></p>
      <p><a href="/api/v1/public/content/openapi.yaml">OpenAPI YAML</a></p>
    </div>
    <div class="card">
      <h2>Notification Service</h2>
      <p><a href="/api/v1/public/notifications/docs">Swagger UI</a></p>
      <p><a href="/api/v1/public/notifications/openapi.yaml">OpenAPI YAML</a></p>
    </div>
    <div class="card">
      <h2>Gateway Routes</h2>
      <p><a href="/api/v1/_meta/routes">Route metadata</a></p>
      <p>Protected APIs still require <code>Authorization: Bearer &lt;jwt&gt;</code>.</p>
    </div>
  </body>
</html>`
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = fmt.Fprint(w, html)
	})

	// Endpoint kiểm tra sức khỏe của Gateway (Liveness probe)
	router.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// Trang cầu nối để đặt lại mật khẩu của người dùng trên Mobile
	router.Get("/reset-password/open", func(w http.ResponseWriter, r *http.Request) {
		token := strings.TrimSpace(r.URL.Query().Get("token"))
		if token == "" {
			writeJSON(w, http.StatusBadRequest, map[string]string{
				"error": "missing token",
			})
			return
		}

		appURL := "pody://reset-password?token=" + url.QueryEscape(token)
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_ = resetPasswordBridgeTemplate.Execute(w, struct {
			Token        string
			AppURL       template.URL
			AppURLString string
		}{
			Token:        token,
			AppURL:       template.URL(appURL),
			AppURLString: appURL,
		})
	})

	// Trang cầu nối kích hoạt xác minh email
	router.Get("/verify-email/open", func(w http.ResponseWriter, r *http.Request) {
		token := strings.TrimSpace(r.URL.Query().Get("token"))
		if token == "" {
			writeJSON(w, http.StatusBadRequest, map[string]string{
				"error": "missing token",
			})
			return
		}

		verifyURL := "/api/v1/public/identity/verify-email?token=" + url.QueryEscape(token)
		appURL := "pody://sign-in?verified=1"
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_ = verifyEmailBridgeTemplate.Execute(w, struct {
			AppURL    template.URL
			VerifyURL string
		}{
			AppURL:    template.URL(appURL),
			VerifyURL: verifyURL,
		})
	})

	// Endpoint kiểm tra trạng thái sẵn sàng nhận request (Readiness probe)
	router.Get("/readyz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
	})

	// Xử lý khi không tìm thấy route tương ứng
	router.NotFound(func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusNotFound, map[string]string{
			"error": "route not found",
		})
	})

	// Xử lý khi HTTP method không được hỗ trợ cho route
	router.MethodNotAllowed(func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{
			"error": "method not allowed",
		})
	})

	// Khởi tạo các Reverse Proxy tương ứng với các route trong config
	proxies := buildServiceProxies(cfg.Routes, logger)

	// Định nghĩa nhóm API chính /api/v1
	router.Route("/api/v1", func(api chi.Router) {
		// Endpoint xem metadata về định tuyến của Gateway
		api.Get("/_meta/routes", func(w http.ResponseWriter, r *http.Request) {
			writeJSON(w, http.StatusOK, map[string]any{
				"routes": cfg.Routes,
			})
		})

		// Nhóm API Public: Không yêu cầu kiểm tra JWT token xác thực
		api.Group(func(public chi.Router) {
			for _, route := range cfg.Routes {
				if !isPublicRoute(route) {
					continue
				}

				proxy := proxies[route.Name]
				if proxy == nil {
					continue
				}

				mountServiceRoute(public, route, proxy)
			}
		})

		// Nhóm API Protected: Yêu cầu bắt buộc kiểm tra JWT Token
		api.Group(func(protected chi.Router) {
			protected.Use(withJWTAuth(cfg.JWTSecret, cfg.AuthSkipPaths))

			for _, route := range cfg.Routes {
				if isPublicRoute(route) {
					continue
				}

				proxy := proxies[route.Name]
				if proxy == nil {
					continue
				}

				mountServiceRoute(protected, route, proxy)
			}
		})
	})

	return &http.Server{
		Addr:         cfg.Addr(),
		Handler:      router,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		IdleTimeout:  cfg.IdleTimeout,
	}
}

// isPublicRoute kiểm tra xem route đó có thuộc nhóm API công khai (Public) không dựa trên tiền tố Prefix.
func isPublicRoute(route config.ServiceRoute) bool {
	return strings.HasPrefix(strings.TrimSpace(route.Prefix), "/api/v1/public/")
}

// buildServiceProxies duyệt qua danh sách các cấu hình route và sinh ra map chứa các đối tượng reverse proxy tương ứng.
func buildServiceProxies(routes []config.ServiceRoute, logger *slog.Logger) map[string]http.Handler {
	proxies := make(map[string]http.Handler, len(routes))
	for _, route := range routes {
		proxy, err := newServiceProxy(route, logger)
		if err != nil {
			logger.Error("failed to create proxy", "service", route.Name, "error", err)
			continue
		}

		proxies[route.Name] = proxy
	}

	return proxies
}

// mountServiceRoute thực hiện đăng ký đường dẫn Prefix và wildcard (*) vào chi.Router để định tuyến cuộc gọi đến Proxy.
func mountServiceRoute(router chi.Router, route config.ServiceRoute, handler http.Handler) {
	suffix := strings.TrimPrefix(route.Prefix, "/api/v1")
	router.Handle(suffix, handler)
	router.Handle(suffix+"/*", handler)
}

// writeJSON ghi dữ liệu phản hồi dạng JSON có thụt lề thụ động và set Content-Type header thích hợp.
func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)

	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	_ = encoder.Encode(payload)
}

// newDiscardLogger sinh ra một slog.Logger rỗng (không ghi log gì cả, dùng cho testing).
func newDiscardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

