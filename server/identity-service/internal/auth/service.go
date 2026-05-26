package auth

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/promex04/pody/server/identity-service/internal/domain"
	"github.com/promex04/pody/server/identity-service/internal/googleauth"
	"github.com/promex04/pody/server/identity-service/internal/notification"
	"github.com/promex04/pody/server/identity-service/internal/store"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials       = errors.New("invalid credentials")
	ErrInvalidRefresh           = errors.New("invalid refresh token")
	ErrUserExists               = errors.New("user already exists")
	ErrInvalidSignUpInput       = errors.New("email, display name, and password with at least 8 characters are required")
	ErrEmailNotVerified         = errors.New("email is not verified")
	ErrInvalidVerificationToken = errors.New("invalid or expired verification token")
	ErrInvalidPasswordReset     = errors.New("invalid or expired password reset otp")
	ErrInvalidResetInput        = errors.New("email, otp, and a new password with at least 8 characters are required")
	ErrInvalidChangePassword    = errors.New("current password and a new password with at least 8 characters are required")
	ErrInvalidCurrentPassword   = errors.New("current password is incorrect")
	ErrPasswordAuthUnavailable  = errors.New("password sign-in is not available for this account")
	ErrInvalidProfileUpdate     = errors.New("display name, username, bio, or avatar url is invalid")
	ErrUsernameAlreadyExists    = errors.New("username already exists")
)

const passwordResetOTPLength = 6

// usernamePattern định nghĩa mẫu regex kiểm tra độ hợp lệ của username: chỉ chứa chữ thường, số, dấu chấm và dấu gạch dưới.
var usernamePattern = regexp.MustCompile(`^[a-z0-9._]+$`)

// Service là service nghiệp vụ chính xử lý việc Xác thực, Đăng ký, Đăng nhập, Đổi mật khẩu, và Outbox Event.
type Service struct {
	repo                store.Repository    // Nơi lưu trữ, truy vấn dữ liệu từ Database
	tokenManager        TokenManager        // Trình quản lý sinh/xác thực JWT
	googleVerify        googleauth.Verifier // Trình verify Google ID Token
	verificationTTL     time.Duration       // Thời gian sống của liên kết xác nhận email
	verificationURLBase string              // URL cơ sở của trang xác thực email gửi cho người dùng
	verificationTopic   string              // Topic Kafka gửi sự kiện yêu cầu xác thực email
	resetTTL            time.Duration       // Thời gian sống của mã OTP reset mật khẩu
	resetTopic          string              // Topic Kafka gửi sự kiện yêu cầu reset mật khẩu
}

// NewService khởi tạo auth Service mới với các thành phần phụ thuộc.
func NewService(
	repo store.Repository,
	tokenManager TokenManager,
	googleVerify googleauth.Verifier,
	verificationTTL time.Duration,
	verificationURLBase string,
	verificationTopic string,
	resetTTL time.Duration,
	resetTopic string,
) Service {
	return Service{
		repo:                repo,
		tokenManager:        tokenManager,
		googleVerify:        googleVerify,
		verificationTTL:     verificationTTL,
		verificationURLBase: verificationURLBase,
		verificationTopic:   verificationTopic,
		resetTTL:            resetTTL,
		resetTopic:          resetTopic,
	}
}

// SignUpInput chứa dữ liệu đầu vào khi người dùng đăng ký tài khoản mới.
type SignUpInput struct {
	Email       string
	Password    string
	DisplayName string
}

// SignInInput chứa dữ liệu đầu vào khi người dùng đăng nhập bằng email/password.
type SignInInput struct {
	Email    string
	Password string
}

// ResetPasswordInput chứa dữ liệu đầu vào khi người dùng tiến hành đặt lại mật khẩu mới.
type ResetPasswordInput struct {
	Email       string
	OTP         string
	NewPassword string
}

// VerifyResetOTPInput chứa dữ liệu đầu vào để kiểm tra mã OTP reset mật khẩu.
type VerifyResetOTPInput struct {
	Email string
	OTP   string
}

// ChangePasswordInput chứa dữ liệu đầu vào khi người dùng đang hoạt động yêu cầu đổi mật khẩu.
type ChangePasswordInput struct {
	CurrentPassword string
	NewPassword     string
}

