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
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/promex04/pody/server/identity-service/internal/domain"
)

var ErrNotFound = errors.New("not found")
var ErrConflict = errors.New("conflict")

// UserRecord kết hợp thực thể domain.User và PasswordHash trong DB.
type UserRecord struct {
	User         domain.User
	PasswordHash sql.NullString
}

// CreateOutboxEventInput định nghĩa các tham số cần thiết để chèn một event mới vào hàng đợi outbox.
type CreateOutboxEventInput struct {
	AggregateType  string
	AggregateID    string
	EventType      string
	PayloadVersion int
	Payload        []byte
}

// OutboxEvent ánh xạ trực tiếp tới bảng outbox_events trong DB PostgreSQL.
type OutboxEvent struct {
	ID        string
	Key       string
	EventType string
	Payload   []byte
	Attempts  int
}

// Repository cung cấp các phương thức thao tác lưu trữ PostgreSQL cho Identity Service.
type Repository interface {
	CreateUserWithEmail(ctx context.Context, email, passwordHash, displayName string) (domain.User, error)
	FindUserByEmail(ctx context.Context, email string) (UserRecord, error)
	FindUserRecordByID(ctx context.Context, userID string) (UserRecord, error)
	FindUserByID(ctx context.Context, userID string) (domain.User, error)
	FindOrCreateGoogleUser(ctx context.Context, providerUserID, email, displayName, avatarURL string) (domain.User, error)
	CreateEmailVerificationWithOutbox(ctx context.Context, userID, token string, expiresAt time.Time, event CreateOutboxEventInput) error
	CreatePasswordResetWithOutbox(ctx context.Context, userID, token string, expiresAt time.Time, event CreateOutboxEventInput) error
	ConsumeEmailVerification(ctx context.Context, token string) (domain.User, error)
	VerifyPasswordReset(ctx context.Context, email, token string) error
	ConsumePasswordReset(ctx context.Context, email, token, passwordHash string) (domain.User, error)
	UpdateUserProfileWithOutbox(ctx context.Context, userID, displayName, username, bio, avatarURL string, event CreateOutboxEventInput) (domain.User, error)
	UpdatePasswordAndRevokeSessions(ctx context.Context, userID, passwordHash string) error
	CreateSession(ctx context.Context, userID, refreshToken string, expiresAt time.Time) error
	FindSessionByRefreshToken(ctx context.Context, refreshToken string) (string, time.Time, bool, error)
	RevokeSessionByRefreshToken(ctx context.Context, refreshToken string) error
	ListPublishableOutboxEvents(ctx context.Context, limit int) ([]OutboxEvent, error)
	MarkOutboxEventPublished(ctx context.Context, eventID string) error
	MarkOutboxEventFailed(ctx context.Context, eventID string, availableAt time.Time, lastError string) error
	DeletePublishedOutboxEventsBefore(ctx context.Context, before time.Time, limit int) (int64, error)
}

// PostgresRepository implement giao diện Repository bằng cơ sở dữ liệu PostgreSQL.
type PostgresRepository struct {
	db *sql.DB
}

// NewPostgresRepository khởi tạo mới một PostgresRepository.
func NewPostgresRepository(db *sql.DB) Repository {
	return &PostgresRepository{db: db}
}

// CreateUserWithEmail chèn thông tin tài khoản người dùng mới và identity liên kết với email vào database sử dụng Transaction.
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

// FindUserByEmail tìm kiếm thông tin người dùng theo email và trạng thái chưa bị xóa.
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

// FindUserByID tìm kiếm thông tin cơ bản domain.User dựa trên ID.
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

