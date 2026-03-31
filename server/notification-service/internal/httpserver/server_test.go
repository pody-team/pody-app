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
	"github.com/promex04/pody/server/notification-service/internal/domain"
	"github.com/promex04/pody/server/notification-service/internal/email"
)

type fakeSender struct {
	messages []email.VerificationMessage
}

type fakeNotificationStore struct {
	notifications []domain.Notification
	settings      domain.NotificationSettings
	unreadCount   int
	seededForUser string
	created       []domain.CreateNotificationInput
}

func (f *fakeSender) SendVerification(_ context.Context, message email.VerificationMessage) error {
	f.messages = append(f.messages, message)
	return nil
}

func (f *fakeSender) SendPasswordReset(context.Context, email.PasswordResetMessage) error {
	return nil
}

func (f *fakeSender) ProviderName() string {
	return "log"
}

func (f *fakeNotificationStore) ListNotifications(context.Context, string, int) ([]domain.Notification, error) {
	return f.notifications, nil
}

func (f *fakeNotificationStore) CountUnreadNotifications(context.Context, string) (int, error) {
	return f.unreadCount, nil
}

func (f *fakeNotificationStore) MarkNotificationRead(context.Context, string, string) (bool, error) {
	return true, nil
}

func (f *fakeNotificationStore) MarkAllNotificationsRead(context.Context, string) (int64, error) {
	return int64(f.unreadCount), nil
}

func (f *fakeNotificationStore) GetNotificationSettings(context.Context, string) (domain.NotificationSettings, error) {
	return f.settings, nil
}

func (f *fakeNotificationStore) UpsertNotificationSettings(_ context.Context, settings domain.NotificationSettings) (domain.NotificationSettings, error) {
	f.settings = settings
	return settings, nil
}

func (f *fakeNotificationStore) CreateNotification(_ context.Context, input domain.CreateNotificationInput) (domain.Notification, error) {
	f.created = append(f.created, input)
	return domain.Notification{
		ID:             "notif-1",
		UserID:         input.UserID,
		Type:           input.Type,
		TargetType:     input.TargetType,
		TargetID:       input.TargetID,
		Title:          input.Title,
		Body:           input.Body,
		ActorSnapshot:  input.ActorSnapshot,
		TargetSnapshot: input.TargetSnapshot,
		CreatedAt:      time.Date(2026, time.March, 30, 7, 0, 0, 0, time.UTC),
	}, nil
}

func (f *fakeNotificationStore) SeedDemoNotifications(_ context.Context, userID string) (int, error) {
	f.seededForUser = userID
	return 4, nil
}

func TestHandleVerificationEmailRequiresInternalAPIKey(t *testing.T) {
	sender := &fakeSender{}
	server := New(config.Config{
		Port:           "8087",
		InternalAPIKey: "change-me",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), sender, &fakeNotificationStore{})

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
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), sender, &fakeNotificationStore{})

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

func TestHandleCreateInboxNotificationQueuesMessage(t *testing.T) {
	store := &fakeNotificationStore{}
	server := New(config.Config{
		Port:           "8087",
		InternalAPIKey: "change-me",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), &fakeSender{}, store)

	request := httptest.NewRequest(http.MethodPost, "/internal/notifications/inbox", strings.NewReader(`{
		"user_id":"creator-1",
		"type":"milestone",
		"target_type":"show",
		"target_id":"show-1",
		"title":"Show da san sang",
		"body":"AI Builder Lab da duoc tao xong.",
		"actor_snapshot":{"display_name":"Pody AI","avatar_url":"https://example.com/ai.png"},
		"target_snapshot":{"title":"AI Builder Lab"}
	}`))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Internal-Api-Key", "change-me")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d with body %q", recorder.Code, recorder.Body.String())
	}
	if len(store.created) != 1 {
		t.Fatalf("expected one created notification, got %d", len(store.created))
	}
	if store.created[0].TargetID != "show-1" {
		t.Fatalf("unexpected target id %q", store.created[0].TargetID)
	}
}

