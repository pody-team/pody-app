package httpserver

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/promex04/pody/server/api-gateway/internal/config"
)

type metaResponse struct {
	Name   string                `json:"name"`
	Status string                `json:"status"`
	Routes []config.ServiceRoute `json:"routes"`
}

func New(cfg config.Config, logger *slog.Logger) *http.Server {
	router := chi.NewRouter()
	router.Use(withCORS(cfg.AllowedOrigins))
	router.Use(withRequestID)
	router.Use(withRecover(logger))
	router.Use(withAccessLog(logger))

	router.Get("/", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, metaResponse{
			Name:   "pody-api-gateway",
			Status: "ok",
			Routes: cfg.Routes,
		})
	})

	router.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	router.Get("/readyz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
	})

	router.NotFound(func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusNotFound, map[string]string{
			"error": "route not found",
		})
	})

	router.MethodNotAllowed(func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{
			"error": "method not allowed",
		})
	})

	router.Route("/api/v1", func(api chi.Router) {
		api.Use(withJWTAuth(cfg.JWTSecret, cfg.AuthSkipPaths))

		api.Get("/_meta/routes", func(w http.ResponseWriter, r *http.Request) {
			writeJSON(w, http.StatusOK, map[string]any{
				"routes": cfg.Routes,
			})
		})

		for _, route := range cfg.Routes {
			proxy, err := newServiceProxy(route, logger)
			if err != nil {
				logger.Error("failed to create proxy", "service", route.Name, "error", err)
				continue
			}

			mountServiceRoute(api, route, proxy)
		}
	})

	return &http.Server{
		Addr:         cfg.Addr(),
		Handler:      router,
		ReadTimeout:  cfg.ReadTimeout,
		WriteTimeout: cfg.WriteTimeout,
		IdleTimeout:  cfg.IdleTimeout,
	}
}

func mountServiceRoute(router chi.Router, route config.ServiceRoute, handler http.Handler) {
	suffix := strings.TrimPrefix(route.Prefix, "/api/v1")
	router.Handle(suffix, handler)
	router.Handle(suffix+"/*", handler)
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)

	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ")
	_ = encoder.Encode(payload)
}
