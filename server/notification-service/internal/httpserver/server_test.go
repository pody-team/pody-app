package httpserver

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/promex04/pody/server/notification-service/internal/config"
	"github.com/promex04/pody/server/notification-service/internal/email"
)

type fakeSender struct {
	messages []email.VerificationMessage
}

func (f *fakeSender) SendVerification(_ context.Context, message email.VerificationMessage) error {
	f.messages = append(f.messages, message)
	return nil
}

func TestHandleVerificationEmailRequiresInternalAPIKey(t *testing.T) {
	sender := &fakeSender{}
	server := New(config.Config{
		Port:           "8087",
		InternalAPIKey: "change-me",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), sender)

	request := httptest.NewRequest(http.MethodPost, "/internal/notifications/email/verification", strings.NewReader(`{"to_email":"hello@pody.vn","verification_url":"http://localhost"}`))
	request.Header.Set("Content-Type", "application/json")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 without internal api key, got %d", recorder.Code)
	}
}

func TestHandleVerificationEmailQueuesMessage(t *testing.T) {
	sender := &fakeSender{}
	server := New(config.Config{
		Port:           "8087",
		InternalAPIKey: "change-me",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), sender)

	request := httptest.NewRequest(http.MethodPost, "/internal/notifications/email/verification", strings.NewReader(`{
		"to_email":"hello@pody.vn",
		"to_display_name":"Promex",
		"verification_url":"http://localhost:8080/api/v1/public/identity/verify-email?token=abc",
		"expires_at":"2026-03-16T12:00:00Z"
	}`))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Internal-Api-Key", "change-me")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", recorder.Code)
	}

	if len(sender.messages) != 1 {
		t.Fatalf("expected one verification message, got %d", len(sender.messages))
	}

	if sender.messages[0].ToEmail != "hello@pody.vn" {
		t.Fatalf("unexpected recipient %q", sender.messages[0].ToEmail)
	}

	var response map[string]string
	if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if response["status"] != "queued" {
		t.Fatalf("unexpected response body: %+v", response)
	}
}

func TestHealthz(t *testing.T) {
	server := New(config.Config{
		Port:            "8087",
		InternalAPIKey:  "change-me",
		ShutdownTimeout: 10 * time.Second,
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), &fakeSender{})

	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
}
