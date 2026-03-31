package httpserver

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/promex04/pody/server/notification-service/internal/config"
	"github.com/promex04/pody/server/notification-service/internal/domain"
	"github.com/promex04/pody/server/notification-service/internal/email"
	"github.com/promex04/pody/server/notification-service/internal/store"
)

type server struct {
	cfg               config.Config
	logger            *slog.Logger
	sender            email.Sender
	notificationStore store.NotificationStore
}

type notificationSettingsRequest struct {
	PushEnabled       bool `json:"push_enabled"`
	EmailEnabled      bool `json:"email_enabled"`
	NewEpisodeEnabled bool `json:"new_episode_enabled"`
	CommentEnabled    bool `json:"comment_enabled"`
	FollowEnabled     bool `json:"follow_enabled"`
	MarketingEnabled  bool `json:"marketing_enabled"`
}

type devSeedNotificationsRequest struct {
	UserID string `json:"user_id"`
}

type createInboxNotificationRequest struct {
	UserID         string               `json:"user_id"`
	ActorUserID    string               `json:"actor_user_id"`
	Type           string               `json:"type"`
	TargetType     string               `json:"target_type"`
	TargetID       string               `json:"target_id"`
	Title          string               `json:"title"`
	Body           string               `json:"body"`
	Preview        string               `json:"preview"`
	ActorSnapshot  domain.ActorSnapshot `json:"actor_snapshot"`
	TargetSnapshot domain.TargetSnapshot `json:"target_snapshot"`
}

func New(cfg config.Config, logger *slog.Logger, sender email.Sender, notificationStore store.NotificationStore) *http.Server {
	s := &server{
		cfg:               cfg,
		logger:            logger,
		sender:            sender,
		notificationStore: notificationStore,
	}

	router := chi.NewRouter()
	router.Use(s.withRequestLog)
	router.Use(s.withRecover)

	router.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	router.Route("/api/v1/public/notifications", func(r chi.Router) {
		r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
			writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
		})
		r.Get("/openapi.yaml", s.handleOpenAPI)
		r.Get("/docs", s.handleSwaggerUI)
	})

	router.Route("/api/v1/notifications", func(r chi.Router) {
		r.Get("/", s.handleListNotifications)
		r.Get("/unread-count", s.handleUnreadCount)
		r.Patch("/read-all", s.handleReadAll)
		r.Patch("/{notificationID}/read", s.handleReadNotification)
		r.Get("/settings", s.handleGetSettings)
		r.Put("/settings", s.handleUpdateSettings)
	})

	router.Route("/internal", func(r chi.Router) {
		r.Use(s.withInternalAPIKey)
		r.Post("/notifications/email/verification", s.handleVerificationEmail)
		r.Post("/notifications/inbox", s.handleCreateInboxNotification)
		r.Post("/notifications/dev/seed-inbox", s.handleSeedInbox)
	})

	return &http.Server{
		Addr:         cfg.Addr(),
		Handler:      router,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  30 * time.Second,
	}
}

func (s *server) handleVerificationEmail(w http.ResponseWriter, r *http.Request) {
	var request email.VerificationMessage
	if err := decodeJSON(r, &request); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	if strings.TrimSpace(request.ToEmail) == "" || strings.TrimSpace(request.VerificationURL) == "" {
		writeError(w, http.StatusBadRequest, errors.New("to_email and verification_url are required"))
		return
	}

	if err := s.sender.SendVerification(r.Context(), request); err != nil {
		writeError(w, http.StatusBadGateway, err)
		return
	}

	writeJSON(w, http.StatusAccepted, map[string]string{"status": "queued"})
}

func (s *server) handleSeedInbox(w http.ResponseWriter, r *http.Request) {
	var req devSeedNotificationsRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	userID := strings.TrimSpace(req.UserID)
	if userID == "" {
		writeError(w, http.StatusBadRequest, errors.New("user_id is required"))
		return
	}

	insertedCount, err := s.notificationStore.SeedDemoNotifications(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusAccepted, map[string]any{
		"status":         "seeded",
		"inserted_count": insertedCount,
		"user_id":        userID,
	})
}

