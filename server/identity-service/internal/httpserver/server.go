package httpserver

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/promex04/pody/server/identity-service/internal/auth"
	"github.com/promex04/pody/server/identity-service/internal/config"
)

type Server struct {
	authService auth.Service
	logger      *slog.Logger
}

func New(cfg config.Config, logger *slog.Logger, authService auth.Service) *http.Server {
	s := &Server{
		authService: authService,
		logger:      logger,
	}

	router := chi.NewRouter()
	router.Use(s.withRequestLog)
	router.Use(s.withRecover)

	router.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	router.Route("/api/v1/public/identity", func(r chi.Router) {
		r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
			writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
		})
		r.Post("/sign-up", s.handleSignUp)
		r.Post("/sign-in", s.handleSignIn)
		r.Post("/google", s.handleGoogleSignIn)
		r.Post("/refresh", s.handleRefresh)
		r.Post("/sign-out", s.handleSignOut)
		r.Get("/verify-email", s.handleVerifyEmail)
		r.Post("/verify-email", s.handleVerifyEmail)
		r.Post("/resend-verification", s.handleResendVerification)
	})

	router.Route("/api/v1/identity", func(r chi.Router) {
		r.Get("/me", s.handleMe)
	})

	return &http.Server{
		Addr:         cfg.Addr(),
		Handler:      router,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  30 * time.Second,
	}
}

type credentialsRequest struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	DisplayName string `json:"display_name"`
}

type googleRequest struct {
	IDToken string `json:"id_token"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type verificationRequest struct {
	Token string `json:"token"`
	Email string `json:"email"`
}

func (s *Server) handleSignUp(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	response, err := s.authService.SignUp(r.Context(), auth.SignUpInput{
		Email:       req.Email,
		Password:    req.Password,
		DisplayName: req.DisplayName,
	})
	if err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusAccepted, response)
}

func (s *Server) handleSignIn(w http.ResponseWriter, r *http.Request) {
	var req credentialsRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	response, err := s.authService.SignIn(r.Context(), auth.SignInInput{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, response)
}

func (s *Server) handleGoogleSignIn(w http.ResponseWriter, r *http.Request) {
	var req googleRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	response, err := s.authService.SignInWithGoogle(r.Context(), req.IDToken)
	if err != nil {
		writeError(w, http.StatusUnauthorized, err)
		return
	}

	writeJSON(w, http.StatusOK, response)
}

func (s *Server) handleRefresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	response, err := s.authService.Refresh(r.Context(), req.RefreshToken)
	if err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, response)
}

func (s *Server) handleSignOut(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	if err := s.authService.SignOut(r.Context(), req.RefreshToken); err != nil {
		s.writeAuthError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handleVerifyEmail(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimSpace(r.URL.Query().Get("token"))
	if token == "" && r.Method == http.MethodPost {
		var req verificationRequest
		if err := decodeJSON(r, &req); err != nil {
			writeError(w, http.StatusBadRequest, err)
			return
		}
		token = req.Token
	}

	user, err := s.authService.VerifyEmail(r.Context(), token)
	if err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"message": "email verified successfully",
		"user":    user,
	})
}

func (s *Server) handleResendVerification(w http.ResponseWriter, r *http.Request) {
	var req verificationRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	response, err := s.authService.ResendVerification(r.Context(), req.Email)
	if err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusAccepted, response)
}

func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	token := bearerToken(r.Header.Get("Authorization"))
	if token == "" {
		writeError(w, http.StatusUnauthorized, errors.New("missing bearer token"))
		return
	}

	user, err := s.authService.Me(r.Context(), token)
	if err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"user": user})
}

func (s *Server) writeAuthError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, auth.ErrUserExists):
		writeError(w, http.StatusConflict, err)
	case errors.Is(err, auth.ErrInvalidSignUpInput):
		writeError(w, http.StatusBadRequest, err)
	case errors.Is(err, auth.ErrEmailNotVerified):
		writeError(w, http.StatusForbidden, err)
	case errors.Is(err, auth.ErrInvalidVerificationToken):
		writeError(w, http.StatusBadRequest, err)
	case errors.Is(err, auth.ErrInvalidCredentials), errors.Is(err, auth.ErrInvalidRefresh):
		writeError(w, http.StatusUnauthorized, err)
	default:
		writeError(w, http.StatusInternalServerError, err)
	}
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

func bearerToken(header string) string {
	const prefix = "Bearer "
	if !strings.HasPrefix(header, prefix) {
		return ""
	}

	return strings.TrimSpace(strings.TrimPrefix(header, prefix))
}

func (s *Server) withRequestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		startedAt := time.Now()
		next.ServeHTTP(w, r)
		s.logger.Info("request completed", "method", r.Method, "path", r.URL.Path, "duration", time.Since(startedAt).String())
	})
}

func (s *Server) withRecover(next http.Handler) http.Handler {
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
