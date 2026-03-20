package httpserver

import (
	"bytes"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/promex04/pody/server/content-service/internal/config"
	"github.com/promex04/pody/server/content-service/internal/store"
)

func TestPublicHomeFeedDoesNotRequireAuth(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/public/content/home", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "\"hosts\"") {
		t.Fatalf("expected hosts in response body, got %q", recorder.Body.String())
	}
}

func TestOpenAPIYAMLEndpoint(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/public/content/openapi.yaml", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "openapi: 3.0.3") {
		t.Fatalf("expected OpenAPI document, got %q", recorder.Body.String())
	}
}

func TestSwaggerUIDocsEndpoint(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/public/content/docs", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "SwaggerUIBundle") {
		t.Fatalf("expected Swagger UI page, got %q", recorder.Body.String())
	}
}

func TestShowDetailIncludesHostsWithoutEpisodes(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/public/content/shows/show-midnight-reset", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
	body := recorder.Body.String()
	if !strings.Contains(body, "\"display_name\":\"Lumi\"") {
		t.Fatalf("expected Lumi host in response, got %q", body)
	}
}

func TestMyShowsRequiresAuthHeader(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/content/me/shows", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", recorder.Code)
	}
}

func TestCreateShowRequiresAuthHeader(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodPost, "/api/v1/content/shows", bytes.NewBufferString(`{
		"title":"Show moi",
		"primary_category":"Cong nghe",
		"hosts":[{"display_name":"Nova 2"}]
	}`))
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", recorder.Code)
	}
}

func TestCreateShowReturnsCreatedShow(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodPost, "/api/v1/content/shows", bytes.NewBufferString(`{
		"title":"Builder's Log",
		"description":"Show danh cho creator dang build dan AI service.",
		"primary_category":"Cong nghe",
		"cover_image_url":"https://example.com/builder-log.png",
		"content_type":"podcast",
		"hosts":[
			{
				"display_name":"Mira",
				"bio":"AI host dong hanh voi creator."
			},
			{
				"display_name":"Atlas",
				"role":"co_host",
				"bio":"Co-host dat cau hoi."
			}
		]
	}`))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Auth-User-ID", "creator-123")
	request.Header.Set("X-Auth-Email", "creator@example.com")
	request.Header.Set("X-Auth-Name", "Creator")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d with body %q", recorder.Code, recorder.Body.String())
	}

	body := recorder.Body.String()
	if !strings.Contains(body, "\"title\":\"Builder's Log\"") {
		t.Fatalf("expected created show title in response, got %q", body)
	}
	if !strings.Contains(body, "\"display_name\":\"Mira\"") || !strings.Contains(body, "\"display_name\":\"Atlas\"") {
		t.Fatalf("expected hosts in response, got %q", body)
	}
}