func TestHealthz(t *testing.T) {
	server := New(config.Config{
		Port:            "8087",
		InternalAPIKey:  "change-me",
		ShutdownTimeout: 10 * time.Second,
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), &fakeSender{}, &fakeNotificationStore{})

	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
}

func TestOpenAPIYAMLEndpoint(t *testing.T) {
	server := New(config.Config{
		Port:           "8087",
		InternalAPIKey: "change-me",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), &fakeSender{}, &fakeNotificationStore{})

	request := httptest.NewRequest(http.MethodGet, "/api/v1/public/notifications/openapi.yaml", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "openapi: 3.0.3") {
		t.Fatalf("expected OpenAPI document, got %q", recorder.Body.String())
	}
	if !strings.Contains(recorder.Body.String(), "/api/v1/notifications/settings:") {
		t.Fatalf("expected protected notification endpoints in spec, got %q", recorder.Body.String())
	}
}

func TestSwaggerUIDocsEndpoint(t *testing.T) {
	server := New(config.Config{
		Port:           "8087",
		InternalAPIKey: "change-me",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), &fakeSender{}, &fakeNotificationStore{})

	request := httptest.NewRequest(http.MethodGet, "/api/v1/public/notifications/docs", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "SwaggerUIBundle") {
		t.Fatalf("expected Swagger UI page, got %q", recorder.Body.String())
	}
}

func TestListNotificationsRequiresAuthUserID(t *testing.T) {
	server := New(config.Config{
		Port:           "8087",
		InternalAPIKey: "change-me",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), &fakeSender{}, &fakeNotificationStore{})

	request := httptest.NewRequest(http.MethodGet, "/api/v1/notifications", nil)
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", recorder.Code)
	}
}

func TestListNotificationsReturnsInbox(t *testing.T) {
	store := &fakeNotificationStore{
		notifications: []domain.Notification{
			{
				ID:    "n-1",
				Title: "New like",
				Body:  "Somebody liked your episode",
				Type:  "like",
			},
		},
	}
	server := New(config.Config{
		Port:           "8087",
		InternalAPIKey: "change-me",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), &fakeSender{}, store)

	request := httptest.NewRequest(http.MethodGet, "/api/v1/notifications", nil)
	request.Header.Set("X-Auth-User-ID", "user-1")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", recorder.Code)
	}

	var response struct {
		Notifications []domain.Notification `json:"notifications"`
	}
	if err := json.NewDecoder(recorder.Body).Decode(&response); err != nil {
		t.Fatalf("decode response: %v", err)
	}

	if len(response.Notifications) != 1 || response.Notifications[0].ID != "n-1" {
		t.Fatalf("unexpected notifications response: %+v", response.Notifications)
	}
}

func TestSeedInboxRequiresUserID(t *testing.T) {
	store := &fakeNotificationStore{}
	server := New(config.Config{
		Port:           "8087",
		InternalAPIKey: "change-me",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), &fakeSender{}, store)

	request := httptest.NewRequest(
		http.MethodPost,
		"/internal/notifications/dev/seed-inbox",
		strings.NewReader(`{}`),
	)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Internal-Api-Key", "change-me")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", recorder.Code)
	}
}

func TestSeedInboxInsertsDemoNotifications(t *testing.T) {
	store := &fakeNotificationStore{}
	server := New(config.Config{
		Port:           "8087",
		InternalAPIKey: "change-me",
	}, slog.New(slog.NewTextHandler(io.Discard, nil)), &fakeSender{}, store)

	request := httptest.NewRequest(
		http.MethodPost,
		"/internal/notifications/dev/seed-inbox",
		strings.NewReader(`{"user_id":"e6f3b79e-3df4-4687-8447-71c71a1b50dc"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-Internal-Api-Key", "change-me")
	recorder := httptest.NewRecorder()

	server.Handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d", recorder.Code)
	}

	if store.seededForUser != "e6f3b79e-3df4-4687-8447-71c71a1b50dc" {
		t.Fatalf("expected seed user id to be captured, got %q", store.seededForUser)
	}
}
