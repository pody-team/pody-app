package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/promex04/pody/server/notification-service/internal/domain"
)

var ErrNotFound = errors.New("not found")

type ProcessedEventStore interface {
	HasProcessedEvent(ctx context.Context, eventID string) (bool, error)
	MarkProcessedEvent(ctx context.Context, eventID, sourceService, eventType string) error
	DeleteProcessedEventsBefore(ctx context.Context, before time.Time, limit int) (int64, error)
}

type CreateDeliveryLogInput struct {
	UserID            string
	Provider          string
	DeliveryStatus    string
	ProviderMessageID string
	ErrorMessage      string
	DeliveredAt       *time.Time
}

type DeliveryLogStore interface {
	CreateEmailDeliveryLog(ctx context.Context, input CreateDeliveryLogInput) error
}

type NotificationStore interface {
	ListNotifications(ctx context.Context, userID string, limit int) ([]domain.Notification, error)
	CountUnreadNotifications(ctx context.Context, userID string) (int, error)
	MarkNotificationRead(ctx context.Context, userID, notificationID string) (bool, error)
	MarkAllNotificationsRead(ctx context.Context, userID string) (int64, error)
	GetNotificationSettings(ctx context.Context, userID string) (domain.NotificationSettings, error)
	UpsertNotificationSettings(ctx context.Context, settings domain.NotificationSettings) (domain.NotificationSettings, error)
	CreateNotification(ctx context.Context, input domain.CreateNotificationInput) (domain.Notification, error)
	SeedDemoNotifications(ctx context.Context, userID string) (int, error)
}

type PostgresStore struct {
	db *sql.DB
}

func NewPostgresStore(db *sql.DB) *PostgresStore {
	return &PostgresStore{db: db}
}

func (s *PostgresStore) HasProcessedEvent(ctx context.Context, eventID string) (bool, error) {
	var exists bool
	err := s.db.QueryRowContext(ctx, `
		SELECT EXISTS (
			SELECT 1
			FROM inbox_processed_events
			WHERE event_id = $1
		)
	`, eventID).Scan(&exists)
	return exists, err
}

