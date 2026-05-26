package httpserver

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"mime/multipart"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/promex04/pody/server/identity-service/internal/auth"
	"github.com/promex04/pody/server/identity-service/internal/config"
	"github.com/promex04/pody/server/identity-service/internal/domain"
	"github.com/promex04/pody/server/identity-service/internal/media"
)

// Server đại diện cho HTTP API server của Identity Service.
type Server struct {
	authService     auth.Service        // Service nghiệp vụ xác thực
	logger          *slog.Logger        // Trình ghi log tập trung
	avatarStore     media.AvatarStorage // Storage lưu trữ ảnh đại diện (MinIO/S3)
	maxAvatarBytes  int64               // Kích thước tối đa được phép của ảnh đại diện
	minioBucketName string              // Tên bucket của MinIO lưu ảnh
}

// New cấu hình router, khai báo middleware, định nghĩa các API routes công khai (public) / bảo mật (protected),
// và khởi tạo đối tượng http.Server.
func New(cfg config.Config, logger *slog.Logger, authService auth.Service, avatarStore media.AvatarStorage) *http.Server {
	s := &Server{
		authService:     authService,
		logger:          logger,
		avatarStore:     avatarStore,
		maxAvatarBytes:  cfg.MaxAvatarBytes,
		minioBucketName: strings.TrimSpace(cfg.MinIOBucketName),
	}

	router := chi.NewRouter()
	router.Use(s.withRequestLog) // Middleware log chi tiết các request
	router.Use(s.withRecover)    // Middleware hồi phục từ panic để tránh crash server

	// Endpoint kiểm tra trạng thái hoạt động trực tiếp của service
	router.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// Nhóm các API Endpoint Công Khai (Public API)
	router.Route("/api/v1/public/identity", func(r chi.Router) {
		r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
			writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
		})
		r.Get("/openapi.yaml", s.handleOpenAPI)                  // OpenAPI spec file
		r.Get("/docs", s.handleSwaggerUI)                        // Swagger UI documentation
		r.Post("/sign-up", s.handleSignUp)                       // Đăng ký tài khoản mới
		r.Post("/sign-in", s.handleSignIn)                       // Đăng nhập bằng Email/Password
		r.Post("/google", s.handleGoogleSignIn)                  // Đăng nhập bằng Google OAuth
		r.Post("/refresh", s.handleRefresh)                      // Làm mới Access Token bằng Refresh Token
		r.Post("/sign-out", s.handleSignOut)                     // Đăng xuất và xóa session
		r.Get("/verify-email", s.handleVerifyEmail)              // Xác minh email (GET link)
		r.Post("/verify-email", s.handleVerifyEmail)             // Xác minh email (POST payload)
		r.Post("/resend-verification", s.handleResendVerification)// Gửi lại email xác thực
		r.Post("/forgot-password", s.handleForgotPassword)       // Yêu cầu đổi mật khẩu do quên
		r.Post("/verify-reset-otp", s.handleVerifyResetOTP)       // Xác minh mã OTP reset mật khẩu
		r.Post("/reset-password", s.handleResetPassword)         // Đặt lại mật khẩu mới
	})

	// Nhóm các API Endpoint Bảo Mật (Protected API - yêu cầu JWT gửi từ API Gateway)
	router.Route("/api/v1/identity", func(r chi.Router) {
		r.Get("/me", s.handleMe)                       // Lấy thông tin cá nhân của user hiện tại
		r.Post("/me/avatar", s.handleUploadAvatar)     // Tải ảnh đại diện mới lên MinIO
		r.Patch("/me", s.handleUpdateProfile)          // Cập nhật thông tin profile (display name, bio, v.v.)
		r.Post("/change-password", s.handleChangePassword)// Đổi mật khẩu tài khoản
	})

	return &http.Server{
		Addr:         cfg.Addr(),
		Handler:      router,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  30 * time.Second,
	}
}

// Structs đại diện cho các request payloads đầu vào của các API
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

// handleSignUp xử lý đăng ký người dùng mới.
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

