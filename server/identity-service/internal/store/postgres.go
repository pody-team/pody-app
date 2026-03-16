package store

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/promex04/pody/server/identity-service/internal/domain"
)

var ErrNotFound = errors.New("not found")

type UserRecord struct {
	User         domain.User
	PasswordHash sql.NullString
}

type CreateOutboxEventInput struct {
	AggregateType  string
	AggregateID    string
	EventType      string
	PayloadVersion int
	Payload        []byte
}

type OutboxEvent struct {
	ID        string
	EventType string
	Payload   []byte
	Attempts  int
}

type Repository interface {
	CreateUserWithEmail(ctx context.Context, email, passwordHash, displayName string) (domain.User, error)
	FindUserByEmail(ctx context.Context, email string) (UserRecord, error)
	FindUserByID(ctx context.Context, userID string) (domain.User, error)
	FindOrCreateGoogleUser(ctx context.Context, providerUserID, email, displayName, avatarURL string) (domain.User, error)
	CreateEmailVerificationWithOutbox(ctx context.Context, userID, token string, expiresAt time.Time, event CreateOutboxEventInput) error
	ConsumeEmailVerification(ctx context.Context, token string) (domain.User, error)
	CreateSession(ctx context.Context, userID, refreshToken string, expiresAt time.Time) error
	FindSessionByRefreshToken(ctx context.Context, refreshToken string) (string, time.Time, bool, error)
	RevokeSessionByRefreshToken(ctx context.Context, refreshToken string) error
	ListPublishableOutboxEvents(ctx context.Context, limit int) ([]OutboxEvent, error)
	MarkOutboxEventPublished(ctx context.Context, eventID string) error
	MarkOutboxEventFailed(ctx context.Context, eventID string, availableAt time.Time, lastError string) error
	DeletePublishedOutboxEventsBefore(ctx context.Context, before time.Time, limit int) (int64, error)
}

type PostgresRepository struct {
	db *sql.DB
}

func NewPostgresRepository(db *sql.DB) Repository {
	return &PostgresRepository{db: db}
}

