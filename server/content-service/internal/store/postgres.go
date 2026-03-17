package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode"

	"github.com/promex04/pody/server/content-service/internal/domain"
)

type PostgresStore struct {
	db *sql.DB
}

var ErrCategoryNotFound = errors.New("category not found")

func NewPostgresStore(db *sql.DB) *PostgresStore {
	return &PostgresStore{db: db}
}

func (s *PostgresStore) CreateShow(ctx context.Context, input domain.CreateShowInput) (domain.ShowDetail, error) {
	title := strings.TrimSpace(input.Title)
	description := strings.TrimSpace(input.Description)
	coverImageURL := strings.TrimSpace(input.CoverImageURL)
	primaryCategory := strings.TrimSpace(input.PrimaryCategory)
	ownerUserID := strings.TrimSpace(input.OwnerUserID)
	ownerDisplayName := strings.TrimSpace(input.OwnerDisplayName)
	ownerEmail := strings.TrimSpace(input.OwnerEmail)
	languageCode := sanitizeLanguageCode(strings.TrimSpace(input.LanguageCode))
	contentType := sanitizeContentType(strings.TrimSpace(input.ContentType))

	if title == "" || primaryCategory == "" || ownerUserID == "" {
		return domain.ShowDetail{}, errors.New("title, primary category, and owner user id are required")
	}
	if ownerDisplayName == "" {
		ownerDisplayName = fallbackOwnerDisplayName(ownerEmail)
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return domain.ShowDetail{}, err
	}
	defer tx.Rollback()

	categoryName, categoryID, err := resolveShowCategory(ctx, tx, primaryCategory)
	if err != nil {
		return domain.ShowDetail{}, err
	}

	baseSlug := slugifyTitle(title)
	slug, err := ensureUniqueShowSlug(ctx, tx, baseSlug)
	if err != nil {
		return domain.ShowDetail{}, err
	}
	if coverImageURL == "" {
		coverImageURL = fallbackShowCoverURL(slug)
	}
	ownerAvatarURL := fallbackOwnerAvatarURL(ownerUserID)
	hosts, err := normalizeCreateHosts(contentType, input.Hosts, slug)
	if err != nil {
		return domain.ShowDetail{}, err
	}

	now := time.Now().UTC()
	var (
		showID      string
		publishedAt time.Time
	)

	err = tx.QueryRowContext(ctx, `
		INSERT INTO shows (
			owner_user_id,
			owner_display_name_snapshot,
			owner_avatar_url_snapshot,
			title,
			slug,
			description,
			content_type,
			language_code,
			cover_image_url,
			publish_status,
			visibility,
			monetization_type,
			credit_cost,
			subscriber_count,
			episode_count,
			total_listen_count,
			published_at
		)
		VALUES (
			$1::uuid,
			$2,
			$3,
			$4,
			$5,
			$6,
			$7,
			$8,
			NULLIF($9, ''),
			'published',
			'public',
			'free',
			0,
			0,
			0,
			0,
			$10
		)
		RETURNING id::text, published_at
	`, ownerUserID, ownerDisplayName, ownerAvatarURL, title, slug, description, contentType, languageCode, coverImageURL, now).Scan(&showID, &publishedAt)
	if err != nil {
		return domain.ShowDetail{}, err
	}

	if _, err := tx.ExecContext(ctx, `
		INSERT INTO show_categories (show_id, category_id, is_primary)
		VALUES ($1::uuid, $2::uuid, true)
	`, showID, categoryID); err != nil {
		return domain.ShowDetail{}, err
	}

	for index, host := range hosts {
		var (
			hostID         string
			voiceProfileID any
		)
		if host.VoiceProfileID != "" {
			voiceProfileID = host.VoiceProfileID
		}
		err = tx.QueryRowContext(ctx, `
			INSERT INTO show_hosts (
				show_id,
				linked_voice_profile_id,
				display_name,
				avatar_url,
				role,
				persona_type,
				sort_order,
				bio
			)
			VALUES (
				$1::uuid,
				$2::uuid,
				$3,
				NULLIF($4, ''),
				$5,
				'ai',
				$6,
				$7
			)
			RETURNING id::text
		`, showID, voiceProfileID, host.DisplayName, host.AvatarURL, host.Role, index, host.Bio).Scan(&hostID)
		if err != nil {
			return domain.ShowDetail{}, err
		}
		hosts[index].ID = hostID
	}

	if err := tx.Commit(); err != nil {
		return domain.ShowDetail{}, err
	}

	return domain.ShowDetail{
		ID:            showID,
		Slug:          slug,
		Title:         title,
		Description:   description,
		CoverImageURL: coverImageURL,
		Categories:    []string{categoryName},
		Tags:          nil,
		Hosts:         hosts,
		Owner: domain.OwnerSummary{
			ID:          ownerUserID,
			DisplayName: ownerDisplayName,
			AvatarURL:   ownerAvatarURL,
		},
		SubscriberCount:   0,
		TotalEpisodeCount: 0,
		TotalListenCount:  0,
		LanguageCode:      languageCode,
		ContentType:       contentType,
		Visibility:        "public",
		MonetizationType:  "free",
		PublishedAt:       publishedAt,
	}, nil
}

