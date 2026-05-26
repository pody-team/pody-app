package config

import (
	"fmt"
	"net/url"
	"os"
	"strings"
	"time"
)

// ServiceRoute định nghĩa một cấu hình định tuyến (routing) cho một upstream service.
type ServiceRoute struct {
	Name      string `json:"name"`       // Tên định danh của service (ví dụ: "identity", "content")
	Prefix    string `json:"prefix"`     // Tiền tố URL mà Gateway sẽ lắng nghe để chuyển tiếp (ví dụ: "/api/v1/identity")
	TargetURL string `json:"target_url"` // URL đích của microservice chạy phía sau Gateway (ví dụ: "http://localhost:8081")
}

// Config chứa toàn bộ thông số cấu hình hoạt động của API Gateway.
type Config struct {
	Port            string        // Cổng mạng mà Gateway lắng nghe (mặc định: "8080")
	AllowedOrigins  []string      // Danh sách các Origin được phép truy cập (CORS)
	ReadTimeout     time.Duration // Thời gian chờ tối đa khi đọc request
	WriteTimeout    time.Duration // Thời gian chờ tối đa khi ghi response
	IdleTimeout     time.Duration // Thời gian chờ tối đa cho một kết nối rảnh (keep-alive)
	ShutdownTimeout time.Duration // Thời gian tối đa để đóng các kết nối khi tắt server (graceful shutdown)
	JWTSecret       string        // Khóa bí mật dùng để xác thực và giải mã chữ ký JWT Token
	AuthSkipPaths   []string      // Danh sách các đường dẫn bỏ qua kiểm tra JWT auth
	Routes          []ServiceRoute // Danh sách cấu hình định tuyến chuyển tiếp request của các service
}

// serviceEnv là cấu trúc lưu trữ thông tin cấu hình môi trường của từng service.
type serviceEnv struct {
	Name         string // Tên định danh
	Prefix       string // Tiền tố route ở Gateway
	EnvKey       string // Tên biến môi trường cấu hình URL của service (ví dụ: "IDENTITY_SERVICE_URL")
	DefaultURL   string // URL mặc định nếu không cấu hình biến môi trường
	UpstreamPath string // Đường dẫn cụ thể trên service gốc nếu cần mapping khác đi
}

// serviceEnvs danh sách định nghĩa tất cả các service hiện có trong hệ thống microservices của Pody.
// Bao gồm cả các cổng public (không cần qua JWT auth middleware ở Gateway) và protected.
var serviceEnvs = []serviceEnv{
	{Name: "identity-public", Prefix: "/api/v1/public/identity", EnvKey: "IDENTITY_SERVICE_URL", DefaultURL: "http://localhost:8081", UpstreamPath: "/api/v1/public/identity"},
	{Name: "notifications-public", Prefix: "/api/v1/public/notifications", EnvKey: "NOTIFICATION_SERVICE_URL", DefaultURL: "http://localhost:8087", UpstreamPath: "/api/v1/public/notifications"},
	{Name: "content-public", Prefix: "/api/v1/public/content", EnvKey: "CONTENT_SERVICE_URL", DefaultURL: "http://localhost:8082", UpstreamPath: "/api/v1/public/content"},
	{Name: "article-public", Prefix: "/api/v1/public/article", EnvKey: "ARTICLE_SERVICE_URL", DefaultURL: "http://localhost:8084", UpstreamPath: "/api/v1/article"},
	{Name: "identity", Prefix: "/api/v1/identity", EnvKey: "IDENTITY_SERVICE_URL", DefaultURL: "http://localhost:8081", UpstreamPath: "/api/v1/identity"},
	{Name: "content", Prefix: "/api/v1/content", EnvKey: "CONTENT_SERVICE_URL", DefaultURL: "http://localhost:8082", UpstreamPath: "/api/v1/content"},
	{Name: "social", Prefix: "/api/v1/social", EnvKey: "SOCIAL_SERVICE_URL", DefaultURL: "http://localhost:8083"},
	{Name: "article", Prefix: "/api/v1/article", EnvKey: "ARTICLE_SERVICE_URL", DefaultURL: "http://localhost:8084", UpstreamPath: "/api/v1/article"},
	{Name: "ai", Prefix: "/api/v1/ai", EnvKey: "AI_SERVICE_URL", DefaultURL: "http://localhost:8085", UpstreamPath: "/api/v1/ai"},
	{Name: "billing", Prefix: "/api/v1/billing", EnvKey: "BILLING_SERVICE_URL", DefaultURL: "http://localhost:8086"},
	{Name: "notifications", Prefix: "/api/v1/notifications", EnvKey: "NOTIFICATION_SERVICE_URL", DefaultURL: "http://localhost:8087", UpstreamPath: "/api/v1/notifications"},
}

