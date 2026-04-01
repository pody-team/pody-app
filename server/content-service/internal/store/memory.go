package store

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"
	"time"

	"github.com/promex04/pody/server/content-service/internal/domain"
)

var ErrNotFound = errors.New("not found")

type ContentStore interface {
	GetHomeFeed(ctx context.Context) (domain.HomeFeed, error)
	GetShowDetail(ctx context.Context, showID string) (domain.ShowDetail, error)
	ListShowEpisodes(ctx context.Context, showID string) ([]domain.EpisodeSummary, error)
	GetEpisodeDetail(ctx context.Context, episodeID string) (domain.EpisodeDetail, error)
	ListEpisodeBookmarks(ctx context.Context, userID string) ([]domain.BookmarkedEpisode, error)
	GetEpisodeBookmarkStatus(ctx context.Context, userID string, episodeID string) (domain.EpisodeBookmarkStatus, error)
	SaveEpisodeBookmark(ctx context.Context, userID string, episodeID string) (domain.EpisodeBookmarkStatus, error)
	DeleteEpisodeBookmark(ctx context.Context, userID string, episodeID string) (domain.EpisodeBookmarkStatus, error)
	ListCreatorShows(ctx context.Context, ownerUserID string) ([]domain.ShowSummary, error)
	CreateShow(ctx context.Context, input domain.CreateShowInput) (domain.ShowDetail, error)
}

type demoStore struct {
	homeFeed    domain.HomeFeed
	showDetails map[string]domain.ShowDetail
	episodes    map[string][]domain.EpisodeSummary
	episodeByID map[string]domain.EpisodeDetail
	bookmarks   map[string]map[string]time.Time
	myShows     []domain.ShowSummary
}

