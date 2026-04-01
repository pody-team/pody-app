package httpserver

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"mime/multipart"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/promex04/pody/server/identity-service/internal/auth"
	"github.com/promex04/pody/server/identity-service/internal/config"
	"github.com/promex04/pody/server/identity-service/internal/media"
)

type Server struct {
	authService    auth.Service
	logger         *slog.Logger
	avatarStore    media.AvatarStorage
	maxAvatarBytes int64
}

func New(cfg config.Config, logger *slog.Logger, authService auth.Service, avatarStore media.AvatarStorage) *http.Server {
	s := &Server{
		authService:    authService,
		logger:         logger,
		avatarStore:    avatarStore,
		maxAvatarBytes: cfg.MaxAvatarBytes,
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
		r.Get("/openapi.yaml", s.handleOpenAPI)
		r.Get("/docs", s.handleSwaggerUI)
		r.Post("/sign-up", s.handleSignUp)
		r.Post("/sign-in", s.handleSignIn)
		r.Post("/google", s.handleGoogleSignIn)
		r.Post("/refresh", s.handleRefresh)
		r.Post("/sign-out", s.handleSignOut)
		r.Get("/verify-email", s.handleVerifyEmail)
		r.Post("/verify-email", s.handleVerifyEmail)
		r.Post("/resend-verification", s.handleResendVerification)
		r.Post("/forgot-password", s.handleForgotPassword)
		r.Post("/verify-reset-otp", s.handleVerifyResetOTP)
		r.Post("/reset-password", s.handleResetPassword)
	})

	router.Route("/api/v1/identity", func(r chi.Router) {
		r.Get("/me", s.handleMe)
		r.Post("/me/avatar", s.handleUploadAvatar)
		r.Patch("/me", s.handleUpdateProfile)
		r.Post("/change-password", s.handleChangePassword)
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

type resetPasswordRequest struct {
	Email       string `json:"email"`
	OTP         string `json:"otp"`
	NewPassword string `json:"new_password"`
}

type verifyResetOTPRequest struct {
	Email string `json:"email"`
	OTP   string `json:"otp"`
}

type changePasswordRequest struct {
	CurrentPassword string `json:"current_password"`
	NewPassword     string `json:"new_password"`
}

type updateProfileRequest struct {
	DisplayName *string `json:"display_name"`
	Username    *string `json:"username"`
	Bio         *string `json:"bio"`
	AvatarURL   *string `json:"avatar_url"`
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

func (s *Server) handleForgotPassword(w http.ResponseWriter, r *http.Request) {
	var req verificationRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	response, err := s.authService.ForgotPassword(r.Context(), req.Email)
	if err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusAccepted, response)
}

func (s *Server) handleResetPassword(w http.ResponseWriter, r *http.Request) {
	var req resetPasswordRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	user, err := s.authService.ResetPassword(r.Context(), auth.ResetPasswordInput{
		Email:       req.Email,
		OTP:         req.OTP,
		NewPassword: req.NewPassword,
	})
	if err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"message": "password reset successful",
		"user":    user,
	})
}

func (s *Server) handleVerifyResetOTP(w http.ResponseWriter, r *http.Request) {
	var req verifyResetOTPRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	if err := s.authService.VerifyResetOTP(r.Context(), auth.VerifyResetOTPInput{
		Email: req.Email,
		OTP:   req.OTP,
	}); err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"message": "password reset otp verified",
	})
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

func (s *Server) handleChangePassword(w http.ResponseWriter, r *http.Request) {
	token := bearerToken(r.Header.Get("Authorization"))
	if token == "" {
		writeError(w, http.StatusUnauthorized, errors.New("missing bearer token"))
		return
	}

	var req changePasswordRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	if err := s.authService.ChangePassword(r.Context(), token, auth.ChangePasswordInput{
		CurrentPassword: req.CurrentPassword,
		NewPassword:     req.NewPassword,
	}); err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"message": "password changed successfully",
	})
}

