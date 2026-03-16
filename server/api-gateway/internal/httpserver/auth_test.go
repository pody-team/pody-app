package httpserver

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestJWTAuthAllowsSkippedPaths(t *testing.T) {
	middleware := withJWTAuth("secret", []string{"/api/v1/_meta/routes"})

	handler := middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/_meta/routes", nil)
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusNoContent {
		t.Fatalf("expected skipped path to bypass auth, got %d", recorder.Code)
	}
}

func TestJWTAuthRejectsMissingBearerToken(t *testing.T) {
	middleware := withJWTAuth("secret", nil)

	handler := middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/social/comments", nil)
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 for missing token, got %d", recorder.Code)
	}
}

func TestJWTAuthAcceptsValidTokenAndForwardsClaims(t *testing.T) {
	middleware := withJWTAuth("secret", nil)

	handler := middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("X-Auth-User-ID"); got != "user-123" {
			t.Fatalf("expected X-Auth-User-ID to be propagated, got %q", got)
		}

		if got := r.Header.Get("X-Auth-Role"); got != "admin" {
			t.Fatalf("expected X-Auth-Role to be propagated, got %q", got)
		}

		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/v1/social/comments", nil)
	req.Header.Set("Authorization", "Bearer "+signedTestToken(t, "secret"))
	recorder := httptest.NewRecorder()

	handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200 for valid token, got %d", recorder.Code)
	}
}

func signedTestToken(t *testing.T, secret string) string {
	t.Helper()

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub":   "user-123",
		"role":  "admin",
		"email": "user@example.com",
		"exp":   time.Now().Add(5 * time.Minute).Unix(),
	})

	signed, err := token.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("failed to sign test token: %v", err)
	}

	return signed
}