func (s *PostgresStore) GetHomeFeed(ctx context.Context) (domain.HomeFeed, error) {
	categories, err := s.listCategories(ctx)
	if err != nil {
		return domain.HomeFeed{}, err
	}

	rows, err := s.db.QueryContext(ctx, `
		SELECT
			s.id::text,
			s.slug::text,
			s.title,
			COALESCE(s.cover_image_url, ''),
			COALESCE(c.name, ''),
			s.content_type,
			s.subscriber_count,
			s.episode_count,
			COALESCE(s.published_at, s.created_at)
		FROM shows s
		LEFT JOIN show_categories sc
			ON sc.show_id = s.id AND sc.is_primary = true
		LEFT JOIN categories c
			ON c.id = sc.category_id
		WHERE s.publish_status = 'published'
			AND s.visibility = 'public'
			AND s.deleted_at IS NULL
		ORDER BY COALESCE(s.published_at, s.created_at) DESC
		LIMIT 20
	`)
	if err != nil {
		return domain.HomeFeed{}, err
	}
	defer rows.Close()

	shows := make([]domain.HomeShowCard, 0)
	for rows.Next() {
		summary, err := scanShowSummary(rows)
		if err != nil {
			return domain.HomeFeed{}, err
		}
		summary.Hosts, err = s.listShowHosts(ctx, summary.ID)
		if err != nil {
			return domain.HomeFeed{}, err
		}

		previewEpisodes, err := s.listPreviewEpisodes(ctx, summary.ID, 3)
		if err != nil {
			return domain.HomeFeed{}, err
		}

		shows = append(shows, domain.HomeShowCard{
			Show:            summary,
			PreviewEpisodes: previewEpisodes,
		})
	}

	if err := rows.Err(); err != nil {
		return domain.HomeFeed{}, err
	}

	return domain.HomeFeed{
		Categories: categories,
		Shows:      shows,
	}, nil
}

