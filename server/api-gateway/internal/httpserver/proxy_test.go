package httpserver

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

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

func contextWithRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, requestIDKey, requestID)
}
