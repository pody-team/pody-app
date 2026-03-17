package domain

import "time"

type ActorSnapshot struct {
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url"`
}

type TargetSnapshot struct {
	Title string `json:"title"`
}

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
