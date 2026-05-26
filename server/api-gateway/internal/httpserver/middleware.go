package httpserver

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type contextKey string

const requestIDKey contextKey = "request_id"
const authClaimsKey contextKey = "auth_claims"

// statusRecorder là một wrapper cho http.ResponseWriter để ghi nhận HTTP status code của response,
// phục vụ cho việc ghi log truy cập (access log).
type statusRecorder struct {
	http.ResponseWriter
	status int
}

// WriteHeader ghi nhận status code trước khi ghi xuống client.
func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

// Flush hỗ trợ việc đẩy dữ liệu (buffering) xuống client nếu ResponseWriter gốc có hỗ trợ.
func (r *statusRecorder) Flush() {
	if flusher, ok := r.ResponseWriter.(http.Flusher); ok {
		flusher.Flush()
	}
}

// Hijack cho phép nâng cấp kết nối (ví dụ: WebSocket) nếu ResponseWriter gốc hỗ trợ.
func (r *statusRecorder) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	hijacker, ok := r.ResponseWriter.(http.Hijacker)
	if !ok {
		return nil, nil, fmt.Errorf("response writer does not support hijacking")
	}
	return hijacker.Hijack()
}

// Push hỗ trợ HTTP/2 server push nếu được hỗ trợ.
func (r *statusRecorder) Push(target string, opts *http.PushOptions) error {
	pusher, ok := r.ResponseWriter.(http.Pusher)
	if !ok {
		return http.ErrNotSupported
	}
	return pusher.Push(target, opts)
}

// Unwrap trả về ResponseWriter gốc bên trong statusRecorder.
func (r *statusRecorder) Unwrap() http.ResponseWriter {
	return r.ResponseWriter
}

// withRequestID là middleware tạo hoặc kế thừa Request ID cho mỗi yêu cầu để phục vụ tracing.
func withRequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requestID := strings.TrimSpace(r.Header.Get("X-Request-ID"))
		if requestID == "" {
			requestID = newRequestID()
		}

		ctx := context.WithValue(r.Context(), requestIDKey, requestID)
		w.Header().Set("X-Request-ID", requestID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// withRecover là middleware xử lý lỗi panic trong Handler để đảm bảo Gateway không bị sập đột ngột.
func withRecover(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if recovered := recover(); recovered != nil {
					if recovered == http.ErrAbortHandler {
						return
					}

					logger.Error("panic recovered", "request_id", requestIDFromContext(r.Context()), "panic", recovered)
					writeJSON(w, http.StatusInternalServerError, map[string]string{
						"error": "internal server error",
					})
				}
			}()

			next.ServeHTTP(w, r)
		})
	}
}

// withAccessLog là middleware ghi nhận nhật ký cuộc gọi (access log) bao gồm method, path, status code và duration.
func withAccessLog(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			startedAt := time.Now()
			recorder := &statusRecorder{
				ResponseWriter: w,
				status:         http.StatusOK,
			}

			next.ServeHTTP(recorder, r)

			logger.Info("request completed",
				"request_id", requestIDFromContext(r.Context()),
				"method", r.Method,
				"path", r.URL.Path,
				"status", recorder.status,
				"duration", time.Since(startedAt).String(),
			)
		})
	}
}