// UpdateProfileInput chứa dữ liệu cập nhật thông tin cá nhân.
type UpdateProfileInput struct {
	DisplayName *string
	Username    *string
	Bio         *string
	AvatarURL   *string
}

// SignUp đăng ký người dùng mới bằng Email và Mật khẩu.
// Mật khẩu được băm (hash) bằng bcrypt. Tài khoản tạo mới sẽ ở trạng thái chờ xác thực (pending_verification).
// Một mã token xác thực được tạo và lưu trữ đi kèm một Outbox Event để gửi email qua Kafka bất đồng bộ.
func (s Service) SignUp(ctx context.Context, input SignUpInput) (domain.VerificationChallenge, error) {
	email := normalizeEmail(input.Email)
	displayName := strings.TrimSpace(input.DisplayName)
	password := strings.TrimSpace(input.Password)

	if email == "" || displayName == "" || len(password) < 8 {
		return domain.VerificationChallenge{}, ErrInvalidSignUpInput
	}

	// Kiểm tra xem email đã được đăng ký trong hệ thống chưa
	if _, err := s.repo.FindUserByEmail(ctx, email); err == nil {
		return domain.VerificationChallenge{}, ErrUserExists
	} else if !errors.Is(err, store.ErrNotFound) {
		return domain.VerificationChallenge{}, err
	}

	// Băm mật khẩu sử dụng bcrypt
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return domain.VerificationChallenge{}, err
	}

	// Lưu người dùng mới vào DB
	user, err := s.repo.CreateUserWithEmail(ctx, email, string(passwordHash), displayName)
	if err != nil {
		return domain.VerificationChallenge{}, err
	}

	// Sinh token xác thực email và gửi outbox event
	return s.issueVerification(ctx, user)
}

// SignIn đăng nhập người dùng bằng email và mật khẩu.
// Kiểm tra mật khẩu hash và xác minh email đã được active chưa. Trả về cặp Access/Refresh Token và thông tin User.
func (s Service) SignIn(ctx context.Context, input SignInInput) (domain.AuthResponse, error) {
	record, err := s.repo.FindUserByEmail(ctx, normalizeEmail(input.Email))
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.AuthResponse{}, ErrInvalidCredentials
		}
		return domain.AuthResponse{}, err
	}

	// So khớp mật khẩu đã băm trong database
	if !record.PasswordHash.Valid || bcrypt.CompareHashAndPassword([]byte(record.PasswordHash.String), []byte(input.Password)) != nil {
		return domain.AuthResponse{}, ErrInvalidCredentials
	}

	// Kiểm tra xem tài khoản đã được xác thực email chưa
	if record.User.Status == "pending_verification" || record.User.EmailVerifiedAt == nil {
		return domain.AuthResponse{}, ErrEmailNotVerified
	}

	// Tạo session mới và phát hành bộ token (Access/Refresh Token)
	return s.issueSession(ctx, record.User)
}

// SignInWithGoogle xử lý luồng đăng nhập bằng bên thứ 3 (Google OAuth).
// Xác minh Google ID Token từ client, tìm hoặc tự động tạo tài khoản Google User, và trả về bộ token đăng nhập.
func (s Service) SignInWithGoogle(ctx context.Context, googleIDToken string) (domain.AuthResponse, error) {
	identity, err := s.googleVerify.Verify(ctx, googleIDToken)
	if err != nil {
		return domain.AuthResponse{}, err
	}

	// Tìm người dùng Google cũ hoặc tự động tạo người dùng mới
	user, err := s.repo.FindOrCreateGoogleUser(ctx, identity.ProviderUserID, identity.Email, fallbackDisplayName(identity.DisplayName, identity.Email), identity.AvatarURL)
	if err != nil {
		return domain.AuthResponse{}, err
	}

	return s.issueSession(ctx, user)
}

// VerifyEmail kích hoạt tài khoản của người dùng dựa trên email verification token nhận từ link người dùng nhấp vào.
func (s Service) VerifyEmail(ctx context.Context, token string) (domain.User, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return domain.User{}, ErrInvalidVerificationToken
	}

	// Consume verification token trong DB (xác thực và cập nhật trạng thái User thành active trong cùng Transaction)
	user, err := s.repo.ConsumeEmailVerification(ctx, token)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.User{}, ErrInvalidVerificationToken
		}
		return domain.User{}, err
	}

	return user, nil
}