// FindUserRecordByID tìm kiếm bản ghi UserRecord đầy đủ kèm password hash dựa trên ID.
func (r *PostgresRepository) FindUserRecordByID(ctx context.Context, userID string) (UserRecord, error) {
	var record UserRecord
	var emailVerifiedAt sql.NullTime
	err := r.db.QueryRowContext(ctx, `
		SELECT id, email, display_name, COALESCE(username, ''), COALESCE(avatar_url, ''), bio, account_type, status, locale, timezone, email_verified_at, created_at, updated_at, password_hash
		FROM users
		WHERE id = $1 AND status <> 'deleted'
	`, userID).Scan(
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

// FindOrCreateGoogleUser tìm kiếm thông tin người dùng Google trong bảng identities.
// Nếu chưa tồn tại, nó sẽ tự động chèn mới tài khoản và cập nhật identity.
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

// CreateEmailVerificationWithOutbox tạo mới token xác minh email, đánh dấu vô hiệu hóa các token cũ
// và ghi nhận sự kiện ra bảng outbox trong cùng một transaction.
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

// CreatePasswordResetWithOutbox lưu trữ mã token đặt lại mật khẩu và ghi nhận sự kiện gửi OTP vào bảng outbox sử dụng transactional outbox.
func (r *PostgresRepository) CreatePasswordResetWithOutbox(ctx context.Context, userID, token string, expiresAt time.Time, event CreateOutboxEventInput) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.ExecContext(ctx, `
		UPDATE password_reset_tokens
		SET used_at = now()
		WHERE user_id = $1 AND used_at IS NULL
	`, userID)
	if err != nil {
		return err
	}

	_, err = tx.ExecContext(ctx, `
		INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
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

// ConsumeEmailVerification kích hoạt tài khoản khi token email_verification trùng khớp, chưa sử dụng, chưa hết hạn.
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

// VerifyPasswordReset kiểm tra token reset mật khẩu của user xem có tồn tại và còn hạn sử dụng hay không.
func (r *PostgresRepository) VerifyPasswordReset(ctx context.Context, email, token string) error {
	var exists bool
	err := r.db.QueryRowContext(ctx, `
		SELECT EXISTS (
			SELECT 1
			FROM password_reset_tokens prt
			JOIN users u ON u.id = prt.user_id
			WHERE u.email = $1
			  AND prt.token_hash = $2
			  AND prt.used_at IS NULL
			  AND prt.expires_at > now()
		)
	`, strings.ToLower(strings.TrimSpace(email)), hashToken(token)).Scan(&exists)
	if err != nil {
		return err
	}
	if !exists {
		return ErrNotFound
	}
	return nil
}

// ConsumePasswordReset đổi mật khẩu mới cho người dùng bằng OTP reset token, đồng thời thu hồi tất cả session đăng nhập cũ.
func (r *PostgresRepository) ConsumePasswordReset(ctx context.Context, email, token, passwordHash string) (domain.User, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return domain.User{}, err
	}
	defer tx.Rollback()

	var resetTokenID string
	var userID string
	err = tx.QueryRowContext(ctx, `
		SELECT prt.id, prt.user_id
		FROM password_reset_tokens prt
		JOIN users u ON u.id = prt.user_id
		WHERE u.email = $1
		  AND prt.token_hash = $2
		  AND prt.used_at IS NULL
		  AND prt.expires_at > now()
	`, strings.ToLower(strings.TrimSpace(email)), hashToken(token)).Scan(&resetTokenID, &userID)
	if errors.Is(err, sql.ErrNoRows) {
		return domain.User{}, ErrNotFound
	}
	if err != nil {
		return domain.User{}, err
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE password_reset_tokens
		SET used_at = now()
		WHERE id = $1
	`, resetTokenID)
	if err != nil {
		return domain.User{}, err
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE users
		SET password_hash = $2
		WHERE id = $1
	`, userID, passwordHash)
	if err != nil {
		return domain.User{}, err
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE auth_sessions
		SET revoked_at = now()
		WHERE user_id = $1 AND revoked_at IS NULL
	`, userID)
	if err != nil {
		return domain.User{}, err
	}

	if err := tx.Commit(); err != nil {
		return domain.User{}, err
	}

	return r.FindUserByID(ctx, userID)
}

// UpdateUserProfileWithOutbox cập nhật thông tin cá nhân của người dùng và chèn sự kiện outbox để đồng bộ profile sang các service khác.
func (r *PostgresRepository) UpdateUserProfileWithOutbox(
	ctx context.Context,
	userID,
	displayName,
	username,
	bio,
	avatarURL string,
	event CreateOutboxEventInput,
) (domain.User, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return domain.User{}, err
	}
	defer tx.Rollback()

	var user domain.User
	var emailVerifiedAt sql.NullTime
	err = tx.QueryRowContext(ctx, `
		UPDATE users
		SET display_name = $2,
		    username = $3,
		    bio = $4,
		    avatar_url = $5
		WHERE id = $1
		  AND status <> 'deleted'
		RETURNING id, email, display_name, COALESCE(username, ''), COALESCE(avatar_url, ''), bio, account_type, status, locale, timezone, email_verified_at, created_at, updated_at
	`, userID, displayName, nullableString(username), bio, nullableString(avatarURL)).Scan(
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
	if err != nil {
		if isUniqueViolation(err) {
			return domain.User{}, ErrConflict
		}
		return domain.User{}, err
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

// UpdatePasswordAndRevokeSessions cập nhật mật khẩu mới và thu hồi các session hiện tại của người dùng.
func (r *PostgresRepository) UpdatePasswordAndRevokeSessions(ctx context.Context, userID, passwordHash string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	result, err := tx.ExecContext(ctx, `
		UPDATE users
		SET password_hash = $2, updated_at = now()
		WHERE id = $1 AND status <> 'deleted'
	`, userID, passwordHash)
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

	_, err = tx.ExecContext(ctx, `
		UPDATE auth_sessions
		SET revoked_at = now()
		WHERE user_id = $1 AND revoked_at IS NULL
	`, userID)
	if err != nil {
		return err
	}

	return tx.Commit()
}

// CreateSession tạo mới một session lưu trữ Refresh Token mã hóa hash vào DB.
func (r *PostgresRepository) CreateSession(ctx context.Context, userID, refreshToken string, expiresAt time.Time) error {
	_, err := r.db.ExecContext(ctx, `
		INSERT INTO auth_sessions (user_id, refresh_token_hash, expires_at)
		VALUES ($1, $2, $3)
	`, userID, hashRefreshToken(refreshToken), expiresAt)
	return err
}

// FindSessionByRefreshToken tìm kiếm session theo mã hash của Refresh Token.
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

// RevokeSessionByRefreshToken vô hiệu hóa một session dựa trên Refresh Token.
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

// ListPublishableOutboxEvents liệt kê các event outbox đang ở trạng thái 'pending' hoặc 'failed' cần được gửi lại.
func (r *PostgresRepository) ListPublishableOutboxEvents(ctx context.Context, limit int) ([]OutboxEvent, error) {
	if limit <= 0 {
		limit = 20
	}

	rows, err := r.db.QueryContext(ctx, `
		SELECT id, aggregate_id::text, event_type, payload::text, attempts
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
		if err := rows.Scan(&event.ID, &event.Key, &event.EventType, &payload, &event.Attempts); err != nil {
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

// MarkOutboxEventPublished đánh dấu event outbox là đã được xuất bản thành công (status = 'published').
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

// MarkOutboxEventFailed đánh dấu event outbox bị lỗi, tăng số lần attempts và tính thời gian khả dụng để thử lại tiếp theo.
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

// DeletePublishedOutboxEventsBefore dọn dẹp các event outbox cũ đã xuất bản thành công trước một mốc thời gian.
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

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code == "23505"
	}
	return false
}