func (s *PostgresStore) GetShowDetail(ctx context.Context, showID string) (domain.ShowDetail, error) {
	showID = strings.TrimSpace(showID)
	var (
		show               domain.ShowDetail
		ownerUserID        string
		ownerDisplayName   string
		ownerAvatarURL     string
		coverImageURL      string
		subscriberCount    int64
		totalEpisodeCount  int64
		totalListenCount   int64
		publishedAt        time.Time
	)

	err := s.db.QueryRowContext(ctx, `
		SELECT
			s.id::text,
			s.slug::text,
			s.title,
			s.description,
			COALESCE(s.cover_image_url, ''),
			s.subscriber_count,
			s.episode_count,
			s.total_listen_count,
			s.language_code,
			s.content_type,
			s.visibility,
			s.monetization_type,
			COALESCE(s.published_at, s.created_at),
			s.owner_user_id::text,
			COALESCE(s.owner_display_name_snapshot, ''),
			COALESCE(s.owner_avatar_url_snapshot, '')
		FROM shows s
		WHERE s.id = $1::uuid
			AND s.publish_status = 'published'
			AND s.visibility = 'public'
			AND s.deleted_at IS NULL
	`, showID).Scan(
		&show.ID,
		&show.Slug,
		&show.Title,
		&show.Description,
		&coverImageURL,
		&subscriberCount,
		&totalEpisodeCount,
		&totalListenCount,
		&show.LanguageCode,
		&show.ContentType,
		&show.Visibility,
		&show.MonetizationType,
		&publishedAt,
		&ownerUserID,
		&ownerDisplayName,
		&ownerAvatarURL,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return domain.ShowDetail{}, ErrNotFound
		}
		return domain.ShowDetail{}, err
	}

	show.CoverImageURL = coverImageURL
	show.SubscriberCount = int(subscriberCount)
	show.TotalEpisodeCount = int(totalEpisodeCount)
	show.TotalListenCount = int(totalListenCount)
	show.PublishedAt = publishedAt
	show.Owner = domain.OwnerSummary{
		ID:          ownerUserID,
		DisplayName: ownerDisplayName,
		AvatarURL:   ownerAvatarURL,
	}

	show.Categories, err = s.listShowCategoryNames(ctx, showID)
	if err != nil {
		return domain.ShowDetail{}, err
	}
	show.Tags, err = s.listShowTagNames(ctx, showID)
	if err != nil {
		return domain.ShowDetail{}, err
	}
	show.Hosts, err = s.listShowHosts(ctx, showID)
	if err != nil {
		return domain.ShowDetail{}, err
	}

	return show, nil
}