// ResendVerification gửi lại email xác thực tài khoản nếu tài khoản vẫn ở trạng thái chưa active.
func (s Service) ResendVerification(ctx context.Context, emailAddress string) (domain.VerificationChallenge, error) {
	record, err := s.repo.FindUserByEmail(ctx, normalizeEmail(emailAddress))
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.VerificationChallenge{}, ErrInvalidCredentials
		}
		return domain.VerificationChallenge{}, err
	}

	// Nếu tài khoản đã được active từ trước thì báo lỗi
	if record.User.EmailVerifiedAt != nil && record.User.Status == "active" {
		return domain.VerificationChallenge{}, ErrUserExists
	}

	return s.issueVerification(ctx, record.User)
}

// ForgotPassword sinh ra mã OTP (6 chữ số) đặt lại mật khẩu và ghi nhận sự kiện Outbox gửi email hướng dẫn qua Kafka.
func (s Service) ForgotPassword(ctx context.Context, emailAddress string) (domain.PasswordResetChallenge, error) {
	email := normalizeEmail(emailAddress)
	sentAt := time.Now().UTC()
	expiresAt := sentAt.Add(s.resetTTL)
	challenge := domain.PasswordResetChallenge{
		Email:        email,
		Message:      "if the account exists, a password reset otp has been sent",
		OTPRequired:  true,
		OTPSentAt:    sentAt,
		OTPExpiresAt: expiresAt,
		OTPLength:    passwordResetOTPLength,
	}

	if email == "" {
		return challenge, nil
	}

	record, err := s.repo.FindUserByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return challenge, nil
		}
		return domain.PasswordResetChallenge{}, err
	}

	// Nếu tài khoản đăng nhập bằng Google (không có mật khẩu) hoặc đã bị xóa
	if !record.PasswordHash.Valid || record.User.Status == "deleted" {
		return challenge, nil
	}

	// Tạo mã OTP đặt lại mật khẩu và ghi nhận outbox event
	if _, err := s.issuePasswordReset(ctx, record.User, sentAt, expiresAt); err != nil {
		return domain.PasswordResetChallenge{}, err
	}

	return challenge, nil
}

// ResetPassword đặt mật khẩu mới sau khi xác thực thành công mã OTP gửi về email.
func (s Service) ResetPassword(ctx context.Context, input ResetPasswordInput) (domain.User, error) {
	email := normalizeEmail(input.Email)
	otp := strings.TrimSpace(input.OTP)
	password := strings.TrimSpace(input.NewPassword)
	if email == "" || otp == "" || len(password) < 8 {
		return domain.User{}, ErrInvalidResetInput
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return domain.User{}, err
	}

	// Xác nhận mã OTP, đổi mật khẩu và xóa token reset mật khẩu trong DB
	user, err := s.repo.ConsumePasswordReset(ctx, email, otp, string(passwordHash))
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.User{}, ErrInvalidPasswordReset
		}
		return domain.User{}, err
	}

	return user, nil
}

// VerifyResetOTP kiểm tra tính hợp lệ của mã OTP reset mật khẩu mà không làm thay đổi trạng thái mật khẩu.
func (s Service) VerifyResetOTP(ctx context.Context, input VerifyResetOTPInput) error {
	email := normalizeEmail(input.Email)
	otp := strings.TrimSpace(input.OTP)
	if email == "" || otp == "" {
		return ErrInvalidPasswordReset
	}

	if err := s.repo.VerifyPasswordReset(ctx, email, otp); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return ErrInvalidPasswordReset
		}
		return err
	}

	return nil
}

// Refresh thực hiện cơ chế xoay vòng Refresh Token (Token Rotation) để cấp Access/Refresh Token mới.
// Thu hồi Refresh Token cũ và phát hành cặp token mới.
func (s Service) Refresh(ctx context.Context, refreshToken string) (domain.AuthResponse, error) {
	refreshToken = strings.TrimSpace(refreshToken)
	if refreshToken == "" {
		return domain.AuthResponse{}, ErrInvalidRefresh
	}

	// Truy vấn session dựa trên Refresh Token
	userID, expiresAt, revoked, err := s.repo.FindSessionByRefreshToken(ctx, refreshToken)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.AuthResponse{}, ErrInvalidRefresh
		}
		return domain.AuthResponse{}, err
	}

	// Kiểm tra xem token đã bị thu hồi hoặc hết hạn chưa
	if revoked || time.Now().UTC().After(expiresAt) {
		return domain.AuthResponse{}, ErrInvalidRefresh
	}

	user, err := s.repo.FindUserByID(ctx, userID)
	if err != nil {
		return domain.AuthResponse{}, err
	}

	// Đánh dấu thu hồi Refresh Token cũ trước khi tạo cặp token mới (Token rotation)
	if err := s.repo.RevokeSessionByRefreshToken(ctx, refreshToken); err != nil {
		return domain.AuthResponse{}, err
	}

	return s.issueSession(ctx, user)
}