func (s *PostgresStore) MarkProcessedEvent(ctx context.Context, eventID, sourceService, eventType string) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO inbox_processed_events (event_id, source_service, event_type)
		VALUES ($1, $2, $3)
		ON CONFLICT (event_id) DO NOTHING
	`, eventID, sourceService, eventType)
	return err
}

func (s *PostgresStore) DeleteProcessedEventsBefore(ctx context.Context, before time.Time, limit int) (int64, error) {
	if limit <= 0 {
		limit = 500
	}

	result, err := s.db.ExecContext(ctx, `
		DELETE FROM inbox_processed_events
		WHERE id IN (
			SELECT id
			FROM inbox_processed_events
			WHERE processed_at < $1
			ORDER BY processed_at ASC
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

func (s *PostgresStore) CreateEmailDeliveryLog(ctx context.Context, input CreateDeliveryLogInput) error {
	if strings.TrimSpace(input.UserID) == "" {
		return nil
	}

	var deliveredAt any
	if input.DeliveredAt != nil {
		deliveredAt = input.DeliveredAt.UTC()
	}

	_, err := s.db.ExecContext(ctx, `
		INSERT INTO delivery_logs (
			user_id,
			channel,
			provider,
			delivery_status,
			provider_message_id,
			error_message,
			delivered_at
		)
		VALUES ($1, 'email', $2, $3, NULLIF($4, ''), NULLIF($5, ''), $6)
	`, input.UserID, strings.TrimSpace(input.Provider), strings.TrimSpace(input.DeliveryStatus), strings.TrimSpace(input.ProviderMessageID), strings.TrimSpace(input.ErrorMessage), deliveredAt)
	return err
}

func (s *PostgresStore) ListNotifications(ctx context.Context, userID string, limit int) ([]domain.Notification, error) {
	if limit <= 0 {
		limit = 50
	}

	rows, err := s.db.QueryContext(ctx, `
		SELECT id, user_id, actor_user_id, type, target_type, target_id, title, body, preview, is_read, read_at, actor_snapshot, target_snapshot, created_at
		FROM notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`, strings.TrimSpace(userID), limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	notifications := make([]domain.Notification, 0, limit)
	for rows.Next() {
		var (
			notification      domain.Notification
			actorUserID       sql.NullString
			targetType        sql.NullString
			targetID          sql.NullString
			preview           sql.NullString
			readAt            sql.NullTime
			actorSnapshotRaw  []byte
			targetSnapshotRaw []byte
		)
		if err := rows.Scan(
			&notification.ID,
			&notification.UserID,
			&actorUserID,
			&notification.Type,
			&targetType,
			&targetID,
			&notification.Title,
			&notification.Body,
			&preview,
			&notification.IsRead,
			&readAt,
			&actorSnapshotRaw,
			&targetSnapshotRaw,
			&notification.CreatedAt,
		); err != nil {
			return nil, err
		}

		if actorUserID.Valid {
			notification.ActorUserID = actorUserID.String
		}
		if targetType.Valid {
			notification.TargetType = targetType.String
		}
		if targetID.Valid {
			notification.TargetID = targetID.String
		}
		if preview.Valid {
			notification.Preview = preview.String
		}
		if readAt.Valid {
			value := readAt.Time.UTC()
			notification.ReadAt = &value
		}

		_ = json.Unmarshal(actorSnapshotRaw, &notification.ActorSnapshot)
		_ = json.Unmarshal(targetSnapshotRaw, &notification.TargetSnapshot)

		notifications = append(notifications, notification)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return notifications, nil
}

func (s *PostgresStore) CountUnreadNotifications(ctx context.Context, userID string) (int, error) {
	var count int
	err := s.db.QueryRowContext(ctx, `
		SELECT COUNT(*)
		FROM notifications
		WHERE user_id = $1 AND is_read = false
	`, strings.TrimSpace(userID)).Scan(&count)
	return count, err
}

func (s *PostgresStore) MarkNotificationRead(ctx context.Context, userID, notificationID string) (bool, error) {
	result, err := s.db.ExecContext(ctx, `
		UPDATE notifications
		SET is_read = true, read_at = COALESCE(read_at, now())
		WHERE id = $1 AND user_id = $2 AND is_read = false
	`, strings.TrimSpace(notificationID), strings.TrimSpace(userID))
	if err != nil {
		return false, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return false, err
	}

	return rowsAffected > 0, nil
}

func (s *PostgresStore) MarkAllNotificationsRead(ctx context.Context, userID string) (int64, error) {
	result, err := s.db.ExecContext(ctx, `
		UPDATE notifications
		SET is_read = true, read_at = COALESCE(read_at, now())
		WHERE user_id = $1 AND is_read = false
	`, strings.TrimSpace(userID))
	if err != nil {
		return 0, err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return 0, err
	}

	return rowsAffected, nil
}

func (s *PostgresStore) GetNotificationSettings(ctx context.Context, userID string) (domain.NotificationSettings, error) {
	var settings domain.NotificationSettings
	err := s.db.QueryRowContext(ctx, `
		INSERT INTO user_notification_settings (user_id)
		VALUES ($1)
		ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id
		RETURNING user_id, push_enabled, email_enabled, new_episode_enabled, comment_enabled, follow_enabled, marketing_enabled, updated_at
	`, strings.TrimSpace(userID)).Scan(
		&settings.UserID,
		&settings.PushEnabled,
		&settings.EmailEnabled,
		&settings.NewEpisodeEnabled,
		&settings.CommentEnabled,
		&settings.FollowEnabled,
		&settings.MarketingEnabled,
		&settings.UpdatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return domain.NotificationSettings{}, ErrNotFound
	}
	return settings, err
}

func (s *PostgresStore) CreateNotification(ctx context.Context, input domain.CreateNotificationInput) (domain.Notification, error) {
	notification := domain.Notification{
		UserID:         strings.TrimSpace(input.UserID),
		ActorUserID:    strings.TrimSpace(input.ActorUserID),
		Type:           strings.TrimSpace(input.Type),
		TargetType:     strings.TrimSpace(input.TargetType),
		TargetID:       strings.TrimSpace(input.TargetID),
		Title:          strings.TrimSpace(input.Title),
		Body:           strings.TrimSpace(input.Body),
		Preview:        strings.TrimSpace(input.Preview),
		ActorSnapshot:  input.ActorSnapshot,
		TargetSnapshot: input.TargetSnapshot,
	}
	if notification.UserID == "" || notification.Type == "" || notification.Title == "" || notification.Body == "" {
		return domain.Notification{}, errors.New("user_id, type, title, and body are required")
	}

	actorSnapshotRaw, _ := json.Marshal(notification.ActorSnapshot)
	targetSnapshotRaw, _ := json.Marshal(notification.TargetSnapshot)

	var (
		actorUserID sql.NullString
		targetType  sql.NullString
		targetID    sql.NullString
		preview     sql.NullString
	)
	if notification.ActorUserID != "" {
		actorUserID = sql.NullString{String: notification.ActorUserID, Valid: true}
	}
	if notification.TargetType != "" {
		targetType = sql.NullString{String: notification.TargetType, Valid: true}
	}
	if notification.TargetID != "" {
		targetID = sql.NullString{String: notification.TargetID, Valid: true}
	}
	if notification.Preview != "" {
		preview = sql.NullString{String: notification.Preview, Valid: true}
	}

	err := s.db.QueryRowContext(ctx, `
		INSERT INTO notifications (
			user_id,
			actor_user_id,
			type,
			target_type,
			target_id,
			title,
			body,
			preview,
			actor_snapshot,
			target_snapshot
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10::jsonb)
		RETURNING id, created_at
	`, notification.UserID, actorUserID, notification.Type, targetType, targetID, notification.Title, notification.Body, preview, actorSnapshotRaw, targetSnapshotRaw).Scan(
		&notification.ID,
		&notification.CreatedAt,
	)
	if err != nil {
		return domain.Notification{}, err
	}

	return notification, nil
}

func (s *PostgresStore) UpsertNotificationSettings(ctx context.Context, settings domain.NotificationSettings) (domain.NotificationSettings, error) {
	var updated domain.NotificationSettings
	err := s.db.QueryRowContext(ctx, `
		INSERT INTO user_notification_settings (
			user_id,
			push_enabled,
			email_enabled,
			new_episode_enabled,
			comment_enabled,
			follow_enabled,
			marketing_enabled
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (user_id) DO UPDATE
		SET
			push_enabled = EXCLUDED.push_enabled,
			email_enabled = EXCLUDED.email_enabled,
			new_episode_enabled = EXCLUDED.new_episode_enabled,
			comment_enabled = EXCLUDED.comment_enabled,
			follow_enabled = EXCLUDED.follow_enabled,
			marketing_enabled = EXCLUDED.marketing_enabled
		RETURNING user_id, push_enabled, email_enabled, new_episode_enabled, comment_enabled, follow_enabled, marketing_enabled, updated_at
	`,
		strings.TrimSpace(settings.UserID),
		settings.PushEnabled,
		settings.EmailEnabled,
		settings.NewEpisodeEnabled,
		settings.CommentEnabled,
		settings.FollowEnabled,
		settings.MarketingEnabled,
	).Scan(
		&updated.UserID,
		&updated.PushEnabled,
		&updated.EmailEnabled,
		&updated.NewEpisodeEnabled,
		&updated.CommentEnabled,
		&updated.FollowEnabled,
		&updated.MarketingEnabled,
		&updated.UpdatedAt,
	)
	return updated, err
}

func (s *PostgresStore) SeedDemoNotifications(ctx context.Context, userID string) (int, error) {
	userID = strings.TrimSpace(userID)
	if userID == "" {
		return 0, ErrNotFound
	}

	type demoNotification struct {
		Type           string
		Title          string
		Body           string
		Preview        string
		IsRead         bool
		ReadAt         *time.Time
		CreatedAt      time.Time
		ActorSnapshot  domain.ActorSnapshot
		TargetSnapshot domain.TargetSnapshot
	}

	now := time.Now().UTC()
	thirtyMinutesAgo := now.Add(-30 * time.Minute)
	twoHoursAgo := now.Add(-2 * time.Hour)
	yesterday := now.Add(-26 * time.Hour)

	items := []demoNotification{
		{
			Type:      "comment",
			Title:     "Linh vừa để lại bình luận mới",
			Body:      "Tập này giải thích quá dễ hiểu, nghe xong muốn học tiếp ngay.",
			Preview:   "Tập này giải thích quá dễ hiểu, nghe xong muốn học tiếp ngay.",
			CreatedAt: now.Add(-5 * time.Minute),
			ActorSnapshot: domain.ActorSnapshot{
				DisplayName: "Linh Tran",
			},
			TargetSnapshot: domain.TargetSnapshot{
				Title: "MVC thời hiện đại",
			},
		},
		{
			Type:      "follow",
			Title:     "Minh Anh đã theo dõi bạn",
			Body:      "Họ muốn nhận cập nhật mỗi khi bạn có tập mới.",
			CreatedAt: thirtyMinutesAgo,
			ActorSnapshot: domain.ActorSnapshot{
				DisplayName: "Minh Anh",
			},
		},
		{
			Type:      "like",
			Title:     "Một tập của bạn vừa có thêm lượt yêu thích",
			Body:      "Người nghe đang phản hồi rất tích cực với chuỗi nội dung mới.",
			CreatedAt: twoHoursAgo,
			ActorSnapshot: domain.ActorSnapshot{
				DisplayName: "Pody Community",
			},
			TargetSnapshot: domain.TargetSnapshot{
				Title: "Design System cho mobile",
			},
		},
		{
			Type:      "new_episode",
			Title:     "Nhắc bạn quay lại với chuỗi đang nghe",
			Body:      "Tập mới của kênh bạn theo dõi đã lên sóng.",
			IsRead:    true,
			ReadAt:    &yesterday,
			CreatedAt: yesterday,
			ActorSnapshot: domain.ActorSnapshot{
				DisplayName: "Pody Picks",
			},
			TargetSnapshot: domain.TargetSnapshot{
				Title: "Product Thinking cho developer",
			},
		},
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	inserted := 0
	for _, item := range items {
		actorSnapshot, err := json.Marshal(item.ActorSnapshot)
		if err != nil {
			return inserted, err
		}
		targetSnapshot, err := json.Marshal(item.TargetSnapshot)
		if err != nil {
			return inserted, err
		}

		var readAt any
		if item.ReadAt != nil {
			readAt = item.ReadAt.UTC()
		}

		_, err = tx.ExecContext(ctx, `
			INSERT INTO notifications (
				user_id,
				type,
				title,
				body,
				preview,
				is_read,
				read_at,
				actor_snapshot,
				target_snapshot,
				created_at
			)
			VALUES ($1, $2, $3, $4, NULLIF($5, ''), $6, $7, $8::jsonb, $9::jsonb, $10)
		`,
			userID,
			item.Type,
			item.Title,
			item.Body,
			item.Preview,
			item.IsRead,
			readAt,
			string(actorSnapshot),
			string(targetSnapshot),
			item.CreatedAt,
		)
		if err != nil {
			return inserted, err
		}
		inserted++
	}

	if err := tx.Commit(); err != nil {
		return inserted, err
	}

	return inserted, nil
}