func (s *server) handleCreateInboxNotification(w http.ResponseWriter, r *http.Request) {
	var req createInboxNotificationRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	notification, err := s.notificationStore.CreateNotification(r.Context(), domain.CreateNotificationInput{
		UserID:         req.UserID,
		ActorUserID:    req.ActorUserID,
		Type:           req.Type,
		TargetType:     req.TargetType,
		TargetID:       req.TargetID,
		Title:          req.Title,
		Body:           req.Body,
		Preview:        req.Preview,
		ActorSnapshot:  req.ActorSnapshot,
		TargetSnapshot: req.TargetSnapshot,
	})
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "required") {
			writeError(w, http.StatusBadRequest, err)
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusAccepted, map[string]any{
		"status":       "queued",
		"notification": notification,
	})
}

func (s *server) handleListNotifications(w http.ResponseWriter, r *http.Request) {
	userID, ok := authUserID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return
	}

	notifications, err := s.notificationStore.ListNotifications(r.Context(), userID, 50)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"notifications": notifications})
}

func (s *server) handleUnreadCount(w http.ResponseWriter, r *http.Request) {
	userID, ok := authUserID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return
	}

	count, err := s.notificationStore.CountUnreadNotifications(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]int{"unread_count": count})
}

func (s *server) handleReadNotification(w http.ResponseWriter, r *http.Request) {
	userID, ok := authUserID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return
	}

	notificationID := strings.TrimSpace(chi.URLParam(r, "notificationID"))
	if notificationID == "" {
		writeError(w, http.StatusBadRequest, errors.New("notification id is required"))
		return
	}

	updated, err := s.notificationStore.MarkNotificationRead(r.Context(), userID, notificationID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"updated": updated})
}

func (s *server) handleReadAll(w http.ResponseWriter, r *http.Request) {
	userID, ok := authUserID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return
	}

	updatedCount, err := s.notificationStore.MarkAllNotificationsRead(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"updated_count": updatedCount})
}

func (s *server) handleGetSettings(w http.ResponseWriter, r *http.Request) {
	userID, ok := authUserID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return
	}

	settings, err := s.notificationStore.GetNotificationSettings(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"settings": settings})
}

func (s *server) handleUpdateSettings(w http.ResponseWriter, r *http.Request) {
	userID, ok := authUserID(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return
	}

	var req notificationSettingsRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	settings, err := s.notificationStore.UpsertNotificationSettings(r.Context(), domain.NotificationSettings{
		UserID:            userID,
		PushEnabled:       req.PushEnabled,
		EmailEnabled:      req.EmailEnabled,
		NewEpisodeEnabled: req.NewEpisodeEnabled,
		CommentEnabled:    req.CommentEnabled,
		FollowEnabled:     req.FollowEnabled,
		MarketingEnabled:  req.MarketingEnabled,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"settings": settings})
}

func (s *server) withInternalAPIKey(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.TrimSpace(r.Header.Get("X-Internal-Api-Key")) != s.cfg.InternalAPIKey {
			writeError(w, http.StatusUnauthorized, errors.New("invalid internal api key"))
			return
		}

		next.ServeHTTP(w, r)
	})
}

func authUserID(r *http.Request) (string, bool) {
	userID := strings.TrimSpace(r.Header.Get("X-Auth-User-ID"))
	return userID, userID != ""
}

func (s *server) withRequestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		startedAt := time.Now()
		next.ServeHTTP(w, r)
		s.logger.Info("request completed", "method", r.Method, "path", r.URL.Path, "duration", time.Since(startedAt).String())
	})
}

func (s *server) withRecover(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				s.logger.Error("panic recovered", "panic", recovered)
				writeError(w, http.StatusInternalServerError, errors.New("internal server error"))
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func decodeJSON(r *http.Request, destination any) error {
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	return decoder.Decode(destination)
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, err error) {
	writeJSON(w, status, map[string]string{"error": err.Error()})
}