// SignOut thực hiện đăng xuất bằng cách thu hồi Refresh Token trong Database.
func (s Service) SignOut(ctx context.Context, refreshToken string) error {
	refreshToken = strings.TrimSpace(refreshToken)
	if refreshToken == "" {
		return ErrInvalidRefresh
	}

	if err := s.repo.RevokeSessionByRefreshToken(ctx, refreshToken); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return ErrInvalidRefresh
		}
		return err
	}

	return nil
}

// Me trả về thông tin chi tiết của người dùng đang đăng nhập dựa vào Access Token.
func (s Service) Me(ctx context.Context, accessToken string) (domain.User, error) {
	userID, err := s.userIDFromAccessToken(accessToken)
	if err != nil {
		return domain.User{}, ErrInvalidCredentials
	}

	return s.repo.FindUserByID(ctx, userID)
}

// ChangePassword cho phép thay đổi mật khẩu hiện tại bằng mật khẩu mới và thu hồi toàn bộ các session cũ của user.
func (s Service) ChangePassword(ctx context.Context, accessToken string, input ChangePasswordInput) error {
	userID, err := s.userIDFromAccessToken(accessToken)
	if err != nil {
		return ErrInvalidCredentials
	}
	currentPassword := strings.TrimSpace(input.CurrentPassword)
	newPassword := strings.TrimSpace(input.NewPassword)
	if userID == "" || currentPassword == "" || len(newPassword) < 8 {
		return ErrInvalidChangePassword
	}

	record, err := s.repo.FindUserRecordByID(ctx, userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return ErrInvalidCredentials
		}
		return err
	}

	// Kiểm tra tài khoản có mật khẩu không (ví dụ: Google User không đăng nhập mật khẩu trực tiếp được)
	if !record.PasswordHash.Valid || strings.TrimSpace(record.PasswordHash.String) == "" {
		return ErrPasswordAuthUnavailable
	}

	// So khớp mật khẩu hiện tại
	if bcrypt.CompareHashAndPassword([]byte(record.PasswordHash.String), []byte(currentPassword)) != nil {
		return ErrInvalidCurrentPassword
	}

	// Sinh mật khẩu băm mới
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	// Cập nhật mật khẩu mới và hủy toàn bộ các session đăng nhập hiện có của user
	if err := s.repo.UpdatePasswordAndRevokeSessions(ctx, userID, string(passwordHash)); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return ErrInvalidCredentials
		}
		return err
	}

	return nil
}