// withCORS cấu hình các header CORS (Cross-Origin Resource Sharing) dựa trên danh sách Origin được cấu hình.
func withCORS(allowedOrigins []string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := strings.TrimSpace(r.Header.Get("Origin"))
			if origin != "" {
				if allowOrigin(allowedOrigins, origin) {
					setCORSHeaders(w, origin, allowedOrigins)
				}
			} else if len(allowedOrigins) == 1 && allowedOrigins[0] == "*" {
				setCORSHeaders(w, "*", allowedOrigins)
			}

			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// withJWTAuth thực hiện xác thực và giải mã JWT token cho các yêu cầu cần được bảo mật.
// Nếu token hợp lệ, trích xuất claims và thêm thông tin định danh vào request header để các service phía sau sử dụng.
func withJWTAuth(secret string, skipPaths []string) func(http.Handler) http.Handler {
	trimmedSecret := strings.TrimSpace(secret)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Bỏ qua xác thực cho các yêu cầu OPTIONS (Preflight request) hoặc nằm trong danh sách loại trừ
			if r.Method == http.MethodOptions || shouldSkipAuth(r.URL.Path, skipPaths) {
				next.ServeHTTP(w, r)
				return
			}

			if trimmedSecret == "" {
				writeJSON(w, http.StatusInternalServerError, map[string]string{
					"error": "jwt secret is not configured",
				})
				return
			}

			// Tách lấy token từ Bearer Authorization header
			tokenString := bearerToken(r.Header.Get("Authorization"))
			if tokenString == "" {
				writeJSON(w, http.StatusUnauthorized, map[string]string{
					"error": "missing bearer token",
				})
				return
			}

			claims := jwt.MapClaims{}
			// Parse và kiểm tra tính hợp lệ của token
			token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (any, error) {
				if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, jwt.ErrTokenSignatureInvalid
				}

				return []byte(trimmedSecret), nil
			})
			if err != nil || !token.Valid {
				writeJSON(w, http.StatusUnauthorized, map[string]string{
					"error": "invalid or expired token",
				})
				return
			}

			ctx := context.WithValue(r.Context(), authClaimsKey, claims)
			// Chèn thêm thông tin định danh từ JWT claims vào HTTP Header để chuyển tiếp cho upstream service
			enrichRequestWithClaims(r, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// setCORSHeaders thiết lập cụ thể các Header liên quan đến CORS.
func setCORSHeaders(w http.ResponseWriter, origin string, allowedOrigins []string) {
	allowOriginValue := origin
	if len(allowedOrigins) == 1 && allowedOrigins[0] == "*" {
		allowOriginValue = "*"
	}

	headers := w.Header()
	headers.Set("Access-Control-Allow-Origin", allowOriginValue)
	headers.Set("Access-Control-Allow-Credentials", "true")
	headers.Set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
	headers.Set("Access-Control-Allow-Headers", "Authorization,Content-Type,Accept,X-Request-ID")
	headers.Set("Access-Control-Expose-Headers", "X-Request-ID")
	headers.Add("Vary", "Origin")
}

// allowOrigin kiểm tra xem một origin gửi lên từ client có được phép truy cập hay không.
func allowOrigin(allowedOrigins []string, origin string) bool {
	for _, allowed := range allowedOrigins {
		if allowed == "*" || allowed == origin {
			return true
		}
	}

	return false
}

// requestIDFromContext trích xuất Request ID từ context của request hiện tại.
func requestIDFromContext(ctx context.Context) string {
	requestID, _ := ctx.Value(requestIDKey).(string)
	return requestID
}

// bearerToken tách phần token thực sự từ header định dạng "Bearer <token>".
func bearerToken(headerValue string) string {
	const prefix = "Bearer "
	if !strings.HasPrefix(headerValue, prefix) {
		return ""
	}

	return strings.TrimSpace(strings.TrimPrefix(headerValue, prefix))
}

// shouldSkipAuth kiểm tra một đường dẫn xem có nằm trong danh sách không cần kiểm tra xác thực JWT hay không.
func shouldSkipAuth(path string, skipPaths []string) bool {
	for _, skipPath := range skipPaths {
		skipPath = strings.TrimSpace(skipPath)
		if skipPath == "" {
			continue
		}

		if strings.HasSuffix(skipPath, "*") {
			prefix := strings.TrimSuffix(skipPath, "*")
			if strings.HasPrefix(path, prefix) {
				return true
			}
			continue
		}

		if skipPath == path {
			return true
		}
	}

	return false
}

// enrichRequestWithClaims giải mã JWT claims và chuyển các thông tin định danh (User ID, Role, Email, Name)
// thành các HTTP Header của request được Gateway chuyển đi (ví dụ: X-Auth-User-ID).
func enrichRequestWithClaims(r *http.Request, claims jwt.MapClaims) {
	if subject, ok := claims["sub"].(string); ok && strings.TrimSpace(subject) != "" {
		r.Header.Set("X-Auth-User-ID", subject)
	}

	if role, ok := claims["role"].(string); ok && strings.TrimSpace(role) != "" {
		r.Header.Set("X-Auth-Role", role)
	}

	if email, ok := claims["email"].(string); ok && strings.TrimSpace(email) != "" {
		r.Header.Set("X-Auth-Email", email)
	}

	if name, ok := claims["name"].(string); ok && strings.TrimSpace(name) != "" {
		r.Header.Set("X-Auth-Name", name)
	}
}

// newRequestID sinh ra một Request ID ngẫu nhiên độ dài 24 ký tự hex.
func newRequestID() string {
	buffer := make([]byte, 12)
	if _, err := rand.Read(buffer); err != nil {
		return time.Now().UTC().Format("20060102150405.000000000")
	}

	return hex.EncodeToString(buffer)
}