func NewDemoStore() ContentStore {
	now := time.Date(2026, time.March, 17, 8, 0, 0, 0, time.UTC)

	futureMindsHost := domain.Host{
		ID:             "ai-host-nova",
		DisplayName:    "Nova",
		AvatarURL:      "https://picsum.photos/seed/nova-host/200/200",
		VoiceProfileID: "vi-vn-nova-01",
		Role:           "host",
		Bio:            "AI host cua Future Minds, chuyen bien cac chu de cong nghe thanh nhung cuoc tro chuyen de nghe va de nho.",
	}
	detectiveHost := domain.Host{
		ID:             "ai-host-minh-tra",
		DisplayName:    "Minh Tra",
		AvatarURL:      "https://picsum.photos/seed/minh-tra-host/200/200",
		VoiceProfileID: "vi-vn-minh-tra-01",
		Role:           "host",
		Bio:            "AI narrator chuyen ke cac ho so dieu tra, tap trung vao nhịp kể chậm va tạo không khí.",
	}
	lumiHost := domain.Host{
		ID:             "ai-host-lumi",
		DisplayName:    "Lumi",
		AvatarURL:      "https://picsum.photos/seed/lumi-host/200/200",
		VoiceProfileID: "vi-vn-lumi-01",
		Role:           "host",
		Bio:            "AI host cho nhung episode nhe nhang, cham va de nghe vao buoi toi.",
	}

	podyOwner := domain.OwnerSummary{
		ID:          "creator-pody-studio",
		DisplayName: "Pody Studio",
		AvatarURL:   "https://picsum.photos/seed/pody-owner/200/200",
	}

	futureMindsSummary := domain.ShowSummary{
		ID:                "show-future-minds",
		Slug:              "future-minds",
		Title:             "Future Minds",
		CoverImageURL:     "https://picsum.photos/seed/future-minds-cover/800/800",
		PrimaryCategory:   "Cong nghe",
		Hosts:             []domain.Host{futureMindsHost},
		ContentType:       "podcast",
		SubscriberCount:   12500,
		TotalEpisodeCount: 3,
		PublishedAt:       now.Add(-72 * time.Hour),
	}
	trueCrimeSummary := domain.ShowSummary{
		ID:                "show-true-crime-daily",
		Slug:              "true-crime-daily",
		Title:             "True Crime Daily",
		CoverImageURL:     "https://picsum.photos/seed/true-crime-daily/800/800",
		PrimaryCategory:   "Dieu tra",
		Hosts:             []domain.Host{detectiveHost},
		ContentType:       "storytelling",
		SubscriberCount:   8200,
		TotalEpisodeCount: 2,
		PublishedAt:       now.Add(-96 * time.Hour),
	}
	mindfulSummary := domain.ShowSummary{
		ID:                "show-midnight-reset",
		Slug:              "midnight-reset",
		Title:             "Midnight Reset",
		CoverImageURL:     "https://picsum.photos/seed/midnight-reset/800/800",
		PrimaryCategory:   "Cham soc ban than",
		Hosts:             []domain.Host{lumiHost},
		ContentType:       "storytelling",
		SubscriberCount:   5600,
		TotalEpisodeCount: 0,
		PublishedAt:       now.Add(-48 * time.Hour),
	}

	showEpisodes := map[string][]domain.EpisodeSummary{
		futureMindsSummary.ID: {
			{
				ID:              "ep-future-minds-001",
				ShowID:          futureMindsSummary.ID,
				Title:           "MVC thoi hien dai: cu nhung khong ky",
				Description:     "Tong hop lai vi sao MVC van song tot va khi nao nen chuyen sang MVVM.",
				CoverImageURL:   futureMindsSummary.CoverImageURL,
				DurationSeconds: 32 * 60,
				PublishedAt:     now.Add(-48 * time.Hour),
				EpisodeNumber:   1,
			},
			{
				ID:              "ep-future-minds-002",
				ShowID:          futureMindsSummary.ID,
				Title:           "Nhìn nhanh ve MVVM va MVP",
				Description:     "So sanh hai pattern pho bien trong mobile development.",
				CoverImageURL:   futureMindsSummary.CoverImageURL,
				DurationSeconds: 28 * 60,
				PublishedAt:     now.Add(-72 * time.Hour),
				EpisodeNumber:   2,
			},
			{
				ID:              "ep-future-minds-003",
				ShowID:          futureMindsSummary.ID,
				Title:           "Clean Architecture thuc chien",
				Description:     "Nhung bai hoc dau tay khi dua clean architecture vao du an that.",
				CoverImageURL:   futureMindsSummary.CoverImageURL,
				DurationSeconds: 35 * 60,
				PublishedAt:     now.Add(-96 * time.Hour),
				EpisodeNumber:   3,
			},
		},
		trueCrimeSummary.ID: {
			{
				ID:              "ep-true-crime-001",
				ShowID:          trueCrimeSummary.ID,
				Title:           "Ho so 1995 va vet ADN bi bo sot",
				Description:     "Mot vu an nguoi ta tuong da nguoi lanh, nhung ADN moi da ke lai cau chuyen khac.",
				CoverImageURL:   trueCrimeSummary.CoverImageURL,
				DurationSeconds: 45 * 60,
				PublishedAt:     now.Add(-24 * time.Hour),
				EpisodeNumber:   1,
			},
			{
				ID:              "ep-true-crime-002",
				ShowID:          trueCrimeSummary.ID,
				Title:           "Camera an ninh da noi gi trong 17 giay cuoi",
				Description:     "Toan bo timeline cua mot dem mat tich duoc lap lai tu nhung khung hinh rat mo.",
				CoverImageURL:   trueCrimeSummary.CoverImageURL,
				DurationSeconds: 39 * 60,
				PublishedAt:     now.Add(-60 * time.Hour),
				EpisodeNumber:   2,
			},
		},
		mindfulSummary.ID: {},
	}

	episodeByID := map[string]domain.EpisodeDetail{
		"ep-future-minds-001": {
			ID:              "ep-future-minds-001",
			ShowID:          futureMindsSummary.ID,
			Title:           "MVC thoi hien dai: cu nhung khong ky",
			Description:     "Nova di tu nhung nguyen ly can ban cua MVC, tai sao kieu tach Model View Controller van hop ly, va luc nao can mot tang ViewModel thuc su.",
			AudioURL:        "https://example.com/audio/future-minds-001.mp3",
			CoverImageURL:   futureMindsSummary.CoverImageURL,
			DurationSeconds: 32 * 60,
			PublishedAt:     now.Add(-48 * time.Hour),
			EpisodeNumber:   1,
			Tags:            []string{"AI", "Architecture", "Mobile"},
			LikeCount:       12500,
			CommentCount:    842,
			Transcript: &domain.EpisodeTranscript{
				Status:          "completed",
				Language:        "vi",
				AlignmentMethod: "mms_fa",
				AssetURL:        "https://example.com/audio/future-minds-001.transcript.json",
				Text:            "Nova di tu nhung nguyen ly can ban cua MVC va khi nao can mot tang ViewModel.",
				DurationSeconds: 32 * 60,
				Segments: []domain.TranscriptSegment{
					{
						Speaker:      "Nova",
						StartSeconds: 0,
						EndSeconds:   18.4,
						Text:         "Hom nay minh bat dau tu cau hoi co ban: MVC co con hop ly khong?",
						Words: []domain.TranscriptWord{
							{StartSeconds: 0, EndSeconds: 0.4, Text: "Hom"},
							{StartSeconds: 0.4, EndSeconds: 0.8, Text: "nay"},
							{StartSeconds: 0.8, EndSeconds: 1.2, Text: "minh"},
						},
					},
					{
						Speaker:      "Nova",
						StartSeconds: 18.4,
						EndSeconds:   41.8,
						Text:         "Neu boundary giua data, UI va event van ro, MVC van rat de ship.",
					},
				},
			},
		},
		"ep-future-minds-002": {
			ID:              "ep-future-minds-002",
			ShowID:          futureMindsSummary.ID,
			Title:           "Nhìn nhanh ve MVVM va MVP",
			Description:     "Mot tap de nghe nhanh nhung du cu the de phan biet MVVM, MVP va khi nao team nen chon moi huong.",
			AudioURL:        "https://example.com/audio/future-minds-002.mp3",
			CoverImageURL:   futureMindsSummary.CoverImageURL,
			DurationSeconds: 28 * 60,
			PublishedAt:     now.Add(-72 * time.Hour),
			EpisodeNumber:   2,
			Tags:            []string{"Architecture", "MVVM", "MVP"},
			LikeCount:       8300,
			CommentCount:    421,
		},
		"ep-future-minds-003": {
			ID:              "ep-future-minds-003",
			ShowID:          futureMindsSummary.ID,
			Title:           "Clean Architecture thuc chien",
			Description:     "Tap nay tong hop ba sai lam pho bien nhat khi dua clean architecture vao san pham dang ship.",
			AudioURL:        "https://example.com/audio/future-minds-003.mp3",
			CoverImageURL:   futureMindsSummary.CoverImageURL,
			DurationSeconds: 35 * 60,
			PublishedAt:     now.Add(-96 * time.Hour),
			EpisodeNumber:   3,
			Tags:            []string{"Clean Architecture", "Product"},
			LikeCount:       6100,
			CommentCount:    310,
		},
		"ep-true-crime-001": {
			ID:              "ep-true-crime-001",
			ShowID:          trueCrimeSummary.ID,
			Title:           "Ho so 1995 va vet ADN bi bo sot",
			Description:     "Minh Tra ke lai qua trinh mo lai mot ho so lanh khi mot mau ADN cu bat ngo khop voi du lieu moi.",
			AudioURL:        "https://example.com/audio/true-crime-001.mp3",
			CoverImageURL:   trueCrimeSummary.CoverImageURL,
			DurationSeconds: 45 * 60,
			PublishedAt:     now.Add(-24 * time.Hour),
			EpisodeNumber:   1,
			Tags:            []string{"True Crime", "DNA", "Investigation"},
			LikeCount:       84200,
			CommentCount:    5200,
		},
		"ep-true-crime-002": {
			ID:              "ep-true-crime-002",
			ShowID:          trueCrimeSummary.ID,
			Title:           "Camera an ninh da noi gi trong 17 giay cuoi",
			Description:     "Mot timeline duoc lap lai tu nhung khung hinh rat mo, va vi sao 17 giay co the thay doi toan bo ket luan.",
			AudioURL:        "https://example.com/audio/true-crime-002.mp3",
			CoverImageURL:   trueCrimeSummary.CoverImageURL,
			DurationSeconds: 39 * 60,
			PublishedAt:     now.Add(-60 * time.Hour),
			EpisodeNumber:   2,
			Tags:            []string{"Investigation", "Timeline"},
			LikeCount:       43100,
			CommentCount:    2100,
		},
	}

	showDetails := map[string]domain.ShowDetail{
		futureMindsSummary.ID: {
			ID:                futureMindsSummary.ID,
			Slug:              futureMindsSummary.Slug,
			Title:             futureMindsSummary.Title,
			Description:       "Show cong nghe do AI host Nova dan dat, bien nhung chu de ky thuat thanh cuoc tro chuyen de theo doi va de nho.",
			CoverImageURL:     futureMindsSummary.CoverImageURL,
			Categories:        []string{"Cong nghe", "Giai thich de hieu"},
			Tags:              []string{"AI", "Tech", "Weekly"},
			Hosts:             []domain.Host{futureMindsHost},
			Owner:             podyOwner,
			SubscriberCount:   futureMindsSummary.SubscriberCount,
			TotalEpisodeCount: futureMindsSummary.TotalEpisodeCount,
			TotalListenCount:  1200000,
			LanguageCode:      "vi",
			ContentType:       "podcast",
			Visibility:        "public",
			MonetizationType:  "free",
			PublishedAt:       futureMindsSummary.PublishedAt,
		},
		trueCrimeSummary.ID: {
			ID:                trueCrimeSummary.ID,
			Slug:              trueCrimeSummary.Slug,
			Title:             trueCrimeSummary.Title,
			Description:       "Nhung ho so hinh su duoc ke lai theo nhịp dieu tra cham, ro va co khong khi, do AI host Minh Tra dan dat.",
			CoverImageURL:     trueCrimeSummary.CoverImageURL,
			Categories:        []string{"Dieu tra", "Chuyen ke"},
			Tags:              []string{"Crime", "Case Files", "Night Listening"},
			Hosts:             []domain.Host{detectiveHost},
			Owner:             podyOwner,
			SubscriberCount:   trueCrimeSummary.SubscriberCount,
			TotalEpisodeCount: trueCrimeSummary.TotalEpisodeCount,
			TotalListenCount:  860000,
			LanguageCode:      "vi",
			ContentType:       "storytelling",
			Visibility:        "public",
			MonetizationType:  "free",
			PublishedAt:       trueCrimeSummary.PublishedAt,
		},
		mindfulSummary.ID: {
			ID:                mindfulSummary.ID,
			Slug:              mindfulSummary.Slug,
			Title:             mindfulSummary.Title,
			Description:       "Mot show chua co tap nao nhung da san sang voi AI host Lumi, danh cho cac episode tam su va reset cuoi ngay.",
			CoverImageURL:     mindfulSummary.CoverImageURL,
			Categories:        []string{"Cham soc ban than", "Ngu ngon"},
			Tags:              []string{"Night", "Reflection"},
			Hosts:             []domain.Host{lumiHost},
			Owner:             podyOwner,
			SubscriberCount:   mindfulSummary.SubscriberCount,
			TotalEpisodeCount: mindfulSummary.TotalEpisodeCount,
			TotalListenCount:  42000,
			LanguageCode:      "vi",
			ContentType:       "storytelling",
			Visibility:        "public",
			MonetizationType:  "free",
			PublishedAt:       mindfulSummary.PublishedAt,
		},
	}

	return &demoStore{
		homeFeed: domain.HomeFeed{
			Categories: []string{"Tat ca", "Cong nghe", "Dieu tra", "Cham soc ban than"},
			Shows: []domain.HomeShowCard{
				{Show: futureMindsSummary, PreviewEpisodes: toPreviewEpisodes(showEpisodes[futureMindsSummary.ID], 3)},
				{Show: trueCrimeSummary, PreviewEpisodes: toPreviewEpisodes(showEpisodes[trueCrimeSummary.ID], 2)},
				{Show: mindfulSummary, PreviewEpisodes: toPreviewEpisodes(showEpisodes[mindfulSummary.ID], 2)},
			},
		},
		showDetails: showDetails,
		episodes:    showEpisodes,
		episodeByID: episodeByID,
		bookmarks:   map[string]map[string]time.Time{},
		myShows:     []domain.ShowSummary{futureMindsSummary, mindfulSummary},
	}
}