func (r *PostgresRepository) CreateUserWithEmail(ctx context.Context, email, passwordHash, displayName string) (domain.User, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return domain.User{}, err
	}
	defer tx.Rollback()

	var user domain.User
	var emailVerifiedAt sql.NullTime
	err = tx.QueryRowContext(ctx, `
		INSERT INTO users (email, password_hash, display_name, status)
		VALUES ($1, $2, $3, 'pending_verification')
		RETURNING id, email, display_name, COALESCE(username, ''), COALESCE(avatar_url, ''), bio, account_type, status, locale, timezone, email_verified_at, created_at, updated_at
	`, email, passwordHash, displayName).Scan(
		&user.ID,
		&user.Email,
		&user.DisplayName,
		&user.Username,
		&user.AvatarURL,
		&user.Bio,
		&user.AccountType,
		&user.Status,
		&user.Locale,
		&user.Timezone,
		&emailVerifiedAt,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if err != nil {
		return domain.User{}, err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO user_identities (user_id, provider, provider_user_id, provider_email, is_primary, last_used_at)
		VALUES ($1, 'email', $2, $3, true, now())
	`, user.ID, strings.ToLower(email), email)
	if err != nil {
		return domain.User{}, err
	}

	if err := tx.Commit(); err != nil {
		return domain.User{}, err
	}

	if emailVerifiedAt.Valid {
		verifiedAt := emailVerifiedAt.Time
		user.EmailVerifiedAt = &verifiedAt
	}

	return user, nil
}

func (r *PostgresRepository) FindUserByEmail(ctx context.Context, email string) (UserRecord, error) {
	var record UserRecord
	var emailVerifiedAt sql.NullTime
	err := r.db.QueryRowContext(ctx, `
		SELECT id, email, display_name, COALESCE(username, ''), COALESCE(avatar_url, ''), bio, account_type, status, locale, timezone, email_verified_at, created_at, updated_at, password_hash
		FROM users
		WHERE email = $1 AND status <> 'deleted'
	`, email).Scan(
		&record.User.ID,
		&record.User.Email,
		&record.User.DisplayName,
		&record.User.Username,
		&record.User.AvatarURL,
		&record.User.Bio,
		&record.User.AccountType,
		&record.User.Status,
		&record.User.Locale,
		&record.User.Timezone,
		&emailVerifiedAt,
		&record.User.CreatedAt,
		&record.User.UpdatedAt,
		&record.PasswordHash,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return UserRecord{}, ErrNotFound
	}

	if emailVerifiedAt.Valid {
		verifiedAt := emailVerifiedAt.Time
		record.User.EmailVerifiedAt = &verifiedAt
	}

	return record, err
}

func (r *PostgresRepository) FindUserByID(ctx context.Context, userID string) (domain.User, error) {
	var user domain.User
	var emailVerifiedAt sql.NullTime
	err := r.db.QueryRowContext(ctx, `
		SELECT id, email, display_name, COALESCE(username, ''), COALESCE(avatar_url, ''), bio, account_type, status, locale, timezone, email_verified_at, created_at, updated_at
		FROM users
		WHERE id = $1 AND status <> 'deleted'
	`, userID).Scan(
		&user.ID,
		&user.Email,
		&user.DisplayName,
		&user.Username,
		&user.AvatarURL,
		&user.Bio,
		&user.AccountType,
		&user.Status,
		&user.Locale,
		&user.Timezone,
		&emailVerifiedAt,
		&user.CreatedAt,
		&user.UpdatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return domain.User{}, ErrNotFound
	}

	if emailVerifiedAt.Valid {
		verifiedAt := emailVerifiedAt.Time
		user.EmailVerifiedAt = &verifiedAt
	}

	return user, err
}

func (r *PostgresRepository) FindOrCreateGoogleUser(ctx context.Context, providerUserID, email, displayName, avatarURL string) (domain.User, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return domain.User{}, err
	}
	defer tx.Rollback()

	var existingUserID string
	err = tx.QueryRowContext(ctx, `
		SELECT user_id
		FROM user_identities
		WHERE provider = 'google' AND provider_user_id = $1
	`, providerUserID).Scan(&existingUserID)
	if err == nil {
		if _, err := tx.ExecContext(ctx, `
			UPDATE user_identities
			SET last_used_at = now()
			WHERE provider = 'google' AND provider_user_id = $1
		`, providerUserID); err != nil {
			return domain.User{}, err
		}
		if err := tx.Commit(); err != nil {
			return domain.User{}, err
		}
		return r.FindUserByID(ctx, existingUserID)
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return domain.User{}, err
	}

	lookupEmail := strings.ToLower(strings.TrimSpace(email))
	err = tx.QueryRowContext(ctx, `
		SELECT id
		FROM users
		WHERE email = $1 AND status <> 'deleted'
	`, lookupEmail).Scan(&existingUserID)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return domain.User{}, err
	}

	userID := existingUserID
	if errors.Is(err, sql.ErrNoRows) {
		userID = uuid.NewString()
		_, err = tx.ExecContext(ctx, `
			INSERT INTO users (id, email, display_name, avatar_url, status, email_verified_at)
			VALUES ($1, $2, $3, $4, 'active', now())
		`, userID, lookupEmail, displayName, nullableString(avatarURL))
		if err != nil {
			return domain.User{}, err
		}
	} else {
		_, err = tx.ExecContext(ctx, `
			UPDATE users
			SET status = 'active', email_verified_at = COALESCE(email_verified_at, now())
			WHERE id = $1
		`, userID)
		if err != nil {
			return domain.User{}, err
		}
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO user_identities (user_id, provider, provider_user_id, provider_email, is_primary, last_used_at)
		VALUES ($1, 'google', $2, $3, true, now())
		ON CONFLICT (provider, provider_user_id)
		DO UPDATE SET provider_email = EXCLUDED.provider_email, last_used_at = now(), updated_at = now()
	`, userID, providerUserID, lookupEmail)
	if err != nil {
		return domain.User{}, err
	}

	if err := tx.Commit(); err != nil {
		return domain.User{}, err
	}

	return r.FindUserByID(ctx, userID)
}

func (r *PostgresRepository) CreateEmailVerificationWithOutbox(ctx context.Context, userID, token string, expiresAt time.Time, event CreateOutboxEventInput) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.ExecContext(ctx, `
		UPDATE email_verification_tokens
		SET used_at = now()
		WHERE user_id = $1 AND used_at IS NULL
	`, userID)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO email_verification_tokens (user_id, token_hash, expires_at)
		VALUES ($1, $2, $3)
	`, userID, hashToken(token), expiresAt)
	if err != nil {
		return err
	}

	payloadVersion := event.PayloadVersion
	if payloadVersion <= 0 {
		payloadVersion = 1
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO outbox_events (
			aggregate_type,
			aggregate_id,
			event_type,
			payload_version,
			payload
		)
		VALUES ($1, $2, $3, $4, $5::jsonb)
	`, event.AggregateType, event.AggregateID, event.EventType, payloadVersion, string(event.Payload))
	if err != nil {
		return err
	}

	return tx.Commit()
}

