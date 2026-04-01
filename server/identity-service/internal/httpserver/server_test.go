package httpserver

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/promex04/pody/server/identity-service/internal/auth"
	"github.com/promex04/pody/server/identity-service/internal/config"
)

func TestOpenAPIYAMLEndpoint(t *testing.T) {
	server := New(config.Config{
		Port: "8081",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), auth.Service{})

	request := httptest.NewRequest(http.MethodGet, "/api/v1/public/identity/openapi.yaml", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "openapi: 3.0.3") {
		t.Fatalf("expected OpenAPI document, got %q", recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "/api/v1/identity/change-password:") || !strings.Contains(recorder.Body.String(), "/api/v1/public/identity/openapi.yaml:") {
		t.Fatalf("expected complete identity spec, got %q", recorder.Body.String())
	}
}

func TestSwaggerUIDocsEndpoint(t *testing.T) {
	server := New(config.Config{
		Port: "8081",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), auth.Service{})

	request := httptest.NewRequest(http.MethodGet, "/api/v1/public/identity/docs", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "SwaggerUIBundle") {
		t.Fatalf("expected Swagger UI page, got %q", recorder.Body.String())
	}
}

func TestHealthz(t *testing.T) {
	server := New(config.Config{
		Port: "8081",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), auth.Service{})

	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
}

func TestPatchMeRequiresBearerToken(t *testing.T) {
	server := New(config.Config{
		Port: "8081",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), auth.Service{})

	request := httptest.NewRequest(http.MethodPatch, "/api/v1/identity/me", strings.NewReader(`{}`))
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", recorder.Code)
	}
}