func (s *demoStore) GetHomeFeed(_ context.Context) (domain.HomeFeed, error) {
	return s.homeFeed, nil
}

func (s *demoStore) GetShowDetail(_ context.Context, showID string) (domain.ShowDetail, error) {
	show, ok := s.showDetails[strings.TrimSpace(showID)]
	if !ok {
		return domain.ShowDetail{}, ErrNotFound
	}

	return show, nil
}

func (s *demoStore) ListShowEpisodes(_ context.Context, showID string) ([]domain.EpisodeSummary, error) {
	episodes, ok := s.episodes[strings.TrimSpace(showID)]
	if !ok {
		return nil, ErrNotFound
	}

	return slices.Clone(episodes), nil
}

func (s *demoStore) GetEpisodeDetail(_ context.Context, episodeID string) (domain.EpisodeDetail, error) {
	episode, ok := s.episodeByID[strings.TrimSpace(episodeID)]
	if !ok {
		return domain.EpisodeDetail{}, ErrNotFound
	}

	return episode, nil
}

func (s *demoStore) ListEpisodeBookmarks(_ context.Context, userID string) ([]domain.BookmarkedEpisode, error) {
	bookmarks := s.bookmarks[strings.TrimSpace(userID)]
	if len(bookmarks) == 0 {
		return []domain.BookmarkedEpisode{}, nil
	}

	items := make([]domain.BookmarkedEpisode, 0, len(bookmarks))
	for episodeID, bookmarkedAt := range bookmarks {
		episode, ok := s.episodeByID[episodeID]
		if !ok {
			continue
		}
		show, ok := s.showDetails[episode.ShowID]
		if !ok {
			continue
		}
		items = append(items, domain.BookmarkedEpisode{
			Episode: domain.EpisodeSummary{
				ID:              episode.ID,
				ShowID:          episode.ShowID,
				Title:           episode.Title,
				Description:     episode.Description,
				CoverImageURL:   episode.CoverImageURL,
				DurationSeconds: episode.DurationSeconds,
				PublishedAt:     episode.PublishedAt,
				EpisodeNumber:   episode.EpisodeNumber,
			},
			Show: domain.ShowSummary{
				ID:                show.ID,
				Slug:              show.Slug,
				Title:             show.Title,
				CoverImageURL:     show.CoverImageURL,
				PrimaryCategory:   fallbackFirst(show.Categories),
				Hosts:             append([]domain.Host{}, show.Hosts...),
				ContentType:       show.ContentType,
				SubscriberCount:   show.SubscriberCount,
				TotalEpisodeCount: show.TotalEpisodeCount,
				PublishedAt:       show.PublishedAt,
			},
			BookmarkedAt: bookmarkedAt,
		})
	}

	slices.SortFunc(items, func(left, right domain.BookmarkedEpisode) int {
		return right.BookmarkedAt.Compare(left.BookmarkedAt)
	})

	return items, nil
}