// UpdateProfile cập nhật thông tin cá nhân của người dùng bao gồm tên hiển thị, username, bio, và avatar url.
// Sau khi cập nhật thành công trong DB, ghi nhận một Outbox Event chứa thông điệp Profile Updated để Kafka chuyển tiếp
// đồng bộ dữ liệu người dùng sang các dịch vụ khác (ví dụ: Content Service).
func (s Service) UpdateProfile(ctx context.Context, accessToken string, input UpdateProfileInput) (domain.User, error) {
	userID, err := s.userIDFromAccessToken(accessToken)
	if err != nil {
		return domain.User{}, ErrInvalidCredentials
	}

	user, err := s.repo.FindUserByID(ctx, userID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.User{}, ErrInvalidCredentials
		}
		return domain.User{}, err
	}

	displayName := user.DisplayName
	if input.DisplayName != nil {
		displayName = strings.TrimSpace(*input.DisplayName)
	}
	if displayName == "" || len(displayName) > 120 {
		return domain.User{}, ErrInvalidProfileUpdate
	}

	username := strings.TrimSpace(user.Username)
	if input.Username != nil {
		username = strings.ToLower(strings.TrimSpace(*input.Username))
	}
	if username == "" || len(username) > 120 || !usernamePattern.MatchString(username) {
		return domain.User{}, ErrInvalidProfileUpdate
	}

	bio := user.Bio
	if input.Bio != nil {
		bio = strings.TrimSpace(*input.Bio)
	}
	if len(bio) > 150 {
		return domain.User{}, ErrInvalidProfileUpdate
	}

	avatarURL := strings.TrimSpace(user.AvatarURL)
	if input.AvatarURL != nil {
		avatarURL = strings.TrimSpace(*input.AvatarURL)
	}
	if avatarURL != "" {
		parsed, err := url.Parse(avatarURL)
		if err != nil || parsed == nil || strings.TrimSpace(parsed.Host) == "" {
			return domain.User{}, ErrInvalidProfileUpdate
		}
		if parsed.Scheme != "http" && parsed.Scheme != "https" {
			return domain.User{}, ErrInvalidProfileUpdate
		}
	}

	// Tạo đối tượng Event thông báo cập nhật Profile
	event := notification.NewUserProfileUpdatedEvent(notification.DefaultUserProfileTopic, notification.UserProfileUpdatedMessage{
		UserID:      userID,
		DisplayName: displayName,
		Username:    username,
		AvatarURL:   avatarURL,
		Bio:         bio,
		UpdatedAt:   time.Now().UTC(),
	})

	payload, err := json.Marshal(event)
	if err != nil {
		return domain.User{}, err
	}

	// Tiến hành cập nhật DB và chèn bản ghi Outbox event vào bảng trong cùng 1 Database Transaction (đảm bảo tính nhất quán dữ liệu)
	updatedUser, err := s.repo.UpdateUserProfileWithOutbox(ctx, userID, displayName, username, bio, avatarURL, store.CreateOutboxEventInput{
		AggregateType:  "user",
		AggregateID:    userID,
		EventType:      event.EventType,
		PayloadVersion: 1,
		Payload:        payload,
	})
	if err != nil {
		if errors.Is(err, store.ErrConflict) {
			return domain.User{}, ErrUsernameAlreadyExists
		}
		if errors.Is(err, store.ErrNotFound) {
			return domain.User{}, ErrInvalidCredentials
		}
		return domain.User{}, err
	}

	return updatedUser, nil
}

// issueSession sinh token đăng nhập và lưu thông tin Refresh Token vào bảng session trong Database.
func (s Service) issueSession(ctx context.Context, user domain.User) (domain.AuthResponse, error) {
	tokens, err := s.tokenManager.Issue(user)
	if err != nil {
		return domain.AuthResponse{}, err
	}

	if err := s.repo.CreateSession(ctx, user.ID, tokens.RefreshToken, tokens.RefreshTokenExpiresAt); err != nil {
		return domain.AuthResponse{}, err
	}

	return domain.AuthResponse{
		User:   user,
		Tokens: tokens,
	}, nil
}

// issueVerification sinh token xác thực email và lưu vào Database cùng với bản ghi Outbox Event để Kafka gửi mail.
func (s Service) issueVerification(ctx context.Context, user domain.User) (domain.VerificationChallenge, error) {
	token, err := randomVerificationToken()
	if err != nil {
		return domain.VerificationChallenge{}, err
	}

	sentAt := time.Now().UTC()
	expiresAt := sentAt.Add(s.verificationTTL)

	verificationURL, err := buildVerificationURL(s.verificationURLBase, token)
	if err != nil {
		return domain.VerificationChallenge{}, err
	}

	event := notification.NewVerificationEvent(s.verificationTopic, notification.VerificationMessage{
		UserID:          user.ID,
		ToEmail:         user.Email,
		ToDisplayName:   user.DisplayName,
		VerificationURL: verificationURL,
		ExpiresAt:       expiresAt,
	})

	payload, err := json.Marshal(event)
	if err != nil {
		return domain.VerificationChallenge{}, err
	}

	// Ghi nhận Token và Outbox Event trong cùng 1 DB Transaction
	if err := s.repo.CreateEmailVerificationWithOutbox(ctx, user.ID, token, expiresAt, store.CreateOutboxEventInput{
		AggregateType:  "user",
		AggregateID:    user.ID,
		EventType:      event.EventType,
		PayloadVersion: 1,
		Payload:        payload,
	}); err != nil {
		return domain.VerificationChallenge{}, err
	}

	return domain.VerificationChallenge{
		Email:                 user.Email,
		VerificationRequired:  true,
		VerificationSentAt:    sentAt,
		VerificationExpiresAt: expiresAt,
		Message:               "verification email sent",
	}, nil
}

