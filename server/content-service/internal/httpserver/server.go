package httpserver

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/promex04/pody/server/content-service/internal/config"
	"github.com/promex04/pody/server/content-service/internal/domain"
	"github.com/promex04/pody/server/content-service/internal/store"
)

type server struct {
	cfg          config.Config
	logger       *slog.Logger
	contentStore store.ContentStore
}

type createShowRequest struct {
	Title           string                  `json:"title"`
	Description     string                  `json:"description"`
	CoverImageURL   string                  `json:"cover_image_url"`
	PrimaryCategory string                  `json:"primary_category"`
	LanguageCode    string                  `json:"language_code"`
	ContentType     string                  `json:"content_type"`
	Hosts           []createShowHostRequest `json:"hosts"`
}

type createShowHostRequest struct {
	DisplayName    string `json:"display_name"`
	AvatarURL      string `json:"avatar_url"`
	VoiceProfileID string `json:"voice_profile_id"`
	Role           string `json:"role"`
	Bio            string `json:"bio"`
}

type authContext struct {
	UserID string
	Email  string
	Name   string
}

func New(cfg config.Config, logger *slog.Logger, contentStore store.ContentStore) *http.Server {
	s := &server{
		cfg:          cfg,
		logger:       logger,
		contentStore: contentStore,
	}

	router := chi.NewRouter()
	router.Use(s.withRequestLog)
	router.Use(s.withRecover)

	router.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	router.Route("/api/v1/public/content", func(r chi.Router) {
		r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
			writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
		})
		r.Get("/openapi.yaml", s.handleOpenAPI)
		r.Get("/docs", s.handleSwaggerUI)
		r.Get("/home", s.handleHomeFeed)
		r.Get("/shows/{showID}", s.handleShowDetail)
		r.Get("/shows/{showID}/episodes", s.handleShowEpisodes)
		r.Get("/episodes/{episodeID}", s.handleEpisodeDetail)
	})

	router.Route("/api/v1/content", func(r chi.Router) {
		r.Post("/shows", s.handleCreateShow)
		r.Get("/me/shows", s.handleMyShows)
		r.Get("/me/shows/{showID}", s.handleMyShowDetail)
		r.Get("/me/shows/{showID}/episodes", s.handleMyShowEpisodes)
		r.Get("/me/episodes/{episodeID}", s.handleMyEpisodeDetail)
		r.Get("/me/bookmarks", s.handleEpisodeBookmarks)
		r.Get("/me/bookmarks/{episodeID}", s.handleEpisodeBookmarkStatus)
		r.Put("/me/bookmarks/{episodeID}", s.handleSaveEpisodeBookmark)
		r.Delete("/me/bookmarks/{episodeID}", s.handleDeleteEpisodeBookmark)
	})

	return &http.Server{
		Addr:         cfg.Addr(),
		Handler:      router,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		IdleTimeout:  cfg.IdleTimeout,
	}
}

func (s *server) handleHomeFeed(w http.ResponseWriter, r *http.Request) {
	feed, err := s.contentStore.GetHomeFeed(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, feed)
}

func (s *server) handleShowDetail(w http.ResponseWriter, r *http.Request) {
	showID := strings.TrimSpace(chi.URLParam(r, "showID"))
	if showID == "" {
		writeError(w, http.StatusBadRequest, errors.New("show id is required"))
		return
	}

	show, err := s.contentStore.GetShowDetail(r.Context(), showID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, errors.New("show not found"))
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"show": show})
}

func (s *server) handleShowEpisodes(w http.ResponseWriter, r *http.Request) {
	showID := strings.TrimSpace(chi.URLParam(r, "showID"))
	if showID == "" {
		writeError(w, http.StatusBadRequest, errors.New("show id is required"))
		return
	}

	episodes, err := s.contentStore.ListShowEpisodes(r.Context(), showID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, errors.New("show not found"))
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"episodes": episodes})
}

func (s *server) handleEpisodeDetail(w http.ResponseWriter, r *http.Request) {
	episodeID := strings.TrimSpace(chi.URLParam(r, "episodeID"))
	if episodeID == "" {
		writeError(w, http.StatusBadRequest, errors.New("episode id is required"))
		return
	}

	episode, err := s.contentStore.GetEpisodeDetail(r.Context(), episodeID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, errors.New("episode not found"))
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"episode": episode})
}

func (s *server) handleMyShows(w http.ResponseWriter, r *http.Request) {
	auth, ok := authContextFromRequest(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return
	}

	shows, err := s.contentStore.ListCreatorShows(r.Context(), auth.UserID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeJSON(w, http.StatusOK, map[string]any{"shows": []any{}})
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"shows": shows})
}

func (s *server) handleMyShowDetail(w http.ResponseWriter, r *http.Request) {
	auth, showID, ok := s.authenticatedShowIDRequest(w, r)
	if !ok {
		return
	}

	show, err := s.contentStore.GetCreatorShowDetail(r.Context(), auth.UserID, showID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, errors.New("show not found"))
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"show": show})
}

func (s *server) handleMyShowEpisodes(w http.ResponseWriter, r *http.Request) {
	auth, showID, ok := s.authenticatedShowIDRequest(w, r)
	if !ok {
		return
	}

	episodes, err := s.contentStore.ListCreatorShowEpisodes(r.Context(), auth.UserID, showID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, errors.New("show not found"))
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"episodes": episodes})
}