func (s *demoStore) GetEpisodeBookmarkStatus(_ context.Context, userID string, episodeID string) (domain.EpisodeBookmarkStatus, error) {
	episodeID = strings.TrimSpace(episodeID)
	if _, ok := s.episodeByID[episodeID]; !ok {
		return domain.EpisodeBookmarkStatus{}, ErrNotFound
	}
	bookmarks := s.bookmarks[strings.TrimSpace(userID)]
	_, exists := bookmarks[episodeID]
	return domain.EpisodeBookmarkStatus{
		EpisodeID:    episodeID,
		IsBookmarked: exists,
	}, nil
}

func (s *demoStore) SaveEpisodeBookmark(_ context.Context, userID string, episodeID string) (domain.EpisodeBookmarkStatus, error) {
	episodeID = strings.TrimSpace(episodeID)
	userID = strings.TrimSpace(userID)
	if _, ok := s.episodeByID[episodeID]; !ok {
		return domain.EpisodeBookmarkStatus{}, ErrNotFound
	}
	if s.bookmarks[userID] == nil {
		s.bookmarks[userID] = map[string]time.Time{}
	}
	s.bookmarks[userID][episodeID] = time.Now().UTC()
	return domain.EpisodeBookmarkStatus{EpisodeID: episodeID, IsBookmarked: true}, nil
}

