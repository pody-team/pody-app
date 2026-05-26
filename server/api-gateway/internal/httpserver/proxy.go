package httpserver

import (
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/promex04/pody/server/api-gateway/internal/config"
)

// newServiceProxy khởi tạo đối tượng ReverseProxy của HTTP standard library cho từng upstream service.
// Đảm nhận việc viết lại request (URL, Host, Headers) và xử lý lỗi khi không kết nối được dịch vụ phía sau.
func newServiceProxy(route config.ServiceRoute, logger *slog.Logger) (http.Handler, error) {
	target, err := url.Parse(route.TargetURL)
	if err != nil {
		return nil, err
	}

	basePrefix := strings.TrimSuffix(route.Prefix, "/")
	targetQuery := target.RawQuery

	proxy := &httputil.ReverseProxy{
		FlushInterval: -1, // Thiết lập đẩy dữ liệu lập tức, phù hợp cho streaming response/SSE
		Director: func(req *http.Request) {
			originalHost := req.Host
			originalPath := req.URL.Path
			// Cắt bỏ phần Prefix của Gateway ra khỏi Path gốc trước khi chuyển tiếp cho service đích.
			// Ví dụ: /api/v1/identity/me -> /me
			trimmedPath := strings.TrimPrefix(originalPath, basePrefix)
			if trimmedPath == "" {
				trimmedPath = "/"
			}
			if !strings.HasPrefix(trimmedPath, "/") {
				trimmedPath = "/" + trimmedPath
			}

			// Thiết lập lại các thông tin của request đích
			req.URL.Scheme = target.Scheme
			req.URL.Host = target.Host
			req.URL.Path = joinPaths(target.Path, trimmedPath)
			req.URL.RawPath = req.URL.EscapedPath()
			req.Host = target.Host

			// Gộp các query parameters ban đầu của request với cấu hình URL đích nếu có
			switch {
			case targetQuery == "":
			case req.URL.RawQuery == "":
				req.URL.RawQuery = targetQuery
			default:
				req.URL.RawQuery = targetQuery + "&" + req.URL.RawQuery
			}

			// Thiết lập các header tiêu chuẩn của reverse proxy để báo cho upstream service biết nguồn gốc request
			req.Header.Set("X-Forwarded-Host", originalHost)
			req.Header.Set("X-Forwarded-Prefix", route.Prefix)
			req.Header.Set("X-Forwarded-Proto", forwardedProto(req))

			// Đính kèm Request ID để đồng bộ hóa trace log giữa Gateway và upstream service
			if requestID := requestIDFromContext(req.Context()); requestID != "" {
				req.Header.Set("X-Request-ID", requestID)
			}
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			// Xử lý lỗi khi service phía sau không phản hồi (ví dụ: bị sập, lỗi kết nối)
			logger.Error("proxy request failed",
				"request_id", requestIDFromContext(r.Context()),
				"service", route.Name,
				"target", route.TargetURL,
				"error", err,
			)
			// Trả về lỗi 502 Bad Gateway và định dạng JSON thông báo lỗi
			writeJSON(w, http.StatusBadGateway, map[string]string{
				"error":   "upstream service unavailable",
				"service": route.Name,
			})
		},
	}

	return proxy, nil
}

// joinPaths nối đường dẫn cơ bản của service đích với đường dẫn request thực tế một cách an toàn.
func joinPaths(basePath, requestPath string) string {
	switch {
	case basePath == "" || basePath == "/":
		return requestPath
	case requestPath == "" || requestPath == "/":
		return strings.TrimRight(basePath, "/")
	default:
		return strings.TrimRight(basePath, "/") + "/" + strings.TrimLeft(requestPath, "/")
	}
}

// forwardedProto xác định giao thức (http hoặc https) của yêu cầu ban đầu gửi tới Gateway.
func forwardedProto(req *http.Request) string {
	if req.TLS != nil {
		return "https"
	}

	if forwarded := strings.TrimSpace(req.Header.Get("X-Forwarded-Proto")); forwarded != "" {
		return forwarded
	}

	return "http"
}

