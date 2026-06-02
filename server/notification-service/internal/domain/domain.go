package domain

import "time"

// ActorSnapshot lưu thông tin rút gọn của tác nhân tạo ra notification.
type ActorSnapshot struct {
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url"`
}

// TargetSnapshot lưu thông tin rút gọn của đối tượng được nhắc tới trong notification.
type TargetSnapshot struct {
	Title string `json:"title"`
}

// Notification biểu diễn một item trong hộp thư thông báo của người dùng.
type Notification struct {
	ID             string         `json:"id"`
	UserID         string         `json:"user_id"`
	ActorUserID    string         `json:"actor_user_id,omitempty"`
	Type           string         `json:"type"`
	TargetType     string         `json:"target_type,omitempty"`
	TargetID       string         `json:"target_id,omitempty"`
	Title          string         `json:"title"`
	Body           string         `json:"body"`
	Preview        string         `json:"preview,omitempty"`
	IsRead         bool           `json:"is_read"`
	ReadAt         *time.Time     `json:"read_at,omitempty"`
	ActorSnapshot  ActorSnapshot  `json:"actor_snapshot"`
	TargetSnapshot TargetSnapshot `json:"target_snapshot"`
	CreatedAt      time.Time      `json:"created_at"`
}

// CreateNotificationInput là payload chuẩn để tạo notification mới.
type CreateNotificationInput struct {
	UserID         string         `json:"user_id"`
	ActorUserID    string         `json:"actor_user_id,omitempty"`
	Type           string         `json:"type"`
	TargetType     string         `json:"target_type,omitempty"`
	TargetID       string         `json:"target_id,omitempty"`
	Title          string         `json:"title"`
	Body           string         `json:"body"`
	Preview        string         `json:"preview,omitempty"`
	ActorSnapshot  ActorSnapshot  `json:"actor_snapshot"`
	TargetSnapshot TargetSnapshot `json:"target_snapshot"`
}

// NotificationSettings biểu diễn cấu hình bật/tắt các loại thông báo của người dùng.
type NotificationSettings struct {
	UserID            string    `json:"user_id"`
	PushEnabled       bool      `json:"push_enabled"`
	EmailEnabled      bool      `json:"email_enabled"`
	NewEpisodeEnabled bool      `json:"new_episode_enabled"`
	CommentEnabled    bool      `json:"comment_enabled"`
	FollowEnabled     bool      `json:"follow_enabled"`
	MarketingEnabled  bool      `json:"marketing_enabled"`
	UpdatedAt         time.Time `json:"updated_at"`
}