func (s *demoStore) DeleteEpisodeBookmark(_ context.Context, userID string, episodeID string) (domain.EpisodeBookmarkStatus, error) {
	episodeID = strings.TrimSpace(episodeID)
	userID = strings.TrimSpace(userID)
	if _, ok := s.episodeByID[episodeID]; !ok {
		return domain.EpisodeBookmarkStatus{}, ErrNotFound
	}
	if s.bookmarks[userID] != nil {
		delete(s.bookmarks[userID], episodeID)
	}
	return domain.EpisodeBookmarkStatus{EpisodeID: episodeID, IsBookmarked: false}, nil
}

func (s *demoStore) ListCreatorShows(_ context.Context, ownerUserID string) ([]domain.ShowSummary, error) {
	if strings.TrimSpace(ownerUserID) == "" {
		return nil, ErrNotFound
	}

	return slices.Clone(s.myShows), nil
}

func (s *demoStore) CreateShow(_ context.Context, input domain.CreateShowInput) (domain.ShowDetail, error) {
	title := strings.TrimSpace(input.Title)
	category := strings.TrimSpace(input.PrimaryCategory)
	ownerUserID := strings.TrimSpace(input.OwnerUserID)
	ownerDisplayName := strings.TrimSpace(input.OwnerDisplayName)
	contentType := fallbackString(strings.TrimSpace(input.ContentType), "podcast")
	if title == "" || category == "" || ownerUserID == "" {
		return domain.ShowDetail{}, errors.New("title, primary category, and owner user id are required")
	}

	if ownerDisplayName == "" {
		ownerDisplayName = fallbackDisplayName(input.OwnerEmail)
	}

	now := time.Now().UTC()
	id := fmt.Sprintf("show-%d", now.UnixNano())
	slug := strings.ToLower(strings.ReplaceAll(title, " ", "-"))
	coverImageURL := strings.TrimSpace(input.CoverImageURL)
	hosts, err := normalizeCreateHosts(contentType, input.Hosts)
	if err != nil {
		return domain.ShowDetail{}, err
	}
	ownerAvatarURL := ""

	show := domain.ShowDetail{
		ID:            id,
		Slug:          slug,
		Title:         title,
		Description:   strings.TrimSpace(input.Description),
		CoverImageURL: coverImageURL,
		Categories:    []string{category},
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
		LanguageCode:      fallbackString(strings.TrimSpace(input.LanguageCode), "vi"),
		ContentType:       contentType,
		Visibility:        "public",
		MonetizationType:  "free",
		PublishedAt:       time.Time{},
	}
	for index := range show.Hosts {
		show.Hosts[index].ID = fmt.Sprintf("host-%d-%d", now.UnixNano(), index+1)
	}

	s.showDetails[show.ID] = show
	s.episodes[show.ID] = []domain.EpisodeSummary{}
	summary := domain.ShowSummary{
		ID:                show.ID,
		Slug:              show.Slug,
		Title:             show.Title,
		CoverImageURL:     show.CoverImageURL,
		PrimaryCategory:   category,
		Hosts:             show.Hosts,
		ContentType:       show.ContentType,
		SubscriberCount:   show.SubscriberCount,
		TotalEpisodeCount: show.TotalEpisodeCount,
		PublishedAt:       show.PublishedAt,
	}
	s.myShows = append([]domain.ShowSummary{summary}, s.myShows...)
	categoryExists := false
	for _, existing := range s.homeFeed.Categories {
		if strings.EqualFold(strings.TrimSpace(existing), category) {
			categoryExists = true
			break
		}
	}
	if !categoryExists {
		s.homeFeed.Categories = append(s.homeFeed.Categories, category)
	}

	return show, nil
}

func toPreviewEpisodes(episodes []domain.EpisodeSummary, limit int) []domain.EpisodePreview {
	if limit <= 0 || len(episodes) == 0 {
		return nil
	}
	if len(episodes) < limit {
		limit = len(episodes)
	}

	items := make([]domain.EpisodePreview, 0, limit)
	for _, episode := range episodes[:limit] {
		items = append(items, domain.EpisodePreview{
			ID:              episode.ID,
			ShowID:          episode.ShowID,
			Title:           episode.Title,
			DurationSeconds: episode.DurationSeconds,
			PublishedAt:     episode.PublishedAt,
		})
	}

	return items
}

func fallbackDisplayName(email string) string {
	email = strings.TrimSpace(strings.ToLower(email))
	if email == "" {
		return "Creator"
	}
	if at := strings.Index(email, "@"); at > 0 {
		return email[:at]
	}
	return email
}

func fallbackString(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

func fallbackFirst(values []string) string {
	if len(values) == 0 {
		return ""
	}
	return strings.TrimSpace(values[0])
}
