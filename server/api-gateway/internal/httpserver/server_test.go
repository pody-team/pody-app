package httpserver

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/promex04/pody/server/api-gateway/internal/config"
)

func TestPublicIdentityHealthzBypassesAuth(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/public/identity/healthz" {
			t.Fatalf("expected upstream healthz path, got %s", r.URL.Path)
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer upstream.Close()

	server := New(config.Config{
		Port:           "8080",
		AllowedOrigins: []string{"*"},
		JWTSecret:      "secret",
		Routes: []config.ServiceRoute{
			{Name: "identity-public", Prefix: "/api/v1/public/identity", TargetURL: upstream.URL + "/api/v1/public/identity", RequiresAuth: false},
		},
	}, newDiscardLogger())

	req := httptest.NewRequest(http.MethodGet, "/api/v1/public/identity/healthz", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected public healthz route to bypass auth, got %d", recorder.Code)
	}
}

func TestProtectedIdentityRouteRequiresAuth(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer upstream.Close()

	server := New(config.Config{
		Port:           "8080",
		AllowedOrigins: []string{"*"},
		JWTSecret:      "secret",
		Routes: []config.ServiceRoute{
			{Name: "identity", Prefix: "/api/v1/identity", TargetURL: upstream.URL + "/api/v1/identity", RequiresAuth: true},
		},
	}, newDiscardLogger())

	req := httptest.NewRequest(http.MethodGet, "/api/v1/identity/me", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected protected route to require auth, got %d", recorder.Code)
	}
}