func (r *PostgresRepository) ConsumeEmailVerification(ctx context.Context, token string) (domain.User, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return domain.User{}, err
	}
	defer tx.Rollback()

	var verificationID string
	var userID string
	err = tx.QueryRowContext(ctx, `
		SELECT id, user_id
		FROM email_verification_tokens
		WHERE token_hash = $1
		  AND used_at IS NULL
		  AND expires_at > now()
	`, hashToken(token)).Scan(&verificationID, &userID)
	if errors.Is(err, sql.ErrNoRows) {
		return domain.User{}, ErrNotFound
	}
	if err != nil {
		return domain.User{}, err
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE email_verification_tokens
		SET used_at = now()
		WHERE id = $1
	`, verificationID)
	if err != nil {
		return domain.User{}, err
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE users
		SET status = 'active', email_verified_at = COALESCE(email_verified_at, now())
		WHERE id = $1
	`, userID)
	if err != nil {
		return domain.User{}, err
	}

	if err := tx.Commit(); err != nil {
		return domain.User{}, err
	}

	return r.FindUserByID(ctx, userID)
}

func (r *PostgresRepository) CreateSession(ctx context.Context, userID, refreshToken string, expiresAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO auth_sessions (user_id, refresh_token_hash, expires_at)
		VALUES ($1, $2, $3)
	`, userID, hashRefreshToken(refreshToken), expiresAt)
	return err
}

func (r *PostgresRepository) FindSessionByRefreshToken(ctx context.Context, refreshToken string) (string, time.Time, bool, error) {
	var userID string
	var expiresAt time.Time
	var revokedAt sql.NullTime

	err := r.db.QueryRowContext(ctx, `
		SELECT user_id, expires_at, revoked_at
		FROM auth_sessions
		WHERE refresh_token_hash = $1
	`, hashRefreshToken(refreshToken)).Scan(&userID, &expiresAt, &revokedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return "", time.Time{}, false, ErrNotFound
	}
	if err != nil {
		return "", time.Time{}, false, err
	}

	return userID, expiresAt, revokedAt.Valid, nil
}

func (r *PostgresRepository) RevokeSessionByRefreshToken(ctx context.Context, refreshToken string) error {
	result, err := r.db.ExecContext(ctx, `
		UPDATE auth_sessions
		SET revoked_at = now()
		WHERE refresh_token_hash = $1 AND revoked_at IS NULL
	`, hashRefreshToken(refreshToken))
	if err != nil {
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return ErrNotFound
	}

	return nil
}

func (r *PostgresRepository) ListPublishableOutboxEvents(ctx context.Context, limit int) ([]OutboxEvent, error) {
	if limit <= 0 {
		limit = 20
	}

	rows, err := r.db.QueryContext(ctx, `
		SELECT id, event_type, payload::text, attempts
		FROM outbox_events
		WHERE status IN ('pending', 'failed')
		  AND available_at <= now()
		ORDER BY created_at ASC
		LIMIT $1
	`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	events := make([]OutboxEvent, 0, limit)
	for rows.Next() {
		var event OutboxEvent
		var payload string
		if err := rows.Scan(&event.ID, &event.EventType, &payload, &event.Attempts); err != nil {
			return nil, err
		}
		event.Payload = []byte(payload)
		events = append(events, event)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return events, nil
}

func (r *PostgresRepository) MarkOutboxEventPublished(ctx context.Context, eventID string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE outbox_events
		SET status = 'published',
		    published_at = now(),
		    last_error = NULL
		WHERE id = $1
	`, eventID)
	return err
}

func (r *PostgresRepository) MarkOutboxEventFailed(ctx context.Context, eventID string, availableAt time.Time, lastError string) error {
	_, err := r.db.ExecContext(ctx, `
		UPDATE outbox_events
		SET status = 'failed',
		    attempts = attempts + 1,
		    available_at = $2,
		    last_error = $3
		WHERE id = $1
	`, eventID, availableAt, strings.TrimSpace(lastError))
	return err
}

func (r *PostgresRepository) DeletePublishedOutboxEventsBefore(ctx context.Context, before time.Time, limit int) (int64, error) {
	if limit <= 0 {
		limit = 200
	}

	result, err := r.db.ExecContext(ctx, `
		DELETE FROM outbox_events
		WHERE id IN (
			SELECT id
			FROM outbox_events
			WHERE status = 'published'
			  AND published_at IS NOT NULL
			  AND published_at < $1
			ORDER BY published_at ASC
			LIMIT $2
		)
	`, before, limit)
	if err != nil {
		return 0, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return 0, err
	}

	return rowsAffected, nil
}

func hashRefreshToken(token string) string {
	return hashToken(token)
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

func nullableString(value string) interface{} {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}

	return value
}
