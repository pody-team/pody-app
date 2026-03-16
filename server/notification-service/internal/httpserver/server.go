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
	"github.com/promex04/pody/server/notification-service/internal/email"
)

type server struct {
	cfg    config.Config
	logger *slog.Logger
	sender email.Sender
}

func New(cfg config.Config, logger *slog.Logger, sender email.Sender) *http.Server {
	s := &server{
		cfg:    cfg,
		logger: logger,
		sender: sender,
	}

	router := chi.NewRouter()
	router.Use(s.withRequestLog)
	router.Use(s.withRecover)

	router.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	router.Route("/internal", func(r chi.Router) {
		r.Use(s.withInternalAPIKey)
		r.Post("/notifications/email/verification", s.handleVerificationEmail)
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

func (s *server) withInternalAPIKey(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.TrimSpace(r.Header.Get("X-Internal-Api-Key")) != s.cfg.InternalAPIKey {
			writeError(w, http.StatusUnauthorized, errors.New("invalid internal api key"))
			return
		}

		next.ServeHTTP(w, r)
	})
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
