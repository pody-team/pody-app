package auth

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"net/url"
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
)

type Service struct {
	repo                store.Repository
	tokenManager        TokenManager
	googleVerify        googleauth.Verifier
	verificationTTL     time.Duration
	verificationURLBase string
	verificationTopic   string
}

func NewService(repo store.Repository, tokenManager TokenManager, googleVerify googleauth.Verifier, verificationTTL time.Duration, verificationURLBase string, verificationTopic string) Service {
	return Service{
		repo:                repo,
		tokenManager:        tokenManager,
		googleVerify:        googleVerify,
		verificationTTL:     verificationTTL,
		verificationURLBase: verificationURLBase,
		verificationTopic:   verificationTopic,
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
	claims, err := s.tokenManager.Parse(accessToken)
	if err != nil {
		return domain.User{}, ErrInvalidCredentials
	}

	userID, _ := claims["sub"].(string)
	if strings.TrimSpace(userID) == "" {
		return domain.User{}, ErrInvalidCredentials
	}

	return s.repo.FindUserByID(ctx, userID)
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

func buildVerificationURL(baseURL, token string) (string, error) {
	if strings.TrimSpace(baseURL) == "" {
		return "", errors.New("EMAIL_VERIFICATION_URL_BASE is required")
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