func (s *PostgresStore) ListShowEpisodes(ctx context.Context, showID string) ([]domain.EpisodeSummary, error) {
	showID = strings.TrimSpace(showID)
	rows, err := s.db.QueryContext(ctx, `
		SELECT
			e.id::text,
			e.show_id::text,
			e.title,
			e.description,
			COALESCE(e.cover_image_url, COALESCE(s.cover_image_url, '')),
			e.duration_seconds,
			COALESCE(e.published_at, e.created_at),
			COALESCE(e.episode_number, 0)
		FROM episodes e
		JOIN shows s ON s.id = e.show_id
		WHERE e.show_id = $1::uuid
			AND e.publish_status = 'published'
			AND e.visibility = 'public'
			AND e.deleted_at IS NULL
			AND s.publish_status = 'published'
			AND s.visibility = 'public'
			AND s.deleted_at IS NULL
		ORDER BY COALESCE(e.published_at, e.created_at) DESC, e.episode_number DESC NULLS LAST
	`, showID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	episodes := make([]domain.EpisodeSummary, 0)
	for rows.Next() {
		var (
			episode         domain.EpisodeSummary
			coverImageURL   string
			durationSeconds int64
			episodeNumber   int64
			publishedAt     time.Time
		)
		if err := rows.Scan(
			&episode.ID,
			&episode.ShowID,
			&episode.Title,
			&episode.Description,
			&coverImageURL,
			&durationSeconds,
			&publishedAt,
			&episodeNumber,
		); err != nil {
			return nil, err
		}
		episode.CoverImageURL = coverImageURL
		episode.DurationSeconds = int(durationSeconds)
		episode.PublishedAt = publishedAt
		episode.EpisodeNumber = int(episodeNumber)
		episodes = append(episodes, episode)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	if len(episodes) == 0 {
		if exists, err := s.showExists(ctx, showID); err != nil {
			return nil, err
		} else if !exists {
			return nil, ErrNotFound
		}
	}

	return episodes, nil
}

func (s *PostgresStore) GetEpisodeDetail(ctx context.Context, episodeID string) (domain.EpisodeDetail, error) {
	episodeID = strings.TrimSpace(episodeID)
	var (
		episode         domain.EpisodeDetail
		coverImageURL   string
		audioURL        string
		durationSeconds int64
		episodeNumber   int64
		likeCount       int64
		commentCount    int64
		publishedAt     time.Time
	)

	err := s.db.QueryRowContext(ctx, `
		SELECT
			e.id::text,
			e.show_id::text,
			e.title,
			e.description,
			COALESCE(e.audio_url, ''),
			COALESCE(e.cover_image_url, COALESCE(s.cover_image_url, '')),
			e.duration_seconds,
			COALESCE(e.published_at, e.created_at),
			COALESCE(e.episode_number, 0),
			e.like_count,
			e.comment_count
		FROM episodes e
		JOIN shows s ON s.id = e.show_id
		WHERE e.id = $1::uuid
			AND e.publish_status = 'published'
			AND e.visibility = 'public'
			AND e.deleted_at IS NULL
			AND s.publish_status = 'published'
			AND s.visibility = 'public'
			AND s.deleted_at IS NULL
	`, episodeID).Scan(
		&episode.ID,
		&episode.ShowID,
		&episode.Title,
		&episode.Description,
		&audioURL,
		&coverImageURL,
		&durationSeconds,
		&publishedAt,
		&episodeNumber,
		&likeCount,
		&commentCount,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return domain.EpisodeDetail{}, ErrNotFound
		}
		return domain.EpisodeDetail{}, err
	}

	episode.AudioURL = audioURL
	episode.CoverImageURL = coverImageURL
	episode.DurationSeconds = int(durationSeconds)
	episode.PublishedAt = publishedAt
	episode.EpisodeNumber = int(episodeNumber)
	episode.LikeCount = int(likeCount)
	episode.CommentCount = int(commentCount)
	episode.Tags, err = s.listEpisodeTagNames(ctx, episodeID)
	if err != nil {
		return domain.EpisodeDetail{}, err
	}

	return episode, nil
}

func (s *PostgresStore) ListCreatorShows(ctx context.Context, ownerUserID string) ([]domain.ShowSummary, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT
			s.id::text,
			s.slug::text,
			s.title,
			COALESCE(s.cover_image_url, ''),
			COALESCE(c.name, ''),
			s.content_type,
			s.subscriber_count,
			s.episode_count,
			COALESCE(s.published_at, s.created_at)
		FROM shows s
		LEFT JOIN show_categories sc
			ON sc.show_id = s.id AND sc.is_primary = true
		LEFT JOIN categories c
			ON c.id = sc.category_id
		WHERE s.owner_user_id = $1::uuid
			AND s.deleted_at IS NULL
		ORDER BY s.updated_at DESC, s.created_at DESC
	`, strings.TrimSpace(ownerUserID))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	shows := make([]domain.ShowSummary, 0)
	for rows.Next() {
		show, err := scanShowSummary(rows)
		if err != nil {
			return nil, err
		}
		show.Hosts, err = s.listShowHosts(ctx, show.ID)
		if err != nil {
			return nil, err
		}
		shows = append(shows, show)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return shows, nil
}

func (s *PostgresStore) listCategories(ctx context.Context) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT name
		FROM categories
		WHERE is_active = true
			AND applies_to IN ('show', 'mixed')
		ORDER BY sort_order ASC, name ASC
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	categories := make([]string, 0)
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		if trimmed := strings.TrimSpace(name); trimmed != "" {
			categories = append(categories, trimmed)
		}
	}

	return categories, rows.Err()
}

func (s *PostgresStore) listPreviewEpisodes(ctx context.Context, showID string, limit int) ([]domain.EpisodePreview, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT
			id::text,
			show_id::text,
			title,
			duration_seconds,
			COALESCE(published_at, created_at)
		FROM episodes
		WHERE show_id = $1::uuid
			AND publish_status = 'published'
			AND visibility = 'public'
			AND deleted_at IS NULL
		ORDER BY COALESCE(published_at, created_at) DESC, episode_number DESC NULLS LAST
		LIMIT $2
	`, showID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	episodes := make([]domain.EpisodePreview, 0, limit)
	for rows.Next() {
		var (
			episode         domain.EpisodePreview
			durationSeconds int64
			publishedAt     time.Time
		)
		if err := rows.Scan(
			&episode.ID,
			&episode.ShowID,
			&episode.Title,
			&durationSeconds,
			&publishedAt,
		); err != nil {
			return nil, err
		}
		episode.DurationSeconds = int(durationSeconds)
		episode.PublishedAt = publishedAt
		episodes = append(episodes, episode)
	}

	return episodes, rows.Err()
}

func (s *PostgresStore) listShowCategoryNames(ctx context.Context, showID string) ([]string, error) {
	return s.listStringRows(ctx, `
		SELECT c.name
		FROM show_categories sc
		JOIN categories c ON c.id = sc.category_id
		WHERE sc.show_id = $1::uuid
		ORDER BY sc.is_primary DESC, c.sort_order ASC, c.name ASC
	`, showID)
}

func (s *PostgresStore) listShowTagNames(ctx context.Context, showID string) ([]string, error) {
	return s.listStringRows(ctx, `
		SELECT t.name
		FROM show_tags st
		JOIN tags t ON t.id = st.tag_id
		WHERE st.show_id = $1::uuid
		ORDER BY t.name ASC
	`, showID)
}

func (s *PostgresStore) listEpisodeTagNames(ctx context.Context, episodeID string) ([]string, error) {
	return s.listStringRows(ctx, `
		SELECT t.name
		FROM episode_tags et
		JOIN tags t ON t.id = et.tag_id
		WHERE et.episode_id = $1::uuid
		ORDER BY t.name ASC
	`, episodeID)
}

func (s *PostgresStore) listStringRows(ctx context.Context, query string, arg string) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, query, arg)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]string, 0)
	for rows.Next() {
		var value string
		if err := rows.Scan(&value); err != nil {
			return nil, err
		}
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			items = append(items, trimmed)
		}
	}

	return items, rows.Err()
}

