package config

import (
	"fmt"
	"net/url"
	"os"
	"strings"
	"time"
)

type ServiceRoute struct {
	Name      string `json:"name"`
	Prefix    string `json:"prefix"`
	TargetURL string `json:"target_url"`
}

type Config struct {
	Port            string
	AllowedOrigins  []string
	ReadTimeout     time.Duration
	WriteTimeout    time.Duration
	IdleTimeout     time.Duration
	ShutdownTimeout time.Duration
	JWTSecret       string
	AuthSkipPaths   []string
	Routes          []ServiceRoute
}

type serviceEnv struct {
	Name         string
	Prefix       string
	EnvKey       string
	DefaultURL   string
	UpstreamPath string
}

var serviceEnvs = []serviceEnv{
	{Name: "identity-public", Prefix: "/api/v1/public/identity", EnvKey: "IDENTITY_SERVICE_URL", DefaultURL: "http://localhost:8081", UpstreamPath: "/api/v1/public/identity"},
	{Name: "notifications-public", Prefix: "/api/v1/public/notifications", EnvKey: "NOTIFICATION_SERVICE_URL", DefaultURL: "http://localhost:8087", UpstreamPath: "/api/v1/public/notifications"},
	{Name: "content-public", Prefix: "/api/v1/public/content", EnvKey: "CONTENT_SERVICE_URL", DefaultURL: "http://localhost:8082", UpstreamPath: "/api/v1/public/content"},
	{Name: "ai-public", Prefix: "/api/v1/public/ai", EnvKey: "AI_SERVICE_URL", DefaultURL: "http://localhost:8085", UpstreamPath: "/api/v1/public/ai"},
	{Name: "identity", Prefix: "/api/v1/identity", EnvKey: "IDENTITY_SERVICE_URL", DefaultURL: "http://localhost:8081", UpstreamPath: "/api/v1/identity"},
	{Name: "content", Prefix: "/api/v1/content", EnvKey: "CONTENT_SERVICE_URL", DefaultURL: "http://localhost:8082", UpstreamPath: "/api/v1/content"},
	{Name: "social", Prefix: "/api/v1/social", EnvKey: "SOCIAL_SERVICE_URL", DefaultURL: "http://localhost:8083"},
	{Name: "article", Prefix: "/api/v1/article", EnvKey: "ARTICLE_SERVICE_URL", DefaultURL: "http://localhost:8084", UpstreamPath: "/api/v1/article"},
	{Name: "ai", Prefix: "/api/v1/ai", EnvKey: "AI_SERVICE_URL", DefaultURL: "http://localhost:8085", UpstreamPath: "/api/v1/ai"},
	{Name: "billing", Prefix: "/api/v1/billing", EnvKey: "BILLING_SERVICE_URL", DefaultURL: "http://localhost:8086"},
	{Name: "notifications", Prefix: "/api/v1/notifications", EnvKey: "NOTIFICATION_SERVICE_URL", DefaultURL: "http://localhost:8087", UpstreamPath: "/api/v1/notifications"},
}

func Load() (Config, error) {
	readTimeout, err := durationFromEnv("READ_TIMEOUT", 5*time.Second)
	if err != nil {
		return Config{}, err
	}

	writeTimeout, err := durationFromEnv("WRITE_TIMEOUT", 10*time.Second)
	if err != nil {
		return Config{}, err
	}

	idleTimeout, err := durationFromEnv("IDLE_TIMEOUT", 30*time.Second)
	if err != nil {
		return Config{}, err
	}

	shutdownTimeout, err := durationFromEnv("SHUTDOWN_TIMEOUT", 10*time.Second)
	if err != nil {
		return Config{}, err
	}

	routes, err := loadRoutes()
	if err != nil {
		return Config{}, err
	}

	return Config{
		Port:            stringFromEnv("PORT", "8080"),
		AllowedOrigins:  csvFromEnv("ALLOWED_ORIGINS", []string{"*"}),
		ReadTimeout:     readTimeout,
		WriteTimeout:    writeTimeout,
		IdleTimeout:     idleTimeout,
		ShutdownTimeout: shutdownTimeout,
		JWTSecret:       stringFromEnv("JWT_SECRET", "change-me"),
		AuthSkipPaths:   csvFromEnv("AUTH_EXCLUDED_PATHS", nil),
		Routes:          routes,
	}, nil
}

func (c Config) Addr() string {
	return ":" + c.Port
}

func loadRoutes() ([]ServiceRoute, error) {
	routes := make([]ServiceRoute, 0, len(serviceEnvs))

	for _, svc := range serviceEnvs {
		targetURL, err := buildTargetURL(stringFromEnv(svc.EnvKey, svc.DefaultURL), svc.UpstreamPath)
		if err != nil {
			return nil, fmt.Errorf("invalid %s: %w", svc.EnvKey, err)
		}

		routes = append(routes, ServiceRoute{
			Name:      svc.Name,
			Prefix:    svc.Prefix,
			TargetURL: targetURL,
		})
	}

	return routes, nil
}

func stringFromEnv(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	return value
}

func csvFromEnv(key string, fallback []string) []string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parts := strings.Split(value, ",")
	items := make([]string, 0, len(parts))

	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			items = append(items, trimmed)
		}
	}

	if len(items) == 0 {
		return fallback
	}

	return items
}

func durationFromEnv(key string, fallback time.Duration) (time.Duration, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback, nil
	}

	duration, err := time.ParseDuration(value)
	if err != nil {
		return 0, fmt.Errorf("invalid %s: %w", key, err)
	}

	return duration, nil
}

func buildTargetURL(baseURL, upstreamPath string) (string, error) {
	parsed, err := url.ParseRequestURI(baseURL)
	if err != nil {
		return "", err
	}

	if strings.TrimSpace(upstreamPath) != "" {
		parsed.Path = joinURLPaths(parsed.Path, upstreamPath)
	}

	return parsed.String(), nil
}

func joinURLPaths(basePath, extraPath string) string {
	switch {
	case basePath == "" || basePath == "/":
		return extraPath
	case extraPath == "" || extraPath == "/":
		return strings.TrimRight(basePath, "/")
	default:
		return strings.TrimRight(basePath, "/") + "/" + strings.TrimLeft(extraPath, "/")
	}
}
