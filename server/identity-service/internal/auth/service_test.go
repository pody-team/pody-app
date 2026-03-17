package auth

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/promex04/pody/server/identity-service/internal/domain"
	"github.com/promex04/pody/server/identity-service/internal/googleauth"
	"github.com/promex04/pody/server/identity-service/internal/notification"
	"github.com/promex04/pody/server/identity-service/internal/store"
	"golang.org/x/crypto/bcrypt"
)

type fakeRepo struct {
	userByEmail         map[string]store.UserRecord
	userByID            map[string]domain.User
	refreshSessions     map[string]fakeSession
	verificationTokens  map[string]string
	passwordResetTokens map[string]string
	outboxEvents        []store.CreateOutboxEventInput
}

type fakeSession struct {
	userID    string
	expiresAt time.Time
	revoked   bool
}

func newFakeRepo() *fakeRepo {
	return &fakeRepo{
		userByEmail:         map[string]store.UserRecord{},
		userByID:            map[string]domain.User{},
		refreshSessions:     map[string]fakeSession{},
		verificationTokens:  map[string]string{},
		passwordResetTokens: map[string]string{},
	}
}

func (f *fakeRepo) CreateUserWithEmail(_ context.Context, email, passwordHash, displayName string) (domain.User, error) {
	now := time.Now()
	user := domain.User{
		ID:          "user-1",
		Email:       email,
		DisplayName: displayName,
		AccountType: "listener",
		Status:      "pending_verification",
		Locale:      "vi",
		Timezone:    "Asia/Ho_Chi_Minh",
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	record := store.UserRecord{
		User:         user,
		PasswordHash: sql.NullString{String: passwordHash, Valid: true},
	}
	f.userByEmail[email] = record
	f.userByID[user.ID] = user
	return user, nil
}

func (f *fakeRepo) FindUserByEmail(_ context.Context, email string) (store.UserRecord, error) {
	record, ok := f.userByEmail[email]
	if !ok {
		return store.UserRecord{}, store.ErrNotFound
	}
	return record, nil
}

func (f *fakeRepo) FindUserByID(_ context.Context, userID string) (domain.User, error) {
	user, ok := f.userByID[userID]
	if !ok {
		return domain.User{}, store.ErrNotFound
	}
	return user, nil
}

func (f *fakeRepo) FindUserRecordByID(_ context.Context, userID string) (store.UserRecord, error) {
	user, ok := f.userByID[userID]
	if !ok {
		return store.UserRecord{}, store.ErrNotFound
	}

	record, ok := f.userByEmail[user.Email]
	if !ok {
		return store.UserRecord{User: user}, nil
	}

	record.User = user
	return record, nil
}

func (f *fakeRepo) FindOrCreateGoogleUser(_ context.Context, providerUserID, email, displayName, avatarURL string) (domain.User, error) {
	now := time.Now()
	user := domain.User{
		ID:              providerUserID,
		Email:           email,
		DisplayName:     displayName,
		AvatarURL:       avatarURL,
		AccountType:     "listener",
		Status:          "active",
		Locale:          "vi",
		Timezone:        "Asia/Ho_Chi_Minh",
		EmailVerifiedAt: &now,
		CreatedAt:       now,
		UpdatedAt:       now,
	}
	f.userByID[user.ID] = user
	return user, nil
}

func (f *fakeRepo) CreateEmailVerificationWithOutbox(_ context.Context, userID, token string, _ time.Time, event store.CreateOutboxEventInput) error {
	f.verificationTokens[token] = userID
	f.outboxEvents = append(f.outboxEvents, event)
	return nil
}

func (f *fakeRepo) CreatePasswordResetWithOutbox(_ context.Context, userID, token string, _ time.Time, event store.CreateOutboxEventInput) error {
	f.passwordResetTokens[token] = userID
	f.outboxEvents = append(f.outboxEvents, event)
	return nil
}

func (f *fakeRepo) ConsumeEmailVerification(_ context.Context, token string) (domain.User, error) {
	userID, ok := f.verificationTokens[token]
	if !ok {
		return domain.User{}, store.ErrNotFound
	}

	user := f.userByID[userID]
	now := time.Now()
	user.Status = "active"
	user.EmailVerifiedAt = &now
	f.userByID[userID] = user

	record := f.userByEmail[user.Email]
	record.User = user
	f.userByEmail[user.Email] = record

	delete(f.verificationTokens, token)
	return user, nil
}

func (f *fakeRepo) VerifyPasswordReset(_ context.Context, email, token string) error {
	userID, ok := f.passwordResetTokens[token]
	if !ok {
		return store.ErrNotFound
	}
	user := f.userByID[userID]
	if user.Email != email {
		return store.ErrNotFound
	}
	return nil
}

func (f *fakeRepo) ConsumePasswordReset(_ context.Context, email, token, passwordHash string) (domain.User, error) {
	userID, ok := f.passwordResetTokens[token]
	if !ok {
		return domain.User{}, store.ErrNotFound
	}

	user := f.userByID[userID]
	if user.Email != email {
		return domain.User{}, store.ErrNotFound
	}
	f.userByID[userID] = user

	record := f.userByEmail[user.Email]
	record.PasswordHash = sql.NullString{String: passwordHash, Valid: true}
	f.userByEmail[user.Email] = record

	delete(f.passwordResetTokens, token)
	return user, nil
}

func (f *fakeRepo) UpdatePasswordAndRevokeSessions(_ context.Context, userID, passwordHash string) error {
	user, ok := f.userByID[userID]
	if !ok {
		return store.ErrNotFound
	}

	record, ok := f.userByEmail[user.Email]
	if !ok {
		record = store.UserRecord{User: user}
	}
	record.PasswordHash = sql.NullString{String: passwordHash, Valid: true}
	record.User = user
	f.userByEmail[user.Email] = record

	for token, session := range f.refreshSessions {
		if session.userID == userID {
			session.revoked = true
			f.refreshSessions[token] = session
		}
	}

	return nil
}

func (f *fakeRepo) CreateSession(_ context.Context, userID, refreshToken string, expiresAt time.Time) error {
	f.refreshSessions[refreshToken] = fakeSession{userID: userID, expiresAt: expiresAt}
	return nil
}

func (f *fakeRepo) FindSessionByRefreshToken(_ context.Context, refreshToken string) (string, time.Time, bool, error) {
	session, ok := f.refreshSessions[refreshToken]
	if !ok {
		return "", time.Time{}, false, store.ErrNotFound
	}
	return session.userID, session.expiresAt, session.revoked, nil
}

func (f *fakeRepo) RevokeSessionByRefreshToken(_ context.Context, refreshToken string) error {
	session, ok := f.refreshSessions[refreshToken]
	if !ok {
		return store.ErrNotFound
	}
	session.revoked = true
	f.refreshSessions[refreshToken] = session
	return nil
}

func (f *fakeRepo) ListPublishableOutboxEvents(context.Context, int) ([]store.OutboxEvent, error) {
	return nil, nil
}

func (f *fakeRepo) MarkOutboxEventPublished(context.Context, string) error {
	return nil
}

func (f *fakeRepo) MarkOutboxEventFailed(context.Context, string, time.Time, string) error {
	return nil
}

func (f *fakeRepo) DeletePublishedOutboxEventsBefore(context.Context, time.Time, int) (int64, error) {
	return 0, nil
}

func newTestService(repo *fakeRepo) Service {
	return NewService(
		repo,
		NewTokenManager("secret", time.Minute, time.Hour),
		fakeGoogleVerifier{},
		time.Hour,
		"http://localhost:8080/api/v1/public/identity/verify-email",
		notification.DefaultVerificationTopic,
		time.Hour,
		notification.DefaultPasswordResetTopic,
	)
}

type fakeGoogleVerifier struct {
	identity googleauth.Identity
	err      error
}

func (f fakeGoogleVerifier) Verify(context.Context, string) (googleauth.Identity, error) {
	if f.err != nil {
		return googleauth.Identity{}, f.err
	}
	return f.identity, nil
}

func TestSignUpAndSignIn(t *testing.T) {
	repo := newFakeRepo()
	service := newTestService(repo)

	signUpResponse, err := service.SignUp(context.Background(), SignUpInput{
		Email:       "hello@pody.vn",
		Password:    "super-secret",
		DisplayName: "Promex",
	})
	if err != nil {
		t.Fatalf("SignUp() error = %v", err)
	}

	if signUpResponse.Email != "hello@pody.vn" {
		t.Fatalf("unexpected sign-up email %q", signUpResponse.Email)
	}

	if len(repo.outboxEvents) != 1 {
		t.Fatalf("expected one outbox event, got %d", len(repo.outboxEvents))
	}

	var event notification.VerificationRequestedEvent
	if err := json.Unmarshal(repo.outboxEvents[0].Payload, &event); err != nil {
		t.Fatalf("unmarshal outbox payload: %v", err)
	}

	if event.EventID == "" || event.IdempotencyKey == "" {
		t.Fatalf("expected event metadata in outbox payload, got %+v", event)
	}

	if event.UserID == "" {
		t.Fatal("expected event user id to be populated")
	}

	_, err = service.SignIn(context.Background(), SignInInput{
		Email:    "hello@pody.vn",
		Password: "super-secret",
	})
	if !errors.Is(err, ErrEmailNotVerified) {
		t.Fatalf("expected ErrEmailNotVerified before verification, got %v", err)
	}

	token := event.VerificationURL
	token = token[strings.LastIndex(token, "=")+1:]
	if _, err := service.VerifyEmail(context.Background(), token); err != nil {
		t.Fatalf("VerifyEmail() error = %v", err)
	}

	signInResponse, err := service.SignIn(context.Background(), SignInInput{
		Email:    "hello@pody.vn",
		Password: "super-secret",
	})
	if err != nil {
		t.Fatalf("SignIn() after verification error = %v", err)
	}

	if signInResponse.Tokens.AccessToken == "" || signInResponse.Tokens.RefreshToken == "" {
		t.Fatal("expected tokens to be issued after verification")
	}
}

func TestGoogleSignIn(t *testing.T) {
	repo := newFakeRepo()
	service := NewService(repo, NewTokenManager("secret", time.Minute, time.Hour), fakeGoogleVerifier{
		identity: googleauth.Identity{
			ProviderUserID: "google-user-1",
			Email:          "google@pody.vn",
			DisplayName:    "Google User",
			AvatarURL:      "https://example.com/avatar.png",
			EmailVerified:  true,
		},
	}, time.Hour, "http://localhost:8080/api/v1/public/identity/verify-email", notification.DefaultVerificationTopic, time.Hour, notification.DefaultPasswordResetTopic)

	response, err := service.SignInWithGoogle(context.Background(), "fake-id-token")
	if err != nil {
		t.Fatalf("SignInWithGoogle() error = %v", err)
	}

	if response.User.ID != "google-user-1" {
		t.Fatalf("unexpected user id %q", response.User.ID)
	}
}

func TestRefreshRejectsUnknownSession(t *testing.T) {
	service := newTestService(newFakeRepo())

	_, err := service.Refresh(context.Background(), "missing-token")
	if !errors.Is(err, ErrInvalidRefresh) {
		t.Fatalf("expected ErrInvalidRefresh, got %v", err)
	}
}

func TestSignUpRejectsInvalidInput(t *testing.T) {
	service := newTestService(newFakeRepo())

	_, err := service.SignUp(context.Background(), SignUpInput{
		Email:       "hello@pody.vn",
		Password:    "short",
		DisplayName: "",
	})
	if !errors.Is(err, ErrInvalidSignUpInput) {
		t.Fatalf("expected ErrInvalidSignUpInput, got %v", err)
	}
}

func TestForgotAndResetPassword(t *testing.T) {
	repo := newFakeRepo()
	service := newTestService(repo)

	now := time.Now()
	user := domain.User{
		ID:          "user-reset-1",
		Email:       "reset@pody.vn",
		DisplayName: "Reset User",
		AccountType: "listener",
		Status:      "active",
		Locale:      "vi",
		Timezone:    "Asia/Ho_Chi_Minh",
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	record := store.UserRecord{
		User:         user,
		PasswordHash: sql.NullString{String: "$2a$10$fakefakefakefakefakefakefakefakefakefakefa", Valid: true},
	}
	repo.userByEmail[user.Email] = record
	repo.userByID[user.ID] = user

	challenge, err := service.ForgotPassword(context.Background(), user.Email)
	if err != nil {
		t.Fatalf("ForgotPassword() error = %v", err)
	}

	if challenge.Message == "" {
		t.Fatal("expected forgot password message")
	}
	if !challenge.OTPRequired || challenge.OTPLength != passwordResetOTPLength {
		t.Fatalf("expected otp challenge metadata, got %+v", challenge)
	}

	if len(repo.outboxEvents) != 1 {
		t.Fatalf("expected one outbox event, got %d", len(repo.outboxEvents))
	}

	var event notification.PasswordResetRequestedEvent
	if err := json.Unmarshal(repo.outboxEvents[0].Payload, &event); err != nil {
		t.Fatalf("unmarshal password reset event: %v", err)
	}

	otp := event.ResetOTP
	resetUser, err := service.ResetPassword(context.Background(), ResetPasswordInput{
		Email:       user.Email,
		OTP:         otp,
		NewPassword: "new-super-secret",
	})
	if err != nil {
		t.Fatalf("ResetPassword() error = %v", err)
	}

	if resetUser.ID != user.ID {
		t.Fatalf("expected reset user %q, got %q", user.ID, resetUser.ID)
	}

	_, err = service.ResetPassword(context.Background(), ResetPasswordInput{
		Email:       user.Email,
		OTP:         otp,
		NewPassword: "new-super-secret",
	})
	if !errors.Is(err, ErrInvalidPasswordReset) {
		t.Fatalf("expected ErrInvalidPasswordReset on reused token, got %v", err)
	}
}

func TestChangePassword(t *testing.T) {
	repo := newFakeRepo()
	service := newTestService(repo)

	now := time.Now()
	passwordHash, err := bcrypt.GenerateFromPassword([]byte("old-password"), bcrypt.DefaultCost)
	if err != nil {
		t.Fatalf("GenerateFromPassword() error = %v", err)
	}

	user := domain.User{
		ID:              "user-change-password-1",
		Email:           "change-password@pody.vn",
		DisplayName:     "Change Password User",
		AccountType:     "listener",
		Status:          "active",
		Locale:          "vi",
		Timezone:        "Asia/Ho_Chi_Minh",
		EmailVerifiedAt: &now,
		CreatedAt:       now,
		UpdatedAt:       now,
	}
	repo.userByID[user.ID] = user
	repo.userByEmail[user.Email] = store.UserRecord{
		User:         user,
		PasswordHash: sql.NullString{String: string(passwordHash), Valid: true},
	}

	session, err := service.issueSession(context.Background(), user)
	if err != nil {
		t.Fatalf("issueSession() error = %v", err)
	}

	if err := service.ChangePassword(context.Background(), session.Tokens.AccessToken, ChangePasswordInput{
		CurrentPassword: "old-password",
		NewPassword:     "new-password-123",
	}); err != nil {
		t.Fatalf("ChangePassword() error = %v", err)
	}

	record, err := repo.FindUserByEmail(context.Background(), user.Email)
	if err != nil {
		t.Fatalf("FindUserByEmail() error = %v", err)
	}

	if bcrypt.CompareHashAndPassword([]byte(record.PasswordHash.String), []byte("new-password-123")) != nil {
		t.Fatal("expected password hash to be updated")
	}

	for _, refreshSession := range repo.refreshSessions {
		if !refreshSession.revoked {
			t.Fatal("expected existing sessions to be revoked after changing password")
		}
	}
}

func TestVerifyResetOTP(t *testing.T) {
	repo := newFakeRepo()
	service := newTestService(repo)

	now := time.Now()
	user := domain.User{
		ID:          "user-reset-otp-1",
		Email:       "otp@pody.vn",
		DisplayName: "OTP User",
		AccountType: "listener",
		Status:      "active",
		Locale:      "vi",
		Timezone:    "Asia/Ho_Chi_Minh",
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	record := store.UserRecord{
		User:         user,
		PasswordHash: sql.NullString{String: "$2a$10$fakefakefakefakefakefakefakefakefakefakefa", Valid: true},
	}
	repo.userByEmail[user.Email] = record
	repo.userByID[user.ID] = user

	_, err := service.ForgotPassword(context.Background(), user.Email)
	if err != nil {
		t.Fatalf("ForgotPassword() error = %v", err)
	}

	var event notification.PasswordResetRequestedEvent
	if err := json.Unmarshal(repo.outboxEvents[0].Payload, &event); err != nil {
		t.Fatalf("unmarshal password reset event: %v", err)
	}

	if err := service.VerifyResetOTP(context.Background(), VerifyResetOTPInput{
		Email: user.Email,
		OTP:   event.ResetOTP,
	}); err != nil {
		t.Fatalf("VerifyResetOTP() error = %v", err)
	}

	err = service.VerifyResetOTP(context.Background(), VerifyResetOTPInput{
		Email: user.Email,
		OTP:   "000000",
	})
	if !errors.Is(err, ErrInvalidPasswordReset) {
		t.Fatalf("expected ErrInvalidPasswordReset, got %v", err)
	}
}
