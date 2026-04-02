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

func TestEpisodeDetailIncludesTranscriptStatus(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/public/content/episodes/ep-future-minds-001", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
	body := recorder.Body.String()
	if !strings.Contains(body, "\"transcript\":{\"status\":\"completed\"") {
		t.Fatalf("expected transcript status in episode detail, got %q", body)
	}
	if !strings.Contains(body, "\"speaker\":\"Nova\"") {
		t.Fatalf("expected transcript speaker in response, got %q", body)
	}
	if !strings.Contains(body, "\"words\":[{\"start_seconds\":0,") {
		t.Fatalf("expected transcript word timings in response, got %q", body)
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

func TestMyShowDetailRequiresAuthHeader(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/content/me/shows/show-future-minds", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", recorder.Code)
	}
}

func TestMyShowDetailReturnsOwnedShow(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/content/me/shows/show-future-minds", nil)
	request.Header.Set("X-Auth-User-ID", "creator-123")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "\"id\":\"show-future-minds\"") {
		t.Fatalf("expected owned show detail in response, got %q", recorder.Body.String())
	}
}

func TestMyEpisodeDetailReturnsOwnedEpisode(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/content/me/episodes/ep-future-minds-001", nil)
	request.Header.Set("X-Auth-User-ID", "creator-123")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "\"id\":\"ep-future-minds-001\"") {
		t.Fatalf("expected owned episode detail in response, got %q", recorder.Body.String())
	}
}

func TestMyShowEpisodesReturnsOwnedEpisodes(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/content/me/shows/show-future-minds/episodes", nil)
	request.Header.Set("X-Auth-User-ID", "creator-123")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "\"episodes\"") {
		t.Fatalf("expected episode list in response, got %q", recorder.Body.String())
	}
}

func TestEpisodeBookmarkRequiresAuthHeader(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/content/me/bookmarks/ep-future-minds-001", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", recorder.Code)
	}
}

func TestEpisodeBookmarksListRequiresAuthHeader(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	request := httptest.NewRequest(http.MethodGet, "/api/v1/content/me/bookmarks", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", recorder.Code)
	}
}

func TestEpisodeBookmarkLifecycle(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	getStatus := func() string {
		request := httptest.NewRequest(http.MethodGet, "/api/v1/content/me/bookmarks/ep-future-minds-001", nil)
		request.Header.Set("X-Auth-User-ID", "creator-123")
		recorder := httptest.NewRecorder()
		server.Handler.ServeHTTP(recorder, request)
		if recorder.Code != http.StatusOK {
			t.Fatalf("expected 200 from GET, got %d with body %q", recorder.Code, recorder.Body.String())
		}
		return recorder.Body.String()
	}

	if body := getStatus(); !strings.Contains(body, "\"is_bookmarked\":false") {
		t.Fatalf("expected unbookmarked status initially, got %q", body)
	}

	putRequest := httptest.NewRequest(http.MethodPut, "/api/v1/content/me/bookmarks/ep-future-minds-001", nil)
	putRequest.Header.Set("X-Auth-User-ID", "creator-123")
	putRecorder := httptest.NewRecorder()
	server.Handler.ServeHTTP(putRecorder, putRequest)
	if putRecorder.Code != http.StatusOK {
		t.Fatalf("expected 200 from PUT, got %d with body %q", putRecorder.Code, putRecorder.Body.String())
	}
	if !strings.Contains(putRecorder.Body.String(), "\"is_bookmarked\":true") {
		t.Fatalf("expected bookmarked status after PUT, got %q", putRecorder.Body.String())
	}

	if body := getStatus(); !strings.Contains(body, "\"is_bookmarked\":true") {
		t.Fatalf("expected bookmarked status after PUT, got %q", body)
	}

	deleteRequest := httptest.NewRequest(http.MethodDelete, "/api/v1/content/me/bookmarks/ep-future-minds-001", nil)
	deleteRequest.Header.Set("X-Auth-User-ID", "creator-123")
	deleteRecorder := httptest.NewRecorder()
	server.Handler.ServeHTTP(deleteRecorder, deleteRequest)
	if deleteRecorder.Code != http.StatusOK {
		t.Fatalf("expected 200 from DELETE, got %d with body %q", deleteRecorder.Code, deleteRecorder.Body.String())
	}
	if !strings.Contains(deleteRecorder.Body.String(), "\"is_bookmarked\":false") {
		t.Fatalf("expected unbookmarked status after DELETE, got %q", deleteRecorder.Body.String())
	}
}

func TestEpisodeBookmarksListReturnsSavedEpisodes(t *testing.T) {
	server := New(config.Config{Port: "8082"}, slog.New(slog.NewTextHandler(io.Discard, nil)), store.NewDemoStore())

	saveRequest := httptest.NewRequest(http.MethodPut, "/api/v1/content/me/bookmarks/ep-future-minds-001", nil)
	saveRequest.Header.Set("X-Auth-User-ID", "creator-123")
	saveRecorder := httptest.NewRecorder()
	server.Handler.ServeHTTP(saveRecorder, saveRequest)
	if saveRecorder.Code != http.StatusOK {
		t.Fatalf("expected 200 from PUT, got %d with body %q", saveRecorder.Code, saveRecorder.Body.String())
	}

	listRequest := httptest.NewRequest(http.MethodGet, "/api/v1/content/me/bookmarks", nil)
	listRequest.Header.Set("X-Auth-User-ID", "creator-123")
	listRecorder := httptest.NewRecorder()
	server.Handler.ServeHTTP(listRecorder, listRequest)
	if listRecorder.Code != http.StatusOK {
		t.Fatalf("expected 200 from GET list, got %d with body %q", listRecorder.Code, listRecorder.Body.String())
	}

	body := listRecorder.Body.String()
	if !strings.Contains(body, "\"bookmarks\"") {
		t.Fatalf("expected bookmarks envelope, got %q", body)
	}
	if !strings.Contains(body, "\"episode\":{\"id\":\"ep-future-minds-001\"") {
		t.Fatalf("expected saved episode in response, got %q", body)
	}
	if !strings.Contains(body, "\"show\":{\"id\":\"show-future-minds\"") {
		t.Fatalf("expected show summary in response, got %q", body)
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
