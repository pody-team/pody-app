package httpserver

import (
	"bufio"
	"bytes"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

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
			{Name: "identity-public", Prefix: "/api/v1/public/identity", TargetURL: upstream.URL + "/api/v1/public/identity"},
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
			{Name: "identity", Prefix: "/api/v1/identity", TargetURL: upstream.URL + "/api/v1/identity"},
		},
	}, newDiscardLogger())

	req := httptest.NewRequest(http.MethodGet, "/api/v1/identity/me", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected protected route to require auth, got %d", recorder.Code)
	}
}

func TestProtectedAIStreamFlushesFirstStatusChunk(t *testing.T) {
	releaseUpstream := make(chan struct{})
	released := false
	release := func() {
		if released {
			return
		}
		close(releaseUpstream)
		released = true
	}
	defer release()

	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/ai/chat-create/threads/stream" {
			t.Fatalf("expected upstream ai stream path, got %s", r.URL.Path)
		}
		if got := r.Header.Get("X-Auth-User-ID"); got != "user-123" {
			t.Fatalf("expected forwarded auth user id, got %q", got)
		}

		w.Header().Set("Content-Type", "text/event-stream")
		flusher, ok := w.(http.Flusher)
		if !ok {
			t.Fatalf("expected upstream writer to support flush")
		}

		_, _ = w.Write([]byte("event: status\n"))
		_, _ = w.Write([]byte("data: {\"phase\":\"thinking\"}\n\n"))
		flusher.Flush()

		<-releaseUpstream

		_, _ = w.Write([]byte("event: done\n"))
		_, _ = w.Write([]byte("data: {}\n\n"))
		flusher.Flush()
	}))
	defer upstream.Close()

	server := New(config.Config{
		Port:           "8080",
		AllowedOrigins: []string{"*"},
		JWTSecret:      "secret",
		Routes: []config.ServiceRoute{
			{Name: "ai", Prefix: "/api/v1/ai", TargetURL: upstream.URL + "/api/v1/ai"},
		},
	}, newDiscardLogger())

	gateway := httptest.NewServer(server.Handler)
	defer gateway.Close()

	type firstChunkResult struct {
		statusCode int
		firstLine  string
		err        error
	}

	resultCh := make(chan firstChunkResult, 1)
	go func() {
		req, err := http.NewRequest(
			http.MethodPost,
			gateway.URL+"/api/v1/ai/chat-create/threads/stream",
			bytes.NewBufferString(`{"prompt":"stream test"}`),
		)
		if err != nil {
			resultCh <- firstChunkResult{err: err}
			return
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Accept", "text/event-stream")
		req.Header.Set("Authorization", "Bearer "+signedTestToken(t, "secret"))

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			resultCh <- firstChunkResult{err: err}
			return
		}
		defer resp.Body.Close()

		reader := bufio.NewReader(resp.Body)
		line, err := reader.ReadString('\n')
		resultCh <- firstChunkResult{
			statusCode: resp.StatusCode,
			firstLine:  line,
			err:        err,
		}
	}()

	select {
	case result := <-resultCh:
		release()
		if result.err != nil {
			t.Fatalf("expected first stream chunk without error, got %v", result.err)
		}
		if result.statusCode != http.StatusOK {
			t.Fatalf("expected status 200, got %d", result.statusCode)
		}
		if result.firstLine != "event: status\n" {
			t.Fatalf("expected first status line immediately, got %q", result.firstLine)
		}
	case <-time.After(2 * time.Second):
		release()
		t.Fatal("expected first SSE chunk to flush through full gateway stack")
	}
}

func TestGatewayDocsLandingPage(t *testing.T) {
	server := New(config.Config{
		Port:           "8080",
		AllowedOrigins: []string{"*"},
		JWTSecret:      "secret",
	}, newDiscardLogger())

	req := httptest.NewRequest(http.MethodGet, "/docs", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected docs landing page to return 200, got %d", recorder.Code)
	}

	body := recorder.Body.String()
	if !strings.Contains(body, "/api/v1/public/identity/docs") || !strings.Contains(body, "/api/v1/public/ai/docs") || !strings.Contains(body, "/api/v1/public/content/docs") || !strings.Contains(body, "/api/v1/public/notifications/docs") {
		t.Fatalf("expected docs landing page to link service docs, got %q", body)
	}
}