// handleSignIn xử lý đăng nhập bằng email & password.
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

	writeJSON(w, http.StatusOK, s.normalizeOutgoingAuthResponse(r, response))
}

// handleGoogleSignIn xử lý đăng nhập bằng tài khoản Google.
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

	writeJSON(w, http.StatusOK, s.normalizeOutgoingAuthResponse(r, response))
}

// handleRefresh cấp lại Access/Refresh Token mới dựa trên Refresh Token cũ.
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

	writeJSON(w, http.StatusOK, s.normalizeOutgoingAuthResponse(r, response))
}

// handleSignOut đăng xuất người dùng bằng cách thu hồi session liên kết với Refresh Token.
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

// handleVerifyEmail kích hoạt tài khoản người dùng dựa trên token gửi về email.
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
		"user":    s.normalizeOutgoingUser(r, user),
	})
}

// handleResendVerification yêu cầu gửi lại email xác nhận tài khoản.
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

// handleForgotPassword xử lý khi người dùng quên mật khẩu và yêu cầu gửi OTP.
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

// handleResetPassword tiến hành cập nhật mật khẩu mới bằng OTP.
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
		"user":    s.normalizeOutgoingUser(r, user),
	})
}

// handleVerifyResetOTP kiểm tra mã OTP reset mật khẩu có chính xác không.
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

// handleMe trả về thông tin cá nhân của người dùng hiện hành thông qua JWT Access Token.
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

	writeJSON(w, http.StatusOK, map[string]any{"user": s.normalizeOutgoingUser(r, user)})
}

// handleChangePassword đổi mật khẩu cho người dùng đã đăng nhập.
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

// handleUpdateProfile cập nhật các trường profile cơ bản như DisplayName, Username, Bio, AvatarURL.
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

	writeJSON(w, http.StatusOK, map[string]any{"user": s.normalizeOutgoingUser(r, user)})
}

// handleUploadAvatar nhận file ảnh đại diện upload multipart form-data, tải lên MinIO Bucket bất đồng bộ,
// và trả về URL ảnh đại diện đã được chuẩn hóa.
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

	// Đọc giới hạn payload dung lượng
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

	// Thực hiện đẩy file lên MinIO Storage
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

	writeJSON(w, http.StatusCreated, map[string]string{
		"avatar_url": s.normalizeOutgoingAvatarURL(r, avatarURL),
	})
}

// writeAuthError ánh xạ chi tiết các loại lỗi nghiệp vụ Auth sang HTTP Status Code tương ứng.
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

// decodeJSON parse JSON request body vào cấu trúc dữ liệu đích.
func decodeJSON(r *http.Request, destination any) error {
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	return decoder.Decode(destination)
}

// writeJSON ghi mã HTTP Status Code và chuyển đổi dữ liệu payload sang dạng JSON trả về cho client.
func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

// writeError ghi mã lỗi trả về cho HTTP client.
func writeError(w http.ResponseWriter, status int, err error) {
	writeJSON(w, status, map[string]string{"error": err.Error()})
}

// bearerToken trích xuất token chuỗi từ Header Authorization "Bearer <token>".
func bearerToken(header string) string {
	const prefix = "Bearer "
	if !strings.HasPrefix(header, prefix) {
		return ""
	}

	return strings.TrimSpace(strings.TrimPrefix(header, prefix))
}

// normalizeOutgoingAuthResponse chuẩn hóa URL ảnh đại diện trong AuthResponse trả về.
func (s *Server) normalizeOutgoingAuthResponse(r *http.Request, response domain.AuthResponse) domain.AuthResponse {
	response.User = s.normalizeOutgoingUser(r, response.User)
	return response
}

// normalizeOutgoingUser chuẩn hóa URL ảnh đại diện trong cấu trúc User.
func (s *Server) normalizeOutgoingUser(r *http.Request, user domain.User) domain.User {
	user.AvatarURL = s.normalizeOutgoingAvatarURL(r, user.AvatarURL)
	return user
}