func (s *PostgresStore) showExists(ctx context.Context, showID string) (bool, error) {
	var exists bool
	err := s.db.QueryRowContext(ctx, `
		SELECT EXISTS(
			SELECT 1
			FROM shows
			WHERE id = $1::uuid
				AND publish_status = 'published'
				AND visibility = 'public'
				AND deleted_at IS NULL
		)
	`, showID).Scan(&exists)
	return exists, err
}

func scanShowSummary(scanner interface {
	Scan(dest ...any) error
}) (domain.ShowSummary, error) {
	var (
		show              domain.ShowSummary
		coverImageURL     string
		subscriberCount   int64
		totalEpisodeCount int64
		publishedAt       time.Time
	)

	if err := scanner.Scan(
		&show.ID,
		&show.Slug,
		&show.Title,
		&coverImageURL,
		&show.PrimaryCategory,
		&show.ContentType,
		&subscriberCount,
		&totalEpisodeCount,
		&publishedAt,
	); err != nil {
		return domain.ShowSummary{}, err
	}

	show.CoverImageURL = coverImageURL
	show.SubscriberCount = int(subscriberCount)
	show.TotalEpisodeCount = int(totalEpisodeCount)
	show.PublishedAt = publishedAt

	return show, nil
}

func (s *PostgresStore) listShowHosts(ctx context.Context, showID string) ([]domain.Host, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT
			id::text,
			display_name,
			COALESCE(avatar_url, ''),
			COALESCE(linked_voice_profile_id::text, ''),
			role,
			COALESCE(bio, '')
		FROM show_hosts
		WHERE show_id = $1::uuid
		ORDER BY sort_order ASC, created_at ASC
	`, showID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	hosts := make([]domain.Host, 0)
	for rows.Next() {
		var host domain.Host
		if err := rows.Scan(
			&host.ID,
			&host.DisplayName,
			&host.AvatarURL,
			&host.VoiceProfileID,
			&host.Role,
			&host.Bio,
		); err != nil {
			return nil, err
		}
		hosts = append(hosts, host)
	}

	return hosts, rows.Err()
}

func normalizeCreateHosts(contentType string, inputs []domain.CreateHostInput, slug string) ([]domain.Host, error) {
	if len(inputs) == 0 {
		return nil, errors.New("at least one host is required")
	}
	if contentType == "storytelling" && len(inputs) != 1 {
		return nil, errors.New("storytelling shows require exactly one host")
	}
	if contentType == "podcast" && len(inputs) > 3 {
		return nil, errors.New("podcast shows support at most 3 hosts in v1")
	}

	hosts := make([]domain.Host, 0, len(inputs))
	for index, input := range inputs {
		displayName := strings.TrimSpace(input.DisplayName)
		if displayName == "" {
			return nil, errors.New("each host must have a display name")
		}
		avatarURL := strings.TrimSpace(input.AvatarURL)
		if avatarURL == "" {
			avatarURL = fallbackHostAvatarURL(fmt.Sprintf("%s-%d", slug, index+1))
		}
		role := sanitizeHostRole(contentType, strings.TrimSpace(input.Role), index)
		hosts = append(hosts, domain.Host{
			DisplayName:    displayName,
			AvatarURL:      avatarURL,
			VoiceProfileID: strings.TrimSpace(input.VoiceProfileID),
			Role:           role,
			Bio:            strings.TrimSpace(input.Bio),
		})
	}

	return hosts, nil
}

func resolveShowCategory(ctx context.Context, tx *sql.Tx, value string) (string, string, error) {
	var (
		categoryName string
		categoryID   string
	)

	err := tx.QueryRowContext(ctx, `
		SELECT id::text, name
		FROM categories
		WHERE is_active = true
			AND applies_to IN ('show', 'mixed')
			AND (slug = $1 OR lower(name) = lower($1))
		ORDER BY sort_order ASC, name ASC
		LIMIT 1
	`, value).Scan(&categoryID, &categoryName)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", "", ErrCategoryNotFound
		}
		return "", "", err
	}

	return categoryName, categoryID, nil
}

func ensureUniqueShowSlug(ctx context.Context, tx *sql.Tx, baseSlug string) (string, error) {
	slug := baseSlug
	for index := 2; ; index++ {
		var exists bool
		if err := tx.QueryRowContext(ctx, `
			SELECT EXISTS(
				SELECT 1
				FROM shows
				WHERE slug = $1
			)
		`, slug).Scan(&exists); err != nil {
			return "", err
		}
		if !exists {
			return slug, nil
		}
		slug = fmt.Sprintf("%s-%d", baseSlug, index)
	}
}

func slugifyTitle(title string) string {
	var builder strings.Builder
	previousHyphen := false

	for _, r := range strings.ToLower(strings.TrimSpace(title)) {
		switch {
		case unicode.IsLetter(r) || unicode.IsDigit(r):
			builder.WriteRune(r)
			previousHyphen = false
		default:
			if builder.Len() > 0 && !previousHyphen {
				builder.WriteByte('-')
				previousHyphen = true
			}
		}
	}

	slug := strings.Trim(builder.String(), "-")
	if slug == "" {
		return "show"
	}
	return slug
}

func fallbackOwnerDisplayName(email string) string {
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" {
		return "Creator"
	}
	if at := strings.Index(email, "@"); at > 0 {
		return email[:at]
	}
	return email
}

func sanitizeLanguageCode(value string) string {
	if value == "" {
		return "vi"
	}
	return value
}

func sanitizeContentType(value string) string {
	switch value {
	case "podcast", "storytelling", "news_digest":
		return value
	default:
		return "podcast"
	}
}

func sanitizeHostRole(contentType string, role string, index int) string {
	switch role {
	case "host", "co_host", "guest", "narrator":
		return role
	}
	if contentType == "storytelling" {
		return "narrator"
	}
	if index == 0 {
		return "host"
	}
	return "co_host"
}

func fallbackShowCoverURL(seed string) string {
	return fmt.Sprintf("https://picsum.photos/seed/show-%s/800/800", seed)
}

func fallbackHostAvatarURL(seed string) string {
	return fmt.Sprintf("https://picsum.photos/seed/host-%s/200/200", seed)
}

func fallbackOwnerAvatarURL(seed string) string {
	return fmt.Sprintf("https://picsum.photos/seed/owner-%s/200/200", seed)
}