func (s *server) handleMyEpisodeDetail(w http.ResponseWriter, r *http.Request) {
	auth, episodeID, ok := s.authenticatedEpisodeIDRequest(w, r)
	if !ok {
		return
	}

	episode, err := s.contentStore.GetCreatorEpisodeDetail(r.Context(), auth.UserID, episodeID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, errors.New("episode not found"))
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"episode": episode})
}

func (s *server) handleEpisodeBookmarks(w http.ResponseWriter, r *http.Request) {
	auth, ok := authContextFromRequest(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return
	}

	bookmarks, err := s.contentStore.ListEpisodeBookmarks(r.Context(), auth.UserID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{"bookmarks": bookmarks})
}

func (s *server) handleCreateShow(w http.ResponseWriter, r *http.Request) {
	auth, ok := authContextFromRequest(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return
	}

	var request createShowRequest
	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, errors.New("invalid request body"))
		return
	}

	show, err := s.contentStore.CreateShow(r.Context(), domain.CreateShowInput{
		OwnerUserID:      auth.UserID,
		OwnerDisplayName: auth.Name,
		OwnerEmail:       auth.Email,
		Title:            request.Title,
		Description:      request.Description,
		CoverImageURL:    request.CoverImageURL,
		PrimaryCategory:  request.PrimaryCategory,
		LanguageCode:     request.LanguageCode,
		ContentType:      request.ContentType,
		Hosts:            mapCreateHosts(request.Hosts),
	})
	if err != nil {
		switch {
		case errors.Is(err, store.ErrCategoryNotFound):
			writeError(w, http.StatusBadRequest, errors.New("primary category was not found"))
		default:
			if strings.Contains(strings.ToLower(err.Error()), "required") {
				writeError(w, http.StatusBadRequest, err)
				return
			}
			writeError(w, http.StatusInternalServerError, err)
		}
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{"show": show})
}

func (s *server) handleEpisodeBookmarkStatus(w http.ResponseWriter, r *http.Request) {
	auth, episodeID, ok := s.authenticatedEpisodeIDRequest(w, r)
	if !ok {
		return
	}

	status, err := s.contentStore.GetEpisodeBookmarkStatus(r.Context(), auth.UserID, episodeID)
	if err != nil {
		s.writeBookmarkError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, status)
}

func (s *server) handleSaveEpisodeBookmark(w http.ResponseWriter, r *http.Request) {
	auth, episodeID, ok := s.authenticatedEpisodeIDRequest(w, r)
	if !ok {
		return
	}

	status, err := s.contentStore.SaveEpisodeBookmark(r.Context(), auth.UserID, episodeID)
	if err != nil {
		s.writeBookmarkError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, status)
}

func (s *server) handleDeleteEpisodeBookmark(w http.ResponseWriter, r *http.Request) {
	auth, episodeID, ok := s.authenticatedEpisodeIDRequest(w, r)
	if !ok {
		return
	}

	status, err := s.contentStore.DeleteEpisodeBookmark(r.Context(), auth.UserID, episodeID)
	if err != nil {
		s.writeBookmarkError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, status)
}

func mapCreateHosts(items []createShowHostRequest) []domain.CreateHostInput {
	hosts := make([]domain.CreateHostInput, 0, len(items))
	for _, item := range items {
		hosts = append(hosts, domain.CreateHostInput{
			DisplayName:    item.DisplayName,
			AvatarURL:      item.AvatarURL,
			VoiceProfileID: item.VoiceProfileID,
			Role:           item.Role,
			Bio:            item.Bio,
		})
	}
	return hosts
}

func (s *server) authenticatedEpisodeIDRequest(w http.ResponseWriter, r *http.Request) (authContext, string, bool) {
	auth, ok := authContextFromRequest(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return authContext{}, "", false
	}

	episodeID := strings.TrimSpace(chi.URLParam(r, "episodeID"))
	if episodeID == "" {
		writeError(w, http.StatusBadRequest, errors.New("episode id is required"))
		return authContext{}, "", false
	}

	return auth, episodeID, true
}

func (s *server) authenticatedShowIDRequest(w http.ResponseWriter, r *http.Request) (authContext, string, bool) {
	auth, ok := authContextFromRequest(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, errors.New("missing auth user id"))
		return authContext{}, "", false
	}

	showID := strings.TrimSpace(chi.URLParam(r, "showID"))
	if showID == "" {
		writeError(w, http.StatusBadRequest, errors.New("show id is required"))
		return authContext{}, "", false
	}

	return auth, showID, true
}

func (s *server) writeBookmarkError(w http.ResponseWriter, err error) {
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, errors.New("episode not found"))
		return
	}
	writeError(w, http.StatusInternalServerError, err)
}

func authContextFromRequest(r *http.Request) (authContext, bool) {
	userID := strings.TrimSpace(r.Header.Get("X-Auth-User-ID"))
	if userID == "" {
		return authContext{}, false
	}

	return authContext{
		UserID: userID,
		Email:  strings.TrimSpace(r.Header.Get("X-Auth-Email")),
		Name:   strings.TrimSpace(r.Header.Get("X-Auth-Name")),
	}, true
}

func (s *server) withRequestLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		next.ServeHTTP(w, r)
		s.logger.Info("request completed", "method", r.Method, "path", r.URL.Path)
	})
}

func (s *server) withRecover(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				s.logger.Error("panic recovered", "panic", recovered)
				writeError(w, http.StatusInternalServerError, errors.New("internal server error"))
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, err error) {
	writeJSON(w, status, map[string]string{"error": err.Error()})
}