// normalizeOutgoingAvatarURL kiểm tra và định dạng lại link ảnh đại diện trả về.
// Hỗ trợ dịch ngược các host nội bộ (ví dụ: "localhost", "minio") của MinIO lưu trong DB thành
// liên kết public URL thông qua X-Forwarded Headers cấu hình bởi API Gateway.
func (s *Server) normalizeOutgoingAvatarURL(r *http.Request, raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}

	parsed, err := url.Parse(raw)
	if err != nil || parsed == nil || strings.TrimSpace(parsed.Host) == "" {
		return raw
	}

	pathSegments := nonEmptySegments(parsed.Path)
	if len(pathSegments) == 0 {
		return raw
	}

	requestHost := forwardedHost(r)
	requestScheme := forwardedScheme(r)
	if requestHost == "" || requestScheme == "" {
		return raw
	}

	if strings.EqualFold(parsed.Host, requestHost) && pathSegments[0] == "minio" {
		return raw
	}

	shouldRewriteInternalHost := isInternalMinioHost(parsed.Host)
	shouldRewriteBucketPath := strings.EqualFold(parsed.Host, requestHost) &&
		s.minioBucketName != "" &&
		pathSegments[0] == s.minioBucketName
	if !shouldRewriteInternalHost && !shouldRewriteBucketPath {
		return raw
	}

	// Chèn segment /minio làm tiền tố của route static reverse proxy qua Gateway
	normalizedSegments := []string{"minio"}
	for _, segment := range pathSegments {
		if segment == "minio" {
			continue
		}
		normalizedSegments = append(normalizedSegments, segment)
	}

	publicURL := &url.URL{
		Scheme:   requestScheme,
		Host:     requestHost,
		Path:     "/" + strings.Join(normalizedSegments, "/"),
		RawQuery: parsed.RawQuery,
		Fragment: parsed.Fragment,
	}
	return publicURL.String()
}

// forwardedHost lấy X-Forwarded-Host header từ proxy hoặc host gốc của request.
func forwardedHost(r *http.Request) string {
	if forwarded := strings.TrimSpace(r.Header.Get("X-Forwarded-Host")); forwarded != "" {
		return forwarded
	}
	return strings.TrimSpace(r.Host)
}

// forwardedScheme lấy X-Forwarded-Proto protocol (http/https) hoặc TLS scheme của request.
func forwardedScheme(r *http.Request) string {
	if forwarded := strings.TrimSpace(r.Header.Get("X-Forwarded-Proto")); forwarded != "" {
		return forwarded
	}
	if r.TLS != nil {
		return "https"
	}
	return "http"
}

// isInternalMinioHost kiểm tra xem host MinIO được lưu trữ có phải là host nội bộ (localhost, minio, pody-minio) hay không.
func isInternalMinioHost(host string) bool {
	normalized := strings.ToLower(strings.TrimSpace(host))
	if parsedHost, _, err := net.SplitHostPort(normalized); err == nil {
		normalized = parsedHost
	}
	return normalized == "localhost" ||
		normalized == "127.0.0.1" ||
		normalized == "0.0.0.0" ||
		normalized == "minio" ||
		normalized == "pody-minio"
}

// nonEmptySegments tách đường dẫn path thành các segment loại bỏ khoảng trống và dấu "/".
func nonEmptySegments(path string) []string {
	parts := strings.Split(path, "/")
	segments := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			segments = append(segments, part)
		}
	}
	return segments
}

// readAvatarPayload giới hạn và đọc toàn bộ dữ liệu byte của ảnh upload.
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

// withRequestLog middleware ghi nhận log log-request cho mỗi API gọi vào server.
func (s *Server) withRequestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		startedAt := time.Now()
		next.ServeHTTP(w, r)
		s.logger.Info("request completed", "method", r.Method, "path", r.URL.Path, "duration", time.Since(startedAt).String())
	})
}

// withRecover middleware bảo vệ tránh crash chương trình khi xảy ra panic, trả về lỗi internal server error.
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