// issuePasswordReset sinh mã OTP đặt lại mật khẩu và lưu vào DB kèm theo bản ghi Outbox Event gửi email.
func (s Service) issuePasswordReset(ctx context.Context, user domain.User, sentAt, expiresAt time.Time) (domain.PasswordResetChallenge, error) {
	otp, err := randomNumericCode(passwordResetOTPLength)
	if err != nil {
		return domain.PasswordResetChallenge{}, err
	}

	event := notification.NewPasswordResetEvent(s.resetTopic, notification.PasswordResetMessage{
		UserID:        user.ID,
		ToEmail:       user.Email,
		ToDisplayName: user.DisplayName,
		ResetOTP:      otp,
		ExpiresAt:     expiresAt,
	})

	payload, err := json.Marshal(event)
	if err != nil {
		return domain.PasswordResetChallenge{}, err
	}

	// Ghi nhận OTP và Outbox Event trong cùng 1 DB Transaction
	if err := s.repo.CreatePasswordResetWithOutbox(ctx, user.ID, otp, expiresAt, store.CreateOutboxEventInput{
		AggregateType:  "user",
		AggregateID:    user.ID,
		EventType:      event.EventType,
		PayloadVersion: 1,
		Payload:        payload,
	}); err != nil {
		return domain.PasswordResetChallenge{}, err
	}

	return domain.PasswordResetChallenge{
		Email:        user.Email,
		Message:      "if the account exists, a password reset otp has been sent",
		OTPRequired:  true,
		OTPSentAt:    sentAt,
		OTPExpiresAt: expiresAt,
		OTPLength:    passwordResetOTPLength,
	}, nil
}

// normalizeEmail chuẩn hóa định dạng email về dạng viết thường và loại bỏ khoảng trắng thừa.
func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

// fallbackDisplayName tự sinh Display Name từ địa chỉ email nếu display name trống.
func fallbackDisplayName(displayName, email string) string {
	displayName = strings.TrimSpace(displayName)
	if displayName != "" {
		return displayName
	}

	email = normalizeEmail(email)
	at := strings.Index(email, "@")
	if at <= 0 {
		return "Pody User"
	}

	return email[:at]
}

// randomVerificationToken sinh token xác minh ngẫu nhiên độ an toàn cao.
func randomVerificationToken() (string, error) {
	buffer := make([]byte, 32)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}

	return base64.RawURLEncoding.EncodeToString(buffer), nil
}

// randomNumericCode sinh chuỗi mã số ngẫu nhiên gồm các chữ số (0-9) với độ dài chỉ định.
func randomNumericCode(length int) (string, error) {
	if length <= 0 {
		length = passwordResetOTPLength
	}

	buffer := make([]byte, length)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}

	code := make([]byte, length)
	for index, value := range buffer {
		code[index] = byte('0' + (value % 10))
	}

	return string(code), nil
}

// buildVerificationURL kết xuất URL xác thực đầy đủ chứa token parameter.
func buildVerificationURL(baseURL, token string) (string, error) {
	return buildURLWithToken("EMAIL_VERIFICATION_URL_BASE", baseURL, token)
}

// buildURLWithToken chèn query parameter "token" vào URL cơ sở.
func buildURLWithToken(envName, baseURL, token string) (string, error) {
	if strings.TrimSpace(baseURL) == "" {
		return "", errors.New(envName + " is required")
	}

	parsed, err := url.Parse(baseURL)
	if err != nil {
		return "", err
	}

	query := parsed.Query()
	query.Set("token", token)
	parsed.RawQuery = query.Encode()
	return parsed.String(), nil
}

// userIDFromAccessToken giải mã và lấy ID người dùng (subject) từ Access Token.
func (s Service) userIDFromAccessToken(accessToken string) (string, error) {
	claims, err := s.tokenManager.Parse(accessToken)
	if err != nil {
		return "", err
	}

	userID, _ := claims["sub"].(string)
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return "", ErrInvalidCredentials
	}

	return userID, nil
}

