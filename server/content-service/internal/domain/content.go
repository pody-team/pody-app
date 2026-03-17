package domain

import "time"

type Host struct {
	ID             string `json:"id"`
	DisplayName    string `json:"display_name"`
	AvatarURL      string `json:"avatar_url"`
	VoiceProfileID string `json:"voice_profile_id,omitempty"`
	Role           string `json:"role"`
	Bio            string `json:"bio,omitempty"`
}

type CreateHostInput struct {
	DisplayName    string `json:"display_name"`
	AvatarURL      string `json:"avatar_url,omitempty"`
	VoiceProfileID string `json:"voice_profile_id,omitempty"`
	Role           string `json:"role,omitempty"`
	Bio            string `json:"bio,omitempty"`
}

type CreateShowInput struct {
	OwnerUserID      string            `json:"owner_user_id,omitempty"`
	OwnerDisplayName string            `json:"owner_display_name,omitempty"`
	OwnerEmail       string            `json:"owner_email,omitempty"`
	Title            string            `json:"title"`
	Description      string            `json:"description,omitempty"`
	CoverImageURL    string            `json:"cover_image_url,omitempty"`
	PrimaryCategory  string            `json:"primary_category"`
	LanguageCode     string            `json:"language_code,omitempty"`
	ContentType      string            `json:"content_type,omitempty"`
	Hosts            []CreateHostInput `json:"hosts"`
}

type OwnerSummary struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url"`
}

type EpisodePreview struct {
	ID              string    `json:"id"`
	ShowID          string    `json:"show_id"`
	Title           string    `json:"title"`
	DurationSeconds int       `json:"duration_seconds"`
	PublishedAt     time.Time `json:"published_at"`
}

type ShowSummary struct {
	ID                string    `json:"id"`
	Slug              string    `json:"slug"`
	Title             string    `json:"title"`
	CoverImageURL     string    `json:"cover_image_url"`
	PrimaryCategory   string    `json:"primary_category"`
	Hosts             []Host    `json:"hosts"`
	ContentType       string    `json:"content_type"`
	SubscriberCount   int       `json:"subscriber_count"`
	TotalEpisodeCount int       `json:"total_episode_count"`
	PublishedAt       time.Time `json:"published_at"`
}

type HomeShowCard struct {
	Show            ShowSummary      `json:"show"`
	PreviewEpisodes []EpisodePreview `json:"preview_episodes"`
}

type HomeFeed struct {
	Categories []string       `json:"categories"`
	Shows      []HomeShowCard `json:"shows"`
}

type ShowDetail struct {
	ID                string       `json:"id"`
	Slug              string       `json:"slug"`
	Title             string       `json:"title"`
	Description       string       `json:"description"`
	CoverImageURL     string       `json:"cover_image_url"`
	Categories        []string     `json:"categories"`
	Tags              []string     `json:"tags"`
	Hosts             []Host       `json:"hosts"`
	Owner             OwnerSummary `json:"owner"`
	SubscriberCount   int          `json:"subscriber_count"`
	TotalEpisodeCount int          `json:"total_episode_count"`
	TotalListenCount  int          `json:"total_listen_count"`
	LanguageCode      string       `json:"language_code"`
	ContentType       string       `json:"content_type"`
	Visibility        string       `json:"visibility"`
	MonetizationType  string       `json:"monetization_type"`
	PublishedAt       time.Time    `json:"published_at"`
}

type EpisodeSummary struct {
	ID              string    `json:"id"`
	ShowID          string    `json:"show_id"`
	Title           string    `json:"title"`
	Description     string    `json:"description"`
	CoverImageURL   string    `json:"cover_image_url"`
	DurationSeconds int       `json:"duration_seconds"`
	PublishedAt     time.Time `json:"published_at"`
	EpisodeNumber   int       `json:"episode_number"`
}

type EpisodeDetail struct {
	ID              string    `json:"id"`
	ShowID          string    `json:"show_id"`
	Title           string    `json:"title"`
	Description     string    `json:"description"`
	AudioURL        string    `json:"audio_url"`
	CoverImageURL   string    `json:"cover_image_url"`
	DurationSeconds int       `json:"duration_seconds"`
	PublishedAt     time.Time `json:"published_at"`
	EpisodeNumber   int       `json:"episode_number"`
	Tags            []string  `json:"tags"`
	LikeCount       int       `json:"like_count"`
	CommentCount    int       `json:"comment_count"`
}