func TestPublicContentHomeBypassesAuth(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/public/content/home" {
			t.Fatalf("expected upstream content home path, got %s", r.URL.Path)
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer upstream.Close()

	server := New(config.Config{
		Port:           "8080",
		AllowedOrigins: []string{"*"},
		JWTSecret:      "secret",
		Routes: []config.ServiceRoute{
			{Name: "content-public", Prefix: "/api/v1/public/content", TargetURL: upstream.URL + "/api/v1/public/content"},
		},
	}, newDiscardLogger())

	req := httptest.NewRequest(http.MethodGet, "/api/v1/public/content/home", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected public content route to bypass auth, got %d", recorder.Code)
	}
}

func TestPublicArticleListBypassesAuth(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/article" {
			t.Fatalf("expected upstream article path, got %s", r.URL.Path)
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer upstream.Close()

	server := New(config.Config{
		Port:           "8080",
		AllowedOrigins: []string{"*"},
		JWTSecret:      "secret",
		Routes: []config.ServiceRoute{
			{Name: "article-public", Prefix: "/api/v1/public/article", TargetURL: upstream.URL + "/api/v1/article"},
		},
	}, newDiscardLogger())

	req := httptest.NewRequest(http.MethodGet, "/api/v1/public/article?limit=5", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected public article route to bypass auth, got %d", recorder.Code)
	}
}

func TestResetPasswordBridgePage(t *testing.T) {
	server := New(config.Config{
		Port:           "8080",
		AllowedOrigins: []string{"*"},
		JWTSecret:      "secret",
	}, newDiscardLogger())

	req := httptest.NewRequest(http.MethodGet, "/reset-password/open?token=abc123", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected reset bridge page to return 200, got %d", recorder.Code)
	}

	body := recorder.Body.String()
	if !strings.Contains(body, "pody://reset-password?token=abc123") {
		t.Fatalf("expected bridge page to contain app deep link, got %q", body)
	}
	if !strings.Contains(body, "Sao chép token") {
		t.Fatalf("expected bridge page to contain fallback copy action, got %q", body)
	}
}

func TestResetPasswordBridgePageRequiresToken(t *testing.T) {
	server := New(config.Config{
		Port:           "8080",
		AllowedOrigins: []string{"*"},
		JWTSecret:      "secret",
	}, newDiscardLogger())

	req := httptest.NewRequest(http.MethodGet, "/reset-password/open", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected reset bridge page without token to return 400, got %d", recorder.Code)
	}
}

func TestVerifyEmailBridgePage(t *testing.T) {
	server := New(config.Config{
		Port:           "8080",
		AllowedOrigins: []string{"*"},
		JWTSecret:      "secret",
	}, newDiscardLogger())

	req := httptest.NewRequest(http.MethodGet, "/verify-email/open?token=abc123", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected verify bridge page to return 200, got %d", recorder.Code)
	}

	body := recorder.Body.String()
	if !strings.Contains(body, "/api/v1/public/identity/verify-email?token=abc123") {
		t.Fatalf("expected verify bridge page to contain verify endpoint, got %q", body)
	}
	if !strings.Contains(body, "pody://sign-in?verified=1") {
		t.Fatalf("expected verify bridge page to contain sign-in deep link, got %q", body)
	}
}

func TestVerifyEmailBridgePageRequiresToken(t *testing.T) {
	server := New(config.Config{
		Port:           "8080",
		AllowedOrigins: []string{"*"},
		JWTSecret:      "secret",
	}, newDiscardLogger())

	req := httptest.NewRequest(http.MethodGet, "/verify-email/open", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected verify bridge page without token to return 400, got %d", recorder.Code)
	}
}
