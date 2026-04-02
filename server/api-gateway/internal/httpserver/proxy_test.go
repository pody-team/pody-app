package httpserver

import (
	"bufio"
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/promex04/pody/server/api-gateway/internal/config"
)

func TestServiceProxyStripsPublicPrefix(t *testing.T) {
	var receivedPath string
	var receivedQuery string
	var receivedRequestID string
	var receivedForwardedPrefix string

	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedPath = r.URL.Path
		receivedQuery = r.URL.RawQuery
		receivedRequestID = r.Header.Get("X-Request-ID")
		receivedForwardedPrefix = r.Header.Get("X-Forwarded-Prefix")
		w.WriteHeader(http.StatusAccepted)
	}))
	defer upstream.Close()

	proxy, err := newServiceProxy(config.ServiceRoute{
		Name:      "social",
		Prefix:    "/api/v1/social",
		TargetURL: upstream.URL,
	}, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatalf("newServiceProxy() returned error: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/v1/social/comments?limit=10", nil)
	req = req.WithContext(contextWithRequestID(req.Context(), "req-123"))
	recorder := httptest.NewRecorder()

	proxy.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusAccepted {
		t.Fatalf("expected status 202 from upstream, got %d", recorder.Code)
	}

	if receivedPath != "/comments" {
		t.Fatalf("expected forwarded path /comments, got %s", receivedPath)
	}

	if receivedQuery != "limit=10" {
		t.Fatalf("expected query limit=10, got %s", receivedQuery)
	}

	if receivedRequestID != "req-123" {
		t.Fatalf("expected request ID req-123, got %s", receivedRequestID)
	}

	if receivedForwardedPrefix != "/api/v1/social" {
		t.Fatalf("expected forwarded prefix header, got %s", receivedForwardedPrefix)
	}
}

func TestServiceProxyRoutesPrefixRootToUpstreamRoot(t *testing.T) {
	var receivedPath string

	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedPath = r.URL.Path
		w.WriteHeader(http.StatusOK)
	}))
	defer upstream.Close()

	proxy, err := newServiceProxy(config.ServiceRoute{
		Name:      "identity",
		Prefix:    "/api/v1/identity",
		TargetURL: upstream.URL,
	}, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatalf("newServiceProxy() returned error: %v", err)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/v1/identity", nil)
	recorder := httptest.NewRecorder()

	proxy.ServeHTTP(recorder, req)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", recorder.Code)
	}

	if receivedPath != "/" {
		t.Fatalf("expected forwarded root path /, got %s", receivedPath)
	}
}

func TestServiceProxyFlushesEventStreamChunks(t *testing.T) {
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
		if r.URL.Path != "/chat-create/threads/stream" {
			t.Fatalf("expected upstream stream path, got %s", r.URL.Path)
		}

		w.Header().Set("Content-Type", "text/event-stream")
		flusher, ok := w.(http.Flusher)
		if !ok {
			t.Fatalf("expected upstream writer to support flush")
		}

		_, _ = io.WriteString(w, "event: status\n")
		_, _ = io.WriteString(w, "data: {\"phase\":\"thinking\"}\n\n")
		flusher.Flush()

		<-releaseUpstream

		_, _ = io.WriteString(w, "event: done\n")
		_, _ = io.WriteString(w, "data: {}\n\n")
		flusher.Flush()
	}))
	defer upstream.Close()

	proxy, err := newServiceProxy(config.ServiceRoute{
		Name:      "ai",
		Prefix:    "/api/v1/ai",
		TargetURL: upstream.URL,
	}, slog.New(slog.NewTextHandler(io.Discard, nil)))
	if err != nil {
		t.Fatalf("newServiceProxy() returned error: %v", err)
	}

	gateway := httptest.NewServer(proxy)
	defer gateway.Close()

	type firstChunkResult struct {
		statusCode int
		firstLine  string
		err        error
	}

	resultCh := make(chan firstChunkResult, 1)
	go func() {
		resp, err := http.Get(gateway.URL + "/api/v1/ai/chat-create/threads/stream")
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
			t.Fatalf("expected first event line to flush immediately, got %q", result.firstLine)
		}
	case <-time.After(2 * time.Second):
		release()
		t.Fatal("expected gateway to flush first SSE chunk before upstream completed")
	}
}

func contextWithRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, requestIDKey, requestID)
}
