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

var usernamePattern = regexp.MustCompile(`^[a-z0-9._]+$`)

type Service struct {
	repo                store.Repository
	tokenManager        TokenManager
	googleVerify        googleauth.Verifier
	verificationTTL     time.Duration
	verificationURLBase string
	verificationTopic   string
	resetTTL            time.Duration
	resetTopic          string
}

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

type SignUpInput struct {
	Email       string
	Password    string
	DisplayName string
}

type SignInInput struct {
	Email    string
	Password string
}

type ResetPasswordInput struct {
	Email       string
	OTP         string
	NewPassword string
}

type VerifyResetOTPInput struct {
	Email string
	OTP   string
}

type ChangePasswordInput struct {
	CurrentPassword string
	NewPassword     string
}

type UpdateProfileInput struct {
	DisplayName *string
	Username    *string
	Bio         *string
	AvatarURL   *string
}

func (s Service) SignUp(ctx context.Context, input SignUpInput) (domain.VerificationChallenge, error) {
	email := normalizeEmail(input.Email)
	displayName := strings.TrimSpace(input.DisplayName)
	password := strings.TrimSpace(input.Password)

	if email == "" || displayName == "" || len(password) < 8 {
		return domain.VerificationChallenge{}, ErrInvalidSignUpInput
	}

	if _, err := s.repo.FindUserByEmail(ctx, email); err == nil {
		return domain.VerificationChallenge{}, ErrUserExists
	} else if !errors.Is(err, store.ErrNotFound) {
		return domain.VerificationChallenge{}, err
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return domain.VerificationChallenge{}, err
	}

	user, err := s.repo.CreateUserWithEmail(ctx, email, string(passwordHash), displayName)
	if err != nil {
		return domain.VerificationChallenge{}, err
	}

	return s.issueVerification(ctx, user)
}

func (s Service) SignIn(ctx context.Context, input SignInInput) (domain.AuthResponse, error) {
	record, err := s.repo.FindUserByEmail(ctx, normalizeEmail(input.Email))
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.AuthResponse{}, ErrInvalidCredentials
		}
		return domain.AuthResponse{}, err
	}

	if !record.PasswordHash.Valid || bcrypt.CompareHashAndPassword([]byte(record.PasswordHash.String), []byte(input.Password)) != nil {
		return domain.AuthResponse{}, ErrInvalidCredentials
	}

	if record.User.Status == "pending_verification" || record.User.EmailVerifiedAt == nil {
		return domain.AuthResponse{}, ErrEmailNotVerified
	}

	return s.issueSession(ctx, record.User)
}

func (s Service) SignInWithGoogle(ctx context.Context, googleIDToken string) (domain.AuthResponse, error) {
	identity, err := s.googleVerify.Verify(ctx, googleIDToken)
	if err != nil {
		return domain.AuthResponse{}, err
	}

	user, err := s.repo.FindOrCreateGoogleUser(ctx, identity.ProviderUserID, identity.Email, fallbackDisplayName(identity.DisplayName, identity.Email), identity.AvatarURL)
	if err != nil {
		return domain.AuthResponse{}, err
	}

	return s.issueSession(ctx, user)
}

func (s Service) VerifyEmail(ctx context.Context, token string) (domain.User, error) {
	token = strings.TrimSpace(token)
	if token == "" {
		return domain.User{}, ErrInvalidVerificationToken
	}

	user, err := s.repo.ConsumeEmailVerification(ctx, token)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.User{}, ErrInvalidVerificationToken
		}
		return domain.User{}, err
	}

	return user, nil
}

func (s Service) ResendVerification(ctx context.Context, emailAddress string) (domain.VerificationChallenge, error) {
	record, err := s.repo.FindUserByEmail(ctx, normalizeEmail(emailAddress))
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.VerificationChallenge{}, ErrInvalidCredentials
		}
		return domain.VerificationChallenge{}, err
	}

	if record.User.EmailVerifiedAt != nil && record.User.Status == "active" {
		return domain.VerificationChallenge{}, ErrUserExists
	}

	return s.issueVerification(ctx, record.User)
}

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

	if !record.PasswordHash.Valid || record.User.Status == "deleted" {
		return challenge, nil
	}

	if _, err := s.issuePasswordReset(ctx, record.User, sentAt, expiresAt); err != nil {
		return domain.PasswordResetChallenge{}, err
	}

	return challenge, nil
}

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

	user, err := s.repo.ConsumePasswordReset(ctx, email, otp, string(passwordHash))
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.User{}, ErrInvalidPasswordReset
		}
		return domain.User{}, err
	}

	return user, nil
}

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

func (s Service) Refresh(ctx context.Context, refreshToken string) (domain.AuthResponse, error) {
	refreshToken = strings.TrimSpace(refreshToken)
	if refreshToken == "" {
		return domain.AuthResponse{}, ErrInvalidRefresh
	}

	userID, expiresAt, revoked, err := s.repo.FindSessionByRefreshToken(ctx, refreshToken)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return domain.AuthResponse{}, ErrInvalidRefresh
		}
		return domain.AuthResponse{}, err
	}

	if revoked || time.Now().UTC().After(expiresAt) {
		return domain.AuthResponse{}, ErrInvalidRefresh
	}

	user, err := s.repo.FindUserByID(ctx, userID)
	if err != nil {
		return domain.AuthResponse{}, err
	}

	if err := s.repo.RevokeSessionByRefreshToken(ctx, refreshToken); err != nil {
		return domain.AuthResponse{}, err
	}

	return s.issueSession(ctx, user)
}

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

func (s Service) Me(ctx context.Context, accessToken string) (domain.User, error) {
	userID, err := s.userIDFromAccessToken(accessToken)
	if err != nil {
		return domain.User{}, ErrInvalidCredentials
	}

	return s.repo.FindUserByID(ctx, userID)
}

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

	if !record.PasswordHash.Valid || strings.TrimSpace(record.PasswordHash.String) == "" {
		return ErrPasswordAuthUnavailable
	}

	if bcrypt.CompareHashAndPassword([]byte(record.PasswordHash.String), []byte(currentPassword)) != nil {
		return ErrInvalidCurrentPassword
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	if err := s.repo.UpdatePasswordAndRevokeSessions(ctx, userID, string(passwordHash)); err != nil {
		if errors.Is(err, store.ErrNotFound) {
			return ErrInvalidCredentials
		}
		return err
	}

	return nil
}

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

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

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

func randomVerificationToken() (string, error) {
	buffer := make([]byte, 32)
	if _, err := rand.Read(buffer); err != nil {
		return "", err
	}

	return base64.RawURLEncoding.EncodeToString(buffer), nil
}

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

func buildVerificationURL(baseURL, token string) (string, error) {
	return buildURLWithToken("EMAIL_VERIFICATION_URL_BASE", baseURL, token)
}

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