func (s *Server) handleUpdateProfile(w http.ResponseWriter, r *http.Request) {
	token := bearerToken(r.Header.Get("Authorization"))
	if token == "" {
		writeError(w, http.StatusUnauthorized, errors.New("missing bearer token"))
		return
	}

	var req updateProfileRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	user, err := s.authService.UpdateProfile(r.Context(), token, auth.UpdateProfileInput{
		DisplayName: req.DisplayName,
		Username:    req.Username,
		Bio:         req.Bio,
		AvatarURL:   req.AvatarURL,
	})
	if err != nil {
		s.writeAuthError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"user": user})
}

func (s *Server) handleUploadAvatar(w http.ResponseWriter, r *http.Request) {
	token := bearerToken(r.Header.Get("Authorization"))
	if token == "" {
		writeError(w, http.StatusUnauthorized, errors.New("missing bearer token"))
		return
	}

	if s.avatarStore == nil {
		writeError(w, http.StatusServiceUnavailable, errors.New("avatar upload is not configured"))
		return
	}

	user, err := s.authService.Me(r.Context(), token)
	if err != nil {
		s.writeAuthError(w, err)
		return
	}

	maxAvatarBytes := s.maxAvatarBytes
	if maxAvatarBytes <= 0 {
		maxAvatarBytes = 5 << 20
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxAvatarBytes+(1<<20))
	if err := r.ParseMultipartForm(maxAvatarBytes + (1 << 20)); err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid multipart form"))
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, http.StatusBadRequest, errors.New("avatar file is required"))
		return
	}
	defer file.Close()

	fileBytes, err := readAvatarPayload(file, maxAvatarBytes)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}

	uploadCtx, cancel := media.UploadTimeoutContext(r.Context())
	defer cancel()

	avatarURL, err := s.avatarStore.UploadAvatar(
		uploadCtx,
		user.ID,
		header.Filename,
		header.Header.Get("Content-Type"),
		bytes.NewReader(fileBytes),
		int64(len(fileBytes)),
	)
	if err != nil {
		switch {
		case errors.Is(err, media.ErrAvatarTooLarge), errors.Is(err, media.ErrAvatarContentType):
			writeError(w, http.StatusBadRequest, err)
		default:
			s.logger.Error("avatar upload failed", "user_id", user.ID, "error", err)
			writeError(w, http.StatusBadGateway, errors.New("failed to upload avatar"))
		}
		return
	}

	writeJSON(w, http.StatusCreated, map[string]string{"avatar_url": avatarURL})
}

func (s *Server) writeAuthError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, auth.ErrUserExists):
		writeError(w, http.StatusConflict, err)
	case errors.Is(err, auth.ErrInvalidSignUpInput):
		writeError(w, http.StatusBadRequest, err)
	case errors.Is(err, auth.ErrInvalidChangePassword), errors.Is(err, auth.ErrPasswordAuthUnavailable):
		writeError(w, http.StatusBadRequest, err)
	case errors.Is(err, auth.ErrInvalidProfileUpdate):
		writeError(w, http.StatusBadRequest, err)
	case errors.Is(err, auth.ErrEmailNotVerified):
		writeError(w, http.StatusForbidden, err)
	case errors.Is(err, auth.ErrUsernameAlreadyExists):
		writeError(w, http.StatusConflict, err)
	case errors.Is(err, auth.ErrInvalidVerificationToken), errors.Is(err, auth.ErrInvalidPasswordReset), errors.Is(err, auth.ErrInvalidResetInput):
		writeError(w, http.StatusBadRequest, err)
	case errors.Is(err, auth.ErrInvalidCurrentPassword):
		writeError(w, http.StatusUnauthorized, err)
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

func readAvatarPayload(file multipart.File, maxReadBytes int64) ([]byte, error) {
	if maxReadBytes <= 0 {
		maxReadBytes = 5 << 20
	}
	payload, err := io.ReadAll(io.LimitReader(file, maxReadBytes+1))
	if err != nil {
		return nil, errors.New("failed to read avatar file")
	}
	if len(payload) == 0 {
		return nil, errors.New("avatar file is empty")
	}
	if int64(len(payload)) > maxReadBytes {
		return nil, media.ErrAvatarTooLarge
	}
	return payload, nil
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
