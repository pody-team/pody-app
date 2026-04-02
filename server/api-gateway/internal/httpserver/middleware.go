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

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(status int) {
	r.status = status
	r.ResponseWriter.WriteHeader(status)
}

func (r *statusRecorder) Flush() {
	if flusher, ok := r.ResponseWriter.(http.Flusher); ok {
		flusher.Flush()
	}
}

func (r *statusRecorder) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	hijacker, ok := r.ResponseWriter.(http.Hijacker)
	if !ok {
		return nil, nil, fmt.Errorf("response writer does not support hijacking")
	}
	return hijacker.Hijack()
}

func (r *statusRecorder) Push(target string, opts *http.PushOptions) error {
	pusher, ok := r.ResponseWriter.(http.Pusher)
	if !ok {
		return http.ErrNotSupported
	}
	return pusher.Push(target, opts)
}

func (r *statusRecorder) Unwrap() http.ResponseWriter {
	return r.ResponseWriter
}

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

func withJWTAuth(secret string, skipPaths []string) func(http.Handler) http.Handler {
	trimmedSecret := strings.TrimSpace(secret)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
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

			tokenString := bearerToken(r.Header.Get("Authorization"))
			if tokenString == "" {
				writeJSON(w, http.StatusUnauthorized, map[string]string{
					"error": "missing bearer token",
				})
				return
			}

			claims := jwt.MapClaims{}
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
			enrichRequestWithClaims(r, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

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

func allowOrigin(allowedOrigins []string, origin string) bool {
	for _, allowed := range allowedOrigins {
		if allowed == "*" || allowed == origin {
			return true
		}
	}

	return false
}

func requestIDFromContext(ctx context.Context) string {
	requestID, _ := ctx.Value(requestIDKey).(string)
	return requestID
}

func bearerToken(headerValue string) string {
	const prefix = "Bearer "
	if !strings.HasPrefix(headerValue, prefix) {
		return ""
	}

	return strings.TrimSpace(strings.TrimPrefix(headerValue, prefix))
}

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

func newRequestID() string {
	buffer := make([]byte, 12)
	if _, err := rand.Read(buffer); err != nil {
		return time.Now().UTC().Format("20060102150405.000000000")
	}

	return hex.EncodeToString(buffer)
}