// Load thực hiện đọc toàn bộ cấu hình từ các biến môi trường và khởi tạo struct Config.
func Load() (Config, error) {
	readTimeout, err := durationFromEnv("READ_TIMEOUT", 30*time.Second)
	if err != nil {
		return Config{}, err
	}

	writeTimeout, err := durationFromEnv("WRITE_TIMEOUT", 5*time.Minute)
	if err != nil {
		return Config{}, err
	}

	idleTimeout, err := durationFromEnv("IDLE_TIMEOUT", 120*time.Second)
	if err != nil {
		return Config{}, err
	}

	shutdownTimeout, err := durationFromEnv("SHUTDOWN_TIMEOUT", 10*time.Second)
	if err != nil {
		return Config{}, err
	}

	// Tải cấu hình định tuyến cho từng service
	routes, err := loadRoutes()
	if err != nil {
		return Config{}, err
	}

	return Config{
		Port:            stringFromEnv("PORT", "8080"),
		AllowedOrigins:  csvFromEnv("ALLOWED_ORIGINS", []string{"*"}),
		ReadTimeout:     readTimeout,
		WriteTimeout:    writeTimeout,
		IdleTimeout:     idleTimeout,
		ShutdownTimeout: shutdownTimeout,
		JWTSecret:       stringFromEnv("JWT_SECRET", "change-me"),
		AuthSkipPaths:   csvFromEnv("AUTH_EXCLUDED_PATHS", nil),
		Routes:          routes,
	}, nil
}

// Addr trả về địa chỉ TCP mà Gateway sẽ lắng nghe (ví dụ: ":8080").
func (c Config) Addr() string {
	return ":" + c.Port
}

// loadRoutes duyệt qua danh sách serviceEnvs để xây dựng các đối tượng ServiceRoute hoàn chỉnh.
func loadRoutes() ([]ServiceRoute, error) {
	routes := make([]ServiceRoute, 0, len(serviceEnvs))

	for _, svc := range serviceEnvs {
		// Tạo URL đích bằng cách lấy URL cấu hình và nối với UpstreamPath
		targetURL, err := buildTargetURL(stringFromEnv(svc.EnvKey, svc.DefaultURL), svc.UpstreamPath)
		if err != nil {
			return nil, fmt.Errorf("invalid %s: %w", svc.EnvKey, err)
		}

		routes = append(routes, ServiceRoute{
			Name:      svc.Name,
			Prefix:    svc.Prefix,
			TargetURL: targetURL,
		})
	}

	return routes, nil
}

// stringFromEnv lấy giá trị của một biến môi trường dạng chuỗi, nếu rỗng thì trả về giá trị mặc định.
func stringFromEnv(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	return value
}

// csvFromEnv lấy danh sách các chuỗi từ biến môi trường phân tách bởi dấu phẩy ",".
func csvFromEnv(key string, fallback []string) []string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parts := strings.Split(value, ",")
	items := make([]string, 0, len(parts))

	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			items = append(items, trimmed)
		}
	}

	if len(items) == 0 {
		return fallback
	}

	return items
}

// durationFromEnv lấy giá trị thời gian (time.Duration) từ biến môi trường, hỗ trợ parse các định dạng chuỗi như "30s", "5m".
func durationFromEnv(key string, fallback time.Duration) (time.Duration, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback, nil
	}

	duration, err := time.ParseDuration(value)
	if err != nil {
		return 0, fmt.Errorf("invalid %s: %w", key, err)
	}

	return duration, nil
}

// buildTargetURL tạo URL hoàn chỉnh và kiểm tra tính hợp lệ của URL đích.
func buildTargetURL(baseURL, upstreamPath string) (string, error) {
	parsed, err := url.ParseRequestURI(baseURL)
	if err != nil {
		return "", err
	}

	if strings.TrimSpace(upstreamPath) != "" {
		parsed.Path = joinURLPaths(parsed.Path, upstreamPath)
	}

	return parsed.String(), nil
}

// joinURLPaths nối hai đường dẫn URL một cách an toàn, xử lý dấu gạch chéo `/` hợp lý.
func joinURLPaths(basePath, extraPath string) string {
	switch {
	case basePath == "" || basePath == "/":
		return extraPath
	case extraPath == "" || extraPath == "/":
		return strings.TrimRight(basePath, "/")
	default:
		return strings.TrimRight(basePath, "/") + "/" + strings.TrimLeft(extraPath, "/")
	}
}

