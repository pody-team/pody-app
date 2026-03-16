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
)

type fakeRepo struct {
	userByEmail        map[string]store.UserRecord
	userByID           map[string]domain.User
	refreshSessions    map[string]fakeSession
	verificationTokens map[string]string
	outboxEvents       []store.CreateOutboxEventInput
}

type fakeSession struct {
	userID    string
	expiresAt time.Time
	revoked   bool
}

func newFakeRepo() *fakeRepo {
	return &fakeRepo{
		userByEmail:        map[string]store.UserRecord{},
		userByID:           map[string]domain.User{},
		refreshSessions:    map[string]fakeSession{},
		verificationTokens: map[string]string{},
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
	service := NewService(repo, NewTokenManager("secret", time.Minute, time.Hour), fakeGoogleVerifier{}, time.Hour, "http://localhost:8080/api/v1/public/identity/verify-email", notification.DefaultVerificationTopic)

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
	}, time.Hour, "http://localhost:8080/api/v1/public/identity/verify-email", notification.DefaultVerificationTopic)

	response, err := service.SignInWithGoogle(context.Background(), "fake-id-token")
	if err != nil {
		t.Fatalf("SignInWithGoogle() error = %v", err)
	}

	if response.User.ID != "google-user-1" {
		t.Fatalf("unexpected user id %q", response.User.ID)
	}
}

func TestRefreshRejectsUnknownSession(t *testing.T) {
	service := NewService(newFakeRepo(), NewTokenManager("secret", time.Minute, time.Hour), fakeGoogleVerifier{}, time.Hour, "http://localhost:8080/api/v1/public/identity/verify-email", notification.DefaultVerificationTopic)

	_, err := service.Refresh(context.Background(), "missing-token")
	if !errors.Is(err, ErrInvalidRefresh) {
		t.Fatalf("expected ErrInvalidRefresh, got %v", err)
	}
}

func TestSignUpRejectsInvalidInput(t *testing.T) {
	service := NewService(newFakeRepo(), NewTokenManager("secret", time.Minute, time.Hour), fakeGoogleVerifier{}, time.Hour, "http://localhost:8080/api/v1/public/identity/verify-email", notification.DefaultVerificationTopic)

	_, err := service.SignUp(context.Background(), SignUpInput{
		Email:       "hello@pody.vn",
		Password:    "short",
		DisplayName: "",
	})
	if !errors.Is(err, ErrInvalidSignUpInput) {
		t.Fatalf("expected ErrInvalidSignUpInput, got %v", err)
	}
}
